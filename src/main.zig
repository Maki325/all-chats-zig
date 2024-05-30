const std = @import("std");
const dotenv = @import("dotenv");
const builtin = @import("builtin");
const websocket = @import("websocket");
const TwitchBot = @import("./twitch/TwitchBot.zig");
const TwitchMsg = @import("./twitch/TwitchMsg.zig");
const YouTubeBot = @import("./youtube/YouTubeBot.zig");

var bot: TwitchBot = undefined;
var rand: std.Random = undefined;

pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = general_purpose_allocator.allocator();

    try dotenv.load(alloc, .{});

    var youtubeBot = try YouTubeBot.init(alloc, "ZIpmrYAzWCU");
    defer youtubeBot.deinit();

    var is_running = true;
    try youtubeBot.run(&is_running);
}

fn runTwitchBot() !void {
    var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    rand = prng.random();

    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = general_purpose_allocator.allocator();

    try dotenv.load(alloc, .{});

    bot = try TwitchBot.init(alloc, handleTwitchMsg);
    defer bot.deinit();

    try bot.handshake("/");

    const envMap = try std.process.getEnvMap(alloc);

    const commandCapReq = "CAP REQ :twitch.tv/tags twitch.tv/commands";
    const commandNick = "NICK maki325";

    var space: [100]u8 = undefined;
    const commandPass = try std.fmt.bufPrint(&space, "PASS oauth:{?s}", .{std.process.EnvMap.get(envMap, "TOKEN")});

    try bot.write(try alloc.dupe(u8, commandCapReq));
    try bot.write(try alloc.dupe(u8, commandPass));
    try bot.write(try alloc.dupe(u8, commandNick));
    try bot.write(try alloc.dupe(u8, "JOIN #maki325"));

    try setAbortSignalHandler(onAbort);

    try bot.client.readLoop(bot);
}

fn handleTwitchMsg(msg: TwitchMsg) void {
    defer msg.deinit();

    msg.print();

    switch (msg.cmd) {
        .Privmsg => {
            var it = std.mem.split(u8, msg.args, ":");
            _ = it.next();
            const text = it.next() orelse {
                return;
            };

            if (std.mem.startsWith(u8, text, "!dice")) {
                var space: [32]u8 = undefined;
                const buf = std.fmt.bufPrint(&space, "PRIVMSG #maki325 :You rolled: {d}!", .{rand.intRangeAtMost(u8, 1, 6)}) catch {
                    return;
                };

                bot.write(buf) catch {};
            }
        },
        else => {},
    }
}

fn onAbort() void {
    std.debug.print("ABORTING THE SHIP!\n", .{});
    bot.client.close();
}

// From here: https://github.com/r00ster91/wool/blob/786b45fff5f0a5c9106a907b5036a2041906fdb7/examples/backends/terminal/src/main.zig#L234
// TODO: PR this if https://github.com/ziglang/zig/issues/13045 is accepted
/// Registers a handler to be run if an abort signal is catched.
/// The abort signal is usually fired if Ctrl+C is pressed in a terminal.
///
/// Use this for non-critical cleanups or resets of terminal state and such.
/// The handler is not guaranteed to be run.
fn setAbortSignalHandler(comptime handler: *const fn () void) !void {
    if (builtin.os.tag == .windows) {
        const handler_routine = struct {
            fn handler_routine(dwCtrlType: std.os.windows.DWORD) callconv(std.os.windows.WINAPI) std.os.windows.BOOL {
                if (dwCtrlType == std.os.windows.CTRL_C_EVENT) {
                    handler();
                    return std.os.windows.TRUE;
                } else {
                    return std.os.windows.FALSE;
                }
            }
        }.handler_routine;
        try std.os.windows.SetConsoleCtrlHandler(handler_routine, true);
    } else {
        const internal_handler = struct {
            fn internal_handler(sig: c_int) callconv(.C) void {
                std.debug.assert(sig == std.os.linux.SIG.INT);
                handler();
            }
        }.internal_handler;
        const act = std.os.linux.Sigaction{
            .handler = .{ .handler = internal_handler },
            .mask = std.os.linux.empty_sigset,
            .flags = 0,
        };
        const ret = std.os.linux.sigaction(std.os.linux.SIG.INT, &act, null);
        std.debug.assert(ret == 0);
    }
}
