const std = @import("std");

const Args = @This();

arg_iterator: std.process.ArgIterator,
host: []const u8 = "localhost",
port: u16 = 5882,
nick: []const u8,
channel: []const u8,

pub fn parse(alloc: std.mem.Allocator) !Args {
    var arg_iterator = try std.process.argsWithAllocator(alloc);

    var host: []const u8 = "localhost";
    var port: u16 = 5882;
    var nick_opt: ?[]const u8 = null;
    var channel_opt: ?[]const u8 = null;

    const program_name = arg_iterator.next() orelse "bot-twitch";

    while (arg_iterator.next()) |arg| {
        const s = ArgName.parse(arg) orelse {
            print("Unknown argument: {s}\n", .{arg});
            help(program_name);
        };
        switch (s) {
            .@"--help" => {
                help(program_name);
            },
            .@"--host" => {
                host = arg_iterator.next() orelse {
                    print("--host provided with no value!\n", .{});
                    help(program_name);
                };
            },
            .@"--port" => {
                const port_str = arg_iterator.next() orelse {
                    print("--port provided with no value!\n", .{});
                    help(program_name);
                };
                port = std.fmt.parseInt(u16, port_str, 10) catch {
                    print("Invalid port provided!\n", .{});
                    help(program_name);
                };
            },
            .@"--nick" => {
                nick_opt = arg_iterator.next() orelse {
                    print("--nick provided with nickname!\n", .{});
                    help(program_name);
                };
            },
            .@"--channel" => {
                channel_opt = arg_iterator.next() orelse {
                    print("--channel provided with no twitch channel username!\n", .{});
                    help(program_name);
                };
            },
        }
    }

    return .{
        .arg_iterator = arg_iterator,
        .host = host,
        .port = port,
        .nick = nick_opt orelse {
            print("Please provide a nickname with --nick!\n", .{});
            help(program_name);
        },
        .channel = channel_opt orelse {
            print("Please provide a twitch channel with --channel!\n", .{});
            help(program_name);
        },
    };
}

pub fn deinit(args: *Args) void {
    args.arg_iterator.deinit();
}

fn print(comptime fmt: []const u8, params: anytype) void {
    std.io.getStdErr().writer().print(fmt, params) catch {};
}

fn help(program_name: []const u8) noreturn {
    print("Usage: {s} [ARGS]\n\nARGS:\n", .{program_name});

    inline for (std.meta.fields(ArgName)) |s| {
        print("{s}: ", .{s.name});
        const value: ArgName = @enumFromInt(s.value);

        switch (value) {
            .@"--help" => {
                print("Shows this help", .{});
            },
            .@"--host" => {
                print("Aggregation server host", .{});
            },
            .@"--port" => {
                print("Aggregation server port", .{});
            },
            .@"--nick" => {
                print("Nickname with which to type in chat", .{});
            },
            .@"--channel" => {
                print("Channel name from where to read messages", .{});
            },
        }
        print("\n", .{});
    }

    std.process.exit(1);
}

const ArgName = enum {
    @"--help",
    @"--host",
    @"--port",
    @"--nick",
    @"--channel",

    fn parse(s: []const u8) ?ArgName {
        inline for (std.meta.fields(ArgName)) |f| {
            if (std.mem.eql(u8, f.name, s)) {
                return @enumFromInt(f.value);
            }
        }

        return null;
    }
};
