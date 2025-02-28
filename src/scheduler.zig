const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;
const LiquoriceClient = @import("root.zig").LiquoriceClient;

const TimerType = enum {
    APP_TOKEN_UPDATE,
    SHUTDOWN,
};

pub const AppTimerCallback = *const fn (*LiquoriceClient) u32;

pub const TimerData = struct {
    _timer_fd: posix.fd_t,
    type: TimerType,
    data: union(TimerType) {
        APP_TOKEN_UPDATE: *LiquoriceClient,
        SHUTDOWN: void,
    },
    callback: union(TimerType) {
        APP_TOKEN_UPDATE: AppTimerCallback,
        SHUTDOWN: void,
    },
};

/// Spawn a callback thread through the worker pool
noinline fn handle_callback(data: *TimerData) void {
    const newtime = switch (data.type) {
        .APP_TOKEN_UPDATE => data.callback.APP_TOKEN_UPDATE(data.data.APP_TOKEN_UPDATE),
        .SHUTDOWN => unreachable,
    };
    if (newtime > 0) {
        const timerspec: posix.system.itimerspec = .{
            .it_interval = .{ .sec = 0, .nsec = 0 },
            .it_value = .{ .sec = newtime, .nsec = 0 },
        };
        posix.timerfd_settime(data._timer_fd, .{}, &timerspec, null) catch |err| {
            std.debug.panic("Unable to update timer_fd: {any}", .{err});
        };
    }
}

pub const SchedulerError = error{
    /// Tried to perform something that isn't allowed
    InvalidOperation,
};

pub const LiquoriceScheduler = struct {
    mtx: std.Thread.Mutex,
    pending: std.ArrayList(*TimerData),
    allocator: std.mem.Allocator,
    epoll_fd: i32,
    shutdown_fd: i32,
    main_thread: ?std.Thread = null,
    worker_pool: std.Thread.Pool,

    pub fn register_app_token(self: *LiquoriceScheduler, client: *LiquoriceClient, callback: AppTimerCallback) !void {
        // register a new timer
        const timerfd = try posix.timerfd_create(.MONOTONIC, .{ .CLOEXEC = true });
        const timerspec: posix.system.itimerspec = .{
            .it_interval = .{ .sec = 0, .nsec = 0 },
            .it_value = .{ .sec = 5, .nsec = 0 },
        };
        try posix.timerfd_settime(timerfd, .{}, &timerspec, null);

        // set up the data
        const data: *TimerData = try self.allocator.create(TimerData);
        data.* = .{
            ._timer_fd = timerfd,
            .type = .APP_TOKEN_UPDATE,
            .data = .{ .APP_TOKEN_UPDATE = client },
            .callback = .{ .APP_TOKEN_UPDATE = callback },
        };

        // register this new fd with epoll
        var event: linux.epoll_event = .{ .events = linux.EPOLL.IN | linux.EPOLL.ET, .data = .{ .ptr = @intFromPtr(data) } };
        try posix.epoll_ctl(self.epoll_fd, linux.EPOLL.CTL_ADD, timerfd, &event);

        // accessing the array list, so lock the mutex now
        self.mtx.lock();
        defer self.mtx.unlock();

        // register the new fd in the array list
        try self.pending.append(data);
    }

    fn _listen(self: *LiquoriceScheduler) !void {
        var ready_list: [16]linux.epoll_event = undefined;
        var alive = true;
        while (alive) outer: {
            const ready_count = posix.epoll_wait(self.epoll_fd, &ready_list, -1);

            // theoretically, we should -never- see this
            // but if we do, it's a good sign we should shut down
            if (ready_count == 0) {
                alive = false;
                break :outer;
            }

            // loop through the ready timers/events
            for (ready_list[0..ready_count]) |ready| {
                const data: *TimerData = @ptrFromInt(ready.data.ptr);
                if (data.type == .SHUTDOWN) {
                    alive = false;
                    break :outer;
                }
                try self.worker_pool.spawn(handle_callback, .{data});
            }
        }
    }

    /// Spawn a new thread, which will listen for and handle epoll events.
    pub fn start(self: *LiquoriceScheduler) !void {
        self.mtx.lock();
        defer self.mtx.unlock();
        if (self.main_thread == null) {
            self.main_thread = try std.Thread.spawn(.{}, _listen, .{self});
        } else {
            return SchedulerError.InvalidOperation;
        }
    }

    /// Initialize the scheduler.
    ///
    /// This will set up epoll and store the epoll descriptor, allowing other
    /// file descriptors to be added to the list being monitored by epoll and
    /// letting you start monitoring with `start()`.
    pub fn init(allocator: std.mem.Allocator) !*LiquoriceScheduler {
        const self = try allocator.create(LiquoriceScheduler);
        var pending = std.ArrayList(*TimerData).init(allocator);
        const epoll_fd = try posix.epoll_create1(linux.EPOLL.CLOEXEC);
        const shutdown_fd = try posix.eventfd(0, linux.EFD.CLOEXEC);
        {
            // register the shutdown fd with epoll
            // set up the data
            const data: *TimerData = try allocator.create(TimerData);
            data.* = .{
                ._timer_fd = shutdown_fd,
                .type = .SHUTDOWN,
                .data = .SHUTDOWN,
                .callback = .SHUTDOWN,
            };
            var event: linux.epoll_event = .{ .events = linux.EPOLL.IN | linux.EPOLL.ET, .data = .{ .ptr = @intFromPtr(data) } };
            try posix.epoll_ctl(epoll_fd, linux.EPOLL.CTL_ADD, shutdown_fd, &event);
            try pending.append(data);
        }
        self.* = .{
            .mtx = .{},
            .epoll_fd = epoll_fd,
            .shutdown_fd = shutdown_fd,
            .allocator = allocator,
            .pending = pending,
            .worker_pool = undefined,
        };
        try self.worker_pool.init(.{
            .allocator = allocator,
            .n_jobs = 3,
        });
        return self;
    }

    /// Close the epoll descriptor, all known timerfd descriptors, and destroy
    /// the scheduler.
    pub fn deinit(self: *LiquoriceScheduler) void {
        self.worker_pool.deinit();
        if (self.main_thread != null) {
            const bytes: u64 = 1;
            _ = posix.write(self.shutdown_fd, std.mem.asBytes(&bytes)) catch |err| {
                std.debug.panic("couldn't write to eventfd to shutdown: {any}\n", .{err});
            };
            self.main_thread.?.join();
        }
        for (self.pending.items) |timer| {
            // this might be an eventfd, but it closes just the same :)
            posix.close(timer._timer_fd);
            self.allocator.destroy(timer);
        }
        posix.close(self.epoll_fd);
        self.pending.deinit();
        self.allocator.destroy(self);
    }
};
