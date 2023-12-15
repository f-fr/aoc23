// Advent of code 23 - day 15
const std = @import("std");
const aoc = @import("aoc");

const assert = std.debug.assert;

const MaxLabel: usize = 6;

fn hash(s: []const u8) u8 {
    var h: u8 = 0;
    for (s) |c| {
        if (c == '\n') continue;
        h = (h +% c) *% 17;
    }
    return h;
}

const Lens = struct {
    label: [MaxLabel + 1]u8,
    focal: u8,

    fn setLabel(self: *Lens, name: []const u8) void {
        const n = name.len;
        assert(n <= MaxLabel);
        @memcpy(self.label[0..n], name);
        self.label[n] = 0;
    }

    fn hasLabel(self: *const Lens, name: []const u8) bool {
        const n = name.len;
        return self.label[n] == 0 and std.mem.eql(u8, self.label[0..n], name);
    }
};

pub fn run(lines: *aoc.Lines) ![2]u64 {
    const Box = std.DoublyLinkedList(Lens);
    var all_lenses: [4000]Box.Node = undefined;
    var nxt_lens: usize = 0;
    var boxes: [256]Box = .{Box{}} ** 256;

    lines.delimiter = ',';
    var score1: u64 = 0;
    while (try lines.next()) |tok| {
        score1 += hash(tok);
        const l = std.mem.indexOfAny(u8, tok, "=-") orelse return error.InvalidOperation;
        if (l > MaxLabel) return error.LabelTooLong;
        const i = hash(tok[0..l]);
        if (tok[l] == '-') {
            // remove the lens
            var node = boxes[i].first;
            while (node) |n| : (node = n.next) {
                if (n.*.data.hasLabel(tok[0..l])) {
                    boxes[i].remove(n);
                    break;
                }
            }
        } else {
            if (l + 2 > tok.len or tok[l + 1] < '0' or tok[l + 1] > '9')
                return error.InvalidFocalLength;
            // insert or replace lens
            var node = boxes[i].first;
            while (node) |n| : (node = n.next) {
                if (n.*.data.hasLabel(tok[0..l])) {
                    n.*.data.focal = tok[l + 1] - '0';
                    break;
                }
            } else {
                all_lenses[nxt_lens].data.setLabel(tok[0..l]);
                all_lenses[nxt_lens].data.focal = tok[l + 1] - '0';
                boxes[i].append(&all_lenses[nxt_lens]);
                nxt_lens += 1;
            }
        }
    }

    var score2: u64 = 0;
    for (&boxes, 0..) |*box, i| {
        var j: usize = 1;
        var node = box.*.first;
        while (node) |n| : (node = n.next) {
            score2 += (i + 1) * j * n.data.focal;
            j += 1;
        }
    }

    return .{ score1, score2 };
}

pub fn main() !void {
    return aoc.run("15", run);
}

test "Day 15 hash" {
    try std.testing.expectEqual(@as(u8, 52), hash("HASH"));
    try std.testing.expectEqual(@as(u8, 52), hash("HASH\n"));
}

test "Day 15 part 1" {
    const EXAMPLE1 =
        \\rn=1,cm-,qp=3,cm=2,qp-,pc=4,ot=9,ab=5,pc-,pc=6,ot=7
        \\
    ;
    const PART1: u64 = 1320;

    var lines = try aoc.Lines.initBuffer(EXAMPLE1);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART1, scores[0]);
}

test "Day 15 part 2" {
    const EXAMPLE2 =
        \\rn=1,cm-,qp=3,cm=2,qp-,pc=4,ot=9,ab=5,pc-,pc=6,ot=7
    ;
    const PART2: u64 = 145;

    var lines = try aoc.Lines.initBuffer(EXAMPLE2);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART2, scores[1]);
}
