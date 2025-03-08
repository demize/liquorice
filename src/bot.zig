const auth = @import("auth.zig");
const LiquoriceToken = auth.LiquoriceToken;

// interface pattern based on https://www.openmymind.net/Zig-Interfaces/
// thanks Karl :)

pub const LiquoriceBot = struct {
    ptr: *anyopaque,
    updateTokenFn: *const fn (ptr: *anyopaque, token: LiquoriceToken) void,

    pub fn init(ptr: anytype) LiquoriceBot {
        const T = @TypeOf(ptr);
        const ptr_info = @typeInfo(T);

        const gen = struct {
            pub fn updateToken(pointer: *anyopaque, token: LiquoriceToken) void {
                const self: T = @ptrCast(@alignCast(pointer));
                return @call(.always_inline, ptr_info.pointer.child.updateToken, .{ self, token });
            }
        };

        return .{
            .ptr = ptr,
            .updateTokenFn = gen.updateToken,
        };
    }
};
