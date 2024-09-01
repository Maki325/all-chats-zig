const std = @import("std");
const websocket = @import("httpz").websocket;
const Context = @import("Context.zig");
const protocol = @import("protocol");

const Handler = @This();

conn: *websocket.Conn,
context: *Context,

pub fn init(conn: *websocket.Conn, context: *Context) !Handler {
    try context.addWsConn(conn);
    return Handler{
        .conn = conn,
        .context = context,
    };
}

// optional hook that, if present, will be called after initialization is complete
pub fn afterInit(h: *Handler) !void {
    try h.conn.writePing(&[0]u8{});
}

pub fn handle(handler: *Handler, message: websocket.Message) !void {
    handleImpl(handler, message) catch |e| {
        std.log.err("Got error ({any}) handling message: {any}", .{ e, message });
    };
}

fn handleImpl(self: *Handler, message: websocket.Message) !void {
    std.log.debug("Got msg: {any}\n", .{message});
    var reader = protocol.Reader.init(message.data);

    const message_id = try reader.readInt(u8);

    std.log.debug("message_id: {d}\n", .{message_id});

    const msg = try protocol.messages.ToServer.Message.deserialize(message_id, &reader);

    std.log.debug("Got msg: {any}\n", .{msg});

    switch (msg) {
        .AddMessage => |add_msg| {
            const query =
                \\INSERT INTO messages (
                \\  platform,
                \\  platformMessageId,
                \\  channelId,
                \\  authorId,
                \\  author,
                \\  message,
                \\  timestamp,
                \\  timestampType
                \\) VALUES (
                \\  ?,
                \\  ?,
                \\  ?,
                \\  ?,
                \\  ?,
                \\  ?,
                \\  ?,
                \\  ?
                \\)
            ;

            var stmt = try self.context.db.prepare(query);
            defer stmt.deinit();

            try stmt.exec(.{}, .{
                .platform = @intFromEnum(add_msg.platform),
                .platformMessageId = add_msg.platform_message_id,
                .channelId = add_msg.channel_id,
                .authorId = add_msg.author_id,
                .author = add_msg.author,
                .message = add_msg.message,
                .timestamp = add_msg.timestamp,
                .timestampType = @intFromEnum(add_msg.timestamp_type),
            });

            const id = self.context.db.getLastInsertRowID();

            var writer = protocol.Writer.init(self.context.alloc);
            defer writer.deinit();
            try (protocol.messages.ToClient.Message{
                .AddMessage = protocol.messages.ToClient.AddMessage{
                    .id = id,
                    .platform = add_msg.platform,
                    .platform_message_id = add_msg.platform_message_id,
                    .channel_id = add_msg.channel_id,
                    .author = add_msg.author,
                    .author_id = add_msg.author_id,
                    .message = add_msg.message,
                    .timestamp_type = add_msg.timestamp_type,
                    .timestamp = add_msg.timestamp,
                },
            }).serialize(&writer);

            try self.context.writeToAllWs(self.conn, writer.data.items);
        },
    }
}

// called whenever the connection is closed, can do some cleanup in here
pub fn close(self: *Handler) void {
    self.context.removeWsConn(self.conn);
    std.log.debug("Closed: {any}\n", .{self});
}
