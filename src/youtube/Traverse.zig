const std = @import("std");

pub fn getChannelId(callback_key: TraverseCallbackKey, value: std.json.Value) ?[]const u8 {
    switch (callback_key) {
        .string => |key| {
            if (std.mem.eql(u8, key, "channelNavigationEndpoint")) {
                switch (value) {
                    .object => |obj| {
                        if (obj.get("browseEndpoint")) |browse_endpoint| {
                            switch (browse_endpoint) {
                                .object => |browse_endpoint_obj| {
                                    if (browse_endpoint_obj.get("browseId")) |browse_id| {
                                        switch (browse_id) {
                                            .string => |s| return s,
                                            else => return null,
                                        }
                                    }
                                },
                                else => {},
                            }
                        }
                    },
                    else => {},
                }
            }
        },
        else => {},
    }

    return null;
}

const LIVE_CHAT_TEXT = "Ћаскање уживо";

pub fn getContinuation(_: TraverseCallbackKey, value: std.json.Value) ?std.json.ObjectMap {
    switch (value) {
        .object => |obj| {
            if (obj.get("title")) |title_value| {
                switch (title_value) {
                    .string => |title| {
                        if (std.mem.eql(u8, title, LIVE_CHAT_TEXT)) {
                            if (obj.get("continuation")) |cont| {
                                switch (cont) {
                                    .object => |cont_obj| return cont_obj,
                                    else => return null,
                                }
                            }
                        }
                    },
                    else => {},
                }
            }
        },
        else => {},
    }

    return null;
}

pub const ActionItem = struct {
    action_type: []const u8,
    item_type: []const u8,
    action: std.json.ObjectMap,
};
pub fn getActionItem(key: TraverseCallbackKey, value: std.json.Value) ?ActionItem {
    const action_type = switch (key) {
        .string => |s| if (std.mem.eql(u8, s, "clickTrackingParams")) {
            return null;
        } else s,
        else => return null,
    };
    switch (value) {
        .object => |obj| {
            if (obj.get("item")) |item_value| {
                switch (item_value) {
                    .object => |item| {
                        const item_type = item.keys()[0];
                        if (item.get(item_type)) |ai| {
                            switch (ai) {
                                .object => |ai_obj| return .{
                                    .action_type = action_type,
                                    .item_type = item_type,
                                    .action = ai_obj,
                                },
                                else => return null,
                            }
                        }
                    },
                    else => {},
                }
            }
        },
        else => {},
    }

    return null;
}

pub fn getContinuationToken(_: TraverseCallbackKey, value: std.json.Value) ?[]const u8 {
    switch (value) {
        .object => |obj| {
            if (obj.get("continuation")) |continuation| {
                switch (continuation) {
                    .string => |s| return s,
                    else => return null,
                }
            }
        },
        else => {},
    }

    return null;
}

const TraverseCallbackKey = union(enum) {
    number: usize,
    string: []const u8,
};

pub fn traverse(
    comptime T: type,
    value: std.json.Value,
    callback: *const fn (key: TraverseCallbackKey, value: std.json.Value) ?T,
) ?T {
    switch (value) {
        .object => |obj| {
            for (obj.keys()) |key| {
                if (obj.get(key)) |obj_value| {
                    if (callback(.{ .string = key }, obj_value)) |ret| {
                        return ret;
                    }
                    if (traverse(T, obj_value, callback)) |ret| {
                        return ret;
                    }
                }
            }
        },
        .array => |array| {
            for (0..array.items.len) |i| {
                if (callback(.{ .number = i }, array.items[i])) |ret| {
                    return ret;
                }
                if (traverse(T, array.items[i], callback)) |ret| {
                    return ret;
                }
            }
        },
        else => {},
    }

    return null;
}
