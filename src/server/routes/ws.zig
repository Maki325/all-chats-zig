const std = @import("std");
const httpz = @import("httpz");
const Handler = @import("../Handler.zig");
const Context = @import("../Context.zig");

pub fn handle(ctx: *Context, req: *httpz.Request, res: *httpz.Response) !void {
    std.debug.print("Got connection!", .{});
    if (try httpz.upgradeWebsocket(Handler, req, res, ctx) == false) {
        // this was not a valid websocket handshake request
        // you should probably return with an error
        res.status = 400;
        res.body = "invalid websocket handshake";
        return;
    }
    // when upgradeWebsocket succeeds, you can no longer use `res`
}
