const testing = @import("std").testing;

pub fn GenArray(comptime T: type, comptime N: usize) type {
    return struct {
        const Self = @This();

        data: [N]T = undefined,
        index: [N]usize = undefined,
        actives: [N]usize = undefined,
        nactives: usize = 0,

        pub fn clear(self: *Self) void {
            self.nactives = 0;
        }

        pub fn get(self: *const Self, i: usize) ?T {
            const j = self.index[i];
            return if (j < self.nactives and self.actives[j] == i) self.data[i] else null;
        }

        pub fn set(self: *Self, i: usize, v: T) void {
            getPtrOrPut(self, i, v).* = v;
        }

        pub fn getPtrOrPut(self: *Self, i: usize, v: T) *T {
            const j = self.index[i];
            const n = self.nactives;
            if (j >= n or self.actives[j] != i) {
                self.index[i] = n;
                self.actives[n] = i;
                self.nactives += 1;
                self.data[i] = v;
            }
            return &self.data[i];
        }

        pub fn items(self: *const Self) []const usize {
            return self.actives[0..self.nactives];
        }
    };
}

test "initially empty" {
    const a = GenArray(i32, 5){};
    try testing.expectEqual(@as(usize, 0), a.items().len);
}

test "set a few elements" {
    var a = GenArray(i32, 5){};
    a.set(2, 3);
    a.set(3, 4);
    a.set(2, 7);
    try testing.expectEqual(@as(?i32, 7), a.get(2));
    try testing.expectEqual(@as(?i32, 4), a.get(3));
    try testing.expectEqual(@as(?i32, null), a.get(0));
    try testing.expectEqual(@as(?i32, null), a.get(1));
    try testing.expectEqual(@as(?i32, 4), a.getPtrOrPut(3, 42).*);
    try testing.expectEqual(@as(?i32, 42), a.getPtrOrPut(1, 42).*);
    a.clear();
    try testing.expectEqual(@as(usize, 0), a.items().len);
    for (0..5) |i| try testing.expectEqual(@as(?i32, null), a.get(i));
}
