const std = @import("std");

const NamedModule = struct {
    name: []const u8,
    module: *std.Build.Module,
};

pub fn addModules(exe: *std.Build.Step.Compile, modules: []const NamedModule) *std.Build.Step.Compile {
    for (modules) |module| {
        exe.root_module.addImport(module.name, module.module);
    }

    // For modifying environment variables with dotenv
    exe.linkSystemLibrary("c");

    return exe;
}

pub fn build(b: *std.Build) void {
    const modules: []const NamedModule = &[_]NamedModule{ .{
        .name = "websocket",
        .module = b.addModule("websocket", .{ .root_source_file = .{ .path = "./deps/websocket.zig/src/websocket.zig" } }),
    }, .{
        .name = "dotenv",
        .module = b.addModule("dotenv", .{ .root_source_file = .{ .path = "./deps/dotenv/lib.zig" } }),
    } };

    const combining_chats = addModules(b.addExecutable(.{
        .name = "combining-chats",
        .root_source_file = b.path("src/main.zig"),
        .target = b.host,
    }), modules);
    b.installArtifact(combining_chats);

    const bot_twitch = addModules(b.addExecutable(.{
        .name = "bot-twitch",
        .root_source_file = b.path("src/twitch/main.zig"),
        .target = b.host,
    }), modules);
    b.installArtifact(bot_twitch);

    const bot_youtube = b.addExecutable(.{
        .name = "bot-youtube",
        .root_source_file = b.path("src/youtube/main.zig"),
        .target = b.host,
    });
    b.installArtifact(bot_youtube);
}
