const std = @import("std");
const websocket = @import("httpz").websocket;
const sqlite = @import("sqlite");

const Context = @This();

pub const Connections = std.ArrayList(*websocket.Conn);
pub const StaticFile = struct { abs: []const u8, url: []const u8 };

alloc: std.mem.Allocator,
db: sqlite.Db,
mutex: std.Thread.Mutex,
wsConnections: Connections,
static_file: ?StaticFile = null,

pub fn addWsConn(self: *Context, conn: *websocket.Conn) !void {
    self.mutex.lock();
    defer self.mutex.unlock();

    try self.wsConnections.append(conn);
}

pub fn removeWsConn(self: *Context, conn_to_remove: *websocket.Conn) void {
    self.mutex.lock();
    defer self.mutex.unlock();

    for (self.wsConnections.items, 0..) |conn, i| {
        if (conn == conn_to_remove) {
            _ = self.wsConnections.swapRemove(i);
            return;
        }
    }
}

pub fn writeToAllWs(self: *Context, conn_to_skip: *websocket.Conn, data: []const u8) !void {
    self.mutex.lock();
    defer self.mutex.unlock();
    for (self.wsConnections.items) |conn| {
        if (conn == conn_to_skip) continue;
        try conn.writeBin(data);
    }
}
