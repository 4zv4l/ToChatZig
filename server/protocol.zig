const std = @import("std");

pub const Protocol = extern struct {
    len: u16,
    username: [128]u8,
    message: [1024]u8,

    /// format the message to the protocol
    pub fn make(user: []const u8, msg: []const u8) Protocol {
        var p = std.mem.zeroes(Protocol);
        p.len = @intCast(u16, user.len) + @intCast(u16, msg.len);
        std.mem.copy(u8, &p.username, user);
        std.mem.copy(u8, &p.message, msg);
        return p;
    }

    /// fill the struct from a raw message
    /// well formatted (to the struct layout)
    pub fn wrap(raw: []const u8) Protocol {
        return Protocol{ .len = raw[0..1], .username = raw[2..126], .message = raw[127..] };
    }

    // extract the username/message from the struct
    //pub fn unwrap(self: Protocol) []const u8 {
    //    return self.body[0..self.head];
    //}
};
