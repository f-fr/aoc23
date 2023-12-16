// Advent of code 23 - day 16
const std = @import("std");
const aoc = @import("aoc");

const NumThreads: usize = 4;
const NumRows: usize = 120;
const NumCols: usize = 120;

const State = struct {
    pos: aoc.Pos,
    dir: aoc.Dir,
};

var jumps: [NumRows][NumCols][4]u8 = undefined;
var score2 = std.atomic.Value(usize).init(0);

const Runner = struct {
    const Self = @This();
    energized: [NumRows][NumCols]u8 = .{.{0} ** NumCols} ** NumRows,
    seen: [NumRows][NumCols][4]u8 = .{.{.{0} ** 4} ** NumCols} ** NumRows,
    generation: u8 = 1,
    score: usize = 0,

    states: [NumRows * NumCols * 4]State = undefined,
    nstates: usize = 0,

    fn statesPopOrNull(self: *Self) ?State {
        if (self.nstates > 0) {
            self.nstates -= 1;
            return self.states[self.nstates];
        } else return null;
    }

    fn statesPush(self: *Self, st: State) void {
        self.states[self.nstates] = st;
        self.nstates += 1;
    }

    fn step(self: *Self, pos: aoc.Pos, dir: aoc.Dir) State {
        const generation = self.generation;
        var score: usize = 0;
        const st: State = next: {
            switch (dir) {
                .north => {
                    const m = jumps[pos.i][pos.j][@intFromEnum(aoc.Dir.north)];
                    for (pos.i - m..pos.i) |i| {
                        score += @intFromBool(self.energized[i][pos.j] != generation);
                        self.energized[i][pos.j] = generation;
                    }
                    break :next .{ .pos = .{ .i = pos.i - m, .j = pos.j }, .dir = dir };
                },
                .west => {
                    const m = jumps[pos.i][pos.j][@intFromEnum(aoc.Dir.west)];
                    for (pos.j - m..pos.j) |j| {
                        score += @intFromBool(self.energized[pos.i][j] != generation);
                        self.energized[pos.i][j] = generation;
                    }
                    break :next .{ .pos = .{ .i = pos.i, .j = pos.j - m }, .dir = dir };
                },
                .south => {
                    const m = jumps[pos.i][pos.j][@intFromEnum(aoc.Dir.south)];
                    for (pos.i + 1..pos.i + m + 1) |i| {
                        score += @intFromBool(self.energized[i][pos.j] != generation);
                        self.energized[i][pos.j] = generation;
                    }
                    break :next .{ .pos = .{ .i = pos.i + m, .j = pos.j }, .dir = dir };
                },
                .east => {
                    const m = jumps[pos.i][pos.j][@intFromEnum(aoc.Dir.east)];
                    for (pos.j + 1..pos.j + m + 1) |j| {
                        score += @intFromBool(self.energized[pos.i][j] != generation);
                        self.energized[pos.i][j] = generation;
                    }
                    break :next .{ .pos = .{ .i = pos.i, .j = pos.j + m }, .dir = dir };
                },
            }
        };
        self.score += score;
        return st;
    }

    fn countEnergized(self: *Self, grid: *const aoc.Grid, start: State) usize {
        const generation = self.generation;

        self.nstates = 1;
        self.states[0] = start;

        self.score = 0;
        var iter: usize = 0;
        while (self.statesPopOrNull()) |st| : (iter += 1) {
            const d: u2 = @intFromEnum(st.dir);

            // check if already visited from this direction
            if (self.seen[st.pos.i][st.pos.j][d] == generation) continue;
            self.seen[st.pos.i][st.pos.j][d] = generation;

            // check if we reached the boundary
            const c = grid.at(st.pos.i, st.pos.j);
            if (iter > 0 and c == ' ') {
                self.score -= 1; // the boundary field does not count
                continue;
            }

            switch (c) {
                ' ' => self.statesPush(self.step(st.pos, st.dir)),
                '\\' => {
                    const new_dir: aoc.Dir = switch (st.dir) {
                        .north => .west,
                        .west => .north,
                        .south => .east,
                        .east => .south,
                    };
                    self.statesPush(self.step(st.pos, new_dir));
                },
                '/' => {
                    const new_dir: aoc.Dir = switch (st.dir) {
                        .north => .east,
                        .east => .north,
                        .south => .west,
                        .west => .south,
                    };
                    self.statesPush(self.step(st.pos, new_dir));
                },
                '-' => switch (st.dir) {
                    .east, .west => self.statesPush(self.step(st.pos, st.dir)),
                    else => inline for (.{ .east, .west }) |new_dir| {
                        self.statesPush(self.step(st.pos, new_dir));
                    },
                },
                '|' => switch (st.dir) {
                    .north, .south => self.statesPush(self.step(st.pos, st.dir)),
                    else => inline for (.{ .north, .south }) |new_dir| {
                        self.statesPush(self.step(st.pos, new_dir));
                    },
                },
                else => unreachable,
            }
        }

        return self.score;
    }
};

