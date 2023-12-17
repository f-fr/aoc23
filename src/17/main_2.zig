// Advent of code 23 - day 17
const std = @import("std");
const aoc = @import("aoc");

const Size: usize = 143;
var grid: aoc.Grid = undefined;
var lowers: [Size][Size]u16 = undefined;
var scores: [2]std.atomic.Value(u32) = .{ std.atomic.Value(u32).init(0), std.atomic.Value(u32).init(0) };

const Orien = enum { vert, horiz };

const Pos = struct { i: u8, j: u8 };
const State = struct {
    pos: Pos,
    orien: Orien,
};

fn step(p: Pos, dir: aoc.Dir) Pos {
    return switch (dir) {
        .north => .{ .i = p.i - 1, .j = p.j },
        .west => .{ .i = p.i, .j = p.j - 1 },
        .south => .{ .i = p.i + 1, .j = p.j },
        .east => .{ .i = p.i, .j = p.j + 1 },
    };
}

const SimpleGraph = struct {
    pub const Node = Pos;
    pub const Edge = void;
    pub const Value = u16;
    pub const Neigh = struct { node: Node, edge: Edge, dist: Value };

    pub const Iterator = struct {
        src: Node,
        i: u8 = 0, //< current direction

        pub fn next(self: *Iterator) ?Neigh {
            while (self.i < 4) {
                self.i += 1;
                const dir: aoc.Dir = @enumFromInt(self.i - 1);
                const pos = step(self.src, dir);
                if (pos.i > 0 and pos.i < grid.n - 1 and pos.j > 0 and pos.j < grid.m - 1)
                    return .{ .node = pos, .edge = {}, .dist = grid.at(self.src.i, self.src.j) - '0' };
            }
            return null;
        }
    };

    pub fn neighs(self: *const SimpleGraph, u: Node) Iterator {
        _ = self;
        return Iterator{ .src = u };
    }

    pub fn heur(self: *const SimpleGraph, u: Node) Value {
        _ = self;
        _ = u;

        return 0;
    }
};

fn SimpleSeen(comptime N: type, comptime D: type) type {
    return struct {
        const Self = @This();

        data: [Size][Size]?D = undefined,

        pub fn init(_: std.mem.Allocator) Self {
            return .{};
        }

        pub fn deinit(self: *Self) void {
            _ = self;
        }

        pub fn clearRetainingCapacity(self: *Self) void {
            self.data = .{.{null} ** Size} ** Size;
        }

        pub fn put(self: *Self, n: N, d: D) !void {
            self.data[n.i][n.j] = d;
        }

        pub fn getPtr(self: *Self, n: N) ?*D {
            if (self.data[n.i][n.j]) |*d| {
                return d;
            } else {
                return null;
            }
        }
    };
}

const Graph = struct {
    pub const Node = State;
    pub const Edge = void;
    pub const Value = u16;
    pub const Neigh = struct { node: Node, edge: Edge, dist: Value };

    min_d: u8 = 1,
    max_d: u8 = 3,

    pub const Iterator = struct {
        min_d: u8,
        max_d: u8,
        src: Node,
        i: u8 = 0, //< current direction

        step: u8 = 0, //< current step-size
        cur: State, //< current position
        dir: aoc.Dir = .east,
        dist: u8 = 0, //< current value

        pub fn next(self: *Iterator) ?Neigh {
            main: while (self.i < 3) {
                if (self.step == 0) {
                    if (self.src.pos.i == 1 and self.src.pos.j == 1) {
                        // special handling of start node
                        if (self.i == 0) { // go east
                            self.cur = .{ .pos = self.src.pos, .orien = .horiz };
                            self.dir = .east;
                        } else if (self.i == 2) { // go south
                            self.cur = .{ .pos = self.src.pos, .orien = .vert };
                            self.dir = .south;
                        } else {
                            return null;
                        }
                    } else {
                        const my_dir: aoc.Dir = if (self.src.orien == .vert) .south else .east;
                        const nxt_orien: Orien = if (self.src.orien == .vert) .horiz else .vert;
                        const nxt_dir: aoc.Dir = @enumFromInt((@intFromEnum(my_dir) + self.i + 1) % 4);
                        self.cur = .{ .pos = self.src.pos, .orien = nxt_orien };
                        self.dir = nxt_dir;
                    }
                    self.dist = 0;
                    const min_d = self.min_d;
                    while (self.step < min_d) : (self.step += 1) {
                        self.cur.pos = step(self.cur.pos, self.dir);
                        if (self.cur.pos.i == 0 or self.cur.pos.j == 0 or self.cur.pos.i == grid.n - 1 or self.cur.pos.j == grid.m - 1) {
                            self.step = 0;
                            self.i += 2;
                            continue :main;
                        }
                        self.dist += grid.at(self.cur.pos.i, self.cur.pos.j) - '0';
                    }
                } else {
                    self.step += 1;
                    self.cur.pos = step(self.cur.pos, self.dir);
                    self.dist += grid.at(self.cur.pos.i, self.cur.pos.j) - '0';
                    if (self.step == self.max_d) {
                        self.step = 0;
                        self.i += 2;
                    }
                }

                const nxt = self.cur.pos;
                if (nxt.i > 0 and nxt.j > 0 and nxt.i < grid.n - 1 and nxt.j < grid.m - 1) {
                    return .{
                        .node = self.cur,
                        .edge = {},
                        .dist = self.dist,
                    };
                } else if (self.step > 0) {
                    self.step = 0;
                    self.i += 2;
                }
            }

            return null;
        }
    };

    pub fn neighs(self: *const Graph, u: Node) Iterator {
        return Iterator{ .min_d = self.min_d, .max_d = self.max_d, .src = u, .cur = u };
    }

    pub fn heur(self: *const Graph, u: Node) Value {
        _ = u;

        _ = self;

        // return lowers[u.pos.i][u.pos.j];
        return 0;
    }
};

