const std = @import("std");
const websocket = @import("websocket");
const TwitchMsg = @import("TwitchMsg.zig");

const Bot = @This();

const TWITCH_ADDRESS = "irc-ws.chat.twitch.tv";
const TWITCH_PORT = 80;

alloc: std.mem.Allocator,
client: websocket.Client,
handleTwitchMsg: *const fn (TwitchMsg) void,

pub fn init(alloc: std.mem.Allocator, handleTwitchMsg: *const fn (TwitchMsg) void) !Bot {
    return .{
        .alloc = alloc,
        .handleTwitchMsg = handleTwitchMsg,
        .client = try websocket.connect(alloc, TWITCH_ADDRESS, TWITCH_PORT, .{}),
    };
}

pub fn deinit(self: *Bot) void {
    self.client.deinit();
}

pub fn handshake(self: *Bot, path: []const u8) !void {
    try self.client.handshake(path, .{
        .timeout_ms = 5000,
        .headers = try self.alloc.dupe(u8, "Host: " ++ TWITCH_ADDRESS),
    });
}

pub fn write(self: *Bot, data: []u8) !void {
    return self.client.write(data);
}

// Interface for WebSocket to use

pub fn handle(self: Bot, wsMsg: websocket.Message) !void {
    const data = wsMsg.data;

    var it = std.mem.split(u8, data, "\r\n");
    while (it.next()) |line| {
        if (line.len == 0) {
            continue;
        }

        self.handleTwitchMsg(try TwitchMsg.init(self.alloc, &line));
    }
}

pub fn close(_: Bot) void {
    std.debug.print("CLOSED\n", .{});
}

// End of WebSocket Interface
