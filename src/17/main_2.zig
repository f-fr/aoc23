// Advent of code 23 - day 17
const std = @import("std");
const aoc = @import("aoc");

const Size: usize = 143;
var grid: aoc.Grid = undefined;
var scores: [2]std.atomic.Value(u32) = .{ std.atomic.Value(u32).init(0), std.atomic.Value(u32).init(0) };

const Orien = enum { vert, horiz, start };

const Pos = @Vector(2, u8);
const State = struct {
    pos: Pos,
    orien: Orien,
};

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
        diff: @Vector(2, u8) = .{ 0, 0 },
        dist: u8 = 0, //< current value

        pub fn next(self: *Iterator) ?Neigh {
            main: while (self.i < 3) {
                if (self.step == 0) {
                    switch (self.src.orien) {
                        .vert => {
                            self.cur = .{ .pos = self.src.pos, .orien = .horiz };
                            self.diff = if (self.i == 0) .{ 0, 255 } else .{ 0, 1 };
                        },
                        .horiz => {
                            self.cur = .{ .pos = self.src.pos, .orien = .vert };
                            self.diff = if (self.i == 0) .{ 255, 0 } else .{ 1, 0 };
                        },
                        .start => switch (self.i) {
                            0 => {
                                self.cur = .{ .pos = self.src.pos, .orien = .horiz };
                                self.diff = .{ 0, 1 };
                            },
                            2 => {
                                self.cur = .{ .pos = self.src.pos, .orien = .vert };
                                self.diff = .{ 1, 0 };
                            },
                            else => unreachable,
                        },
                    }
                    self.dist = 0;
                    const min_d = self.min_d;
                    while (self.step < min_d) : (self.step += 1) {
                        self.cur.pos +%= self.diff;
                        const c = grid.at(self.cur.pos[0], self.cur.pos[1]);
                        if (c == ' ') {
                            self.step = 0;
                            self.i += 2;
                            continue :main;
                        }
                        self.dist += c - '0';
                    }
                    return .{ .node = self.cur, .edge = {}, .dist = self.dist };
                } else {
                    self.step += 1;
                    self.cur.pos +%= self.diff;
                    if (self.step == self.max_d) {
                        self.step = 0;
                        self.i += 2;
                    }
                }

                const c = grid.at(self.cur.pos[0], self.cur.pos[1]);
                if (c != ' ') {
                    self.dist += c - '0';
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

        pub fn ensureTotalCapacity(self: *Self, capacity: usize) !void {
            _ = self;
            _ = capacity;
        }

        pub fn clearRetainingCapacity(self: *Self) void {
            self.data = .{.{.{null} ** 2} ** Size} ** Size;
        }

        pub fn put(self: *Self, n: N, d: D) !void {
            self.data[n.pos[0]][n.pos[1]][@intFromEnum(n.orien) & 1] = d;
        }

        pub fn getPtr(self: *Self, n: N) ?*D {
            if (self.data[n.pos[0]][n.pos[1]][@intFromEnum(n.orien)]) |*d| {
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

    try search.ensureCapacity(Size * Size * 2);

    g.min_d = min_d;
    g.max_d = max_d;

    try search.start(.{ .pos = .{ 1, 1 }, .orien = .start });
    var score: u32 = Size * Size * 10;
    while (try search.next()) |nxt| {
        if (nxt.node.pos[0] == grid.n - 2 and nxt.node.pos[1] == grid.m - 2) {
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

    grid = try lines.readGridWithBoundary(a, ' ');

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
