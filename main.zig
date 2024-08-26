const std = @import("std");

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var prng = std.rand.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.crypto.random.bytes(std.mem.asBytes(&seed));
        break :blk seed;
    });
    const rand = prng.random();

    var players = std.StringHashMap(u32).init(allocator);
    defer players.deinit();

    var i: usize = 0;
    while (i < 10000) : (i += 1) {
        const name = try std.fmt.allocPrint(allocator, "Player{d}", .{i + 1});
        defer allocator.free(name);

        const score = rand.intRangeAtMost(u32, 0, 10000);
        if (players.get(name) == null) {
            try players.put(name, score);
        } else {
            continue;
        }
    }

    const file = try std.fs.cwd().createFile("players.json", .{});
    defer file.close();

    const writer = file.writer();
    try writer.writeAll("{\n");

    var it = players.iterator();
    var index: usize = 0;
    while (it.next()) |entry| {
        try writer.print("  \"{s}\": {d}", .{ entry.key_ptr.*, entry.value_ptr.* });
        if (index < players.count() - 1) {
            try writer.writeAll(",");
        }
        try writer.writeAll("\n");
        index += 1;
    }

    try writer.writeAll("}\n");

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Created players.json with {d} players.\n", .{players.count()});
}
