const std = @import("std");
const builtin = @import("builtin");

const ArgData = struct {
    field_name: []const u8,
};

pub fn innerArgs(
    comptime in_args: anytype,
    comptime NullableStruct: type,
    comptime create_null_data: fn () NullableStruct,
    comptime ArgsStruct: type,
    comptime map: std.StaticStringMap(ArgData),
    comptime set: fn (*NullableStruct, []const u8, value: anytype) error{InvalidInput}!void,
    comptime fields: []const std.builtin.Type.StructField,
) type {
    return struct {
        // const Self = @This();
        pub fn parse(default_program_name: []const u8, alloc: std.mem.Allocator) !ArgsStruct {
            var arg_iterator = try std.process.argsWithAllocator(alloc);
            const program_name = arg_iterator.next() orelse default_program_name;
            _ = program_name;

            var args_to_fill = create_null_data();

            while (arg_iterator.next()) |arg| {
                const arg_data = map.get(arg) orelse {
                    std.debug.print("Unknown argument: {s}\n", .{arg});
                    // help(program_name);
                    std.process.exit(2);
                };

                try set(&args_to_fill, arg_data.field_name, arg_iterator.next() orelse {
                    std.debug.print("{s} provided with no value!\n", .{arg});
                    // help(program_name);
                    std.process.exit(2);
                });

                // @field(args_to_fill, arg_data.field_name) = arg_iterator.next() orelse {
                //     std.debug.print("{s} provided with no value!\n", .{arg});
                //     // help(program_name);
                //     std.process.exit(2);
                // };
                // _ = args_to_fill;
                // _ = data;
            }

            var final_args: ArgsStruct = undefined;
            inline for (fields) |f| {
                const arg = @field(in_args, f.name);
                const field_name = @field(arg, "field_name");

                const field_type = @field(arg, "field_type");
                switch (@typeInfo(field_type)) {
                    .Optional => {
                        @field(final_args, field_name) = @field(args_to_fill, field_name);
                    },
                    else => {
                        @field(final_args, field_name) = @field(args_to_fill, field_name) orelse {
                            std.debug.print("Field not filled! {s}\n", .{field_name});
                            return error.FieldNotFilled;
                        };
                    },
                }
            }

            std.debug.print("Args: {any}\n", .{args_to_fill});

            return final_args;
        }
    };
}

pub fn get_struct_type(comptime in_args: anytype) type {
    const fields = switch (@typeInfo(@TypeOf(in_args))) {
        .Struct => |s| blk: {
            if (!s.is_tuple) {
                return error.ExpectedTuple;
            }
            break :blk s.fields;
        },
        else => {
            dump(@typeInfo(@TypeOf(in_args)));
            return error.ExpectedTuple;
        },
    };

    _ = std.builtin.Type;
    var args_fields: [fields.len]std.builtin.Type.StructField = undefined;

    inline for (fields, 0..) |f, i| {
        const arg = @field(in_args, f.name);
        if (!@hasField(@TypeOf(arg), "field_name")) {
            @panic("No field_name!");
            // return error.NoFieldName;
        }
        if (!@hasField(@TypeOf(arg), "field_type")) {
            if (!@hasField(@TypeOf(arg), "fn")) {
                @panic("No field_type or fn!");
                // return error.NoFieldType;
            }
            continue;
        }
        if (!@hasField(@TypeOf(arg), "flag")) {
            @panic("No flag!");
            // return error.NoFieldType;
        }
        const field_name = @field(arg, "field_name");
        const field_type = @field(arg, "field_type");
        args_fields[i] = .{
            .name = field_name,
            .type = field_type,
            .default_value = null,
            .is_comptime = false,
            .alignment = 0,
        };
    }

    const GeneratedStruct = @Type(.{
        .Struct = .{
            .layout = .auto,
            .is_tuple = false,
            .fields = &args_fields,
            .decls = &.{},
        },
    });

    return GeneratedStruct;
}

