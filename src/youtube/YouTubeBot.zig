const std = @import("std");
const TimeMs = i64;

const YouTubeBot = @This();

alloc: std.mem.Allocator,
client: std.http.Client,

inner_tube_api_key: []const u8,
inner_tube_ctx: std.json.Parsed(std.json.Value),
channel_id: []const u8,
continuation_token: []const u8,
seen_msgs: std.StringArrayHashMap(TimeMs),

pub fn init(alloc: std.mem.Allocator, stream_id: []const u8) !YouTubeBot {
    var client = std.http.Client{
        .allocator = alloc,
    };

    var data = std.ArrayList(u8).init(alloc);
    defer data.deinit();
    const res = try client.fetch(.{
        .location = .{ .url = try std.mem.concat(alloc, u8, &.{ "https://www.youtube.com/watch?v=", stream_id }) },
        .response_storage = .{ .dynamic = &data },
        .headers = .{
            .user_agent = .{ .override = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/96.0.4664.45 Safari/537.36" },
        },
    });

    if (res.status != std.http.Status.ok) {
        return error.FailToGetStream;
    }

    if (data.items.len == 0) {
        return error.NoDataForStream;
    }

    var start_index: usize = 0;
    var initial_data_string: []const u8 = undefined;
    while (true) {
        const yt_initial_data = "ytInitialData";
        var index = std.mem.indexOfPos(u8, data.items, start_index, yt_initial_data) orelse {
            return error.FailedToGetInitialData;
        };

        start_index = index + 1;

        index += yt_initial_data.len;

        while (std.ascii.isWhitespace(data.items[index])) {
            index += 1;
        }

        if (data.items[index] != '=') {
            continue;
        }
        index += 1;

        while (std.ascii.isWhitespace(data.items[index])) {
            index += 1;
        }

        if (data.items[index] != '{') {
            continue;
        }

        const end_index = std.mem.indexOfPos(u8, data.items, start_index, "};") orelse {
            continue;
        };

        initial_data_string = try alloc.dupe(u8, data.items[index..(end_index + 1)]);
        break;
    }

    start_index = 0;
    var config_string: []const u8 = undefined;
    while (true) {
        const yt_cfg_set = "ytcfg.set({";
        var index = std.mem.indexOfPos(u8, data.items, start_index, yt_cfg_set) orelse {
            return error.FailedToGetConfig;
        };

        start_index = index + 1;

        index += yt_cfg_set.len;

        const end_index = std.mem.indexOfPos(u8, data.items, start_index, "});") orelse {
            continue;
        };

        config_string = try alloc.dupe(u8, data.items[(index - 1)..(end_index + 1)]);
        break;
    }

    const initial_data = try std.json.parseFromSlice(std.json.Value, alloc, initial_data_string, .{});
    defer initial_data.deinit();

    const config = try std.json.parseFromSlice(std.json.Value, alloc, config_string, .{});
    defer config.deinit();

    const channel_id_value = traverse(
        initial_data.value,
        getChannelId,
    );

    const channel_id = if (channel_id_value) |channel_id| switch (channel_id) {
        .string => |channel_id_string| try alloc.dupe(u8, channel_id_string),
        else => {
            return error.NoChannelId;
        },
    } else {
        return error.NoChannelId;
    };

    const continuation_value = traverse(
        initial_data.value,
        getContinuation,
    );

    const continuation = if (continuation_value) |continuation| switch (continuation) {
        .object => |continuation_obj| continuation_obj,
        else => {
            return error.NoContinuation;
        },
    } else {
        return error.NoContinuation;
    };

    const continuation_token_value = traverse(std.json.Value{ .object = continuation }, getContinuationToken);
    const continuation_token = if (continuation_token_value) |continuation_token| switch (continuation_token) {
        .string => |continuation_token_str| try alloc.dupe(u8, continuation_token_str),
        else => {
            return error.NoContinuationToken;
        },
    } else {
        return error.NoContinuationToken;
    };

    const inner_tube_api_key = switch (config.value) {
        .object => |obj| if (obj.get("INNERTUBE_API_KEY")) |api_key_value|
            switch (api_key_value) {
                .string => |api_key| try alloc.dupe(u8, api_key),
                else => {
                    return error.IncorrectInnerTubeApiKey;
                },
            }
        else {
            return error.NoInnerTubeApiKey;
        },
        else => {
            return error.NoInnerTubeApiKey;
        },
    };

    const inner_tube_ctx_str = switch (config.value) {
        .object => |obj| if (obj.get("INNERTUBE_CONTEXT")) |ctx_value|
            switch (ctx_value) {
                .object => try std.json.stringifyAlloc(alloc, ctx_value, .{}),
                else => {
                    return error.IncorrectInnerTubeCtx;
                },
            }
        else {
            return error.NoInnerTubeCtx;
        },
        else => {
            return error.NoInnerTubeCtx;
        },
    };
    defer alloc.free(inner_tube_ctx_str);

    const inner_tube_ctx = try std.json.parseFromSlice(std.json.Value, alloc, inner_tube_ctx_str, .{});

    return .{
        .alloc = alloc,
        .inner_tube_api_key = inner_tube_api_key,
        .inner_tube_ctx = inner_tube_ctx,
        .channel_id = channel_id, //
        .continuation_token = continuation_token,
        .client = client,
        .seen_msgs = std.StringArrayHashMap(TimeMs).init(alloc),
    };
}

pub fn run(self: *YouTubeBot, running: *bool) !void {
    while (running.*) {
        try self.fetchActions();
        std.time.sleep(250 * std.time.ns_per_ms);
        break;
    }
}

fn fetchActions(self: *YouTubeBot) !void {
    var res_data = std.ArrayList(u8).init(self.alloc);
    defer res_data.deinit();

    const payload = try std.json.stringifyAlloc(self.alloc, .{
        .context = self.inner_tube_ctx.value, //
        .continuation = self.continuation_token, //
        .webClientInfo = .{ .isDocumentHidden = false }, //
    }, .{});
    defer self.alloc.free(payload);

    const res = try self.client.fetch(.{
        .location = .{ .url = try std.mem.concat(self.alloc, u8, &.{ "https://www.youtube.com/youtubei/v1/live_chat/get_live_chat?key=", self.inner_tube_api_key }) },
        .response_storage = .{ .dynamic = &res_data },
        .method = .POST,
        .payload = payload,
    });

    if (res.status != .ok) {
        return error.FailedToFetchChat;
    }

    const data = try std.json.parseFromSlice(std.json.Value, self.alloc, res_data.items, .{});
    defer data.deinit();

    const live_chat_continuation: ?std.json.ObjectMap = getLiveChatContinuation(data.value);

    const next_continuation: ?[]const u8 = getNextContinuation(live_chat_continuation);

    if (next_continuation) |c| {
        self.alloc.free(self.continuation_token);
        self.continuation_token = try self.alloc.dupe(u8, c);
    }

    const actions: ?std.json.Array = if (live_chat_continuation) |lcc|
        if (lcc.get("actions")) |cont|
            switch (cont) {
                .array => |arr| arr,
                else => null,
            }
        else
            null
    else
        null;

    const current_time_ms = std.time.milliTimestamp();
    for (actions.?.items) |action| {
        const item = if (traverse(action, getActionItem)) |item| switch (item) {
            .object => |obj| obj,
            else => continue,
        } else continue;

        if (getString(item.get("id"))) |id| {
            std.debug.print("Id: {?s}\n", .{id});
            try self.seen_msgs.put(id, current_time_ms);
        }
    }
}

fn getLiveChatContinuation(value: std.json.Value) ?std.json.ObjectMap {
    const obj = if (getObject(value)) |obj| obj else return null;

    const cc = if (obj.get("continuationContents")) |cc| cc else return null;
    const cc_obj = if (getObject(cc)) |cc_obj| cc_obj else return null;
    const lcc = if (cc_obj.get("liveChatContinuation")) |lcc| lcc else return null;
    if (getObject(lcc)) |lcc_obj| {
        return lcc_obj;
    } else {
        return null;
    }
}

fn getNextContinuation(liveChatContinuation: ?std.json.ObjectMap) ?[]const u8 {
    const cont = if (liveChatContinuation.?.get("continuations")) |cont| cont else return null;
    const arr = switch (cont) {
        .array => |arr| arr,
        else => return null,
    };
    if (arr.items.len == 0) return null;

    const ct: std.json.Value = switch (arr.items[0]) {
        .object => if (traverse(arr.items[0], getContinuationToken)) |ct| ct else return null,
        else => return null,
    };
    switch (ct) {
        .string => |s| return s,
        else => return null,
    }
}

fn getObject(value: std.json.Value) ?std.json.ObjectMap {
    switch (value) {
        .object => |obj| return obj,
        else => return null,
    }
}

fn getString(value: ?std.json.Value) ?[]const u8 {
    if (value) |v| {
        switch (v) {
            .string => |s| return s,
            else => return null,
        }
    }
    return null;
}

fn getChannelId(callback_key: TraverseCallbackKey, value: std.json.Value) ?std.json.Value {
    switch (callback_key) {
        .string => |key| {
            if (std.mem.eql(u8, key, "channelNavigationEndpoint")) {
                switch (value) {
                    .object => |obj| {
                        if (obj.get("browseEndpoint")) |browse_endpoint| {
                            switch (browse_endpoint) {
                                .object => |browse_endpoint_obj| {
                                    if (browse_endpoint_obj.get("browseId")) |browse_id| {
                                        return browse_id;
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

fn getContinuation(_: TraverseCallbackKey, value: std.json.Value) ?std.json.Value {
    switch (value) {
        .object => |obj| {
            if (obj.get("title")) |title_value| {
                switch (title_value) {
                    .string => |title| {
                        if (std.mem.eql(u8, title, LIVE_CHAT_TEXT)) {
                            return obj.get("continuation");
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

fn getActionItem(key: TraverseCallbackKey, value: std.json.Value) ?std.json.Value {
    switch (key) {
        .string => |s| if (std.mem.eql(u8, s, "clickTrackingParams")) {
            return null;
        },
        else => return null,
    }
    switch (value) {
        .object => |obj| {
            if (obj.get("item")) |item_value| {
                switch (item_value) {
                    .object => |item| {
                        return item.get(item.keys()[0]);
                    },
                    else => {},
                }
            }
        },
        else => {},
    }

    return null;
}

fn getContinuationToken(_: TraverseCallbackKey, value: std.json.Value) ?std.json.Value {
    switch (value) {
        .object => |obj| {
            if (obj.get("continuation")) |continuation| {
                return continuation;
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

const TraverseCallback = *const fn (key: TraverseCallbackKey, value: std.json.Value) ?std.json.Value;

fn traverse(value: std.json.Value, callback: TraverseCallback) ?std.json.Value {
    switch (value) {
        .object => |obj| {
            for (obj.keys()) |key| {
                if (obj.get(key)) |obj_value| {
                    if (callback(.{ .string = key }, obj_value)) |ret| {
                        return ret;
                    }
                    if (traverse(obj_value, callback)) |ret| {
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
                if (traverse(array.items[i], callback)) |ret| {
                    return ret;
                }
            }
        },
        else => {},
    }

    return null;
}

pub fn deinit(self: *YouTubeBot) void {
    self.alloc.free(self.channel_id);
    self.alloc.free(self.continuation_token);
    self.alloc.free(self.inner_tube_api_key);
    self.inner_tube_ctx.deinit();
}
