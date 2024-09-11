const std = @import("std");
const websocket = @import("websocket");
const TwitchMsg = @import("TwitchMsg.zig");
const Args = @import("args.zig");

const TwitchBot = @This();

const TWITCH_ADDRESS = "irc-ws.chat.twitch.tv";
const TWITCH_PORT = 80;
const TWITCH_HANDSHAKE_PATH = "/";

pub const HandleTwitchMsgFnError = error{GeneralError};
// https://github.com/ziglang/zig/issues/12325
// We got a dependency loop, so we can't use `*TwitchBot` and have to use `*anyopaque`
const HandleTwitchMsgFn = *const fn (bot: *anyopaque, msg: *TwitchMsg) HandleTwitchMsgFnError!void;

const InitResult = union(enum) {
    Ok: TwitchBot,
    Twitch: anyerror,
    Aggregator: anyerror,
};

alloc: std.mem.Allocator,
client: websocket.Client,
aggregator_client: websocket.Client,
handleTwitchMsg: HandleTwitchMsgFn,

pub fn init(alloc: std.mem.Allocator, args: anytype, handleTwitchMsg: HandleTwitchMsgFn) InitResult {
    var client = websocket.connect(alloc, TWITCH_ADDRESS, TWITCH_PORT, .{}) catch |e| {
        return .{ .Twitch = e };
    };
    errdefer client.deinit();
    var aggregator_client = websocket.connect(alloc, args.host, args.port, .{}) catch |e| {
        return .{ .Aggregator = e };
    };
    errdefer aggregator_client.deinit();
    return .{ .Ok = .{
        .alloc = alloc,
        .handleTwitchMsg = handleTwitchMsg,
        .client = client,
        .aggregator_client = aggregator_client,
    } };
}

pub fn deinit(self: *TwitchBot) void {
    self.aggregator_client.close();
    self.aggregator_client.deinit();

    self.client.close();
    self.client.deinit();
}

pub fn handshakeTwitch(self: *TwitchBot) !void {
    try self.client.handshake(TWITCH_HANDSHAKE_PATH, .{
        .timeout_ms = 5000,
        .headers = "Host: " ++ TWITCH_ADDRESS,
    });
}

pub fn handshakeAggregator(self: *TwitchBot) !void {
    try self.aggregator_client.handshake("/ws", .{
        .timeout_ms = 5000,
    });
}

pub fn write(self: *TwitchBot, data: []u8) !void {
    return self.client.write(data);
}

pub fn shutdown(self: *TwitchBot) void {
    self.client.close();
    self.aggregator_client.close();
}

// Interface for WebSocket to use

pub fn handle(self: *TwitchBot, wsMsg: websocket.Message) !void {
    handleImpl(self, wsMsg) catch |e| {
        std.log.err("Got error ({any}) handling ws message: {any}", .{ e, wsMsg });
    };
}

pub fn handleImpl(self: *TwitchBot, wsMsg: websocket.Message) !void {
    const data = wsMsg.data;

    var it = std.mem.split(u8, data, "\r\n");
    while (it.next()) |line| {
        if (line.len == 0) {
            continue;
        }

        var msg = try TwitchMsg.init(self.alloc, &line);
        defer msg.deinit();
        self.handleTwitchMsg(self, &msg) catch |e| {
            std.log.err("Got error ({any}) handling twitch msg: {any}", .{ e, msg });
        };
    }
}

pub fn close(_: *TwitchBot) void {}

// End of WebSocket Interface
