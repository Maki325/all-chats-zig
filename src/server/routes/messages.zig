const std = @import("std");
const httpz = @import("httpz");
const protocol = @import("protocol");
const Handler = @import("../Handler.zig");
const Context = @import("../Context.zig");
const Message = @import("../models/Message.zig");

// POST messages/:id/toggle
pub fn toggle(ctx: *Context, req: *httpz.Request, res: *httpz.Response) !void {
    const message_id = try std.fmt.parseInt(i64, req.param("id").?, 10);

    {
        const query =
            \\UPDATE
            \\  messages
            \\SET
            \\  visible = NOT visible
            \\WHERE
            \\  id = ?;
        ;
        var stmt = try ctx.db.prepare(query);
        defer stmt.deinit();

        try stmt.exec(.{}, .{
            .id = message_id,
        });
    }

    const message = (try Message.selectOne(&ctx.db, req.arena, message_id)).?;
    const html = try message.toHtml(res.arena);

    var writer = protocol.Writer.init(req.arena);
    defer writer.deinit();
    try (protocol.messages.ToClient.Message{
        .ToggleMessage = protocol.messages.ToClient.ToggleMessage{
            .id = message.id,
            .visible = message.visible != 0,
        },
    }).serialize(&writer);

    try ctx.writeToAllWs(null, writer.data.items);

    res.body = html;
}
