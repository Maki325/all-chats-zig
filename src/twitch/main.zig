const std = @import("std");
const dotenv = @import("dotenv");
const builtin = @import("builtin");
const protocol = @import("protocol");
const TwitchBot = @import("./TwitchBot.zig");
const TwitchMsg = @import("./TwitchMsg.zig");
const Args = @import("args.zig");
const common = @import("common");

var rand: std.Random = undefined;

pub fn main() void {
    var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        std.posix.getrandom(std.mem.asBytes(&seed)) catch |e| {
            std.log.warn("Couldn't get a random seed! {!}", .{e});
        };
        break :blk seed;
    });
    rand = prng.random();

    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = general_purpose_allocator.allocator();
    defer _ = general_purpose_allocator.deinit();

    // const A = struct {
    //     b: []const u8,
    // };
    // try common.args.parse(A);
    // try common.args.parse(.{
    //     .{ "someNumber", i32 },
    // });

    common.args.parse(.{
        .{ .a = 5 },
        .{ .a = 5 },
    }) catch |e| {
        // idk
        std.log.err("Args parse error! {!}", .{e});
    };
    std.process.exit(1);

    dotenv.load(alloc, .{}) catch |e| {
        std.log.err("Couldn't load .env file! {!}", .{e});
        std.process.exit(1);
    };

    var env_map = std.process.getEnvMap(alloc) catch |e| {
        std.log.err("Couldn't get the env map! {!}", .{e});
        std.process.exit(1);
    };
    defer env_map.deinit();

    var args = Args.parse(alloc) catch |e| {
        std.log.err("Couldn't parse args! {!}", .{e});
    };
    defer args.deinit();

    var bot = switch (TwitchBot.init(alloc, args, handleTwitchMsg)) {
        .Ok => |bot| bot,
        .Twitch => |err| {
            std.log.err("Couldn't connect to Twitch irc chat! {!}", .{err});
            std.process.exit(1);
        },
        .Aggregator => |err| {
            std.log.err("Couldn't connect to the aggregator client! {!}", .{err});
            std.process.exit(1);
        },
    };
    defer bot.deinit();

    bot.handshakeTwitch() catch |e| {
        std.log.err("Couldn't handshake with twitch! {!}", .{e});
        std.process.exit(1);
    };
    bot.handshakeAggregator() catch |e| {
        std.log.err("Couldn't handshake with the aggregator! {!}", .{e});
        std.process.exit(1);
    };

    var space: [100]u8 = undefined;

    bot.write(std.fmt.bufPrint(&space, "CAP REQ :twitch.tv/tags twitch.tv/membership twitch.tv/commands", .{}) catch unreachable) catch |e| {
        std.log.err("Couldn't send the CAP REQ message! {!}", .{e});
        std.process.exit(1);
    };
    bot.write(std.fmt.bufPrint(&space, "PASS oauth:{s}", .{
        std.process.EnvMap.get(env_map, "TOKEN") orelse @panic("Please provide TOKEN in the environment variables"),
    }) catch unreachable) catch |e| {
        std.log.err("Couldn't send the PASS message! {!}", .{e});
        std.process.exit(1);
    };
    bot.write(std.fmt.bufPrint(&space, "NICK {s}", .{args.nick}) catch unreachable) catch |e| {
        std.log.err("Couldn't send the NICK message! {!}", .{e});
        std.process.exit(1);
    };
    bot.write(std.fmt.bufPrint(&space, "JOIN #{s}", .{args.channel}) catch unreachable) catch |e| {
        std.log.err("Couldn't send the JOIN message! {!}", .{e});
        std.process.exit(1);
    };

    const Aborter = struct {
        var twitch_bot: *TwitchBot = undefined;

        fn abort() void {
            twitch_bot.shutdown();
            std.log.info("\n", .{});
        }
    };
    Aborter.twitch_bot = &bot;

    setAbortSignalHandler(Aborter.abort) catch |e| {
        std.log.err("Couldn't set the abortion signal handler! {!}", .{e});
        std.process.exit(1);
    };

    bot.client.readLoop(&bot) catch |e| {
        std.log.err("There was an error during the read loop! {!}", .{e});
        std.process.exit(1);
    };

    std.log.info("Twitch bot has shutdown gracefully.", .{});
}

fn handleTwitchMsg(_bot: *anyopaque, msg: *TwitchMsg) TwitchBot.HandleTwitchMsgFnError!void {
    const bot: *TwitchBot = @ptrCast(@alignCast(_bot));
    msg.print();

    switch (msg.cmd) {
        .Ping => {
            const buf = std.fmt.allocPrint(bot.alloc, "PONG {s}", .{msg.args}) catch {
                return;
            };
            defer bot.alloc.free(buf);
            bot.write(buf) catch {};
        },
        .Privmsg => {
            const index = std.mem.indexOf(u8, msg.args, ":") orelse return;
            const text = msg.args[(index + 1)..];

            const user_id: ?[]const u8 = if (msg.tag_map.get("user-id")) |value|
                if (value) |author| author else null
            else
                null;

            const author: ?[]const u8 = if (msg.tag_map.get("display-name")) |value|
                if (value) |author| author else null
            else
                null;

            const timestamp: ?i64 = if (msg.tag_map.get("tmi-sent-ts")) |value|
                if (value) |ts| std.fmt.parseInt(i64, ts, 10) catch null else null
            else
                null;

            const msg_id: ?[]const u8 = if (msg.tag_map.get("id")) |value|
                if (value) |id| id else null
            else
                null;

            const room_id: ?[]const u8 = if (msg.tag_map.get("room-id")) |value|
                if (value) |room_id| room_id else null
            else
                null;

            if (author != null and timestamp != null and msg_id != null and user_id != null and room_id != null) {
                var writer = protocol.Writer.init(bot.alloc);
                defer writer.deinit();
                (protocol.messages.ToServer.Message{
                    .AddMessage = protocol.messages.ToServer.AddMessage{
                        .platform = .Twitch,
                        .platform_message_id = msg_id.?,
                        // https://dev.twitch.tv/docs/api/reference/#get-channel-information
                        .channel_id = room_id.?,
                        .author_id = user_id.?,
                        .author = author.?,
                        .message = text,
                        .timestamp_type = .Milisecond,
                        .timestamp = timestamp.?,
                    },
                }).serialize(&writer) catch {
                    return error.GeneralError;
                };

                bot.aggregator_client.writeBin(writer.data.items) catch return error.GeneralError;
            }

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

/// From here: https://github.com/r00ster91/wool/blob/786b45fff5f0a5c9106a907b5036a2041906fdb7/examples/backends/terminal/src/main.zig#L234
/// TODO: PR this if https://github.com/ziglang/zig/issues/13045 is accepted
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
