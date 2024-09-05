const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const common = NamedModule.fromFile(b, "common", "./src/common/lib.zig");
    const protocol = NamedModule.fromFile(b, "protocol", "./src/protocol/lib.zig");
    const dotenv = NamedModule.fromFile(b, "dotenv", "./deps/dotenv/lib.zig");
    const websocket = NamedModule.fromZon(b, "websocket");
    const httpz = NamedModule.fromZon(b, "httpz");

    const server = addModules(b.addExecutable(.{
        .name = "combining-chats",
        .root_source_file = b.path("src/server/main.zig"),
        .target = target,
        .optimize = optimize,
    }), &.{ protocol, httpz, dotenv });
    addSQLite(b, server);
    addResources(b, server, target, optimize);
    b.installArtifact(server);
    addRunStep(b, server, "run-server", true);

    const bot_twitch = addModules(b.addExecutable(.{
        .name = "bot-twitch",
        .root_source_file = b.path("src/twitch/main.zig"),
        .target = target,
        .optimize = optimize,
    }), &.{ common, protocol, websocket, dotenv });
    b.installArtifact(bot_twitch);
    addRunStep(b, bot_twitch, "run-twitch", true);

    const bot_youtube = addModules(b.addExecutable(.{
        .name = "bot-youtube",
        .root_source_file = b.path("src/youtube/main.zig"),
        .target = target,
        .optimize = optimize,
    }), &.{ protocol, websocket });
    b.installArtifact(bot_youtube);
    addRunStep(b, bot_youtube, "run-youtube", true);
}

const NamedModule = struct {
    name: []const u8,
    module: *std.Build.Module,

    fn fromFile(b: *std.Build, name: []const u8, path: []const u8) NamedModule {
        return .{
            .name = name,
            .module = b.addModule(name, .{ .root_source_file = b.path(path) }),
        };
    }

    fn fromZon(b: *std.Build, name: []const u8) NamedModule {
        return .{
            .name = name,
            .module = b.dependency(name, .{}).module(name),
        };
    }
};

pub fn addModules(exe: *std.Build.Step.Compile, modules: []const NamedModule) *std.Build.Step.Compile {
    for (modules) |module| {
        exe.root_module.addImport(module.name, module.module);
    }

    // For modifying environment variables with dotenv
    exe.linkSystemLibrary("c");

    return exe;
}

pub fn addRunStep(b: *std.Build, exe: *std.Build.Step.Compile, name: []const u8, pass_args: bool) void {
    const run = b.addRunArtifact(exe);
    if (pass_args) {
        if (b.args) |args| {
            run.addArgs(args);
        }
    }
    const run_step = b.step(name, "Run the application");
    run_step.dependOn(&run.step);
}

pub fn addSQLite(b: *std.Build, exe: *std.Build.Step.Compile) void {
    const sqlite = b.dependency("sqlite", .{
        .target = b.host,
    });

    exe.root_module.addImport("sqlite", sqlite.module("sqlite"));

    // link the bundled sqlite3
    exe.linkLibrary(sqlite.artifact("sqlite"));
}

pub fn addResources(b: *std.Build, exe: *std.Build.Step.Compile, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode) void {
    const generate_embedded_resources = b.addExecutable(.{
        .name = "generate_embedded_resources",
        .root_source_file = b.path("tools/generate_embedded_resources.zig"),
        .target = target,
        .optimize = optimize,
    });

    const generate_embedded_resources_step = b.addRunArtifact(generate_embedded_resources);
    const output = generate_embedded_resources_step.addOutputFileArg("resources.zig");
    _ = generate_embedded_resources_step.addDepFileOutputArg("deps.d");
    generate_embedded_resources_step.addDirectoryArg(b.path("./client/"));

    exe.root_module.addAnonymousImport("resources", .{ .root_source_file = output });
}
