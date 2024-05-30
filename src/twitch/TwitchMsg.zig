const std = @import("std");

const TwitchMsg = @This();

alloc: std.mem.Allocator,
msg: []const u8,

tags: ?[]const u8,
source: ?Source,
sourceRaw: ?[]const u8,
cmd: Cmd,
cmdRaw: []const u8,
args: []const u8,

pub fn init(alloc: std.mem.Allocator, msgPtr: *const []const u8) !TwitchMsg {
    const msg = try alloc.dupe(u8, msgPtr.*);

    var msgParts = std.mem.split(u8, msg, " ");

    var tags: ?[]const u8 = null;

    if (msg[0] == '@') {
        tags = msgParts.next() orelse {
            std.debug.print("No `tags` in message: \"{s}\"", .{msg});
            return error.NoTags;
        };
    }

    var sourceRaw: ?[]const u8 = null;
    var source: ?Source = null;

    if (msg[msgParts.index orelse 0] == ':') {
        sourceRaw = msgParts.next() orelse {
            std.debug.print("No `source` in message: \"{s}\"", .{msg});
            return error.NoSource;
        };
        if (sourceRaw) |raw| {
            var it = std.mem.split(u8, raw, "!");
            const nick = it.next() orelse {
                return error.NoSourceHost;
            };
            const hostRaw = it.next();
            source = if (hostRaw) |host|
                .{ .hostAndNick = .{ .host = host, .nick = nick } }
            else
                .{ .host = nick };
        }
    }

    const cmdRaw = msgParts.next() orelse {
        std.debug.print("No `command` in message: \"{s}\"", .{msg});
        return error.NoCmd;
    };

    const cmd: Cmd =
        if (std.mem.eql(u8, cmdRaw, "001")) .SuccessfullyAuthenticated //
    else if (std.mem.eql(u8, cmdRaw, "JOIN")) .Join //
    else if (std.mem.eql(u8, cmdRaw, "PART")) .Part //
    else if (std.mem.eql(u8, cmdRaw, "NOTICE")) .Notice //
    else if (std.mem.eql(u8, cmdRaw, "CLEARCHAT")) .Clearchat //
    else if (std.mem.eql(u8, cmdRaw, "HOSTTARGET")) .Hosttarget //
    else if (std.mem.eql(u8, cmdRaw, "PRIVMSG")) .Privmsg //
    else if (std.mem.eql(u8, cmdRaw, "PING")) .Ping //
    else if (std.mem.eql(u8, cmdRaw, "CAP")) .Cap //
    else if (std.mem.eql(u8, cmdRaw, "GLOBALUSERSTATE")) .Globaluserstate //
    else if (std.mem.eql(u8, cmdRaw, "USERSTATE")) .Userstate //
    else if (std.mem.eql(u8, cmdRaw, "ROOMSTATE")) .Roomstate //
    else if (std.mem.eql(u8, cmdRaw, "RECONNECT")) .Reconnect //
    else if (std.mem.eql(u8, cmdRaw, "421")) .Unsupported //
    else .Unknown;

    // `msgParts.index` - number of chars
    const args = msg[msgParts.index orelse 0 ..];

    // <TAGS> <CMD> <CMD> <?ROOM> <?ARGS> <?ARGS> <?ARGS>
    return TwitchMsg{
        .alloc = alloc,
        .msg = msg,

        .tags = tags,
        .source = source,
        .sourceRaw = sourceRaw,
        .cmd = cmd,
        .cmdRaw = cmdRaw,
        .args = args,
    };
}

pub fn print(self: *const TwitchMsg) void {
    std.debug.print("TwitchMsg: {{\n  tags = \"{?s}\",\n  source = \"{?any}\",\n  cmd = {s},\n  args = \"{s}\"\n}}\n", .{
        self.tags,
        self.source,
        @tagName(self.cmd),
        self.args,
    });
}

pub fn printRaw(self: *const TwitchMsg) void {
    std.debug.print("TwitchMsg: {{\n  tags = \"{?s}\",\n  source = \"{?s}\",\n  cmdRaw = \"{s}\",\n  args = \"{s}\"\n}}\n", .{
        self.tags,
        self.sourceRaw,
        self.cmdRaw,
        self.args,
    });
}

pub fn deinit(self: TwitchMsg) void {
    self.alloc.free(self.msg);
}

const Cmd = enum(u8) {
    Join,
    Part,
    Notice,
    Clearchat,
    Hosttarget,
    Privmsg,
    Ping,
    Cap,
    Globaluserstate,
    Userstate,
    Roomstate,
    Reconnect,
    Unsupported,
    SuccessfullyAuthenticated,
    Unknown,
};

const SourceTypes = enum {
    host,
    hostAndNick,
};
const HostAndNick = struct {
    host: []const u8,
    nick: []const u8,
};
const Source = union(SourceTypes) {
    host: []const u8, //
    hostAndNick: HostAndNick,
};
