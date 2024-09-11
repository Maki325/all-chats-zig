const std = @import("std");
const builtin = @import("builtin");

// fn MakeStruct(comptime in: anytype) type {
//     var fields: [in.len]std.builtin.Type.StructField = undefined;
//     for (in, 0..) |t, i| {
//         var fieldType: type = t[1];
//         var fieldName: []const u8 = t[0][0..];
//         if (fieldName[0] == '?') {
//             fieldType = @Type(.{ .Optional = .{ .child = fieldType } });
//             fieldName = fieldName[1..];
//         }
//         fields[i] = .{
//             .name = fieldName,
//             .field_type = fieldType,
//             .default_value = null,
//             .is_comptime = false,
//             .alignment = 0,
//         };
//     }
//     return @Type(.{
//         .Struct = .{
//             .layout = .Auto,
//             .fields = fields[0..],
//             .decls = &[_]std.builtin.TypeInfo.Declaration{},
//             .is_tuple = false,
//         },
//     });
// }

fn dump2(data: anytype) void {
    const T = @TypeOf(data);
    inline for (@typeInfo(T).Struct.fields) |field| {
        std.debug.print("{s}: {any}\n", .{ field.name, @field(data, field.name) });
    }
}
fn dump3(T: type) void {
    inline for (T.Union.fields) |field| {
        std.debug.print("{s}\n", .{field.name});
    }
}
fn dump4(args_info: anytype) void {
    const T = @TypeOf(args_info);
    // std.debug.print("C: {s}\n", .{@typeInfo(T).UnionField.name});
    // std.debug.print("A: {s}\n", .{@typeName(T)});
    inline for (std.meta.fields(T)) |f| {
        if (f.type == T) {
            std.debug.print("B: {s}\n", .{f.name});
            // return @field(args_info, f.name);
        }
        std.debug.print("D: {s}\n", .{f.name});
    }
    // inline for (@typeInfo(T).Union.tag_type) |field| {
    //     std.debug.print("{s}\n", .{field.name});
    // }
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

pub const Arg = struct {
    field_name: []const u8,
    field_type: type,
    flag: []const u8,
};

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

pub fn Args(comptime in_args: anytype) type {
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

    const NullableStruct, const create_null_data, const ArgsStruct, const map: std.StaticStringMap(ArgData), const set = comptime blk: {
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
                // return error.NoFieldType;
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

        // std.debug.print("{any}\n", .{flag_kvs});
        // std.debug.print("{s}\n", .{flag_kvs[0][0]});

        const map = std.StaticStringMap(ArgData).initComptime(flag_kvs);
        // std.debug.print("{any}\n", .{map.keys()});

        // std.builtin.Type.Struct
        const NullableStruct = @Type(.{
            .Struct = .{
                .layout = .auto,
                .is_tuple = false,
                .fields = &args_nullable_fields,
                .decls = &.{},
            },
        });

        const GeneratedStruct = @Type(.{
            .Struct = .{
                .layout = .auto,
                .is_tuple = false,
                .fields = &args_fields,
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

        break :blk .{ NullableStruct, create_null_data, GeneratedStruct, map, set };
    };

    return innerArgs(in_args, NullableStruct, create_null_data, ArgsStruct, map, set, fields);
}

pub fn parse(comptime in_args: anytype, default_program_name: []const u8, alloc: std.mem.Allocator) !void {
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

    const ArgData2 = struct {
        field_name: []const u8,
    };

    var args_to_fill, const ArgsType, const map: std.StaticStringMap(ArgData2), const set = comptime blk: {
        _ = std.builtin.Type;
        var args_fields: [fields.len]std.builtin.Type.StructField = undefined;
        var args_nullable_fields: [fields.len]std.builtin.Type.StructField = undefined;
        // var flag_kvs: [fields.len]std.meta.Tuple(&[_]type{ []const u8, *const anyopaque }) = undefined;
        var flag_kvs: [fields.len]std.meta.Tuple(&[_]type{ []const u8, ArgData2 }) = undefined;

        for (fields, 0..) |f, i| {
            const arg = @field(in_args, f.name);
            if (!@hasField(@TypeOf(arg), "field_name")) {
                @panic("No field_name!");
                // return error.NoFieldName;
            }
            if (!@hasField(@TypeOf(arg), "field_type")) {
                @panic("No field_type!");
                // return error.NoFieldType;
            }
            if (!@hasField(@TypeOf(arg), "flag")) {
                @panic("No flag!");
                // return error.NoFieldType;
            }
            flag_kvs[i][0] = @field(arg, "flag");
            const field_name = @field(arg, "field_name");
            const field_type = @field(arg, "field_type");
            flag_kvs[i][1] = ArgData2{
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

        // std.debug.print("{any}\n", .{flag_kvs});
        // std.debug.print("{s}\n", .{flag_kvs[0][0]});

        const map = std.StaticStringMap(ArgData2).initComptime(flag_kvs);
        // std.debug.print("{any}\n", .{map.keys()});

        // std.builtin.Type.Struct
        const NullableStruct = @Type(.{
            .Struct = .{
                .layout = .auto,
                .is_tuple = false,
                .fields = &args_nullable_fields,
                .decls = &.{},
            },
        });

        const GeneratedStruct = @Type(.{
            .Struct = .{
                .layout = .auto,
                .is_tuple = false,
                .fields = &args_fields,
                .decls = &.{},
            },
        });

        const set = struct {
            fn set(self: *NullableStruct, field_name: []const u8, value: anytype) void {
                inline for (std.meta.fields(NullableStruct)) |f| {
                    if (std.mem.eql(u8, f.name, field_name)) {
                        @field(self, f.name) = value;
                        return;
                    }
                }
            }
        }.set;

        var nullable_data_to_fill: NullableStruct = undefined;
        for (args_nullable_fields) |f| {
            @field(nullable_data_to_fill, f.name) = null;
        }

        break :blk .{ nullable_data_to_fill, GeneratedStruct, map, set };
    };

    var arg_iterator = try std.process.argsWithAllocator(alloc);
    const program_name = arg_iterator.next() orelse default_program_name;
    _ = program_name;

    while (arg_iterator.next()) |arg| {
        const arg_data = map.get(arg) orelse {
            std.debug.print("Unknown argument: {s}\n", .{arg});
            // help(program_name);
            std.process.exit(2);
        };

        set(&args_to_fill, arg_data.field_name, arg_iterator.next() orelse {
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

    var final_args: ArgsType = undefined;
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
                    return error.FieldNotFilled;
                };
            },
        }
    }

    std.debug.print("Args: {any}\n", .{args_to_fill});

    return final_args;
}

pub fn parse2(comptime ArgsType: type) !void {
    // std.fmt.format(writer: anytype, comptime fmt: []const u8, args: anytype)
    // var arg_iterator = try std.process.argsWithAllocator(alloc);
    // _ = MakeStruct(ArgsType);

    // std.builtin.Type;
    // std.builtin.Type.Struct;
    const args_info = @typeInfo(ArgsType).Struct;
    // dump(args_info);
    // dump2(args_info.Struct);
    // std.debug.print("{any}\n", .{ArgsInfo});

    // // std.debug.print("{any}", .{ArgsInfo.fields});
    // // ArgsInfo.fields[0].type = ?ArgsInfo.fields[0].type;

    const generated_struct = comptime blk: {
        _ = std.builtin.Type;
        var fields: [args_info.fields.len]std.builtin.Type.StructField = undefined;

        for (args_info.fields, 0..) |f, i| {
            fields[i] = .{
                .name = f.name,
                .type = @Type(.{ .Optional = .{ .child = f.type } }),
                .default_value = f.default_value,
                .is_comptime = f.is_comptime,
                .alignment = f.alignment,
            };
        }

        var data: @Type(.{
            .Struct = .{
                .layout = .auto,
                .is_tuple = false,
                .fields = &fields,
                .decls = &.{},
            },
        }) = undefined;

        for (args_info.fields) |f| {
            @field(data, f.name) = null;
        }

        break :blk data;
    };
    std.debug.print("What? {any}\n", .{generated_struct});

    // var fields: [ArgsInfo.fields.len]std.builtin.Type.StructField = comptime undefined;
    // fields[0] = @Type(.{ .void = void });
    // var fields = try alloc.alloc(std.builtin.Type.StructField, 1);
    // defer alloc.free(fields);

    // for (ArgsInfo.fields, 0..) |f, i| {
    //     fields[i] = f;
    //     fields[i].type = ?fields[i].type;
    // }

    // @Type(.{
    //     .Struct = .{
    //         .layout = .auto,
    //         .is_tuple = false,
    //         .fields = &fields,
    //         .decls = &.{},
    //     },
    // });

    // std.debug.print("{any}", .{ArgsInfo.fields});

    // var host: []const u8 = "localhost";
    // var port: u16 = 5882;
    // var nick_opt: ?[]const u8 = null;
    // var channel_opt: ?[]const u8 = null;

    // const program_name = arg_iterator.next() orelse "bot-twitch";

    // while (arg_iterator.next()) |arg| {
    //     const s = ArgName.parse(arg) orelse {
    //         print("Unknown argument: {s}\n", .{arg});
    //         help(program_name);
    //     };
    //     switch (s) {
    //         .@"--help" => {
    //             help(program_name);
    //         },
    //         .@"--host" => {
    //             host = arg_iterator.next() orelse {
    //                 print("--host provided with no value!\n", .{});
    //                 help(program_name);
    //             };
    //         },
    //         .@"--port" => {
    //             const port_str = arg_iterator.next() orelse {
    //                 print("--port provided with no value!\n", .{});
    //                 help(program_name);
    //             };
    //             port = std.fmt.parseInt(u16, port_str, 10) catch {
    //                 print("Invalid port provided!\n", .{});
    //                 help(program_name);
    //             };
    //         },
    //         .@"--nick" => {
    //             nick_opt = arg_iterator.next() orelse {
    //                 print("--nick provided with nickname!\n", .{});
    //                 help(program_name);
    //             };
    //         },
    //         .@"--channel" => {
    //             channel_opt = arg_iterator.next() orelse {
    //                 print("--channel provided with no twitch channel username!\n", .{});
    //                 help(program_name);
    //             };
    //         },
    //     }
    // }

    // return .{
    //     .arg_iterator = arg_iterator,
    //     .host = host,
    //     .port = port,
    //     .nick = nick_opt orelse {
    //         print("Please provide a nickname with --nick!\n", .{});
    //         help(program_name);
    //     },
    //     .channel = channel_opt orelse {
    //         print("Please provide a twitch channel with --channel!\n", .{});
    //         help(program_name);
    //     },
    // };
}
