const std = @import("std");
const Builder = std.Build;
const builtin = @import("builtin");

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const exe = b.addExecutable(.{
        .name = "svd4zig",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
    });

    b.default_step.dependOn(&exe.step);
    b.installArtifact(exe);
}
