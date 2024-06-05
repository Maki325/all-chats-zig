const std = @import("std");
const websocket = @import("websocket");
const sqlite = @import("sqlite");
const Context = @import("Context.zig");
const Handler = @import("Handler.zig");

const Server = @This();

pub fn run(alloc: std.mem.Allocator) !void {
    var db = try sqlite.Db.init(.{
        .mode = sqlite.Db.Mode{ .File = "./my.db" },
        .open_flags = .{
            .write = true,
            .create = true,
        },
        .threading_mode = .MultiThread,
    });
    defer db.deinit();

    try initDb(&db);

    var context = Context{
        .alloc = alloc,
        .db = db,
        .connections = Context.Connections.init(alloc),
        .mutex = .{},
    };
    defer context.connections.deinit();

    std.debug.print("Started!\n", .{});
    try websocket.listen(Handler, alloc, &context, .{
        .port = 9223,
        .max_headers = 10,
        .address = "127.0.0.1",
    });
}

fn initDb(db: *sqlite.Db) !void {
    const query =
        \\CREATE TABLE IF NOT EXISTS messages(id INTEGER PRIMARY KEY, platform INT NOT NULL, author TEXT NOT NULL, message TEXT NOT NULL, timestamp INTEGER NOT NULL);
    ;

    var stmt = try db.prepare(query);
    defer stmt.deinit();

    try stmt.exec(.{}, .{});
}
