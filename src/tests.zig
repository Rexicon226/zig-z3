const z3 = @import("z3");
const std = @import("std");
const testing = std.testing;
const gpa = testing.allocator;

test "context" {
    var ctx = try z3.Context.init(gpa, &.{.{ "proof", "true" }});
    defer ctx.deinit(gpa);
}

test "solve for model" {
    var solver: z3.Solver = try .init(gpa);
    defer solver.deinit(gpa);

    const x = solver.constant(.int, "x", .{});
    const y = solver.constant(.int, "y", .{});

    const zero = solver.int64(0);
    const two = solver.int64(2);
    const seven = solver.int64(7);

    solver.assert(x.gt(y));
    solver.assert(y.gt(zero));
    solver.assert(y.rem(seven).eq(two));

    const x_plus_two = x.add(&.{two});
    solver.assert(x_plus_two.gt(seven));
    try testing.expectEqual(.sat, solver.check());

    const model = solver.getLastModel();
    defer model.deinit();
    const xv = model.eval(x, true).?.int64().?;
    const yv = model.eval(y, true).?.int64().?;

    try testing.expect(xv > yv);
    try testing.expectEqual(2, @mod(yv, 7));
    try testing.expect(xv + 2 > 7);
}

test "bitvectors" {
    var solver: z3.Solver = try .init(gpa);
    defer solver.deinit(gpa);

    const a = solver.constant(.bv, "a", .{64});
    const b = solver.constant(.bv, "b", .{64});
    const two = solver.bvFromInt64(2, 64); // ast::BV::from_i64(2, 64);

    solver.assert(a.bvsgt(b));
    solver.assert(b.bvsgt(two));
    const b_plus_two = b.bvadd(two);
    solver.assert(b_plus_two.bvsgt(a));
    try testing.expectEqual(.sat, solver.check());

    const model = solver.getLastModel();
    defer model.deinit();
    const av = model.eval(a, true).?.int64().?;
    const bv = model.eval(b, true).?.int64().?;
    try testing.expect(av > bv);
    try testing.expect(bv > 2);
    try testing.expect(bv + 2 > av);
}
