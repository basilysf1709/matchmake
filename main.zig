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

    // Start timer for AVL insertion
    const avl_start = std.time.nanoTimestamp();

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

    // End timer for AVL insertion
    const avl_end = std.time.nanoTimestamp();

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

    // Start timer for top 10 players retrieval
    const top_start = std.time.nanoTimestamp();

    // Retrieve and print top 10 players
    try stdout.print("\nTop 10 Players:\n", .{});
    const top_players = try leaderboard.getTopPlayers(10);
    defer allocator.free(top_players);

    for (top_players, 0..) |player, idx| {
        try stdout.print("{d}. {s}: {d}\n", .{ idx + 1, player.name, player.score });
    }

    // End timer for top 10 players retrieval
    const top_end = std.time.nanoTimestamp();

    // New functionality: Get closest players to input score
    try stdout.print("\nEnter a score to find the 10 closest players: ", .{});
    const input = try std.io.getStdIn().reader().readUntilDelimiterAlloc(allocator, '\n', 1024);
    defer allocator.free(input);

    const input_score = try std.fmt.parseInt(u32, input, 10);

    // Start timer for closest players retrieval
    const closest_start = std.time.nanoTimestamp();

    const closest_players = try leaderboard.getClosestPlayers(input_score);
    defer allocator.free(closest_players);

    try stdout.print("\n10 Closest Players to score {d}:\n", .{input_score});
    for (closest_players, 0..) |player, idx| {
        const score_diff = if (player.score > input_score) player.score - input_score else input_score - player.score;
        try stdout.print("{d}. {s}: {d} (diff: {d})\n", .{ idx + 1, player.name, player.score, score_diff });
    }

    // End timer for closest players retrieval
    const closest_end = std.time.nanoTimestamp();

    // Print timing information
    try stdout.print("\nTiming Information:\n", .{});
    try stdout.print("AVL Tree Insertion: {} ns\n", .{avl_end - avl_start});
    try stdout.print("Top 10 Players Retrieval: {} ns\n", .{top_end - top_start});
    try stdout.print("10 Closest Players Retrieval: {} ns\n", .{closest_end - closest_start});
}
