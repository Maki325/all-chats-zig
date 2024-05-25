const std = @import("std");

pub fn build(b: *std.Build) void {
    const websocket = b.addModule("websocket", .{ .root_source_file = .{ .path = "./deps/websocket.zig/src/websocket.zig" } });
    const dotenv = b.addModule("dotenv", .{ .root_source_file = .{ .path = "./deps/dotenv/lib.zig" } });

    const exe = b.addExecutable(.{
        .name = "combining-chats",
        .root_source_file = b.path("src/main.zig"),
        .target = b.host,
    });

    exe.root_module.addImport("websocket", websocket);
    exe.root_module.addImport("dotenv", dotenv);
    // For modifying environment variables with dotenv
    exe.linkSystemLibrary("c");

    b.installArtifact(exe);
}
