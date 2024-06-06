const std = @import("std");
const protocol = @import("../../lib.zig");

const AddMessage = @This();

platform: protocol.Platform,
platform_message_id: []const u8,
channel_id: []const u8,
author_id: []const u8,
author: []const u8,
message: []const u8,
timestamp_type: protocol.TimestampType,
timestamp: i64,

pub fn serialize(self: AddMessage, writer: *protocol.Writer) !void {
    try writer.writeInt(u8, @intFromEnum(self.platform));

    try writer.writeInt(usize, self.platform_message_id.len);
    try writer.write(self.platform_message_id);

    try writer.writeInt(usize, self.channel_id.len);
    try writer.write(self.channel_id);

    try writer.writeInt(usize, self.author_id.len);
    try writer.write(self.author_id);

    try writer.writeInt(usize, self.author.len);
    try writer.write(self.author);

    try writer.writeInt(usize, self.message.len);
    try writer.write(self.message);

    try writer.writeInt(u8, @intFromEnum(self.timestamp_type));
    try writer.writeInt(i64, self.timestamp);
}

pub fn deserialize(reader: *protocol.Reader) !AddMessage {
    const platform: protocol.Platform = @enumFromInt(try reader.readInt(u8));

    const platform_message_id_len = try reader.readInt(usize);
    const platform_message_id = try reader.readSlice(u8, platform_message_id_len);

    const channel_id_len = try reader.readInt(usize);
    const channel_id = try reader.readSlice(u8, channel_id_len);

    const author_id_len = try reader.readInt(usize);
    const author_id = try reader.readSlice(u8, author_id_len);

    const author_len = try reader.readInt(usize);
    const author = try reader.readSlice(u8, author_len);

    const message_len = try reader.readInt(usize);
    const message = try reader.readSlice(u8, message_len);

    const timestamp_type: protocol.TimestampType = @enumFromInt(try reader.readInt(u8));
    const timestamp = try reader.readInt(i64);

    return .{
        .platform = platform,
        .platform_message_id = platform_message_id,
        .channel_id = channel_id,
        .author_id = author_id,
        .author = author,
        .message = message,
        .timestamp_type = timestamp_type,
        .timestamp = timestamp,
    };
}
