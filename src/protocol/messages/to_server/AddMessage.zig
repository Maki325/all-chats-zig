const std = @import("std");
const protocol = @import("../../lib.zig");

const AddMessage = @This();

platform: protocol.Platform,
author: []const u8,
message: []const u8,
timestamp: i64,

pub fn serialize(self: AddMessage, writer: *protocol.Writer) !void {
    try writer.writeInt(u8, @intFromEnum(self.platform));

    try writer.writeInt(usize, self.author.len);
    try writer.write(self.author);

    try writer.writeInt(usize, self.message.len);
    try writer.write(self.message);

    try writer.writeInt(i64, self.timestamp);
}

pub fn deserialize(reader: *protocol.Reader) !AddMessage {
    const platform: protocol.Platform = @enumFromInt(try reader.readInt(u8));

    const author_len = try reader.readInt(usize);
    const author = try reader.readSlice(u8, author_len);

    const message_len = try reader.readInt(usize);
    const message = try reader.readSlice(u8, message_len);

    const timestamp = try reader.readInt(i64);

    return .{
        .platform = platform,
        .author = author,
        .message = message,
        .timestamp = timestamp,
    };
}
