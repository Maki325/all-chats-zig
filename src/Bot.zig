const std = @import("std");
const websocket = @import("websocket");

const Bot = @This();

const TWITCH_ADDRESS = "irc-ws.chat.twitch.tv";
const TWITCH_PORT = 80;

alloc: std.mem.Allocator,
client: websocket.Client,

pub fn init(alloc: std.mem.Allocator) !Bot {
    return .{
        .alloc = alloc,
        .client = try websocket.connect(alloc, TWITCH_ADDRESS, TWITCH_PORT, .{}),
    };
}

pub fn deinit(self: *Bot) void {
    self.client.deinit();
}

pub fn connect(self: *Bot, path: []const u8) !void {
    try self.client.handshake(path, .{
        .timeout_ms = 5000,
        .headers = try self.alloc.dupe(u8, "Host: " ++ TWITCH_ADDRESS),
    });
    const thread = try self.client.readLoopInNewThread(self);
    thread.detach();
}

pub fn write(self: *Bot, data: []u8) !void {
    return self.client.write(data);
}

// Interface for WebSocket to use

pub fn handle(_: Bot, message: websocket.Message) !void {
    const data = message.data;
    std.debug.print("CLIENT GOT: {s}\n", .{data});
}

pub fn close(_: Bot) void {
    std.debug.print("CLOSED\n", .{});
}

// End of WebSocket Interface
