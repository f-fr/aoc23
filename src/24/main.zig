// Advent of code 23 - day 24
const std = @import("std");
const aoc = @import("aoc");

const Hail = struct {
    p: @Vector(3, i128),
    d: @Vector(3, i128),
};

pub fn run(lines: *aoc.Lines) ![2]u64 {
    return runWithBounds(lines, 200000000000000, 400000000000000);
}

fn runWithBounds(lines: *aoc.Lines, min: i64, max: i64) ![2]u64 {
    var arena = std.heap.ArenaAllocator.init(aoc.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var hails = try std.ArrayList(Hail).initCapacity(a, 1000);

    while (try lines.next()) |line| {
        const parts = try aoc.toNumsAny(i128, 6, line, ",@ ");
        try hails.append(.{ .p = parts[0..3].*, .d = parts[3..].* });
    }

    var score1: usize = 0;
    for (0..hails.items.len) |i| {
        const p1 = hails.items[i].p;
        const d1 = hails.items[i].d;
        for (i + 1..hails.items.len) |j| {
            const p2 = hails.items[j].p;
            const d2 = -hails.items[j].d;

            const c = p2 - p1;
            const denom = d1[1] * d2[0] - d1[0] * d2[1];
            const numx = d2[1] * c[0] - d2[0] * c[1];
            const numy = d1[1] * c[0] - d1[0] * c[1];
            if (denom == 0) {
                // aoc.println("p1:{any} d1:{any}\np2:{any} d2:{any}", .{ p1, d1, p2, d2 });
                if (findPointOnRay(.{ p1[0], p1[1] }, .{ d1[0], d1[1] }, .{ p2[0], p2[1] })) |t| {
                    if (t[0] * t[1] >= 0) score1 += 1;
                }
                if (findPointOnRay(.{ p2[0], p2[1] }, .{ d2[0], d2[1] }, .{ p1[0], p1[1] })) |t| {
                    if (t[0] * t[1] >= 0) score1 += 1;
                }
                continue;
            }

            const t1 = -numx; // / denom;
            const t2 = numy; // / denom;

            const x = p1[0] * denom + t1 * d1[0]; // actually denom * intersection
            const y = p1[1] * denom + t1 * d1[1]; // actually denom * intersection
            const z = p1[2] * denom + t1 * d1[2]; // actually denom * intersection

            const x2 = p2[0] * denom - t2 * d2[0]; // actually denom * intersection
            const y2 = p2[1] * denom - t2 * d2[1]; // actually denom * intersection
            const z2 = p2[2] * denom - t2 * d2[2]; // actually denom * intersection

            if (x != x2) unreachable;
            if (y != y2) unreachable;

            if (z == z2) unreachable;

            const mind = if (denom > 0) min * denom else max * denom;
            const maxd = if (denom > 0) max * denom else min * denom;

            if (t1 * denom >= 0 and t2 * denom >= 0 and mind <= x2 and x2 <= maxd and mind <= y2 and y2 <= maxd) score1 += 1;
        }
    }

    var score2: u64 = 0;
    {
        var crts = std.ArrayList(aoc.Crt(i1024)).init(a);
        for (0..3) |j| {
            var d: i64 = -300;
            while (d < 300) : (d += 1) {
                crts.clearRetainingCapacity();
                for (0..hails.items.len) |i| {
                    const m = @abs(hails.items[i].d[j] - d);
                    var xi = hails.items[i].p[j];
                    while (xi < 0) : (xi += @intCast(m)) {}

                    if (m > 1) try crts.append(.{ .a = @intCast(xi), .m = @intCast(m) });
                }

                if (aoc.crt(i1024, crts.items)) |x| {
                    //aoc.println("BLA {any}", .{crts.items});
                    //aoc.println("hmm x:{} d:{}", .{ x, d });
                    score2 += @intCast(x);
                }
            }
        }
    }

    return .{ score1, score2 };
}

fn findPointOnRay(p: @Vector(2, i128), d: @Vector(2, i128), q: @Vector(2, i128)) ?[2]i128 {
    if (d[0] != 0) {
        const tnum = q[0] - p[0];
        const tden = d[0];
        const t: f64 = @as(f64, @floatFromInt(tnum)) / @as(f64, @floatFromInt(tden));
        _ = t;
        // aoc.println("1: {d}", .{t});
        // aoc.println("x:{d} y:{d}", .{ @as(f64, @floatFromInt(p[0])) + t * @as(f64, @floatFromInt(d[0])), @as(f64, @floatFromInt(p[1])) + t * @as(f64, @floatFromInt(d[1])) });
        if (tden * p[1] + tnum * d[1] == tden * q[1]) return .{ tnum, tden };
    } else if (d[1] != 0) {
        const tnum = q[1] - p[1];
        const tden = d[1];
        const t: f64 = @as(f64, @floatFromInt(tnum)) / @as(f64, @floatFromInt(tden));
        _ = t;
        // aoc.println("2: {d}", .{t});
        if (tden * p[0] + tnum * d[0] == tden * q[0]) return .{ tnum, tden };
    }
    return null;
}

pub fn main() !void {
    return aoc.run("24", run);
}

// test "Day 24 part 1" {
//     const EXAMPLE1 =
//         \\19, 13, 30 @ -2,  1, -2
//         \\18, 19, 22 @ -1, -1, -2
//         \\20, 25, 34 @ -2, -2, -4
//         \\12, 31, 28 @ -1, -2, -1
//         \\20, 19, 15 @  1, -5, -3
//     ;
//     const PART1: u64 = 2;

//     var lines = try aoc.Lines.initBuffer(EXAMPLE1);
//     defer lines.deinit();
//     const scores = try runWithBounds(&lines, 7, 27);

//     try std.testing.expectEqual(PART1, scores[0]);
// }

test "Day 24 part 2" {
    const EXAMPLE2 =
        \\19, 13, 30 @ -2,  1, -2
        \\18, 19, 22 @ -1, -1, -2
        \\20, 25, 34 @ -2, -2, -4
        \\12, 31, 28 @ -1, -2, -1
        \\20, 19, 15 @  1, -5, -3
    ;
    const PART2: u64 = 42;

    var lines = try aoc.Lines.initBuffer(EXAMPLE2);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART2, scores[1]);
}
