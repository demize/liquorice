const std = @import("std");
const httpz = @import("httpz");

pub fn listen() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var server = try httpz.Server(void).init(allocator, .{ .port = 8080, .request = .{
        .max_form_count = 20,
    } }, {});
    defer server.deinit();
    defer server.stop();

    var router = server.router(.{});
    router.get("/", index, .{});

    std.debug.print("liquorice: listening", .{});
    try server.listen();
}

fn index(_: *httpz.Request, res: *httpz.Response) !void {
    res.body =
        \\<!DOCTYPE html>
        \\<html>
        \\<head>
        \\<title>liquorice.zig test page</title>
        \\</head>
        \\<body>
        \\<h1>liquorice.zig is working!</h1>
        \\</body>
        \\</html>
    ;
}
