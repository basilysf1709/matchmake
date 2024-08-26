const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Player = struct {
    name: []const u8,
    score: u32,
};

pub const Node = struct {
    player: Player,
    left: ?*Node,
    right: ?*Node,
    height: i32,

    pub fn init(player: Player) Node {
        return .{
            .player = player,
            .left = null,
            .right = null,
            .height = 1,
        };
    }
};

pub const AVLLeaderboard = struct {
    root: ?*Node,
    allocator: *Allocator,

    pub fn init(allocator: *Allocator) AVLLeaderboard {
        return .{
            .root = null,
            .allocator = allocator,
        };
    }

    pub fn insert(self: *AVLLeaderboard, player: Player) !void {
        self.root = try self.insertRecursive(self.root, player);
    }

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

    pub fn delete(self: *AVLLeaderboard, score: u32) !void {
        self.root = try self.deleteRecursive(self.root, score);
    }

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

    fn minValueNode(self: *AVLLeaderboard, node: *Node) *Node {
        var current = node;
        while (current.left != null) {
            current = current.left.?;
        }
        return current;
    }

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

    pub fn inorderTraversal(self: *AVLLeaderboard) !void {
        try self.inorderTraversalRecursive(self.root);
    }

    fn inorderTraversalRecursive(self: *AVLLeaderboard, node: ?*Node) !void {
        if (node) |current| {
            try self.inorderTraversalRecursive(current.left);
            std.debug.print("{d} ", .{current.player.score});
            try self.inorderTraversalRecursive(current.right);
        }
    }

    pub fn getTopPlayers(self: *AVLLeaderboard, n: usize) ![]Player {
        var result = try self.allocator.alloc(Player, n);
        errdefer self.allocator.free(result);

        var count: usize = 0;
        try self.getTopPlayersRecursive(self.root, &result, &count, n);

        return result[0..count];
    }

    fn getTopPlayersRecursive(self: *AVLLeaderboard, node: ?*Node, result: *[]Player, count: *usize, n: usize) !void {
        if (node) |current| {
            try self.getTopPlayersRecursive(current.right, result, count, n);

            if (count.* < n) {
                result.*[count.*] = current.player;
                count.* += 1;
            } else {
                return;
            }

            try self.getTopPlayersRecursive(current.left, result, count, n);
        }
    }

    pub fn getRank(self: *AVLLeaderboard, score: u32) !usize {
        var rank: usize = 0;
        try self.getRankRecursive(self.root, score, &rank);
        return rank;
    }

    fn getRankRecursive(self: *AVLLeaderboard, node: ?*Node, score: u32, rank: *usize) !void {
        if (node) |current| {
            if (score > current.player.score) {
                rank.* += 1;
                if (current.left) |left| {
                    rank.* += @intCast(usize, left.height);
                }
                try self.getRankRecursive(current.right, score, rank);
            } else if (score < current.player.score) {
                try self.getRankRecursive(current.left, score, rank);
            } else {
                if (current.left) |left| {
                    rank.* += @intCast(usize, left.height);
                }
            }
        }
    }

    pub fn getPlayersInRange(self: *AVLLeaderboard, min_score: u32, max_score: u32) ![]Player {
        var result = std.ArrayList(Player).init(self.allocator);
        defer result.deinit();

        try self.getPlayersInRangeRecursive(self.root, min_score, max_score, &result);

        return result.toOwnedSlice();
    }

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

    fn updateHeight(node: *Node) void {
        const left_height = if (node.left) |left| left.height else 0;
        const right_height = if (node.right) |right| right.height else 0;
        node.height = @max(left_height, right_height) + 1;
    }

    fn rotateRight(node: *Node) !*Node {
        var new_root = node.left orelse return node;
        node.left = new_root.right;
        new_root.right = node;

        updateHeight(node);
        updateHeight(new_root);

        return new_root;
    }

    fn rotateLeft(node: *Node) !*Node {
        var new_root = node.right orelse return node;
        node.right = new_root.left;
        new_root.left = node;

        updateHeight(node);
        updateHeight(new_root);

        return new_root;
    }

    fn getBalance(node: *Node) i32 {
        const left_height = if (node.left) |left| left.height else 0;
        const right_height = if (node.right) |right| right.height else 0;
        return left_height - right_height;
    }

    // Memory management methods
    pub fn deinit(self: *AVLLeaderboard) void {
        if (self.root) |root| {
            self.deinitRecursive(root);
        }
    }

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
