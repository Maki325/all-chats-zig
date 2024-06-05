const std = @import("std");
const websocket = @import("websocket");
const Context = @import("Context.zig");
const protocol = @import("protocol");

const Handler = @This();

conn: *websocket.Conn,
context: *Context,

pub fn init(_: websocket.Handshake, conn: *websocket.Conn, context: *Context) !Handler {
    try context.addConn(conn);
    return Handler{
        .conn = conn,
        .context = context,
    };
}

// optional hook that, if present, will be called after initialization is complete
pub fn afterInit(h: *Handler) !void {
    std.debug.print("afterInit!\n", .{});
    try h.conn.writePing(&[0]u8{});
}

pub fn handle(handler: *Handler, message: websocket.Message) !void {
    handleImpl(handler, message) catch |e| {
        std.log.err("Got error ({any}) handling message: {any}\n", .{ e, message });
    };
}

fn handleImpl(self: *Handler, message: websocket.Message) !void {
    std.debug.print("Got msg: {any}\n", .{message});
    var reader = protocol.Reader.init(message.data);

    const message_id = try reader.readInt(u8);

    std.debug.print("message_id: {d}\n", .{message_id});

    const msg = try protocol.messages.ToServer.Message.deserialize(message_id, &reader);

    std.debug.print("Got msg: {any}\n", .{msg});

    switch (msg) {
        .AddMessage => |add_msg| {
            std.debug.print("Platform: {s}\n", .{@tagName(add_msg.platform)});
            std.debug.print("Author: {s}\n", .{add_msg.author});
            std.debug.print("Message: {s}\n", .{add_msg.message});
            std.debug.print("TimeStamp: {d}\n", .{add_msg.timestamp});

            const query =
                \\INSERT INTO messages (platform, author, message, timestamp) VALUES (?, ?, ?, ?)
            ;

            var stmt = try self.context.db.prepare(query);
            defer stmt.deinit();

            try stmt.exec(.{}, .{
                .platform = @intFromEnum(add_msg.platform),
                .author = add_msg.author,
                .message = add_msg.message,
                .timestamp = add_msg.timestamp,
            });

            const id = self.context.db.getLastInsertRowID();

            var writer = protocol.Writer.init(self.context.alloc);
            defer writer.deinit();
            try (protocol.messages.ToClient.Message{
                .AddMessage = protocol.messages.ToClient.AddMessage{
                    .id = id,
                    .author = add_msg.author,
                    .message = add_msg.message,
                    .platform = add_msg.platform,
                    .timestamp = add_msg.timestamp,
                },
            }).serialize(&writer);

            try self.context.writeToAll(self.conn, writer.data.items);
        },
    }
}

// called whenever the connection is closed, can do some cleanup in here
pub fn close(self: *Handler) void {
    self.context.removeConn(self.conn);
    std.debug.print("Closed: {any}\n", .{self});
}
