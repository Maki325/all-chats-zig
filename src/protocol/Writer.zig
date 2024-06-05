const std = @import("std");
const protocol = @import("./lib.zig");

const Writer = @This();
const Data = std.ArrayList(u8);

data: Data,

pub fn init(alloc: std.mem.Allocator) Writer {
    return .{
        .data = Data.init(alloc),
    };
}

pub fn deinit(self: Writer) void {
    self.data.deinit();
}

pub fn writeInt(self: *Writer, comptime T: type, value: T) std.mem.Allocator.Error!void {
    try self.data.writer().writeInt(T, value, protocol.endian);
}

pub fn write(self: *Writer, bytes: []const u8) std.mem.Allocator.Error!void {
    _ = try self.data.writer().write(bytes);
}
