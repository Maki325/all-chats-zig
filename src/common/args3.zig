const std = @import("std");
const builtin = @import("builtin");

pub fn new() Builder(0) {
    return .{
        .args = undefined,
    };
}

fn Builder(size: comptime_int) type {
    return struct {
        const Self = @This();
        args: [size]Args,

        pub fn field(self: Self, name: []const u8, flag: []const u8, ty: ?type) Builder(size + 1) {
            const builder: Builder(size + 1) = .{ .args = undefined };
            inline for (self.args, 0..) |arg, i| {
                builder.args[i] = arg;
            }
            builder.args[size] = .{ .field = .{ .name = name, .flag = flag, .type = ty } };

            return builder;
        }

        pub fn help(self: Self, help_fn: fn () noreturn) Builder(size + 1) {
            const builder: Builder(size + 1) = .{ .args = undefined };
            inline for (self.args, 0..) |arg, i| {
                builder.args[i] = arg;
            }
            builder.args[size] = .{ .help = help_fn };

            return builder;
        }

        pub fn build(self: Self) type {
            comptime {
                var args_fields: [size]std.builtin.Type.StructField = undefined;
                for (self.args, 0..) |arg, i| {
                    switch (arg) {
                        .field => |f| {
                            args_fields[i] = .{
                                .name = f.name,
                                .type = f.type orelse []const u8,
                                .default_value = null,
                                .is_comptime = false,
                                .alignment = 0,
                            };
                        },
                        else => {
                            continue;
                        },
                    }
                }

                return @Type(.{
                    .Struct = .{
                        .layout = .auto,
                        .is_tuple = false,
                        .fields = &args_fields,
                        .decls = &.{},
                    },
                });
            }
        }
    };
}

const Args = union(enum) {
    help: fn () noreturn,
    field: struct {
        name: []const u8,
        flag: []const u8,
        type: ?type,
    },
};

pub fn main() void {
    // zig fmt: off
    const ArgType = new()
        .field("hello", "--hello", null)
        .help(struct {
            fn help() noreturn {
                std.debug.print("A!", .{});
            }
        }.help)
        .build();
        // zig fmt: on

    const args: ArgType = undefined;

    std.debug.print("Args: {any}\n", .{args});
}