fn run_thread(grid: *const aoc.Grid, idx: usize) void {
    var runner = Runner{};
    for (1..grid.n - 1) |i| {
        if (i % NumThreads != idx) continue;
        runner.generation += 1;
        _ = score2.fetchMax(runner.countEnergized(grid, .{ .pos = .{ .i = i, .j = 0 }, .dir = .east }), .Monotonic);

        runner.generation += 1;
        _ = score2.fetchMax(runner.countEnergized(grid, .{ .pos = .{ .i = i, .j = grid.m - 1 }, .dir = .west }), .Monotonic);
    }

    if (runner.generation > 200) runner.generation = 0;
    for (1..grid.m - 1) |j| {
        if (j % NumThreads != idx) continue;
        runner.generation += 1;
        _ = score2.fetchMax(runner.countEnergized(grid, .{ .pos = .{ .i = 0, .j = j }, .dir = .south }), .Monotonic);
        runner.generation += 1;
        _ = score2.fetchMax(runner.countEnergized(grid, .{ .pos = .{ .i = grid.n - 1, .j = j }, .dir = .north }), .Monotonic);
    }
}

pub fn run(lines: *aoc.Lines) ![2]u64 {
    var arena = std.heap.ArenaAllocator.init(aoc.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const grid = try lines.readGridWithBoundary(a, ' ');

    // distance from (i,j) in direction d until next non-'.'-field
    for (1..grid.n - 1) |i| {
        var j: u8 = 0;
        while (j < grid.m - 1) {
            var j_start = j;
            j += 1;
            while (grid.at(i, j) == '.') j += 1;
            jumps[i][j_start][@intFromEnum(aoc.Dir.east)] = j - j_start;
            jumps[i][j][@intFromEnum(aoc.Dir.west)] = j - j_start;
            j_start = j;
        }
    }
    for (1..grid.m - 1) |j| {
        var i: u8 = 0;
        while (i < grid.n - 1) {
            var i_start = i;
            i += 1;
            while (grid.at(i, j) == '.') i += 1;
            jumps[i_start][j][@intFromEnum(aoc.Dir.south)] = i - i_start;
            jumps[i][j][@intFromEnum(aoc.Dir.north)] = i - i_start;
            i_start = i;
        }
    }

    var runner = Runner{};

    const score1 = runner.countEnergized(&grid, .{ .pos = .{ .i = 1, .j = 0 }, .dir = .east });

    var threads: [NumThreads]std.Thread = undefined;
    for (0..NumThreads) |thread_i| {
        threads[thread_i] = try std.Thread.spawn(.{}, run_thread, .{ &grid, thread_i });
    }

    for (threads) |th| th.join();

    return .{ score1, score2.load(.Monotonic) };
}

pub fn main() !void {
    return aoc.run("16", run);
}

test "Day 16 part 1" {
    const EXAMPLE1 =
        \\.|...\....
        \\|.-.\.....
        \\.....|-...
        \\........|.
        \\..........
        \\.........\
        \\..../.\\..
        \\.-.-/..|..
        \\.|....-|.\
        \\..//.|....
    ;
    const PART1: u64 = 46;

    var lines = try aoc.Lines.initBuffer(EXAMPLE1);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART1, scores[0]);
}

test "Day 16 part 2" {
    const EXAMPLE2 =
        \\.|...\....
        \\|.-.\.....
        \\.....|-...
        \\........|.
        \\..........
        \\.........\
        \\..../.\\..
        \\.-.-/..|..
        \\.|....-|.\
        \\..//.|....
    ;
    const PART2: u64 = 51;

    var lines = try aoc.Lines.initBuffer(EXAMPLE2);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART2, scores[1]);
}
