const std = @import("std");
const dotenv = @import("dotenv");
const httpz = @import("httpz");
const sqlite = @import("sqlite");
const Handler = @import("./Handler.zig");
const Context = @import("./Context.zig");
const routes = @import("./routes/routes.zig");

pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = general_purpose_allocator.allocator();

    try dotenv.load(alloc, .{});

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
        .wsConnections = Context.Connections.init(alloc),
        .mutex = .{},
    };
    defer context.wsConnections.deinit();

    var server = try httpz.ServerCtx(*Context, *Context).init(alloc, .{
        .address = "0.0.0.0",
    }, &context);

    var router = server.router();

    // use get/post/put/head/patch/options/delete
    // you can also use "all" to attach to all methods
    router.get("/api/user/:id", getUser);

    router.get("/ws", routes.ws);

    std.debug.print("Listening on port 5882!", .{});
    // start the server in the current thread, blocking.
    try server.listen();
}

fn initDb(db: *sqlite.Db) !void {
    const query =
        \\CREATE TABLE IF NOT EXISTS messages(
        \\  id INTEGER PRIMARY KEY,
        \\  platform INT NOT NULL,
        \\  platformMessageId TEXT NOT NULL,
        \\  channelId TEXT NOT NULL,
        \\  authorId TEXT NOT NULL,
        \\  author TEXT NOT NULL,
        \\  message TEXT NOT NULL,
        \\  timestamp INTEGER NOT NULL,
        \\  timestampType INTEGER NOT NULL
        \\);
    ;

    var stmt = try db.prepare(query);
    defer stmt.deinit();

    try stmt.exec(.{}, .{});
}

fn getUser(_: *Context, req: *httpz.Request, res: *httpz.Response) !void {
    // status code 200 is implicit.

    // The json helper will automatically set the res.content_type = httpz.ContentType.JSON;
    // Here we're passing an inferred anonymous structure, but you can pass anytype
    // (so long as it can be serialized using std.json.stringify)

    try res.json(.{ .id = req.param("id").?, .name = "Teg" }, .{});
}
