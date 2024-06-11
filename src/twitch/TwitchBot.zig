const std = @import("std");
const websocket = @import("websocket");
const TwitchMsg = @import("TwitchMsg.zig");

const TwitchBot = @This();

const TWITCH_ADDRESS = "irc-ws.chat.twitch.tv";
const TWITCH_PORT = 80;
const TWITCH_HANDSHAKE_PATH = "/";

pub const HandleTwitchMsgFnError = error{GeneralError};
const HandleTwitchMsgFn = *const fn (*TwitchBot, *TwitchMsg) HandleTwitchMsgFnError!void;

alloc: std.mem.Allocator,
client: websocket.Client,
aggregator_client: websocket.Client,
handleTwitchMsg: HandleTwitchMsgFn,

pub fn init(alloc: std.mem.Allocator, handleTwitchMsg: HandleTwitchMsgFn) !TwitchBot {
    return .{
        .alloc = alloc,
        .handleTwitchMsg = handleTwitchMsg,
        .client = try websocket.connect(alloc, TWITCH_ADDRESS, TWITCH_PORT, .{}),
        .aggregator_client = try websocket.connect(alloc, "localhost", 5882, .{}),
    };
}

pub fn deinit(self: *TwitchBot) void {
    self.aggregator_client.deinit();
    self.client.deinit();
}

pub fn handshakeTwitch(self: *TwitchBot) !void {
    try self.client.handshake(TWITCH_HANDSHAKE_PATH, .{
        .timeout_ms = 5000,
        .headers = try self.alloc.dupe(u8, "Host: " ++ TWITCH_ADDRESS),
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

// Interface for WebSocket to use

pub fn handle(self: *TwitchBot, wsMsg: websocket.Message) !void {
    handleImpl(self, wsMsg) catch |e| {
        std.log.err("Got error ({any}) handling ws message: {any}\n", .{ e, wsMsg });
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
            std.log.err("Got error ({any}) handling twitch msg: {any}\n", .{ e, msg });
        };
    }
}

pub fn close(self: *TwitchBot) void {
    self.aggregator_client.close();
    std.debug.print("Closed TwitchBot\n", .{});
}

// End of WebSocket Interface
