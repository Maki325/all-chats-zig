const std = @import("std");
const httpz = @import("httpz");
const protocol = @import("protocol");
const Handler = @import("../Handler.zig");
const Context = @import("../Context.zig");
const Message = @import("../models/Message.zig");

pub fn handle(ctx: *Context, req: *httpz.Request, res: *httpz.Response) !void {
    const content = try std.fs.cwd().readFileAlloc(req.arena, "templates/admin.html", 1024 * 1024);
    defer req.arena.free(content);

    const messages = try Message.selectMany(&ctx.db, res.arena);
    defer res.arena.free(messages);

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

        const html = try msg.toHtml(req.arena);
        defer req.arena.free(html);
        try messages_html.appendSlice(html);
    }

    const replaced = try std.mem.replaceOwned(u8, res.arena, content, "{{MESSAGES}}", messages_html.items);

    res.status = 200;
    res.body = replaced;
    return;
}
