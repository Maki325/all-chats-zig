const std = @import("std");
const YouTubeBot = @import("./YouTubeBot.zig");

pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = general_purpose_allocator.allocator();

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    if (args.len != 2) {
        std.log.err("Usage: {s} <stream id>\n", .{args[0]});
        return;
    }

    const stream_id = args[1];

    var youtubeBot = try YouTubeBot.init(alloc, stream_id);
    defer youtubeBot.deinit();

    var is_running = true;
    try youtubeBot.run(&is_running);
}
