// Advent of code 23 - day 12
const std = @import("std");
const aoc = @import("aoc");

const State = struct {
    idx: u8,
    pos: u8,
};
const States = std.AutoArrayHashMap(State, u64);

fn unfold(comptime N: comptime_int, alloc: std.mem.Allocator, record: []const u8, blocks: []const u8) !struct { []u8, []u8 } {
    const new_records = try std.mem.join(alloc, "?", &(.{record} ** N));
    errdefer alloc.free(new_records);
    const new_blocks = try std.mem.join(alloc, "", &(.{blocks} ** N));
    return .{ new_records, new_blocks };
}

fn addState(states: *States, idx: u8, pos: u8, cnt: u64) !void {
    (try states.getOrPutValue(.{ .idx = idx, .pos = pos }, 0)).value_ptr.* += cnt;
}

pub fn run(lines: *aoc.Lines) ![2]u64 {
    var arena = std.heap.ArenaAllocator.init(aoc.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var cur_states = States.init(a);
    var nxt_states = States.init(a);

    var score1: u64 = 0;
    var score2: u64 = 0;
    while (try lines.next()) |line| {
        const parts = try aoc.splitN(2, line, " ");
        const single_blocks = try aoc.toNumsA(u8, a, parts[1], ",");

        const unfolded = try unfold(5, a, parts[0], single_blocks);
        defer a.free(unfolded[0]);
        defer a.free(unfolded[1]);

        const records = unfolded[0];
        const blocks = unfolded[1];

        cur_states.clearRetainingCapacity();
        try cur_states.put(.{ .idx = 0, .pos = 0 }, 1);

        for (records, 0..) |c, i| {
            nxt_states.clearRetainingCapacity();

            var it = cur_states.iterator();
            while (it.next()) |st_entry| {
                const st = st_entry.key_ptr.*;
                const n = st_entry.value_ptr.*;
                if (st.pos == 0) {
                    // before a block
                    if (st.idx < blocks.len and (c == '#' or c == '?')) {
                        // start block
                        try addState(&nxt_states, st.idx, st.pos + 1, n);
                    }
                    if (c == '.' or c == '?') {
                        // increase gap
                        try addState(&nxt_states, st.idx, st.pos, n);
                    }
                } else if (st.pos == blocks[st.idx]) {
                    // behind block -> we expect a gap
                    if (c == '.' or c == '?') {
                        try addState(&nxt_states, st.idx + 1, 0, n);
                    }
                } else {
                    // within a block -> expect no gap
                    if (c == '#' or c == '?') {
                        try addState(&nxt_states, st.idx, st.pos + 1, n);
                    }
                }
            }

            if (i == parts[0].len) {
                const m: u8 = @intCast(single_blocks.len);
                if (cur_states.get(.{ .idx = m, .pos = 0 })) |n| {
                    score1 += n;
                }
                if (cur_states.get(.{ .idx = m - 1, .pos = blocks[m - 1] })) |n| {
                    score1 += n;
                }
            }

            std.mem.swap(States, &cur_states, &nxt_states);
        }

        const m: u8 = @intCast(blocks.len);
        if (cur_states.get(.{ .idx = m, .pos = 0 })) |n| {
            score2 += n;
        }
        if (cur_states.get(.{ .idx = m - 1, .pos = blocks[m - 1] })) |n| {
            score2 += n;
        }
    }

    return .{ score1, score2 };
}

pub fn main() !void {
    return aoc.run("12", run);
}

test "Day 12 part 1 - example 1" {
    const EXAMPLE1 =
        \\#.#.### 1,1,3
        \\.#...#....###. 1,1,3
        \\.#.###.#.###### 1,3,1,6
        \\####.#...#... 4,1,1
        \\#....######..#####. 1,6,5
        \\.###.##....# 3,2,1
    ;
    const PART1: u64 = 6;

    var lines = try aoc.Lines.initBuffer(EXAMPLE1);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART1, scores[0]);
}

test "Day 12 part 1 - example 2" {
    const EXAMPLE1 =
        \\???.### 1,1,3
        \\.??..??...?##. 1,1,3
        \\?#?#?#?#?#?#?#? 1,3,1,6
        \\????.#...#... 4,1,1
        \\????.######..#####. 1,6,5
        \\?###???????? 3,2,1
    ;
    const PART1: u64 = 21;

    var lines = try aoc.Lines.initBuffer(EXAMPLE1);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART1, scores[0]);
}

test "Day 12 part 2" {
    const EXAMPLE2 =
        \\???.### 1,1,3
        \\.??..??...?##. 1,1,3
        \\?#?#?#?#?#?#?#? 1,3,1,6
        \\????.#...#... 4,1,1
        \\????.######..#####. 1,6,5
        \\?###???????? 3,2,1
    ;
    const PART2: u64 = 525152;

    var lines = try aoc.Lines.initBuffer(EXAMPLE2);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART2, scores[1]);
}
