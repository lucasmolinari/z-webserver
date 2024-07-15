// zig version 0.14.0-dev.224+95d9292a7

const std = @import("std");
const net = std.net;
const log = std.log;
const StringHashmap = std.StringHashMap;

const printd = std.debug.print;

const Method = enum {
    GET,
    POST,
    PUT,
    PATCH,
    DELETE,
    HEAD,
    OPTIONS,
};

const Header = struct {
    method: Method,
    uri: []const u8,
    version: []const u8,
    options: ?StringHashmap([]const u8),

    fn print_debug(self: *Header) void {
        printd("Method: {s}\nURI: {s}\nVersion: {s}\n", .{ @tagName(self.method), self.uri, self.version });
        if (self.options != null) {
            var opts_iter = self.options.?.iterator();
            printd("Options:\n", .{});
            while (opts_iter.next()) |entry| {
                printd("{s}: {s}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
            }
        } else {
            printd("No options set.", .{});
        }
    }

    fn deinit(self: *Header) void {
        if (self.options != null) {
            self.options.?.deinit();
        }
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const addr = try net.Address.parseIp("127.0.0.1", 80);
    var listener = try addr.listen(.{ .reuse_port = true });
    log.info("Server listening on: {any}", .{addr});

    while (true) {
        const conn = try listener.accept();
        log.info("[Connection established with: {any}]", .{conn.address});

        var header = parse_header(allocator, conn.stream) catch |err| {
            switch (err) {
                error.UnknownMethod => {
                    log.info("Unknown Method in Request", .{});
                    continue;
                },
                error.InvalidHeader => {
                    log.info("Invalid Headers in Request", .{});
                    continue;
                },
                else => return err,
            }
        };
        header.print_debug();
        defer {
            log.info("[Connection closed with: {any}]\n", .{conn.address});
            conn.stream.close();
            header.deinit();
        }
    }
}

fn parse_header(allocator: std.mem.Allocator, stream: net.Stream) !Header {
    const reader = stream.reader();

    const first_line = try reader.readUntilDelimiterOrEofAlloc(allocator, '\n', std.math.maxInt(usize));
    var iter = std.mem.splitAny(u8, first_line.?, "\n");

    var words = std.mem.splitAny(u8, iter.next().?, " ");

    const method = std.meta.stringToEnum(Method, words.next().?) orelse return error.UnknownMethod;
    const uri = words.next() orelse return error.InvalidHeader;
    const version = words.next() orelse return error.InvalidHeader;

    var opts = StringHashmap([]const u8).init(allocator);

    while (true) {
        const line = try reader.readUntilDelimiterOrEofAlloc(allocator, '\n', std.math.maxInt(usize)) orelse break;
        if (line.len == 1 and std.mem.eql(u8, line, "\r")) break;
        var option = std.mem.splitAny(u8, line, ":");
        const key = option.next() orelse break;
        var value = option.next() orelse break;
        if (value[0] == ' ') value = value[1..];
        try opts.put(key, value);
    }

    const options = if (opts.count() == 0) null else opts;

    return Header{
        .method = method,
        .uri = uri,
        .version = version,
        .options = options,
    };
}
