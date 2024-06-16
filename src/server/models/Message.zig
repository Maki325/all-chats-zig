const std = @import("std");
const protocol = @import("protocol");
const c = @cImport({
    @cInclude("stdlib.h");
    @cInclude("time.h");
});
const sqlite = @import("sqlite");

const Message = @This();

id: i64,
platform: u64,
author_id: []const u8,
author: []const u8,
message: []const u8,
timestamp: i64,
timestamp_type: protocol.TimestampType,
visible: u64,

pub fn selectMany(db: *sqlite.Db, alloc: std.mem.Allocator) ![]Message {
    const query =
        \\SELECT
        \\  id,
        \\  platform,
        \\  authorId,
        \\  author,
        \\  message,
        \\  timestamp,
        \\  timestampType,
        \\  visible
        \\FROM
        \\  messages
        \\ORDER BY
        \\  id DESC
        \\LIMIT 100;
    ;
    var stmt = try db.prepare(query);
    defer stmt.deinit();

    return try stmt.all(Message, alloc, .{}, .{});
}

pub fn selectOne(db: *sqlite.Db, alloc: std.mem.Allocator, id: i64) !?Message {
    const query =
        \\SELECT
        \\  id,
        \\  platform,
        \\  authorId,
        \\  author,
        \\  message,
        \\  timestamp,
        \\  timestampType,
        \\  visible
        \\FROM
        \\  messages
        \\WHERE
        \\  id = ?
        \\;
    ;

    var stmt = try db.prepare(query);
    defer stmt.deinit();

    return try stmt.oneAlloc(Message, alloc, .{}, .{
        .id = id,
    });
}

pub fn toHtml(self: *const Message, alloc: std.mem.Allocator) ![]const u8 {
    // const s_ms = self.getSecondsAndMiliseconds();
    // const tm = Time.fromTm(c.localtime(&s_ms.seconds));
    const tm = Time.fromTimestamp(self.timestamp, self.timestamp_type);

    const html = try std.fmt.allocPrint(alloc,
        \\<tr id="msg-{d}" {s}>
        \\    <td class="msg-id">{d}</td>
        \\    <td class="msg-platform"><div><img class="msg-platform-icon" src="{s}" /></div></td>
        \\    <td><a class="msg-sender" href="{s}/{s}">{s}</a></td>
        \\    <td class="msg-text">{s}</td>
        \\    <td id="msg-timestamp-{d}" class="msg-timestamp" hx-preserve="true">{d}/{d:0>2}/{d:0>2} {d:0>2}:{d:0>2}:{d:0>2}.{d:0>3}</td>
        \\    <td class="msg-action" hx-post="/messages/{d}/toggle" hx-target="#msg-{d}" hx-swap="outerHTML">{s}</td>
        \\</tr>
        \\
    , .{
        self.id,
        if (self.visible == 0) "class=\"deleted\"" else "",
        self.id,
        switch (self.platform) {
            0 => "./youtube.svg",
            1 => "./twitch-purple.svg",
            else => "Unknown!",
        },
        switch (self.platform) {
            0 => "https://youtube.com/channel",
            1 => "https://twitch.tv",
            else => "Unknown Platform!",
        },
        switch (self.platform) {
            0 => self.author_id,
            1 => self.author,
            else => "Unknown Platform!",
        },
        self.author,
        self.message,
        self.id,

        // Date
        tm.year + 1900,
        tm.month + 1,
        tm.month_day,
        // Time
        tm.hour,
        tm.minute,
        tm.second,
        tm.milisecond,

        self.id,
        self.id,
        if (self.visible == 0) "Show" else "Hide",
    });

    return html;
}

