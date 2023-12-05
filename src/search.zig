const std = @import("std");
const testing = std.testing;

const PriQueue = @import("./priqueue.zig").PriQueue;

pub fn Search(comptime G: type) type {
    return struct {
        const Self = @This();
        const P = PriQueue(G.Node, G.Value);
        const S = std.AutoHashMap(G.Node, Data);

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
