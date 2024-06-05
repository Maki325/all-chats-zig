const std = @import("std");
const websocket = @import("websocket");
const sqlite = @import("sqlite");

const Context = @This();

pub const Connections = std.ArrayList(*websocket.Conn);

alloc: std.mem.Allocator,
db: sqlite.Db,
mutex: std.Thread.Mutex,
connections: Connections,

pub fn addConn(self: *Context, conn: *websocket.Conn) !void {
    self.mutex.lock();
    defer self.mutex.unlock();

    try self.connections.append(conn);
}

pub fn removeConn(self: *Context, conn_to_remove: *websocket.Conn) void {
    self.mutex.lock();
    defer self.mutex.unlock();

    for (self.connections.items, 0..) |conn, i| {
        if (conn == conn_to_remove) {
            _ = self.connections.swapRemove(i);
            return;
        }
    }
}

pub fn writeToAll(self: *Context, conn_to_skip: *websocket.Conn, data: []const u8) !void {
    self.mutex.lock();
    defer self.mutex.unlock();
    for (self.connections.items) |conn| {
        if (conn == conn_to_skip) continue;
        try conn.writeBin(data);
    }
}