pub fn toOdlHtml(self: *const Message, alloc: std.mem.Allocator) ![]const u8 {
    var timeBuf: [32]u8 = undefined;
    const time = self.getSecondsAndMiliseconds();
    const ts = c.localtime(&time.seconds);
    ts.*.tm_year;
    const len = c.strftime(&timeBuf, timeBuf.len, "%Y/%2m/%2d %2H:%2M:%2S", ts);
    if (len == 0) {
        return error.TimeFormatError;
    }

    const html = try std.fmt.allocPrint(alloc,
        \\<tr id="msg-{d}" {s}>
        \\    <td class="msg-id">{d}</td>
        \\    <td class="msg-platform"><div><img class="msg-platform-icon" src="{s}" /></div></td>
        \\    <td><a class="msg-sender" href="{s}/{s}">{s}</a></td>
        \\    <td class="msg-text">{s}</td>
        \\    <td id="msg-timestamp-{d}" class="msg-timestamp" hx-preserve="true">{s}.{d:0>3}</td>
        \\    <td class="msg-action" hx-post="/messages/{d}/toggle" hx-target="#msg-{d}" hx-swap="outerHTML">{s}</td>
        \\</tr>
        \\
    , .{
        self.id,
        if (self.visible == 0) "class=\"deleted\"" else "",
        self.id,
        switch (self.platform) {
            0 => "./youtube.svg",
            1 => "./twitch-purple.svg",
            else => "Unknown!",
        },
        switch (self.platform) {
            0 => "https://youtube.com/channel",
            1 => "https://twitch.tv",
            else => "Unknown Platform!",
        },
        switch (self.platform) {
            0 => self.author_id,
            1 => self.author,
            else => "Unknown Platform!",
        },
        self.author,
        self.message,
        self.id,
        // Time

        // End Time
        // self.timestamp,
        // @intFromEnum(self.timestamp_type),
        timeBuf[0..len],
        time.miliseconds,
        self.id,
        self.id,
        if (self.visible == 0) "Show" else "Hide",
    });

    return html;
}

const Time = struct {
    year: u16,
    month: u8,
    month_day: u8,
    hour: u8,
    minute: u8,
    second: u8,
    milisecond: u16,

    fn fromTm(tm: [*c]c.struct_tm) Time {
        // https://cplusplus.com/reference/ctime/tm
        return Time{
            .year = @intCast(tm.*.tm_year),
            .month = @intCast(tm.*.tm_mon),
            .month_day = @intCast(tm.*.tm_mday),
            .hour = @intCast(tm.*.tm_hour),
            .minute = @intCast(tm.*.tm_min),
            .second = @intCast(tm.*.tm_sec),
            .milisecond = 0,
        };
    }

    fn fromTimestamp(timestamp: i64, timestamp_type: protocol.TimestampType) Time {
        var seconds: i64 = undefined;
        var miliseconds: u16 = undefined;
        switch (timestamp_type) {
            .Second => {
                seconds = timestamp;
                miliseconds = 0;
            },
            .Milisecond => {
                seconds = @divFloor(timestamp, std.time.ms_per_s);
                miliseconds = @intCast(@mod(timestamp, std.time.ms_per_s));
            },
            .Microsecond => {
                seconds = @divFloor(timestamp, 1_000_000);
                miliseconds = @intCast(@divFloor(@mod(timestamp, 1_000_000), 1_000));
            },
            .Nanosecond => {
                seconds = @divFloor(timestamp, std.time.ns_per_s);
                miliseconds = @intCast(@divFloor(@mod(timestamp, std.time.ns_per_s), std.time.ns_per_ms));
            },
        }

        const tm = c.localtime(&seconds);

        // https://cplusplus.com/reference/ctime/tm
        return Time{
            .year = @intCast(tm.*.tm_year),
            .month = @intCast(tm.*.tm_mon),
            .month_day = @intCast(tm.*.tm_mday),
            .hour = @intCast(tm.*.tm_hour),
            .minute = @intCast(tm.*.tm_min),
            .second = @intCast(tm.*.tm_sec),
            .milisecond = miliseconds,
        };
    }
};

fn getSecondsAndMiliseconds(self: *const Message) struct { seconds: i64, miliseconds: u64 } {
    switch (self.timestamp_type) {
        .Second => return .{ .seconds = self.timestamp, .miliseconds = 0 },
        .Milisecond => return .{
            .seconds = @divFloor(self.timestamp, std.time.ms_per_s),
            .miliseconds = @intCast(@mod(self.timestamp, std.time.ms_per_s)),
        },
        .Microsecond => return .{
            .seconds = @divFloor(self.timestamp, 1_000_000),
            .miliseconds = @intCast(@mod(self.timestamp, 1_000_000)),
        },
        .Nanosecond => return .{
            .seconds = @divFloor(self.timestamp, std.time.ns_per_s),
            .miliseconds = @intCast(@mod(self.timestamp, std.time.ns_per_s)),
        },
    }
}
