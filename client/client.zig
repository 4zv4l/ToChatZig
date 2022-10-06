const std = @import("std");
const Stream = std.net.Stream;
const Protocol = @import("./protocol.zig").Protocol;
const print = std.debug.print;

fn getUserName(buff: []u8, stdin: anytype) []const u8 {
    print("Username: ", .{});
    const username = stdin.readUntilDelimiter(buff, '\n') catch {
        return "Anonyme";
    };
    return username;
}

fn handleOutGoing(client: Stream, stdin: anytype, username: []const u8) !void {
    const bufio = std.io.BufferedReader(1024, @TypeOf(stdin));
    var breader = bufio{ .unbuffered_reader = stdin };
    var reader = breader.reader();
    var buffer: [1024]u8 = undefined;
    while (true) {
        print("> ", .{});
        const input = try reader.readUntilDelimiter(&buffer, '\n');
        if (std.mem.containsAtLeast(u8, "exit", 1, input)) {
            print("Disconnecting :)\n", .{});
            std.os.exit(0);
        }
        const serial = Protocol.make(username, input);
        try client.writer().writeStruct(serial);
    }
}

fn handleComing(client: Stream, username: []const u8) !void {
    var reader = client.reader();
    while (true) {
        var data = reader.readStruct(Protocol) catch {
            print("\rDisconnected..\n", .{});
            std.os.exit(0);
        };
        if (std.mem.containsAtLeast(u8, &data.username, 1, username) == false)
            print("\r{s}: {s}\n> ", .{ data.username, data.message });
    }
}

fn handle(client: Stream) !void {
    const stdin = std.io.getStdIn().reader();
    var username_buffer: [128]u8 = undefined;
    const username = getUserName(&username_buffer, stdin);
    const t = try std.Thread.spawn(.{}, handleComing, .{ client, username });
    t.detach();
    try handleOutGoing(client, stdin, username);
}

pub fn main() !void {
    // init gpa allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();
    // alloc command line arguments
    const argv = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, argv);
    // check arguments
    if (argv.len != 3) {
        print("usage {s} [ip] [port]\n", .{argv[0]});
        return;
    }
    // parse arguments to Address
    const ip = argv[1];
    const port = try std.fmt.parseUnsigned(u16, argv[2], 10);
    const addr = try std.net.Address.parseIp(ip, port);
    // init the client
    var client = try std.net.tcpConnectToAddress(addr);
    defer client.close();
    print("Connected to {s}:{}\n", .{ ip, port });
    try handle(client);
}
