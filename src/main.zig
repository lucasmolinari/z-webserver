const std = @import("std");
const net = std.net;
const http = std.http;

const printd = std.debug.print;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const addr = try std.net.Address.parseIp("127.0.0.1", 80);
    var conn = try addr.listen(.{ .reuse_port = true });
    printd("Server listening on: {any}", .{addr});

    while (true) {
        var cli = try conn.accept();
        printd("Connection established with: {} \n", .{cli.address});
        defer cli.stream.close();
    }
}
