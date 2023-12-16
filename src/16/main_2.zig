// Advent of code 23 - day 16
const std = @import("std");
const aoc = @import("aoc");

const NumRows: usize = 120;
const NumCols: usize = 120;

const State = struct {
    pos: aoc.Pos,
    dir: aoc.Dir,
};

var jumps: [NumRows][NumCols][4]u8 = undefined;
var energized: [NumRows][NumCols]u8 = .{.{0} ** NumCols} ** NumRows;
var seen: [NumRows][NumCols][4]u8 = .{.{.{0} ** 4} ** NumCols} ** NumRows;
var generation: u8 = 1;
var score: usize = 0;

var states: [NumRows * NumCols * 4]State = undefined;
var nstates: usize = 0;

fn statesPopOrNull() ?State {
    if (nstates > 0) {
        nstates -= 1;
        return states[nstates];
    } else return null;
}

fn statesPush(st: State) void {
    states[nstates] = st;
    nstates += 1;
}

fn step(pos: aoc.Pos, dir: aoc.Dir) State {
    switch (dir) {
        .north => {
            const m = jumps[pos.i][pos.j][@intFromEnum(aoc.Dir.north)];
            for (pos.i - m..pos.i) |i| {
                score += @intFromBool(energized[i][pos.j] != generation);
                energized[i][pos.j] = generation;
            }
            return .{ .pos = .{ .i = pos.i - m, .j = pos.j }, .dir = dir };
        },
        .west => {
            const m = jumps[pos.i][pos.j][@intFromEnum(aoc.Dir.west)];
            for (pos.j - m..pos.j) |j| {
                score += @intFromBool(energized[pos.i][j] != generation);
                energized[pos.i][j] = generation;
            }
            return .{ .pos = .{ .i = pos.i, .j = pos.j - m }, .dir = dir };
        },
        .south => {
            const m = jumps[pos.i][pos.j][@intFromEnum(aoc.Dir.south)];
            for (pos.i + 1..pos.i + m + 1) |i| {
                score += @intFromBool(energized[i][pos.j] != generation);
                energized[i][pos.j] = generation;
            }
            return .{ .pos = .{ .i = pos.i + m, .j = pos.j }, .dir = dir };
        },
        .east => {
            const m = jumps[pos.i][pos.j][@intFromEnum(aoc.Dir.east)];
            for (pos.j + 1..pos.j + m + 1) |j| {
                score += @intFromBool(energized[pos.i][j] != generation);
                energized[pos.i][j] = generation;
            }
            return .{ .pos = .{ .i = pos.i, .j = pos.j + m }, .dir = dir };
        },
    }
}

fn countEnergized(grid: *const aoc.Grid, start: State) u64 {
    nstates = 1;
    states[0] = start;

    score = 0;
    var iter: usize = 0;
    while (statesPopOrNull()) |st| : (iter += 1) {
        const d: u2 = @intFromEnum(st.dir);

        // check if already visited from this direction
        if (seen[st.pos.i][st.pos.j][d] == generation) continue;
        seen[st.pos.i][st.pos.j][d] = generation;

        // check if we reached the boundary
        const c = grid.at(st.pos.i, st.pos.j);
        if (iter > 0 and c == ' ') {
            score -= 1; // the boundary field does not count
            continue;
        }

        switch (c) {
            ' ' => statesPush(step(st.pos, st.dir)),
            '\\' => {
                const new_dir: aoc.Dir = switch (st.dir) {
                    .north => .west,
                    .west => .north,
                    .south => .east,
                    .east => .south,
                };
                statesPush(step(st.pos, new_dir));
            },
            '/' => {
                const new_dir: aoc.Dir = switch (st.dir) {
                    .north => .east,
                    .east => .north,
                    .south => .west,
                    .west => .south,
                };
                statesPush(step(st.pos, new_dir));
            },
            '-' => switch (st.dir) {
                .east, .west => statesPush(step(st.pos, st.dir)),
                else => inline for (.{ .east, .west }) |new_dir| {
                    statesPush(step(st.pos, new_dir));
                },
            },
            '|' => switch (st.dir) {
                .north, .south => statesPush(step(st.pos, st.dir)),
                else => inline for (.{ .north, .south }) |new_dir| {
                    statesPush(step(st.pos, new_dir));
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

    const score1 = countEnergized(&grid, .{ .pos = .{ .i = 1, .j = 0 }, .dir = .east });

    var score2: u64 = 0;
    for (1..grid.n - 1) |i| {
        generation += 1;
        score2 = @max(score2, countEnergized(&grid, .{ .pos = .{ .i = i, .j = 0 }, .dir = .east }));
        generation += 1;
        score2 = @max(score2, countEnergized(&grid, .{ .pos = .{ .i = i, .j = grid.m - 1 }, .dir = .west }));
    }

    if (generation > 200) generation = 0;
    for (1..grid.m - 1) |j| {
        generation += 1;
        score2 = @max(score2, countEnergized(&grid, .{ .pos = .{ .i = 0, .j = j }, .dir = .south }));
        generation += 1;
        score2 = @max(score2, countEnergized(&grid, .{ .pos = .{ .i = grid.n - 1, .j = j }, .dir = .north }));
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
