const std = @import("std");
const crypto = std.crypto;
const Box = std.crypto.nacl.Box;
const toHex = std.fmt.fmtSliceHexLower;
const print = std.debug.print;

test "hacky crypto" {
    const msg = "Hello, World !";
    var ciph_msg: [msg.len + Box.tag_length]u8 = undefined;
    var plain_text: [msg.len]u8 = undefined;

    var nonce: [Box.nonce_length]u8 = undefined;
    crypto.random.bytes(&nonce);

    const keys = try Box.KeyPair.create(null);

    print("\npublic: {}\nprivate: {}\n", .{ toHex(&keys.public_key), toHex(&keys.secret_key) });

    try Box.seal(&ciph_msg, msg, nonce, keys.public_key, keys.secret_key);

    print("=> {s}\n", .{ciph_msg});

    try Box.open(&plain_text, &ciph_msg, nonce, keys.public_key, keys.secret_key);

    print("=> {s}\n", .{plain_text});
}
