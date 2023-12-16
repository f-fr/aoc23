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

fn countEnergized(grid: *const aoc.Grid, start: State, states: *States) !u64 {
    var seen: [NumRows][NumCols][4]bool = .{.{.{false} ** 4} ** NumCols} ** NumRows;

    states.clearRetainingCapacity();
    try states.append(start);

    while (states.popOrNull()) |st| {
        const d: usize = @intFromEnum(st.dir);
        const c = grid.at(st.pos.i, st.pos.j);
        if (c == ' ' or seen[st.pos.i][st.pos.j][d]) continue;
        seen[st.pos.i][st.pos.j][d] = true;

        switch (c) {
            '.' => try states.append(.{ .pos = st.pos.step(st.dir), .dir = st.dir }),
            '\\' => {
                const new_dir: aoc.Dir = switch (st.dir) {
                    .north => .west,
                    .west => .north,
                    .south => .east,
                    .east => .south,
                };
                try states.append(.{ .pos = st.pos.step(new_dir), .dir = new_dir });
            },
            '/' => {
                const new_dir: aoc.Dir = switch (st.dir) {
                    .north => .east,
                    .east => .north,
                    .south => .west,
                    .west => .south,
                };
                try states.append(.{ .pos = st.pos.step(new_dir), .dir = new_dir });
            },
            '-' => switch (st.dir) {
                .east, .west => try states.append(.{ .pos = st.pos.step(st.dir), .dir = st.dir }),
                else => inline for (.{ .east, .west }) |new_dir| {
                    try states.append(.{ .pos = st.pos.step(new_dir), .dir = new_dir });
                },
            },
            '|' => switch (st.dir) {
                .north, .south => try states.append(.{ .pos = st.pos.step(st.dir), .dir = st.dir }),
                else => inline for (.{ .north, .south }) |new_dir| {
                    try states.append(.{ .pos = st.pos.step(new_dir), .dir = new_dir });
                },
            },
            else => return error.InvalidGrid,
        }
    }

    var score: u64 = 0;
    for (1..grid.n - 1) |i| {
        for (1..grid.m - 1) |j| {
            // var sn = false;
            inline for (0..4) |d| {
                if (seen[i][j][d]) {
                    score += 1;
                    break;
                }
            }
        }
    }

    return score;
}

pub fn run(lines: *aoc.Lines) ![2]u64 {
    var arena = std.heap.ArenaAllocator.init(aoc.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var states = States.init(a);
    const grid = try lines.readGridWithBoundary(a, ' ');

    const score1 = try countEnergized(&grid, .{ .pos = .{ .i = 1, .j = 1 }, .dir = .east }, &states);

    var score2: u64 = 0;
    for (1..grid.n - 1) |i| {
        score2 = @max(score2, try countEnergized(&grid, .{ .pos = .{ .i = i, .j = 1 }, .dir = .east }, &states));
        score2 = @max(score2, try countEnergized(&grid, .{ .pos = .{ .i = i, .j = grid.n - 2 }, .dir = .west }, &states));
    }

    for (1..grid.m - 1) |j| {
        score2 = @max(score2, try countEnergized(&grid, .{ .pos = .{ .i = 1, .j = j }, .dir = .south }, &states));
        score2 = @max(score2, try countEnergized(&grid, .{ .pos = .{ .i = 1, .j = grid.m - 2 }, .dir = .north }, &states));
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
