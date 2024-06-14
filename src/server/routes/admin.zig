const std = @import("std");
const httpz = @import("httpz");
const protocol = @import("protocol");
const Handler = @import("../Handler.zig");
const Context = @import("../Context.zig");

pub fn handle(ctx: *Context, req: *httpz.Request, res: *httpz.Response) !void {
    const content = try std.fs.cwd().readFileAlloc(req.arena, "templates/admin.html", 1024 * 1024);
    defer req.arena.free(content);

    const query =
        \\SELECT
        \\  id,
        \\  platform,
        \\  authorId,
        \\  author,
        \\  message,
        \\  timestamp,
        \\  timestampType
        \\FROM
        \\  messages
        \\ORDER BY
        \\  id DESC
        \\LIMIT 100;
    ;
    var stmt = try ctx.db.prepare(query);
    defer stmt.deinit();

    const messages = try stmt.all(struct {
        id: i64,
        platform: u64,
        author_id: []const u8,
        author: []const u8,
        message: []const u8,
        timestamp: i64,
        timestamp_type: u64,
    }, res.arena, .{}, .{});

    // We could use `req.arena` instead of `res.arena`, but would probably make
    // The loop bellow slower as we couldn't just reset the pointer to the current place
    // Because the ArrayList would be expanding constantly, thus moving the pointer forward
    // Without it being able to `free` the memory by moving backwards because we wouldn't be
    // The top of the "stack"
    var messages_html = std.ArrayList(u8).init(res.arena);
    defer messages_html.deinit();

    for (messages) |msg| {
        // We build in "req.arena" as it's temporary and fast(?) as it's FixedBufferAllocator
        // What we do is allocate something on it, and after appending it to the messages_html
        // We just return the pointer back to where it was at the begining by freeing
        // So it should be very cheap

        const href: []const u8 =
            switch (msg.platform) {
            0 => try std.fmt.allocPrint(req.arena, "https://youtube.com/channel/{s}", .{msg.author_id}),
            1 => try std.fmt.allocPrint(req.arena, "https://twitch.tv/{s}", .{msg.author}),
            else => try req.arena.dupe(u8, "Unknown Platform!"),
        };
        defer req.arena.free(href);

        const html = try std.fmt.allocPrint(req.arena,
            \\<tr>
            \\    <td class="msg-id">{d}</td>
            \\    <td class="msg-platform"><div><img class="msg-platform-icon" src="{s}" /></div></td>
            \\    <td><a class="msg-sender" href="{s}">{s}</a></td>
            \\    <td class="msg-text">{s}</td>
            \\    <td class="msg-timestamp">{d},{d}</td>
            \\</tr>
            \\
        , .{ msg.id, switch (msg.platform) {
            0 => "./youtube.svg",
            1 => "./twitch-purple.svg",
            else => "Unknown!",
        }, href, msg.author, msg.message, msg.timestamp, msg.timestamp_type });
        defer req.arena.free(html);

        try messages_html.appendSlice(html);
    }

    const replaced = try std.mem.replaceOwned(u8, res.arena, content, "{{MESSAGES}}", messages_html.items);

    res.status = 200;
    res.body = replaced;
    return;
}
