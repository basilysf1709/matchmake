const std = @import("std");
const AVLLeaderboard = @import("avl.zig").AVLLeaderboard;
const Player = @import("avl.zig").Player;

pub fn main() !void {
    // Use the page allocator for memory allocation
    const allocator = std.heap.page_allocator;

    // Create a hash map to store players (name -> score)
    var players = std.StringHashMap(u32).init(allocator);
    defer players.deinit();

    // Create an AVL tree to store players
    var leaderboard = AVLLeaderboard.init(allocator);
    defer leaderboard.deinit();

    // Get a writer for standard output
    const stdout = std.io.getStdOut().writer();

    // Generate 1,000,000 players
    var i: usize = 0;
    while (i < 100000) : (i += 1) {
        // Create a player name in the format "Player<number>"
        const name = try std.fmt.allocPrint(allocator, "Player{d}", .{i + 1});
        errdefer allocator.free(name);

        // Generate a random score between 0 and 999,999
        var score: u32 = undefined;
        while (true) {
            score = std.crypto.random.uintAtMost(u32, 1000000);
            if (!players.contains(name)) break;
        }
        try players.put(name, score);

        // Insert player into AVL tree
        try leaderboard.insert(Player{ .name = name, .score = score });

        // Print progress every 100,000 players
        if (i % 10000 == 0) {
            try stdout.print("Generated {d} players\n", .{i});
        }
    }

    try stdout.print("All players generated. Writing to file...\n", .{});

    // Create and open the output file
    const file = try std.fs.cwd().createFile("players.json", .{});
    defer file.close();

    // Get a writer for the file
    const writer = file.writer();
    try writer.writeAll("{\n");

    // Iterate through all players and write them to the file
    var it = players.iterator();
    var index: usize = 0;
    while (it.next()) |entry| {
        // Write each player as a JSON key-value pair
        try writer.print("  \"{s}\": {d}", .{ entry.key_ptr.*, entry.value_ptr.* });
        if (index < players.count() - 1) {
            try writer.writeAll(",");
        }
        try writer.writeAll("\n");
        index += 1;

        // Print progress every 1,000 players written
        if (index % 10000 == 0) {
            try stdout.print("Wrote {d} players to file\n", .{index});
        }
    }

    // Close the JSON object
    try writer.writeAll("}\n");

    // Print completion message
    try stdout.print("Created players.json with {d} players.\n", .{players.count()});

    // Retrieve and print top 10 players
    try stdout.print("\nTop 10 Players:\n", .{});
    const top_players = try leaderboard.getTopPlayers(10);
    defer allocator.free(top_players);

    for (top_players, 0..) |player, idx| {
        try stdout.print("{d}. {s}: {d}\n", .{ idx + 1, player.name, player.score });
    }
}
