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
    flag: []const u8,
};

pub fn parse(comptime args: anytype) !void {
    switch (@typeInfo(@TypeOf(args))) {
        .Array => {},
        else => {
            dump(@typeInfo(@TypeOf(args)));
            return error.ExpectedArray;
        },
    }
    switch (@typeInfo(@typeInfo(@TypeOf(args)).Array.child)) {
        .Struct => {},
        else => {
            return error.ExpectedStruct;
        },
    }
    std.debug.print("Ok\n", .{});
    // const args_info = @typeInfo(ArgsType).Struct;

    // const generated_struct = comptime blk: {
    //     _ = std.builtin.Type;
    //     var fields: [args_info.fields.len]std.builtin.Type.Array StructField = undefined;

    //     for (args_info.fields, 0..) |f, i| {
    //         fields[i] = .{
    //             .name = f.name,
    //             .type = @Type(.{ .Optional = .{ .child = f.type } }),
    //             .default_value = f.default_value,
    //             .is_comptime = f.is_comptime,
    //             .alignment = f.alignment,
    //         };
    //     }

    //     var data: @Type(.{
    //         .Struct = .{
    //             .layout = .auto,
    //             .is_tuple = false,
    //             .fields = &fields,
    //             .decls = &.{},
    //         },
    //     }) = undefined;

    //     for (args_info.fields) |f| {
    //         @field(data, f.name) = null;
    //     }

    //     break :blk data;
    // };
    // std.debug.print("What? {any}\n", .{generated_struct});
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
