// Advent of code 23 - day 21
const std = @import("std");
const aoc = @import("aoc");

const DetectionSize = 3;

pub fn run(lines: *aoc.Lines) ![2]u64 {
    return runWithCounts(lines, 64, 26501365);
}

fn runWithCounts(lines: *aoc.Lines, niter1: usize, niter2: usize) ![2]u64 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var alloc = gpa.allocator();
    const grid = try lines.readGrid(alloc);
    defer alloc.free(grid.data);
    const start = grid.findFirst('S') orelse return error.NoStartingPosition;

    const score1 = try runPart1(alloc, &grid, start, niter1);
    const score2 = try runPart2(alloc, &grid, start, niter2);
    return .{ score1, score2 };
}

fn runPart1(alloc: std.mem.Allocator, grid: *const aoc.Grid, start: aoc.Pos, niter: usize) !usize {
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const a = arena.allocator();

    const Queue = std.ArrayList(aoc.Pos);
    var queue1 = try Queue.initCapacity(a, grid.n * grid.m);
    var queue2 = try Queue.initCapacity(a, grid.n * grid.m);
    var cur = &queue1;
    var nxt = &queue2;
    var seen = try aoc.GridT(u32).initWith(a, grid.n, grid.m, std.math.maxInt(u32));

    cur.appendAssumeCapacity(start);

    for (0..niter) |iter| {
        nxt.clearRetainingCapacity();
        for (cur.items) |p| {
            for (aoc.Dirs) |dir| {
                const q = p.maybeStep(dir, grid.n, grid.m) orelse continue;
                if (grid.atPos(q) != '#' and seen.atPos(q) != iter) {
                    seen.setPos(q, @intCast(iter));
                    nxt.appendAssumeCapacity(q);
                }
            }
        }
        std.mem.swap(*Queue, &cur, &nxt);
    }

    return cur.items.len;
}

fn runPart2(alloc: std.mem.Allocator, grid: *const aoc.Grid, start: aoc.Pos, niter: usize) !u64 {
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
    const a = arena.allocator();

    const Pos = aoc.PosT(i16);
    const Queue = std.ArrayList(Pos);
    var queue1 = try Queue.initCapacity(a, grid.n * grid.m * 4);
    var queue2 = try Queue.initCapacity(a, grid.n * grid.m * 4);
    var cur = &queue1;
    var nxt = &queue2;

    // const Seen = std.AutoHashMap(Pos, void);
    // var seen1 = Seen.init(a);
    // var seen2 = Seen.init(a);
    const N = 2000;
    var seen = try alloc.alloc(bool, N * N);
    var seencnt: u64 = 0;
    var nxtseencnt: u64 = 0;

    @memset(seen, false);
    cur.appendAssumeCapacity(.{ .i = @intCast(start.i), .j = @intCast(start.j) });

    var prv_cnt: i64 = 0;
    var prv2_cnt: i64 = 0;
    var prv_score: u64 = 0;
    var score2: u64 = 0;

    var iter: usize = 1;
    const n: i32 = @intCast(grid.n);
    const m: i32 = @intCast(grid.m);
    while (iter <= @max(niter, 100)) : (iter += 1) {
        nxt.clearRetainingCapacity();
        for (cur.items) |p| {
            for (aoc.Dirs) |dir| {
                const q = p.step(dir);
                if (grid.at(@intCast(@mod(q.i, n)), @intCast(@mod(q.j, m))) == '#') continue;
                const qi: i64 = @intCast(q.i);
                const qj: i64 = @intCast(q.j);
                const idx = (qi + N / 2 + (qj + N / 2) * N);
                if (!seen[@intCast(idx)]) {
                    seen[@intCast(idx)] = true;
                    seencnt += 1;
                    nxt.appendAssumeCapacity(q);
                }
            }
        }
        std.mem.swap(*Queue, &cur, &nxt);
        if (iter > 2 * grid.n and iter % grid.n == niter % grid.n) {
            const cnt = seencnt;
            // evaluate the interpolation polynomial at x = niter
            //
            // y1 * (x - x1)(x - x2)(x - x3)/(x2 - x1)/(x3 - x1) ...
            const x1: f64 = @floatFromInt(iter - 2 * grid.n);
            const x2: f64 = @floatFromInt(iter - 1 * grid.n);
            const x3: f64 = @floatFromInt(iter);
            const y1: f64 = @floatFromInt(prv2_cnt);
            const y2: f64 = @floatFromInt(prv_cnt);
            const y3: f64 = @floatFromInt(cnt);
            const x: f64 = @floatFromInt(niter);

            const value = ( //
                (y1 * (x - x2) * (x - x3) / (x1 - x2) / (x1 - x3)) +
                (y2 * (x - x1) * (x - x3) / (x2 - x1) / (x2 - x3)) +
                (y3 * (x - x1) * (x - x2) / (x3 - x1) / (x3 - x2)));
            if (value > 0 and prv_score == @as(u64, @intFromFloat(value))) {
                // hopefully this has stabilized now
                score2 = @intFromFloat(value);
                break;
            }

            prv2_cnt = prv_cnt;
            prv_cnt = @intCast(cnt);
            if (value > 0) prv_score = @intFromFloat(value);
        }
        std.mem.swap(u64, &seencnt, &nxtseencnt);
    }

    return score2;
}

pub fn main() !void {
    return aoc.run("21", run);
}

test "Day 21 part 1" {
    const EXAMPLE1 =
        \\...........
        \\.....###.#.
        \\.###.##..#.
        \\..#.#...#..
        \\....#.#....
        \\.##..S####.
        \\.##..#...#.
        \\.......##..
        \\.##.#.####.
        \\.##..##.##.
        \\...........
    ;
    const PART1: u64 = 16;

    var lines = try aoc.Lines.initBuffer(EXAMPLE1);
    defer lines.deinit();
    const scores = try runWithCounts(&lines, 6, 6);

    try std.testing.expectEqual(PART1, scores[0]);
}

test "Day 21 part 2" {
    const EXAMPLE2 =
        \\...........
        \\.....###.#.
        \\.###.##..#.
        \\..#.#...#..
        \\....#.#....
        \\.##..S####.
        \\.##..#...#.
        \\.......##..
        \\.##.#.####.
        \\.##..##.##.
        \\...........
    ;

    inline for (.{ .{ 50, 1594 }, .{ 100, 6536 }, .{ 500, 167004 }, .{ 1000, 668697 }, .{ 5000, 16733044 } }) |t| {
        var lines = try aoc.Lines.initBuffer(EXAMPLE2);
        defer lines.deinit();
        const scores = try runWithCounts(&lines, 0, t[0]);
        try std.testing.expectEqual(@as(u64, t[1]), scores[1]);
    }
}
