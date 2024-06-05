const std = @import("std");
const protocol = @import("./lib.zig");

const Reader = @This();
const ReadError = error{
    EndOfStream,
};

data: []const u8,
pos: usize = 0,

pub fn init(data: []const u8) Reader {
    return .{
        .data = data,
        .pos = 0,
    };
}

pub fn read(self: *Reader, buffer: []u8) ReadError!usize {
    const end = @min(self.pos + buffer.len, self.data.len);
    @memcpy(buffer, self.data[self.pos..end]);
    const len = end - self.pos;
    self.pos = end;
    return len;
}

pub fn readInt(self: *Reader, comptime T: type) ReadError!T {
    const bytes = comptime @divExact(@typeInfo(T).Int.bits, 8);
    if (self.pos + bytes > self.data.len) {
        return error.EndOfStream;
    }

    const int = std.mem.readInt(T, @ptrCast(self.data.ptr + self.pos), protocol.endian);
    self.pos += bytes;
    return int;
}

pub fn readSlice(self: *Reader, comptime T: type, len: usize) ReadError![]const T {
    const bytes_per = @divExact(@typeInfo(T).Int.bits, 8);
    if (self.pos + bytes_per * len > self.data.len) {
        return error.EndOfStream;
    }

    const end = self.pos + bytes_per * len;
    const slice = @as([]const T, self.data[self.pos..end]);

    self.pos = end;

    return slice;
}
