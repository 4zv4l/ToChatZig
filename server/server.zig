const std = @import("std");
const net = std.net;
const Connection = std.net.StreamServer.Connection;
const Lock = std.Thread.Mutex;
const Protocol = @import("./protocol.zig").Protocol;
const print = std.debug.print;

/// Clients struct to handle the list of clients
const ClientsList = std.ArrayList(Connection);
const Clients = struct {
    list: ClientsList,
    len: usize,

    pub fn show(self: *Clients) !void {
        var stdout = std.io.getStdOut().writer();
        try stdout.print("clients: {d}\n", .{self.len});
        for (self.list.items) |client| {
            try stdout.print("-> {any}\n", .{client.address});
        }
        try stdout.print("-----------------------\n", .{});
    }
};

/// return the index of the client from clients
fn getIndexOfFd(clients: []Connection, client: Connection) usize {
    for (clients) |c, i| {
        if (c.stream.handle == client.stream.handle) {
            return i;
        }
    }
    return 0;
}

/// handle a client by recv its messages and broadcasting them
fn handle(client: Connection, clients: *Clients, lock: *Lock) !void {
    var stream = client.stream;
    var username = std.mem.zeroes([128]u8);
    // remove the client from the list
    defer {
        while (lock.tryLock()) {}
        const index = getIndexOfFd(clients.list.items, client);
        _ = clients.list.swapRemove(index);
        clients.len -= 1;
        client.stream.close();
        clients.show() catch {};
        lock.unlock();
        const bye = Protocol.make(&username, "Bye-Bye (disconnected)");
        for (clients.list.items) |c| {
            var writer = c.stream.writer();
            writer.writeStruct(bye) catch {};
        }
    }
    // read from client
    var reader = stream.reader();
    while (true) {
        const data = reader.readStruct(Protocol) catch |e| switch (e) {
            error.EndOfStream => {
                print("{}: disconnected\n", .{client.address});
                return;
            },
            else => return e,
        };
        if (username[0] == 0) std.mem.copy(u8, &username, &data.username);
        print("{s}: recv(\"{s}\", {d})\n", .{ data.username, data.message, data.len });
        // send to all client
        for (clients.list.items) |c| {
            var writer = c.stream.writer();
            try writer.writeStruct(data);
        }
    }
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
    // init the server
    var server = std.net.StreamServer.init(.{ .reuse_address = true });
    defer server.deinit();
    // start listening
    try server.listen(addr);
    print("Listening on {s}:{}\n", .{ ip, port });
    // main loop handling clients in threads
    var clients = Clients{ .list = ClientsList.init(allocator), .len = 0 };
    defer clients.list.deinit();
    var lock: Lock = .{};
    while (server.accept()) |client| {
        // add client to the list
        try clients.list.append(client);
        clients.len += 1;
        try clients.show();
        const t = try std.Thread.spawn(.{}, handle, .{ client, &clients, &lock });
        t.detach();
    } else |e| return e;
}
