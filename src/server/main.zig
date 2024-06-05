const std = @import("std");
const dotenv = @import("dotenv");
const websocket = @import("websocket");
const sqlite = @import("sqlite");
const Handler = @import("./Handler.zig");
const Context = @import("./Context.zig");
const Server = @import("./Server.zig");

pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = general_purpose_allocator.allocator();

    try dotenv.load(alloc, .{});

    try Server.run(alloc);
}
