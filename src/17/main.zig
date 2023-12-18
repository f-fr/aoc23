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
        i: u8 = 0,
        d: u8 = 1,

        pub fn next(self: *Iterator) ?Neigh {
            while (true) {
                if (self.d > self.g.max_d) return null;

                const nxt_d = self.d;
                const nxt_dir: aoc.Dir = @enumFromInt((@intFromEnum(self.src.dir) + self.i * 2 + 1) % 4);
                const maybe_nxt = stepn(self.src.pos, nxt_dir, self.d);

                self.i += 1;
                if (self.i >= 2) {
                    self.i = 0;
                    self.d += 1;
                }

                if (maybe_nxt) |nxt| {
                    if (nxt.i > 0 and nxt.j > 0 and nxt.i < grid.n - 1 and nxt.j < grid.m - 1) {
                        var dist: usize = 0;
                        var p = self.src.pos;
                        for (0..nxt_d) |_| {
                            p = p.step(nxt_dir);
                            dist += grid.atPos(p) - '0';
                        }

                        return .{
                            .node = .{ .pos = nxt, .dir = nxt_dir },
                            .edge = {},
                            .dist = dist,
                        };
                    }
                }
            }
        }
    };

    pub fn neighs(self: *const Graph, u: Node) Iterator {
        return Iterator{ .g = self, .src = u, .d = self.min_d };
    }

    pub fn heur(self: *const Graph, u: Node) Value {
        _ = self;
        _ = u;

        return 0;
    }
};

pub fn run(lines: *aoc.Lines) ![2]u64 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
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
        inline for (.{ .east, .south }) |start_dir| {
            try search.start(.{ .pos = .{ .i = 1, .j = 1 }, .dir = start_dir });
            while (try search.next()) |nxt| {
                if (nxt.node.pos.i == grid.n - 2 and nxt.node.pos.j == grid.m - 2) {
                    scores[part] = @min(scores[part], nxt.dist);
                    break;
                }
            }
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
