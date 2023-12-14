const testing = @import("std").testing;

pub fn GenArray(comptime T: type, comptime N: usize) type {
    return struct {
        const Self = @This();

        data: [N]T = undefined,
        gens: [N]usize = .{0} ** N,
        generation: usize = 1,
        actives: [N]usize = undefined,
        nactives: usize = 0,

        pub fn clear(self: *Self) void {
            self.nactives = 0;
            self.generation += 1;
        }

        pub fn get(self: *const Self, i: usize) ?T {
            return if (self.gens[i] == self.generation) self.data[i] else null;
        }

        pub fn set(self: *Self, i: usize, v: T) void {
            getPtrOrPut(self, i, v).* = v;
        }

        pub fn getPtrOrPut(self: *Self, i: usize, v: T) *T {
            if (self.gens[i] != self.generation) {
                self.gens[i] = self.generation;
                self.actives[self.nactives] = i;
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
