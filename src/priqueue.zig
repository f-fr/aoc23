const std = @import("std");

fn PriQueue(comptime V: type) type {
    return struct {
        const Self = @This();

        pub const Item = struct { i: usize };

        allocator: std.mem.Allocator,
        heap: []usize = &.{},
        values: []V = &.{},
        positions: []usize = &.{},

        len: usize = 0,
        firstfree: ?usize = null,

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{ .allocator = allocator };
        }

        pub fn initCapacity(allocator: std.mem.Allocator, capacity: usize) std.mem.Allocator.Error!Self {
            const heap = try allocator.alloc(usize, capacity);
            const values = try allocator.alloc(V, capacity);
            const positions = try allocator.alloc(usize, capacity);

            return .{
                .allocator = allocator,
                .heap = heap,
                .values = values,
                .positions = positions,
            };
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.heap);
            self.allocator.free(self.values);
            self.allocator.free(self.positions);
        }

        pub fn isEmpty(self: *const Self) bool {
            return self.len == 0;
        }

        pub fn count(self: *const Self) usize {
            return self.len;
        }

        pub fn push(self: *Self, value: V) !Item {
            var idx: usize = undefined;
            if (self.firstfree) |free| {
                idx = free;
                self.firstfree = self.positions[idx];
                if (self.firstfree == free) self.firstfree = null;
                self.values[idx] = value;
                self.positions[idx] = self.len;
            } else {
                idx = self.len;
                if (self.heap.len >= self.len) {
                    const newcap = @max(self.heap.len * 2, 16);
                    self.heap = try self.allocator.realloc(self.heap, newcap);
                    self.values = try self.allocator.realloc(self.values, newcap);
                    self.positions = try self.allocator.realloc(self.positions, newcap);
                }
                self.values[idx] = value;
                self.positions[idx] = self.len;
            }

            self.heap[self.len] = idx;
            self.len += 1;
            self.upheap(idx);
            return .{ .i = idx };
        }

        pub fn decrease(self: *Self, item: Item, value: V) bool {
            if (self.values[item.i] <= value) return false;
            self.values[item.i] = value;
            self.upheap(item.i);
            return true;
        }

        fn upheap(self: *Self, idx: usize) void {
            var i = self.positions[idx];
            while (i > 0) {
                const j = (i - 1) / 2;
                if (self.values[self.heap[j]] <= self.values[idx]) break;
                self.heap[i] = self.heap[j];
                self.positions[self.heap[j]] = i;
                i = j;
            }
            self.heap[i] = idx;
            self.positions[idx] = i;
        }

        pub fn popOrNull(self: *Self) ?struct { item: Item, value: V } {
            if (self.heap.len == 0) return null;

            const idx = self.heap[0];
            self.positions[idx] = self.firstfree orelse idx;
            self.firstfree = idx;

            self.len -= 1;
            const last = self.heap[self.len];

            if (self.len > 0) {
                var i: usize = 0;
                while (true) {
                    var j = 2 * i + 1;
                    const k = j + 1;
                    if (j >= self.len) break;
                    if (k < self.len and self.values[self.heap[k]] < self.values[self.heap[j]]) j = k;
                    if (self.values[self.heap[j]] >= self.values[last]) break;
                    self.heap[i] = self.heap[j];
                    self.positions[self.heap[j]] = i;
                    i = j;
                }
                self.heap[i] = last;
                self.positions[last] = i;
            }

            return .{ .item = .{ .i = idx }, .value = self.values[idx] };
        }
    };
}

const testing = std.testing;

test "empty pqueue" {
    var h = PriQueue(usize).init(testing.allocator);
    try testing.expect(h.isEmpty());
    try testing.expectEqual(@as(usize, 0), h.count());
    try testing.expect(h.popOrNull() == null);
}

test "push and pop" {
    var h = PriQueue(usize).init(testing.allocator);
    defer h.deinit();
    const itm1 = try h.push(42);
    try testing.expect(!h.isEmpty());
    try testing.expectEqual(@as(usize, 1), h.count());
    const res1 = h.popOrNull() orelse unreachable;
    try testing.expectEqual(itm1, res1.item);
    try testing.expectEqual(@as(usize, 42), res1.value);
    try testing.expect(h.isEmpty());
    try testing.expectEqual(@as(usize, 0), h.count());
}

test "heapsort" {
    const ary = [_]u32{ 5, 1, 7, 10, 3, 8, 2, 4, 9, 6 };
    var itms: [10]PriQueue(u32).Item = undefined;
    var h = PriQueue(u32).init(testing.allocator);
    defer h.deinit();

    for (ary) |x| {
        itms[x - 1] = try h.push(x);
    }

    for (1..11) |i| {
        const res = h.popOrNull() orelse unreachable;
        try testing.expectEqual(i, res.value);
        try testing.expectEqual(itms[i - 1], res.item);
    }
}

test "heapsort with decrease" {
    const ary = [_]u32{ 205, 701, 107, 610, 403, 808, 502, 704, 409, 306 };
    var itms: [10]PriQueue(u32).Item = undefined;
    var h = PriQueue(u32).init(testing.allocator);
    defer h.deinit();

    for (ary) |x| {
        itms[x % 100 - 1] = try h.push(x);
    }

    for (1..11) |i| {
        try testing.expect(h.decrease(itms[i - 1], h.values[itms[i - 1].i] % 100));
        const res = h.popOrNull() orelse unreachable;
        try testing.expectEqual(i, res.value);
        try testing.expectEqual(itms[i - 1], res.item);
    }
}

test "heapsort with decrease and free" {
    const ary = [_]u32{ 205, 701, 107, 610, 403, 808, 502, 704, 409, 306 };
    var itms: [10]PriQueue(u32).Item = undefined;
    var h = PriQueue(u32).init(testing.allocator);
    defer h.deinit();

    for (ary) |x| {
        if (x % 100 <= 5) itms[x % 100 - 1] = try h.push(x);
    }

    for (1..6) |i| {
        try testing.expect(h.decrease(itms[i - 1], h.values[itms[i - 1].i] % 100));
        const res = h.popOrNull() orelse unreachable;
        try testing.expectEqual(i, res.value);
        try testing.expectEqual(itms[i - 1], res.item);
    }

    for (ary) |x| {
        if (x % 100 > 5) itms[x % 100 - 1] = try h.push(x);
    }

    for (6..11) |i| {
        try testing.expect(h.decrease(itms[i - 1], h.values[itms[i - 1].i] % 100));
        const res = h.popOrNull() orelse unreachable;
        try testing.expectEqual(i, res.value);
        try testing.expectEqual(itms[i - 1], res.item);
    }
}