fn Seen(comptime N: type, comptime D: type) type {
    return struct {
        const Self = @This();

        data: [Size][Size][2]?D = undefined,

        pub fn init(_: std.mem.Allocator) Self {
            return .{};
        }

        pub fn deinit(self: *Self) void {
            _ = self;
        }

        pub fn clearRetainingCapacity(self: *Self) void {
            self.data = .{.{.{null} ** 2} ** Size} ** Size;
        }

        pub fn put(self: *Self, n: N, d: D) !void {
            self.data[n.pos.i][n.pos.j][@intFromEnum(n.orien)] = d;
        }

        pub fn getPtr(self: *Self, n: N) ?*D {
            if (self.data[n.pos.i][n.pos.j][@intFromEnum(n.orien)]) |*d| {
                return d;
            } else {
                return null;
            }
        }
    };
}

fn run_search(part: usize, min_d: u8, max_d: u8) !void {
    var buf: [Size * Size * 100]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    const a = fba.allocator();

    var g = Graph{};
    var search = aoc.SearchWithSeen(Graph, Seen).init(a, &g);
    defer search.deinit();

    g.min_d = min_d;
    g.max_d = max_d;

    try search.start(.{ .pos = .{ .i = 1, .j = 1 }, .orien = .vert });
    var score: u32 = Size * Size * 10;
    while (try search.next()) |nxt| {
        if (nxt.node.pos.i == grid.n - 2 and nxt.node.pos.j == grid.m - 2) {
            score = @min(score, nxt.dist);
            break;
        }
    }

    scores[part].store(score, .Monotonic);
}

pub fn run(lines: *aoc.Lines) ![2]u64 {
    var arena = std.heap.ArenaAllocator.init(aoc.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    grid = try lines.readGridWithBoundary(a, '0');

    // {
    //     var sg = SimpleGraph{};
    //     var ssearch = aoc.SearchWithSeen(SimpleGraph, SimpleSeen).init(a, &sg);
    //     defer ssearch.deinit();
    //     try ssearch.start(.{ .i = @intCast(grid.n - 2), .j = @intCast(grid.m - 2) });
    //     while (try ssearch.next()) |nxt| {
    //         lowers[nxt.node.i][nxt.node.j] = nxt.dist;
    //     }
    //     aoc.println("LOWER {}", .{lowers[1][1]});
    // }

    // var g = Graph{};
    // var search = aoc.SearchWithSeen(Graph, Seen).init(a, &g);
    // defer search.deinit();

    // inline for (.{ .{ 1, 3 }, .{ 4, 10 } }, 0..) |bnds, part| {
    //     g.min_d = bnds[0];
    //     g.max_d = bnds[1];
    //     try search.start(.{ .pos = .{ .i = 1, .j = 1 }, .orien = .vert });
    //     while (try search.next()) |nxt| {
    //         if (nxt.node.pos.i == grid.n - 2 and nxt.node.pos.j == grid.m - 2) {
    //             scores[part] = @min(scores[part], nxt.dist);
    //         } else if (nxt.dist >= scores[part]) break;
    //     }
    // }

    var th1 = try std.Thread.spawn(.{}, run_search, .{ 0, 1, 3 });
    var th2 = try std.Thread.spawn(.{}, run_search, .{ 1, 4, 10 });

    th1.join();
    th2.join();

    return .{ scores[0].load(.Monotonic), scores[1].load(.Monotonic) };
}

pub fn main() !void {
    return aoc.run("17", run);
}

test "Day 17 part 1" {
    const EXAMPLE1 =
        \\2413432311323
        \\3215453535623
        \\3255245654254
        \\3446585845452
        \\4546657867536
        \\1438598798454
        \\4457876987766
        \\3637877979653
        \\4654967986887
        \\4564679986453
        \\1224686865563
        \\2546548887735
        \\4322674655533
    ;
    const PART1: u64 = 102;

    var lines = try aoc.Lines.initBuffer(EXAMPLE1);
    defer lines.deinit();
    const allscores = try run(&lines);

    try std.testing.expectEqual(PART1, allscores[0]);
}

test "Day 17 part 2 - example 1" {
    const EXAMPLE2 =
        \\2413432311323
        \\3215453535623
        \\3255245654254
        \\3446585845452
        \\4546657867536
        \\1438598798454
        \\4457876987766
        \\3637877979653
        \\4654967986887
        \\4564679986453
        \\1224686865563
        \\2546548887735
        \\4322674655533
    ;
    const PART2: u64 = 94;

    var lines = try aoc.Lines.initBuffer(EXAMPLE2);
    defer lines.deinit();
    const allscores = try run(&lines);

    try std.testing.expectEqual(PART2, allscores[1]);
}

test "Day 17 part 2 - example 2" {
    const EXAMPLE2 =
        \\111111111111
        \\999999999991
        \\999999999991
        \\999999999991
        \\999999999991
    ;
    const PART2: u64 = 71;

    var lines = try aoc.Lines.initBuffer(EXAMPLE2);
    defer lines.deinit();
    const allscores = try run(&lines);

    try std.testing.expectEqual(PART2, allscores[1]);
}