pub fn parse(comptime in_args: anytype, default_program_name: []const u8, alloc: std.mem.Allocator) !get_struct_type(in_args) {
    const fields = switch (@typeInfo(@TypeOf(in_args))) {
        .Struct => |s| blk: {
            if (!s.is_tuple) {
                return error.ExpectedTuple;
            }
            break :blk s.fields;
        },
        else => {
            dump(@typeInfo(@TypeOf(in_args)));
            return error.ExpectedTuple;
        },
    };

    const create_null_data, const map: std.StaticStringMap(ArgData), const set = comptime blk: {
        _ = std.builtin.Type;
        var args_fields: [fields.len]std.builtin.Type.StructField = undefined;
        var args_nullable_fields: [fields.len]std.builtin.Type.StructField = undefined;
        // var flag_kvs: [fields.len]std.meta.Tuple(&[_]type{ []const u8, *const anyopaque }) = undefined;
        var flag_kvs: [fields.len]std.meta.Tuple(&[_]type{ []const u8, ArgData }) = undefined;

        for (fields, 0..) |f, i| {
            const arg = @field(in_args, f.name);
            if (!@hasField(@TypeOf(arg), "field_name")) {
                @panic("No field_name!");
                // return error.NoFieldName;
            }
            if (!@hasField(@TypeOf(arg), "field_type")) {
                @panic("No field_type!");
                // if (!@hasField(@TypeOf(arg), "fn")) {
                //     @panic("No field_type or fn!");
                //     // return error.NoFieldType;
                // }
                // continue;
            }
            if (!@hasField(@TypeOf(arg), "flag")) {
                @panic("No flag!");
                // return error.NoFieldType;
            }
            flag_kvs[i][0] = @field(arg, "flag");
            const field_name = @field(arg, "field_name");
            const field_type = @field(arg, "field_type");
            flag_kvs[i][1] = ArgData{
                .field_name = field_name,
            };
            args_nullable_fields[i] = .{
                .name = field_name,
                // .type = @field(arg, "field_type"),
                .type = @Type(.{ .Optional = .{ .child = field_type } }),
                .default_value = null,
                .is_comptime = false,
                .alignment = 0,
            };
            args_fields[i] = .{
                .name = field_name,
                .type = field_type,
                .default_value = null,
                .is_comptime = false,
                .alignment = 0,
            };
        }

        const map = std.StaticStringMap(ArgData).initComptime(flag_kvs);

        const NullableStruct = @Type(.{
            .Struct = .{
                .layout = .auto,
                .is_tuple = false,
                .fields = &args_nullable_fields,
                .decls = &.{},
            },
        });

        const set = struct {
            fn set(self: *NullableStruct, field_name: []const u8, value: anytype) error{InvalidInput}!void {
                inline for (std.meta.fields(NullableStruct), 0..) |f, i| {
                    if (std.mem.eql(u8, f.name, field_name)) {
                        const arg = @field(in_args, fields[i].name);
                        if (@hasField(@TypeOf(arg), "parse")) {
                            @field(self, f.name) = try @field(arg, "parse")(value);
                        } else {
                            @field(self, f.name) = value;
                        }
                        return;
                    }
                }
            }
        }.set;

        const create_null_data = struct {
            fn create_null_data() NullableStruct {
                var nullable_data_to_fill: NullableStruct = undefined;
                inline for (args_nullable_fields) |f| {
                    @field(nullable_data_to_fill, f.name) = null;
                }

                return nullable_data_to_fill;
            }
        }.create_null_data;

        break :blk .{ create_null_data, map, set };
    };

    var arg_iterator = try std.process.argsWithAllocator(alloc);
    const program_name = arg_iterator.next() orelse default_program_name;
    _ = program_name;

    var args_to_fill = create_null_data();

    while (arg_iterator.next()) |arg| {
        const arg_data = map.get(arg) orelse {
            std.debug.print("Unknown argument: {s}\n", .{arg});
            // help(program_name);
            std.process.exit(2);
        };

        try set(&args_to_fill, arg_data.field_name, arg_iterator.next() orelse {
            std.debug.print("{s} provided with no value!\n", .{arg});
            // help(program_name);
            std.process.exit(2);
        });
    }

    var final_args: get_struct_type(in_args) = undefined;
    inline for (fields) |f| {
        const arg = @field(in_args, f.name);
        const field_name = @field(arg, "field_name");

        const field_type = @field(arg, "field_type");
        switch (@typeInfo(field_type)) {
            .Optional => {
                @field(final_args, field_name) = @field(args_to_fill, field_name);
            },
            else => {
                @field(final_args, field_name) = @field(args_to_fill, field_name) orelse {
                    std.debug.print("Field not filled! {s}\n", .{field_name});
                    return error.FieldNotFilled;
                };
            },
        }
    }

    std.debug.print("Args: {any}\n", .{args_to_fill});

    return final_args;
}

fn get_type() type {
    return struct {
        a: u32,
        // fn run() void {
        //     std.debug.print("AA\n", .{});
        // }
    };
}

pub fn idfk() get_type() {
    return .{
        .a = 12,
    };
}

fn dump(args_info: std.builtin.Type) void {
    switch (args_info) {
        .Type => std.debug.print("Type\n", .{}),
        .Void => std.debug.print("Void\n", .{}),
        .Bool => std.debug.print("Bool\n", .{}),
        .NoReturn => std.debug.print("NoReturn\n", .{}),
        .Int => std.debug.print("Int\n", .{}),
        .Float => std.debug.print("Float\n", .{}),
        .Pointer => std.debug.print("Pointer\n", .{}),
        .Array => std.debug.print("Array\n", .{}),
        .Struct => std.debug.print("Struct\n", .{}),
        .ComptimeFloat => std.debug.print("ComptimeFloat\n", .{}),
        .ComptimeInt => std.debug.print("ComptimeInt\n", .{}),
        .Undefined => std.debug.print("Undefined\n", .{}),
        .Null => std.debug.print("Null\n", .{}),
        .Optional => std.debug.print("Optional\n", .{}),
        .ErrorUnion => std.debug.print("ErrorUnion\n", .{}),
        .ErrorSet => std.debug.print("ErrorSet\n", .{}),
        .Enum => std.debug.print("Enum\n", .{}),
        .Union => std.debug.print("Union\n", .{}),
        .Fn => std.debug.print("Fn\n", .{}),
        .Opaque => std.debug.print("Opaque\n", .{}),
        .Frame => std.debug.print("Frame\n", .{}),
        .AnyFrame => std.debug.print("AnyFrame\n", .{}),
        .Vector => std.debug.print("Vector\n", .{}),
        .EnumLiteral => std.debug.print("EnumLiteral\n", .{}),
    }
}
