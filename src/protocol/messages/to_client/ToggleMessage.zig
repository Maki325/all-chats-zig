const std = @import("std");
const protocol = @import("../../lib.zig");

const ToggleMessage = @This();

id: i64,
visible: bool,

pub fn serialize(self: ToggleMessage, writer: *protocol.Writer) !void {
    try writer.writeInt(i64, self.id);
    try writer.writeInt(u8, @intFromBool(self.visible));
}

pub fn deserialize(reader: *protocol.Reader) !ToggleMessage {
    const id = try reader.readInt(i64);
    const visible = (try reader.readInt(u8)) != 0;

    return ToggleMessage{
        .id = id,
        .visible = visible,
    };
}
