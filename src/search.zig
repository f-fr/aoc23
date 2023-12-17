const std = @import("std");
const testing = std.testing;

const PriQueue = @import("./priqueue.zig").PriQueue;

pub fn Search(comptime G: type) type {
    return SearchWithSeen(G, std.AutoHashMap);
}

pub fn SearchWithSeen(comptime G: type, comptime Seen: fn (comptime type, comptime type) type) type {
    return struct {
        const Self = @This();
        const P = PriQueue(G.Node, G.Value);
        const S = Seen(G.Node, Data);

        const Data = struct {
            predecessor_node: G.Node,
            incoming_edge: G.Edge,
            distance: G.Value,
            lower: G.Value,
            item: ?P.Item,
        };

        graph: *const G,
        it: ?G.Iterator = null,
        pqueue: P,
        seen: S,

        pub fn init(allocator: std.mem.Allocator, g: *const G) Self {
            return .{
                .graph = g,
                //.pqueue = P.initCapacity(allocator, 200 * 200) catch unreachable,
                .pqueue = P.init(allocator),
                .seen = S.init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            self.pqueue.deinit();
            self.seen.deinit();
        }

        pub fn start(self: *Self, s: G.Node) !void {
            self.it = null;
            self.pqueue.clearRetainingCapacity();
            self.seen.clearRetainingCapacity();

            try self.seen.put(s, Data{
                .predecessor_node = s,
                .incoming_edge = undefined,
                .distance = 0,
                .lower = 0,
                .item = null,
            });
            try self.update_node(s, 0);
        }

        fn update_node(self: *Self, u: G.Node, dist: G.Value) !void {
            var it = self.graph.neighs(u);
            while (it.next()) |nxt| {
                const d = dist + nxt.dist;
                if (self.seen.getPtr(nxt.node)) |vdata| {
                    if (vdata.item) |item| {
                        // node is known
                        if (d < vdata.distance) {
                            vdata.distance = d;
                            vdata.predecessor_node = u;
                            vdata.incoming_edge = nxt.edge;
                            _ = self.pqueue.decrease(item, d + vdata.lower);
                        }
                    }
                } else {
                    // node is unknown
                    const lower = self.graph.heur(nxt.node);
                    const item = try self.pqueue.push(nxt.node, d + lower);
                    try self.seen.put(nxt.node, Data{
                        .predecessor_node = u,
                        .incoming_edge = nxt.edge,
                        .distance = d,
                        .lower = lower,
                        .item = item,
                    });
                }
            }
        }

        pub fn next(self: *Self) !?struct { pred: G.Node, node: G.Node, edge: G.Edge, dist: G.Value } {
            if (self.pqueue.popOrNull()) |u| {
                // node is not in the heap anymore, forget its item
                const data = self.seen.getPtr(u.key) orelse unreachable;
                data.item = null;
                const dist = data.distance;
                const incoming_edge = data.incoming_edge;
                const predecessor_node = data.predecessor_node;
                try self.update_node(u.key, dist);
                return .{ .pred = predecessor_node, .node = u.key, .edge = incoming_edge, .dist = dist };
            } else {
                return null;
            }
        }
    };
}

test "simple undirected" {
    const EdgeInfo = struct { u8, u8, usize };
    const edges = [_]EdgeInfo{ .{ 'b', 'c', 11 }, .{ 'b', 'a', 1 }, .{ 'c', 'd', 8 }, .{ 'c', 't', 1 }, .{ 's', 'a', 1 }, .{ 'a', 'd', 10 } };

    const Graph = struct {
        pub const Node = u8;
        pub const Edge = u16;
        pub const Value = usize;
        pub const Neigh = struct { node: Node, edge: Edge, dist: Value };

        pub const Iterator = struct {
            src: Node,
            i: ?Edge = null,

            pub fn next(self: *Iterator) ?Neigh {
                var i = if (self.i) |u| u + 1 else 0;
                while (i < edges.len) : (i += 1) {
                    if (edges[i][0] == self.src) {
                        self.i = i;
                        return .{ .node = edges[i][1], .edge = i, .dist = edges[i][2] };
                    } else if (edges[i][1] == self.src) {
                        self.i = i;
                        return .{ .node = edges[i][0], .edge = i, .dist = edges[i][2] };
                    }
                }
                self.i = i;
                return null;
            }
        };

        pub fn neighs(self: *const @This(), u: Node) Iterator {
            _ = self;
            return Iterator{ .src = u };
        }

        pub fn heur(self: *const @This(), u: Node) usize {
            _ = self;
            _ = u;

            return 0;
        }
    };

    var g = Graph{};
    var search = Search(Graph).init(testing.allocator, &g);
    defer search.deinit();
    try search.start('s');
    var preds = [1]?u8{null} ** 256;
    while (try search.next()) |nxt| {
        preds[nxt.node] = nxt.pred;
    }

    try testing.expectEqual(@as(?u8, null), preds['s']);
    try testing.expectEqual(@as(?u8, 's'), preds['a']);
    try testing.expectEqual(@as(?u8, 'a'), preds['b']);
    try testing.expectEqual(@as(?u8, 'b'), preds['c']);
    try testing.expectEqual(@as(?u8, 'c'), preds['t']);
}

test "lattice graph" {
    const Nd = struct { x: i32, y: i32 };

    const s = Nd{ .x = 2, .y = 3 };
    const t = Nd{ .x = 7, .y = 1 };

    const Graph = struct {
        const Self = @This();
        const Node = Nd;
        const Edge = [2]Node;
        const Value = f64;

        const Special = [_]Edge{ .{ .{ .x = 4, .y = 1 }, .{ .x = 5, .y = 1 } }, .{ .{ .x = 2, .y = 2 }, .{ .x = 3, .y = 2 } }, .{ .{ .x = 3, .y = 2 }, .{ .x = 4, .y = 2 } }, .{ .{ .x = 6, .y = 2 }, .{ .x = 7, .y = 2 } }, .{ .{ .x = 6, .y = 3 }, .{ .x = 7, .y = 4 } }, .{ .{ .x = 5, .y = 2 }, .{ .x = 5, .y = 3 } }, .{ .{ .x = 6, .y = 1 }, .{ .x = 6, .y = 2 } } };

        pub const Iterator = struct {
            src: Node,
            dir: usize = 0,

            pub fn next(self: *Iterator) ?struct { node: Node, edge: Edge, dist: Value } {
                if (self.dir == 4) return null;
                self.dir += 1;
                const u = self.src;
                const v =
                    switch (self.dir) {
                    1 => Node{ .x = u.x - 1, .y = u.y },
                    2 => Node{ .x = u.x, .y = u.y - 1 },
                    3 => Node{ .x = u.x + 1, .y = u.y },
                    4 => Node{ .x = u.x, .y = u.y + 1 },
                    else => unreachable,
                };
                const e = if (self.dir <= 2) .{ v, u } else .{ u, v };
                var d: Value = 2;
                for (Special) |f| {
                    if (e[0].x == f[0].x and e[1].x == f[1].x and e[0].y == f[0].y and e[1].y == f[1].y) {
                        d = 3;
                        break;
                    }
                }
                return .{ .node = v, .edge = e, .dist = d };
            }
        };

        fn neighs(self: *const Self, u: Node) Iterator {
            _ = self;
            return .{ .src = u };
        }

        fn heur(self: *const Self, u: Node) Value {
            _ = self;
            return @floatFromInt(4 * (@abs(u.x - t.x) + @abs(u.y - t.y)) / 2);
        }
    };

    var g = Graph{};
    var search = Search(Graph).init(testing.allocator, &g);
    defer search.deinit();
    try search.start(s);

    var preds = [1][12]?Nd{[1]?Nd{null} ** 12} ** 12;

    while (try search.next()) |nxt| {
        try testing.expect(nxt.node.x >= @min(s.x, t.x) - @as(i32, 1));
        try testing.expect(nxt.node.x <= @max(s.x, t.x) + @as(i32, 1));
        try testing.expect(nxt.node.y >= @min(s.x, t.y) - @as(i32, 1));
        try testing.expect(nxt.node.y <= @max(s.y, t.y) + @as(i32, 1));

        const x: usize = @intCast(nxt.node.x);
        const y: usize = @intCast(nxt.node.y);
        preds[x][y] = nxt.pred;

        if (nxt.node.x == t.x and nxt.node.y == t.y) break;
    }

    try testing.expectEqualDeep(Nd{ .x = 6, .y = 1 }, preds[7][1].?);
    try testing.expectEqualDeep(Nd{ .x = 5, .y = 1 }, preds[6][1].?);
    try testing.expectEqualDeep(Nd{ .x = 5, .y = 2 }, preds[5][1].?);
    try testing.expectEqualDeep(Nd{ .x = 4, .y = 2 }, preds[5][2].?);
    try testing.expectEqualDeep(Nd{ .x = 4, .y = 3 }, preds[4][2].?);
    try testing.expectEqualDeep(Nd{ .x = 3, .y = 3 }, preds[4][3].?);
    try testing.expectEqualDeep(Nd{ .x = 2, .y = 3 }, preds[3][3].?);
}
