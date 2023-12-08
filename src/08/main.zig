// Advent of code 23 - day 08
const std = @import("std");
const aoc = @import("aoc");

const NodesMap = std.StringHashMap(u32);

fn addNode(a: std.mem.Allocator, nodes: *NodesMap, node: []const u8) !u32 {
    const r = try nodes.getOrPutAdapted(node, nodes.ctx);
    if (!r.found_existing) {
        r.key_ptr.* = try a.dupe(u8, node);
        r.value_ptr.* = nodes.count() - 1;
    }
    return r.value_ptr.*;
}

fn lcm(a: u64, b: u64) u64 {
    return a * (b / std.math.gcd(a, b));
}

pub fn run(lines: *aoc.Lines) ![2]u64 {
    var arena = std.heap.ArenaAllocator.init(aoc.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const dirs = try a.dupe(u8, try lines.next() orelse return error.UnexpectedEOF);

    _ = try lines.next(); // empty line

    var nodes = NodesMap.init(a);
    try nodes.ensureTotalCapacity(1000);
    var nexts = try std.ArrayList(struct { left: u32, right: u32 }).initCapacity(a, 1000);

    while (try lines.next()) |line| {
        const parts = try aoc.splitAnyN(4, try a.dupe(u8, line), " (),=");
        const s = try addNode(a, &nodes, parts[0]);
        const l = try addNode(a, &nodes, parts[1]);
        const r = try addNode(a, &nodes, parts[2]);
        try nexts.resize(@max(s + 1, nexts.items.len));
        nexts.items[s] = .{ .left = l, .right = r };
    }

    var scores = [2]u64{ 0, 0 };
    var us = try std.ArrayList(u32).initCapacity(a, nodes.count());

    const ends = try a.alloc(bool, nodes.count());
    const lens = try a.alloc(u32, nodes.count());
    for (0..2) |part| {
        us.clearRetainingCapacity();
        @memset(ends, false);
        if (part == 0) {
            const aaa = nodes.get("AAA") orelse continue; // skip part 1
            const zzz = nodes.get("ZZZ") orelse continue; // skip part 1
            try us.append(aaa);
            ends[zzz] = true;
        } else {
            var it = nodes.iterator();
            while (it.next()) |entry| {
                if (std.mem.endsWith(u8, entry.key_ptr.*, "A"))
                    try us.append(entry.value_ptr.*)
                else if (std.mem.endsWith(u8, entry.key_ptr.*, "Z"))
                    ends[entry.value_ptr.*] = true;
            }
        }

        @memset(lens, 0);
        for (us.items) |start| {
            var cnt: u32 = 0;
            var i: usize = 0;
            var u = start;
            while (!ends[u]) {
                u = if (dirs[i] == 'L') nexts.items[u].left else nexts.items[u].right;
                i = (i + 1) % dirs.len;
                cnt += 1;
            }
            lens[start] = cnt;
        }

        // Compute lcm of all lengths.
        // This is actually not correct (a general solution requires
        // the CRT and a bit more math)
        scores[part] = 1;
        for (lens) |l| {
            if (l != 0) scores[part] = lcm(scores[part], l);
        }
    }

    return scores;
}

pub fn main() !void {
    return aoc.run("08", run);
}

test "Day 08 part 1 example 1" {
    const EXAMPLE1 =
        \\RL
        \\
        \\AAA = (BBB, CCC)
        \\BBB = (DDD, EEE)
        \\CCC = (ZZZ, GGG)
        \\DDD = (DDD, DDD)
        \\EEE = (EEE, EEE)
        \\GGG = (GGG, GGG)
        \\ZZZ = (ZZZ, ZZZ)
    ;
    const PART1: u64 = 2;

    var lines = try aoc.Lines.initBuffer(EXAMPLE1);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART1, scores[0]);
}

test "Day 08 part 1 example 2" {
    const EXAMPLE1 =
        \\LLR
        \\
        \\AAA = (BBB, BBB)
        \\BBB = (AAA, ZZZ)
        \\ZZZ = (ZZZ, ZZZ)
    ;
    const PART1: u64 = 6;

    var lines = try aoc.Lines.initBuffer(EXAMPLE1);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART1, scores[0]);
}

test "Day 08 part 2" {
    const EXAMPLE2 =
        \\LR
        \\
        \\11A = (11B, XXX)
        \\11B = (XXX, 11Z)
        \\11Z = (11B, XXX)
        \\22A = (22B, XXX)
        \\22B = (22C, 22C)
        \\22C = (22Z, 22Z)
        \\22Z = (22B, 22B)
        \\XXX = (XXX, XXX)
    ;
    const PART2: u64 = 6;

    var lines = try aoc.Lines.initBuffer(EXAMPLE2);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART2, scores[1]);
}
