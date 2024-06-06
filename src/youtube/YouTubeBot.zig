const std = @import("std");
const websocket = @import("websocket");
const protocol = @import("protocol");
const Traverse = @import("Traverse.zig");

const TimeMs = i64;
const SeenMsgsMap = std.StringHashMap(TimeMs);

const YouTubeBot = @This();

alloc: std.mem.Allocator,
client: std.http.Client,
aggregator_client: websocket.Client,

inner_tube_api_key: []const u8,
inner_tube_ctx: std.json.Parsed(std.json.Value),
channel_id: []const u8,
continuation_token: []const u8,
seen_msgs: SeenMsgsMap,

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

    const channel_id = if (Traverse.traverse(
        []const u8,
        initial_data.value,
        Traverse.getChannelId,
    )) |id|
        try alloc.dupe(u8, id)
    else {
        return error.NoChannelId;
    };

    const continuation = Traverse.traverse(
        std.json.ObjectMap,
        initial_data.value,
        Traverse.getContinuation,
    ) orelse {
        return error.NoContinuation;
    };

    const continuation_token = if (Traverse.traverse([]const u8, std.json.Value{ .object = continuation }, Traverse.getContinuationToken)) |token| try alloc.dupe(u8, token) else {
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
        .seen_msgs = SeenMsgsMap.init(alloc),
        .aggregator_client = try websocket.connect(alloc, "localhost", 9223, .{}),
    };
}

pub fn deinit(self: *YouTubeBot) void {
    self.alloc.free(self.channel_id);
    self.alloc.free(self.continuation_token);
    self.alloc.free(self.inner_tube_api_key);
    self.inner_tube_ctx.deinit();
}

pub fn run(self: *YouTubeBot, running: *bool) !void {
    try self.aggregator_client.handshake("/", .{
        .timeout_ms = 5000,
    });
    std.debug.print("Started YouTube bot!\n", .{});

    var i: usize = 0;
    while (running.*) {
        // 1 minute has passed
        // We do 4 iter every second
        // i.e. one iter every 250ms
        // So its 4 * 60 seconds = 240 iters
        if (i >= 240) {
            const current_time_ms = std.time.milliTimestamp();
            var keys_to_be_removed = try std.ArrayList([]const u8).initCapacity(self.alloc, self.seen_msgs.count());
            defer keys_to_be_removed.deinit();
            var iter = self.seen_msgs.keyIterator();
            while (iter.next()) |key| {
                const time_ms = self.seen_msgs.get(key.*) orelse continue;
                if (current_time_ms - time_ms > std.time.ms_per_min) {
                    try keys_to_be_removed.append(try self.alloc.dupe(u8, key.*));
                }
            }

            for (keys_to_be_removed.items) |key| {
                _ = self.seen_msgs.remove(key);
            }
        }

        self.fetchActions() catch |e| {
            std.log.err("Fetching actions failed! {any}", .{e});
        };
        std.time.sleep(250 * std.time.ns_per_ms);

        i += 1;
    }
}

fn fetchActions(self: *YouTubeBot) !void {
    var res_data = std.ArrayList(u8).init(self.alloc);
    defer res_data.deinit();

    const payload = try std.json.stringifyAlloc(self.alloc, .{
        .context = self.inner_tube_ctx.value,
        .continuation = self.continuation_token,
        .webClientInfo = .{ .isDocumentHidden = false },
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
    if (actions) |as| {
        for (as.items) |action| {
            const item = Traverse.traverse(Traverse.ActionItem, action, Traverse.getActionItem) orelse continue;

            const id = getString(item.action.get("id")) orelse continue;
            if (self.seen_msgs.contains(id)) {
                continue;
            }
            self.seen_msgs.put(try self.alloc.dupe(u8, id), current_time_ms) catch continue;

            if (std.mem.eql(u8, item.action_type, "addChatItemAction") and
                std.mem.eql(u8, item.item_type, "liveChatTextMessageRenderer"))
            {
                const channel_id = getString(item.action.get("authorExternalChannelId")) orelse continue;

                const author_obj = getObject(item.action.get("authorName")) orelse continue;
                const author = getString(author_obj.get("simpleText")) orelse continue;

                const ts_text = getString(item.action.get("timestampUsec")) orelse continue;
                const timestamp_microseconds = std.fmt.parseInt(i64, ts_text, 10) catch continue;

                const msg = getObject(item.action.get("message")) orelse continue;
                const runs = getArray(msg.get("runs")) orelse continue;

                var msg_text = std.ArrayList(u8).init(self.alloc);
                defer msg_text.deinit();
                for (runs.items) |msg_part| {
                    const part = getObject(msg_part) orelse continue;
                    const text = getString(part.get("text")) orelse continue;
                    try msg_text.appendSlice(text);
                }

                std.debug.print("{s}: {s}\n", .{ author, msg_text.items });

                var writer = protocol.Writer.init(self.alloc);
                defer writer.deinit();
                (protocol.messages.ToServer.Message{
                    .AddMessage = protocol.messages.ToServer.AddMessage{
                        .platform = .YouTube,
                        .platform_message_id = id,
                        .channel_id = self.channel_id,
                        .author_id = channel_id,
                        .author = author,
                        .message = msg_text.items,
                        .timestamp_type = .Microsecond,
                        .timestamp = timestamp_microseconds,
                    },
                }).serialize(&writer) catch continue;

                self.aggregator_client.writeBin(writer.data.items) catch continue;
            }
        }
    }
}

fn getLiveChatContinuation(value: std.json.Value) ?std.json.ObjectMap {
    const obj = getObject(value) orelse return null;

    const cc = obj.get("continuationContents") orelse return null;
    const cc_obj = getObject(cc) orelse return null;
    const lcc = cc_obj.get("liveChatContinuation") orelse return null;
    if (getObject(lcc)) |lcc_obj| {
        return lcc_obj;
    } else {
        return null;
    }
}

fn getNextContinuation(liveChatContinuation: ?std.json.ObjectMap) ?[]const u8 {
    const cont = liveChatContinuation.?.get("continuations") orelse return null;
    const arr = switch (cont) {
        .array => |arr| arr,
        else => return null,
    };
    if (arr.items.len == 0) return null;

    switch (arr.items[0]) {
        .object => return Traverse.traverse([]const u8, arr.items[0], Traverse.getContinuationToken),
        else => return null,
    }
}

fn getObject(value: ?std.json.Value) ?std.json.ObjectMap {
    if (value) |v| {
        switch (v) {
            .object => |obj| return obj,
            else => return null,
        }
    }
    return null;
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

fn getArray(value: ?std.json.Value) ?std.json.Array {
    if (value) |v| {
        switch (v) {
            .array => |arr| return arr,
            else => return null,
        }
    }
    return null;
}
