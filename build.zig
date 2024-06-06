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
    const protocol = NamedModule{
        .name = "protocol",
        .module = b.addModule("protocol", .{ .root_source_file = .{ .path = "./src/protocol/lib.zig" } }),
    };
    const websocket = NamedModule{
        .name = "websocket",
        .module = b.addModule("websocket", .{ .root_source_file = .{ .path = "./deps/websocket.zig/src/websocket.zig" } }),
    };
    const modules: []const NamedModule = &[_]NamedModule{ websocket, .{
        .name = "dotenv",
        .module = b.addModule("dotenv", .{ .root_source_file = .{ .path = "./deps/dotenv/lib.zig" } }),
    }, protocol };

    const server = addModules(b.addExecutable(.{
        .name = "combining-chats",
        .root_source_file = b.path("src/server/main.zig"),
        .target = b.host,
    }), modules);
    {
        const sqlite = b.dependency("sqlite", .{
            .target = b.host,
        });

        server.root_module.addImport("sqlite", sqlite.module("sqlite"));

        // links the bundled sqlite3, so leave this out if you link the system one
        server.linkLibrary(sqlite.artifact("sqlite"));
    }
    b.installArtifact(server);

    const bot_twitch = addModules(b.addExecutable(.{
        .name = "bot-twitch",
        .root_source_file = b.path("src/twitch/main.zig"),
        .target = b.host,
    }), modules);
    b.installArtifact(bot_twitch);

    const bot_youtube = addModules(b.addExecutable(.{
        .name = "bot-youtube",
        .root_source_file = b.path("src/youtube/main.zig"),
        .target = b.host,
    }), &.{ protocol, websocket });
    b.installArtifact(bot_youtube);
}
