const std = @import("std");
const protocol = @import("../../lib.zig");

pub const AddMessage = @import("./AddMessage.zig");

pub const Message = union(enum(u8)) {
    AddMessage: AddMessage,

    pub fn deserialize(id: u8, reader: *protocol.Reader) !Message {
        switch (id) {
            0 => return .{ .AddMessage = try AddMessage.deserialize(reader) },
            else => return error.UnknownMessage,
        }
    }

    pub fn serialize(self: Message, writer: *protocol.Writer) !void {
        switch (self) {
            .AddMessage => |msg| {
                try writer.writeInt(u8, 0);
                try msg.serialize(writer);
            },
        }
    }
};
