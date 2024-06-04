const std = @import("std");
const dotenv = @import("dotenv");
const YouTubeBot = @import("./youtube/YouTubeBot.zig");

pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = general_purpose_allocator.allocator();

    try dotenv.load(alloc, .{});

    var youtubeBot = try YouTubeBot.init(alloc, "ZIpmrYAzWCU");
    defer youtubeBot.deinit();

    var is_running = true;
    try youtubeBot.run(&is_running);
}
