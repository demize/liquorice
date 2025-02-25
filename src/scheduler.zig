const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;

pub fn test_epoll() !noreturn {
    const timerfd = try posix.timerfd_create(.MONOTONIC, .{ .CLOEXEC = true });
    {
        const timerspec: posix.system.itimerspec = .{
            .it_interval = .{ .sec = 10, .nsec = 0 },
            .it_value = .{ .sec = 0, .nsec = 500000 },
        };
        try posix.timerfd_settime(timerfd, .{}, &timerspec, null);
    }
    const epollfd = try posix.epoll_create1(0);
    defer posix.close(epollfd);

    {
        var event: linux.epoll_event = .{ .events = linux.EPOLL.IN, .data = .{
            .fd = timerfd,
        } };
        try posix.epoll_ctl(epollfd, linux.EPOLL.CTL_ADD, timerfd, &event);
    }

    var ready_list: [16]linux.epoll_event = undefined;
    std.debug.print("starting the loop\n", .{});
    while (true) {
        const ready_count = posix.epoll_wait(epollfd, &ready_list, -1);
        std.debug.print("wait complete\n", .{});
        for (ready_list[0..ready_count]) |ready| {
            std.debug.print("ready count: {d}\n", .{ready_count});
            var buf: [1024]u8 = undefined;
            @memset(&buf, 0);
            const read = try posix.read(ready.data.fd, &buf);
            std.debug.print("read {d} bytes: {s}\n", .{ read, std.fmt.fmtSliceHexLower(&buf) });
        }
    }
}
