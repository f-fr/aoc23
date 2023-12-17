// Advent of code 23 - day 17
const std = @import("std");
const aoc = @import("aoc");

var grid: aoc.Grid = undefined;

const State = struct {
    pos: aoc.Pos,
    dir: aoc.Dir,
};

fn stepn(p: aoc.Pos, dir: aoc.Dir, n: usize) ?aoc.Pos {
    return switch (dir) {
        .north => if (p.i >= n) .{ .i = p.i - n, .j = p.j } else null,
        .west => if (p.j >= n) .{ .i = p.i, .j = p.j - n } else null,
        .south => .{ .i = p.i + n, .j = p.j },
        .east => .{ .i = p.i, .j = p.j + n },
    };
}

const Graph = struct {
    pub const Node = State;
    pub const Edge = void;
    pub const Value = usize;
    pub const Neigh = struct { node: Node, edge: Edge, dist: Value };

    min_d: u8 = 1,
    max_d: u8 = 3,

    pub const Iterator = struct {
        g: *const Graph,
        src: Node,
        i: u8 = 0, //< current direction

        step: u8 = 0, //< current step-size
        cur: State, //< current position
        dist: u8 = 0, //< current value

        pub fn next(self: *Iterator) ?Neigh {
            main: while (true) {
                if (self.i >= 3) {
                    // aoc.println("END OF {},{}", .{ self.src.pos.i, self.src.pos.j });
                    return null;
                }

                if (self.step == 0) {
                    // aoc.println("START DIR {} src:{},{}", .{ self.i, self.src.pos.i, self.src.pos.j });
                    const nxt_dir: aoc.Dir = @enumFromInt((@intFromEnum(self.src.dir) + self.i + 1) % 4);

                    self.dist = 0;
                    self.cur = .{ .pos = self.src.pos, .dir = nxt_dir };
                    const min_d = self.g.min_d;
                    while (self.step < min_d) : (self.step += 1) {
                        self.cur.pos = self.cur.pos.step(nxt_dir);
                        if (self.cur.pos.i == 0 or self.cur.pos.j == 0 or self.cur.pos.i == grid.n - 1 or self.cur.pos.j == grid.m - 1) {
                            self.step = 0;
                            if (self.src.pos.i == 1 and self.src.pos.j == 1)
                                self.i += 1
                            else
                                self.i += 2;
                            continue :main;
                        }
                        self.dist += grid.atPos(self.cur.pos) - '0';
                        // aoc.println("ADD {},{} -> {},{},{}: {} {}", .{ self.src.pos.i, self.src.pos.j, self.cur.pos.i, self.cur.pos.j, self.cur.dir, grid.atPos(self.cur.pos) - '0', self.dist });
                    }
                } else {
                    self.step += 1;
                    self.cur.pos = self.cur.pos.step(self.cur.dir);
                    self.dist += grid.atPos(self.cur.pos) - '0';
                    // aoc.println("ADD {},{} -> {},{},{}: {} {}", .{ self.src.pos.i, self.src.pos.j, self.cur.pos.i, self.cur.pos.j, self.cur.dir, grid.atPos(self.cur.pos) - '0', self.dist });
                    if (self.step == self.g.max_d) {
                        self.step = 0;
                        if (self.src.pos.i == 1 and self.src.pos.j == 1)
                            self.i += 1
                        else
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
                    if (self.src.pos.i == 1 and self.src.pos.j == 1)
                        self.i += 1
                    else
                        self.i += 2;
                }
            }
        }
    };

    pub fn neighs(self: *const Graph, u: Node) Iterator {
        return Iterator{ .g = self, .src = u, .cur = u };
    }

    pub fn heur(self: *const Graph, u: Node) Value {
        _ = self;
        _ = u;

        return 0;
    }
};

pub fn run(lines: *aoc.Lines) ![2]u64 {
    var arena = std.heap.ArenaAllocator.init(aoc.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    grid = try lines.readGridWithBoundary(a, '0');
    var g = Graph{};
    var search = aoc.Search(Graph).init(a, &g);
    defer search.deinit();

    var scores: [2]u64 = .{std.math.maxInt(u64)} ** 2;

    inline for (.{ .{ 1, 3 }, .{ 4, 10 } }, 0..) |bnds, part| {
        g.min_d = bnds[0];
        g.max_d = bnds[1];
        try search.start(.{ .pos = .{ .i = 1, .j = 1 }, .dir = .north });
        while (try search.next()) |nxt| {
            // aoc.println("{},{},{}  :   {}", .{ nxt.node.pos.i, nxt.node.pos.j, nxt.node.dir, nxt.dist });
            if (nxt.node.pos.i == grid.n - 2 and nxt.node.pos.j == grid.m - 2) {
                scores[part] = @min(scores[part], nxt.dist);
            } else if (nxt.dist >= scores[part]) break;
        }
    }

    return scores;
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
    const scores = try run(&lines);

    try std.testing.expectEqual(PART1, scores[0]);
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
    const scores = try run(&lines);

    try std.testing.expectEqual(PART2, scores[1]);
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
    const scores = try run(&lines);

    try std.testing.expectEqual(PART2, scores[1]);
}
