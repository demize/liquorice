const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const httpz = b.dependency("httpz", .{
        .target = target,
        .optimize = optimize,
    });
    const zul = b.dependency("zul", .{
        .target = target,
        .optimize = optimize,
    });

    const liquoriceModule = b.addModule("liquorice", .{
        .root_source_file = b.path("src/root.zig"),
        .imports = &.{ .{ .name = "httpz", .module = httpz.module("httpz") }, .{ .name = "zul", .module = zul.module("zul") } },
        .target = target,
        .optimize = optimize,
    });

    const lib_unit_tests = b.addTest(.{
        .root_module = liquoriceModule,
        .target = target,
        .optimize = optimize,
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_lib_unit_tests.step);
}
