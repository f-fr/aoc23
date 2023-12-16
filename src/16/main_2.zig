// Advent of code 23 - day 16
const std = @import("std");
const aoc = @import("aoc");

const NumRows: usize = 120;
const NumCols: usize = 120;

const State = struct {
    pos: aoc.Pos,
    dir: aoc.Dir,
};

const States = std.ArrayList(State);

fn step(pos: aoc.Pos, dir: aoc.Dir, jumps: *const [NumRows][NumCols][4]usize, energized: *[NumRows][NumCols]bool, score: *usize) State {
    const st: State = next: {
        switch (dir) {
            .north => {
                const m = jumps[pos.i][pos.j][@intFromEnum(aoc.Dir.north)];
                for (pos.i - m..pos.i) |i| {
                    if (!energized[i][pos.j]) {
                        score.* += 1;
                        energized[i][pos.j] = true;
                    }
                }
                break :next .{ .pos = .{ .i = pos.i - m, .j = pos.j }, .dir = dir };
            },
            .south => {
                const m = jumps[pos.i][pos.j][@intFromEnum(aoc.Dir.south)];
                for (pos.i + 1..pos.i + m + 1) |i| {
                    if (!energized[i][pos.j]) {
                        score.* += 1;
                        energized[i][pos.j] = true;
                    }
                }
                break :next .{ .pos = .{ .i = pos.i + m, .j = pos.j }, .dir = dir };
            },
            .west => {
                const m = jumps[pos.i][pos.j][@intFromEnum(aoc.Dir.west)];
                for (pos.j - m..pos.j) |j| {
                    if (!energized[pos.i][j]) {
                        score.* += 1;
                        energized[pos.i][j] = true;
                    }
                }
                break :next .{ .pos = .{ .i = pos.i, .j = pos.j - m }, .dir = dir };
            },
            .east => {
                const m = jumps[pos.i][pos.j][@intFromEnum(aoc.Dir.east)];
                for (pos.j + 1..pos.j + m + 1) |j| {
                    if (!energized[pos.i][j]) {
                        score.* += 1;
                        energized[pos.i][j] = true;
                    }
                }
                break :next .{ .pos = .{ .i = pos.i, .j = pos.j + m }, .dir = dir };
            },
        }
    };

    return st;
}

fn countEnergized(grid: *const aoc.Grid, jumps: *const [NumRows][NumCols][4]usize, start: State, states: *States) u64 {
    var energized: [NumRows][NumCols]bool = .{.{false} ** NumCols} ** NumRows;
    var seen: [NumRows][NumCols]u4 = .{.{0} ** NumCols} ** NumRows;

    states.clearRetainingCapacity();
    states.appendAssumeCapacity(start);

    var score: usize = 0;
    var iter: usize = 0;
    while (states.popOrNull()) |st| : (iter += 1) {
        const d: u2 = @intFromEnum(st.dir);

        // check if already visited from this direction
        if (seen[st.pos.i][st.pos.j] & (@as(u4, 1) << d) != 0) continue;
        seen[st.pos.i][st.pos.j] |= @as(u4, 1) << d;

        // check if we reached the boundary
        const c = grid.at(st.pos.i, st.pos.j);
        if (iter > 0 and c == ' ') {
            score -= 1; // the boundary field does not count
            continue;
        }

        switch (c) {
            ' ' => states.appendAssumeCapacity(step(st.pos, st.dir, jumps, &energized, &score)),
            '\\' => {
                const new_dir: aoc.Dir = switch (st.dir) {
                    .north => .west,
                    .west => .north,
                    .south => .east,
                    .east => .south,
                };
                states.appendAssumeCapacity(step(st.pos, new_dir, jumps, &energized, &score));
            },
            '/' => {
                const new_dir: aoc.Dir = switch (st.dir) {
                    .north => .east,
                    .east => .north,
                    .south => .west,
                    .west => .south,
                };
                states.appendAssumeCapacity(step(st.pos, new_dir, jumps, &energized, &score));
            },
            '-' => switch (st.dir) {
                .east, .west => states.appendAssumeCapacity(step(st.pos, st.dir, jumps, &energized, &score)),
                else => inline for (.{ .east, .west }) |new_dir| {
                    states.appendAssumeCapacity(step(st.pos, new_dir, jumps, &energized, &score));
                },
            },
            '|' => switch (st.dir) {
                .north, .south => states.appendAssumeCapacity(step(st.pos, st.dir, jumps, &energized, &score)),
                else => inline for (.{ .north, .south }) |new_dir| {
                    states.appendAssumeCapacity(step(st.pos, new_dir, jumps, &energized, &score));
                },
            },
            else => unreachable,
        }
    }

    return score;
}

pub fn run(lines: *aoc.Lines) ![2]u64 {
    var arena = std.heap.ArenaAllocator.init(aoc.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const grid = try lines.readGridWithBoundary(a, ' ');
    var states = try States.initCapacity(a, grid.n * grid.m * 4);

    // distance from (i,j) in direction d until next non-'.'-field
    var jumps: [NumRows][NumCols][4]usize = undefined;
    for (1..grid.n - 1) |i| {
        var j: usize = 0;
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
        var i: usize = 0;
        while (i < grid.n - 1) {
            var i_start = i;
            i += 1;
            while (grid.at(i, j) == '.') i += 1;
            jumps[i_start][j][@intFromEnum(aoc.Dir.south)] = i - i_start;
            jumps[i][j][@intFromEnum(aoc.Dir.north)] = i - i_start;
            i_start = i;
        }
    }

    const score1 = countEnergized(&grid, &jumps, .{ .pos = .{ .i = 1, .j = 0 }, .dir = .east }, &states);

    var score2: u64 = 0;
    for (1..grid.n - 1) |i| {
        score2 = @max(score2, countEnergized(&grid, &jumps, .{ .pos = .{ .i = i, .j = 0 }, .dir = .east }, &states));
        score2 = @max(score2, countEnergized(&grid, &jumps, .{ .pos = .{ .i = i, .j = grid.m - 1 }, .dir = .west }, &states));
    }

    for (1..grid.m - 1) |j| {
        score2 = @max(score2, countEnergized(&grid, &jumps, .{ .pos = .{ .i = 0, .j = j }, .dir = .south }, &states));
        score2 = @max(score2, countEnergized(&grid, &jumps, .{ .pos = .{ .i = grid.n - 1, .j = j }, .dir = .north }, &states));
    }

    return .{ score1, score2 };
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
