const std = @import("std");

pub const messages = @import("./messages/messages.zig");
pub const Reader = @import("./Reader.zig");
pub const Writer = @import("./Writer.zig");

pub const Platform = enum(u8) {
    YouTube,
    Twitch,
};

pub const TimestampType = enum(u8) {
    Second,
    Milisecond,
    Microsecond,
    Nanosecond,
};

// Using Big Endian because that's the norm for Web software
// But maybe we can use Little Endian, so we skip the byte swap
pub const endian: std.builtin.Endian = .big;
