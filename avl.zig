const std = @import("std");
const Allocator = std.mem.Allocator;

// Represents a player in the leaderboard
pub const Player = struct {
    name: []const u8,
    score: u32,
};

// Represents a node in the AVL tree
pub const Node = struct {
    player: Player,
    left: ?*Node,
    right: ?*Node,
    height: i32,

    // Initialize a new node with a player
    pub fn init(player: Player) Node {
        return .{
            .player = player,
            .left = null,
            .right = null,
            .height = 1,
        };
    }
};

// AVL tree implementation for the leaderboard
pub const AVLLeaderboard = struct {
    root: ?*Node,
    allocator: std.mem.Allocator,

    // Initialize a new AVL leaderboard
    pub fn init(allocator: std.mem.Allocator) AVLLeaderboard {
        return .{
            .root = null,
            .allocator = allocator,
        };
    }

    // Insert a player into the leaderboard
    pub fn insert(self: *AVLLeaderboard, player: Player) !void {
        self.root = try self.insertRecursive(self.root, player);
    }

    // Recursive helper function for insert
    fn insertRecursive(self: *AVLLeaderboard, node: ?*Node, player: Player) !?*Node {
        if (node == null) {
            const new_node = try self.allocator.create(Node);
            new_node.* = Node.init(player);
            return new_node;
        }

        var current = node.?;
        if (player.score < current.player.score) {
            current.left = try self.insertRecursive(current.left, player);
        } else if (player.score > current.player.score) {
            current.right = try self.insertRecursive(current.right, player);
        } else {
            // If scores are equal, we can either update the existing node or insert as a duplicate
            // Here, we'll update the existing node
            current.player = player;
            return current;
        }

        updateHeight(current);

        const balance = getBalance(current);

        // Left Left Case
        if (balance > 1 and player.score < current.left.?.player.score) {
            return try self.rotateRight(current);
        }

        // Right Right Case
        if (balance < -1 and player.score > current.right.?.player.score) {
            return try self.rotateLeft(current);
        }

        // Left Right Case
        if (balance > 1 and player.score > current.left.?.player.score) {
            current.left = try self.rotateLeft(current.left.?);
            return try self.rotateRight(current);
        }

        // Right Left Case
        if (balance < -1 and player.score < current.right.?.player.score) {
            current.right = try self.rotateRight(current.right.?);
            return try self.rotateLeft(current);
        }

        return current;
    }

    // Delete a player from the leaderboard by score
    pub fn delete(self: *AVLLeaderboard, score: u32) !void {
        self.root = try self.deleteRecursive(self.root, score);
    }

    // Recursive helper function for delete
    fn deleteRecursive(self: *AVLLeaderboard, node: ?*Node, score: u32) !?*Node {
        if (node == null) {
            return null;
        }

        var current = node.?;
        if (score < current.player.score) {
            current.left = try self.deleteRecursive(current.left, score);
        } else if (score > current.player.score) {
            current.right = try self.deleteRecursive(current.right, score);
        } else {
            // Node to delete found
            if (current.left == null) {
                const temp = current.right;
                self.allocator.destroy(current);
                return temp;
            } else if (current.right == null) {
                const temp = current.left;
                self.allocator.destroy(current);
                return temp;
            }

            // Node with two children: Get the inorder successor (smallest in the right subtree)
            const temp = self.minValueNode(current.right.?);
            current.player = temp.player;
            current.right = try self.deleteRecursive(current.right, temp.player.score);
        }

        updateHeight(current);

        return try self.balanceNode(current);
    }

    // Find the node with the minimum value in the tree
    fn minValueNode(node: *Node) *Node {
        var current = node;
        while (current.left != null) {
            current = current.left.?;
        }
        return current;
    }

    // Search for a player by score
    pub fn search(self: *AVLLeaderboard, score: u32) ?*Node {
        var current = self.root;
        while (current) |node| {
            if (score == node.player.score) {
                return node;
            } else if (score < node.player.score) {
                current = node.left;
            } else {
                current = node.right;
            }
        }
        return null;
    }

    // Perform an inorder traversal of the tree
    pub fn inorderTraversal(self: *AVLLeaderboard) !void {
        try self.inorderTraversalRecursive(self.root);
    }

    // Recursive helper function for inorder traversal
    fn inorderTraversalRecursive(self: *AVLLeaderboard, node: ?*Node) !void {
        if (node) |current| {
            try self.inorderTraversalRecursive(current.left);
            std.debug.print("{d} ", .{current.player.score});
            try self.inorderTraversalRecursive(current.right);
        }
    }

    // Get the top N players from the leaderboard
    pub fn getTopPlayers(self: *AVLLeaderboard, n: usize) ![]Player {
        var result = try self.allocator.alloc(Player, n);
        errdefer self.allocator.free(result);

        var count: usize = 0;
        try self.getTopPlayersRecursive(self.root, &result, &count, n);

        return result[0..count];
    }

    // Recursive helper function for getTopPlayers
    fn getTopPlayersRecursive(self: *AVLLeaderboard, node: ?*Node, result: *[]Player, count: *usize, n: usize) !void {
        if (node) |current| {
            // First, traverse the right subtree
            try self.getTopPlayersRecursive(current.right, result, count, n);

            // Then, process the current node
            if (count.* < n) {
                result.*[count.*] = current.player;
                count.* += 1;
            } else {
                return;
            }

            // Finally, traverse the left subtree
            try self.getTopPlayersRecursive(current.left, result, count, n);
        }
    }

    // Get the rank of a player by score
    pub fn getRank(self: *AVLLeaderboard, score: u32) !usize {
        var rank: usize = 0;
        try self.getRankRecursive(self.root, score, &rank);
        return rank;
    }

    // Recursive helper function for getRank
    fn getRankRecursive(self: *AVLLeaderboard, node: ?*Node, score: u32, rank: *usize) !void {
        if (node) |current| {
            if (score > current.player.score) {
                rank.* += 1;
                if (current.left) |left| {
                    rank.* += @intCast(left.height);
                }
                try self.getRankRecursive(current.right, score, rank);
            } else if (score < current.player.score) {
                try self.getRankRecursive(current.left, score, rank);
            } else {
                if (current.left) |left| {
                    rank.* += @intCast(left.height);
                }
            }
        }
    }

    // Get players within a score range
    pub fn getPlayersInRange(self: *AVLLeaderboard, min_score: u32, max_score: u32) ![]Player {
        var result = std.ArrayList(Player).init(self.allocator);
        defer result.deinit();

        try self.getPlayersInRangeRecursive(self.root, min_score, max_score, &result);

        return result.toOwnedSlice();
    }

    // Recursive helper function for getPlayersInRange
    fn getPlayersInRangeRecursive(self: *AVLLeaderboard, node: ?*Node, min_score: u32, max_score: u32, result: *std.ArrayList(Player)) !void {
        if (node) |current| {
            if (current.player.score >= min_score and current.player.score <= max_score) {
                try result.append(current.player);
            }

            if (current.player.score > min_score) {
                try self.getPlayersInRangeRecursive(current.left, min_score, max_score, result);
            }

            if (current.player.score < max_score) {
                try self.getPlayersInRangeRecursive(current.right, min_score, max_score, result);
            }
        }
    }

    // Get players closest to a target score
    pub fn getClosestPlayers(self: *AVLLeaderboard, target_score: u32) ![]Player {
        var result = std.ArrayList(Player).init(self.allocator);
        defer result.deinit();

        try self.getClosestPlayersRecursive(self.root, target_score, &result);

        // Sort the result by the absolute difference from the input score
        std.mem.sort(Player, result.items, target_score, struct {
            pub fn lessThan(target: u32, a: Player, b: Player) bool {
                const diff_a = if (a.score > target) a.score - target else target - a.score;
                const diff_b = if (b.score > target) b.score - target else target - b.score;
                return diff_a < diff_b;
            }
        }.lessThan);

        // Return the top 10 closest players or all if less than 10
        const num_players = @min(result.items.len, 10);
        return try self.allocator.dupe(Player, result.items[0..num_players]);
    }

    // Recursive helper function for getClosestPlayers
    fn getClosestPlayersRecursive(self: *AVLLeaderboard, node: ?*Node, score: u32, result: *std.ArrayList(Player)) !void {
        if (node) |current| {
            try result.append(current.player);

            if (score < current.player.score) {
                try self.getClosestPlayersRecursive(current.left, score, result);
            } else {
                try self.getClosestPlayersRecursive(current.right, score, result);
            }
        }
    }

    // Balance a node in the AVL tree
    fn balanceNode(self: *AVLLeaderboard, node: *Node) !*Node {
        updateHeight(node);
        const balance = getBalance(node);

        if (balance > 1) {
            if (getBalance(node.left.?) >= 0) {
                return try self.rotateRight(node);
            } else {
                node.left = try self.rotateLeft(node.left.?);
                return try self.rotateRight(node);
            }
        } else if (balance < -1) {
            if (getBalance(node.right.?) <= 0) {
                return try self.rotateLeft(node);
            } else {
                node.right = try self.rotateRight(node.right.?);
                return try self.rotateLeft(node);
            }
        }

        return node;
    }

    // Update the height of a node
    fn updateHeight(node: *Node) void {
        const left_height = if (node.left) |left| left.height else 0;
        const right_height = if (node.right) |right| right.height else 0;
        node.height = @max(left_height, right_height) + 1;
    }

    // Perform a right rotation on a node
    fn rotateRight(self: *AVLLeaderboard, node: *Node) !*Node {
        _ = self; // Explicitly ignore the self parameter
        var new_root = node.left orelse return node;
        node.left = new_root.right;
        new_root.right = node;

        updateHeight(node);
        updateHeight(new_root);

        return new_root;
    }

    // Perform a left rotation on a node
    fn rotateLeft(self: *AVLLeaderboard, node: *Node) !*Node {
        _ = self; // Explicitly ignore the self parameter
        var new_root = node.right orelse return node;
        node.right = new_root.left;
        new_root.left = node;

        updateHeight(node);
        updateHeight(new_root);

        return new_root;
    }

    // Get the balance factor of a node
    fn getBalance(node: *Node) i32 {
        const left_height = if (node.left) |left| left.height else 0;
        const right_height = if (node.right) |right| right.height else 0;
        return left_height - right_height;
    }

    // Clean up the AVL tree and free memory
    pub fn deinit(self: *AVLLeaderboard) void {
        if (self.root) |root| {
            self.deinitRecursive(root);
        }
    }

    // Recursive helper function for deinit
    fn deinitRecursive(self: *AVLLeaderboard, node: *Node) void {
        if (node.left) |left| {
            self.deinitRecursive(left);
        }
        if (node.right) |right| {
            self.deinitRecursive(right);
        }
        self.allocator.destroy(node);
    }
};
