const std = @import("std");
const dotenv = @import("dotenv");
const Bot = @import("./Bot.zig");

pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = general_purpose_allocator.allocator();

    try dotenv.load(alloc, .{});

    var bot = try Bot.init(alloc);
    defer bot.deinit();

    // try bot.connect("irc");
    // try bot.connect2();

    const envMap = try std.process.getEnvMap(alloc);

    const commandCapReq = "CAP REQ :twitch.tv/tags twitch.tv/commands";
    const commandNick = "NICK maki325";

    var space: [100]u8 = undefined;
    const commandPass = try std.fmt.bufPrint(&space, "PASS oauth:{?s}", .{std.process.EnvMap.get(envMap, "TOKEN")});

    try bot.write(try alloc.dupe(u8, commandCapReq));
    try bot.write(try alloc.dupe(u8, commandPass));
    try bot.write(try alloc.dupe(u8, commandNick));
    try bot.write(try alloc.dupe(u8, "JOIN #user"));
    try bot.write(try alloc.dupe(u8, "PRIVMSG #user :Hello"));

    std.time.sleep(60 * std.time.ns_per_s);
}
