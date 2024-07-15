// zig version 0.14.0-dev.224+95d9292a7

const std = @import("std");
const net = std.net;
const log = std.log;
const StringHashmap = std.StringHashMap;

const printd = std.debug.print;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const addr = try net.Address.parseIp("127.0.0.1", 80);
    var listener = try addr.listen(.{ .reuse_port = true });
    log.info("Server listening on: {any}", .{addr});

    while (true) {
        const conn = try listener.accept();
        log.info("Connection established with: {any}", .{conn.address});

        _ = try conn.stream.write("Hello, world!");
        try parse_req(allocator, conn.stream);
    }
}

fn parse_req(allocator: std.mem.Allocator, stream: net.Stream) !void {
    defer stream.close();

    const reader = stream.reader();
    var array_list = std.ArrayList(u8).init(allocator);
    defer array_list.deinit();

    try reader.readAllArrayList(&array_list, std.math.maxInt(usize));

    var iter = std.mem.splitAny(u8, array_list.items, "\n");

    var first_line = std.mem.splitAny(u8, iter.next().?, " ");

    const method = first_line.next().?;
    const uri = first_line.next().?;
    const version = first_line.next().?;
    printd("Method: {s}\nURI: {s}\nVersion: {s}\n", .{ method, uri, version });

    var opts = StringHashmap([]const u8).init(allocator);
    while (iter.next()) |line| {
        if (line.len == 1 and std.mem.eql(u8, line, "\r")) break;
        var option = std.mem.splitAny(u8, line, ":");
        const key = option.next().?;
        var value = option.next().?;
        if (value[0] == ' ') value = value[1..];

        try opts.put(key, value);
    }

    var opts_iter = opts.iterator();
    while (opts_iter.next()) |entry| {
        printd("{s}: {s}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
    }
}
