const std = @import("std");
const builtin = @import("builtin");
const dotenv = @import("dotenv");
const httpz = @import("httpz");
const sqlite = @import("sqlite");
const resources = @import("resources");
const Context = @import("./Context.zig");
const routes = @import("./routes/routes.zig");

const dbg = builtin.mode == std.builtin.OptimizeMode.Debug;

pub fn main() !void {
    var general_purpose_allocator = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = general_purpose_allocator.allocator();
    defer _ = general_purpose_allocator.deinit();

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

    router.get("/api/user/:id", getUser);

    const route_contextes = try routeStaticFiles(alloc, router);
    defer route_contextes.deinit();

    router.get("/ws", routes.ws);
    router.get("/admin", routes.admin);
    router.post("/messages/:id/toggle", routes.messages.toggle);

    std.log.info("Listening on port 5882!\n", .{});
    try server.listen();
}

const RouteContextes = struct {
    alloc: std.mem.Allocator,
    route_contextes: std.ArrayList(*Context),

    fn init(alloc: std.mem.Allocator) RouteContextes {
        return .{
            .alloc = alloc,
            .route_contextes = std.ArrayList(*Context).init(alloc),
        };
    }

    pub fn append(self: *RouteContextes, item: struct { entry_path: []const u8, dir_path: []const u8 }) std.mem.Allocator.Error!struct { ctx: *Context, url: []const u8 } {
        const ctx = try self.alloc.create(Context);
        const static_file = Context.StaticFile{
            .abs = try std.fmt.allocPrint(self.alloc, "{s}/{s}", .{ item.dir_path, item.entry_path }),
            .url = try self.alloc.dupe(u8, item.entry_path),
        };
        ctx.static_file = static_file;
        try self.route_contextes.append(ctx);

        return .{ .ctx = ctx, .url = static_file.url };
    }

    fn deinit(self: RouteContextes) void {
        for (self.route_contextes.items) |ctx| {
            if (ctx.static_file) |file| {
                self.alloc.free(file.abs);
                self.alloc.free(file.url);
            }
        }
        self.route_contextes.deinit();
    }
};

fn routeStaticFiles(alloc: std.mem.Allocator, router: *httpz.Router(*Context, *Context)) !RouteContextes {
    var route_contextes = RouteContextes.init(alloc);
    errdefer route_contextes.deinit();

    if (dbg) {
        var dir = try std.fs.cwd().openDir("client", .{ .iterate = true });
        defer dir.close();
        const dir_path = try dir.realpathAlloc(alloc, ".");
        defer alloc.free(dir_path);

        var walker = try dir.walk(alloc);
        defer walker.deinit();

        while (try walker.next()) |entry| {
            switch (entry.kind) {
                .file => {
                    const item = try route_contextes.append(.{ .entry_path = entry.path, .dir_path = dir_path });
                    router.getC(item.url, staticFileHandler, .{ .ctx = item.ctx });

                    const INDEX_HTML = "/index.html";
                    if (std.mem.endsWith(u8, item.url, INDEX_HTML)) {
                        router.getC(item.url[0 .. item.url.len - INDEX_HTML.len], staticFileHandler, .{ .ctx = item.ctx });
                    } else if (std.mem.eql(u8, item.url, "index.html")) {
                        router.getC("/", staticFileHandler, .{ .ctx = item.ctx });
                    }
                },
                else => {},
            }
        }
    } else {
        comptime var handlers: [resources.resources.len]HandlerPtr = undefined;
        comptime for (resources.resources, 0..) |resource, i| {
            handlers[i] = &genResourceHandler(resource);
        };
        for (resources.resources, 0..) |resource, i| {
            const handler = handlers[i];

            router.get(resource.path, handler);

            const INDEX_HTML = "/index.html";
            if (std.mem.endsWith(u8, resource.path, INDEX_HTML)) {
                router.get(resource.path[0 .. resource.path.len - INDEX_HTML.len], handler);
            }
        }
    }

    return route_contextes;
}

fn staticFileHandler(ctx: *Context, _: *httpz.Request, res: *httpz.Response) !void {
    const Fifo = std.fifo.LinearFifo(u8, .{ .Static = 10 });
    const path = if (ctx.static_file) |file| file.abs else return;

    res.status = 200;
    res.content_type = httpz.ContentType.forFile(path);
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    var buff_reader = std.io.bufferedReader(file.reader());

    var fifo = Fifo.init();
    defer fifo.deinit();
    try fifo.pump(buff_reader.reader(), res.writer());
}

const Handler = fn (*Context, *httpz.Request, *httpz.Response) anyerror!void;
const HandlerPtr = *const Handler;

fn genResourceHandler(comptime resource: resources.Resource) Handler {
    return struct {
        fn f(_: *Context, _: *httpz.Request, res: *httpz.Response) !void {
            res.status = 200;
            res.content_type = httpz.ContentType.forFile(resource.path);
            res.body = resource.data;
        }
    }.f;
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
        \\  timestampType INTEGER NOT NULL,
        \\  visible INTEGER NOT NULL DEFAULT 1
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
