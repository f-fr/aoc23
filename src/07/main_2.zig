// Advent of code 23 - day 07
const std = @import("std");
const aoc = @import("aoc");

const Card = u4;
const Hand = [6]Card;
const Bid = struct {
    hand: u32,
    handj: u32,
    bid: u32,

    fn lessThan(_: void, a: Bid, b: Bid) bool {
        return a.hand < b.hand;
    }

    fn lessThanJ(_: void, a: Bid, b: Bid) bool {
        return a.handj < b.handj;
    }
};

fn handKind(cards: *[5]Card) struct { kind: Card, mostcommon: Card } {
    var counts = [_]u3{0} ** 15;
    var npairs: usize = 0;
    var max: u3 = 0;
    var mostcommon: Card = 0;
    for (cards) |c| {
        counts[c] += 1;
        if (c != 11 and counts[c] > max) {
            max = counts[c];
            mostcommon = c;
        }
        if (counts[c] == 2) npairs += 1;
    }

    // don't forget the J=11
    max = @max(max, counts[11]);

    const kind: Card = switch (max) {
        5 => 7, // 5 of a kind
        4 => 6, // 4 of a kind
        3 => 4 + @as(Card, @intFromBool(npairs == 2)), // full house or three of a kind
        2 => 2 + @as(Card, @intFromBool(npairs == 2)), // one or two pairs
        else => 1, // high card
    };

    return .{ .kind = kind, .mostcommon = mostcommon };
}

fn pack(hand: Hand) u32 {
    var v: u32 = 0;
    inline for (hand) |h| v = (v << 4) | h;
    return v;
}

fn readHand(s: []const u8) ![2]u32 {
    var hand: Hand = undefined;
    for (s, 1..) |c, i| {
        hand[i] = switch (c) {
            'T' => 10,
            'J' => 11,
            'Q' => 12,
            'K' => 13,
            'A' => 14,
            '2'...'9' => @as(Card, @intCast(c - '2')) + 2,
            else => return error.InvalidCard,
        };
    }

    const handkind = handKind(hand[1..]);
    hand[0] = handkind.kind;

    // it only makes sense to replace all J by the most common card
    var handj = hand;
    std.mem.replaceScalar(Card, handj[1..], 11, handkind.mostcommon);
    handj[0] = handKind(handj[1..]).kind;

    // replace J by 1 (lowest possible card)
    for (hand[1..], handj[1..]) |c, *cj| {
        if (c == 11) cj.* = 1;
    }

    return .{ pack(hand), pack(handj) };
}

pub fn run(lines: *aoc.Lines) ![2]u64 {
    var arena = std.heap.ArenaAllocator.init(aoc.allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var bids = try std.ArrayList(Bid).initCapacity(a, 1000);

    while (try lines.next()) |line| {
        const parts = try aoc.splitN(2, line, " ");
        const hands = try readHand(parts[0]);
        const bid = try aoc.toNum(u32, parts[1]);
        try bids.append(.{ .hand = hands[0], .handj = hands[1], .bid = bid });
    }

    std.mem.sortUnstable(Bid, bids.items, {}, Bid.lessThan);
    var score1: u64 = 0;
    for (bids.items, 1..) |b, rank| score1 += b.bid * rank;

    std.mem.sortUnstable(Bid, bids.items, {}, Bid.lessThanJ);
    var score2: u64 = 0;
    for (bids.items, 1..) |b, rank| score2 += b.bid * rank;

    return .{ score1, score2 };
}

pub fn main() !void {
    return aoc.run("07", run);
}

test "Day 07 part 1" {
    const EXAMPLE1 =
        \\32T3K 765
        \\T55J5 684
        \\KK677 28
        \\KTJJT 220
        \\QQQJA 483
    ;
    const PART1: u64 = 6440;

    var lines = try aoc.Lines.initBuffer(EXAMPLE1);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART1, scores[0]);
}

test "Day 07 part 2" {
    const EXAMPLE2 =
        \\32T3K 765
        \\T55J5 684
        \\KK677 28
        \\KTJJT 220
        \\QQQJA 483
    ;
    const PART2: u64 = 5905;

    var lines = try aoc.Lines.initBuffer(EXAMPLE2);
    defer lines.deinit();
    const scores = try run(&lines);

    try std.testing.expectEqual(PART2, scores[1]);
}
