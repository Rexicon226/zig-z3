const z3 = @import("z3");
const std = @import("std");
const testing = std.testing;

test "context" {
    var ctx = z3.Context.init(.{
        .proof = true,
        .encoding = .ascii,
        .timeout = 10,
    });
    defer ctx.deinit();
}

test "solve for model" {
    var solver: z3.Model = .initSolver();
    defer solver.deinit();

    const x = solver.constant(.int, "x", .{});
    const y = solver.constant(.int, "y", .{});

    const zero = solver.fromInt64(0);
    const two = solver.fromInt64(2);
    const seven = solver.fromInt64(7);

    solver.assert(x.gt(y));
    solver.assert(y.gt(zero));
    solver.assert(y.rem(seven).eq(two));

    const x_plus_two = x.add(&.{two});
    solver.assert(x_plus_two.gt(seven));
    try testing.expectEqual(.sat, solver.check());

    const model = solver.getLastModel();
    defer model.deinit();
    const xv = model.eval(x, true).?.asInt64().?;
    const yv = model.eval(y, true).?.asInt64().?;

    try testing.expect(xv > yv);
    try testing.expectEqual(2, @mod(yv, 7));
    try testing.expect(xv + 2 > 7);
}

test "bitvectors" {
    var solver: z3.Model = .initSolver();
    defer solver.deinit();

    const a = solver.constant(.bv, "a", .{64});
    const b = solver.constant(.bv, "b", .{64});
    const two = solver.bvFromInt64(2, 64);

    solver.assert(a.bvsgt(b));
    solver.assert(b.bvsgt(two));
    const b_plus_two = b.bvadd(two);
    solver.assert(b_plus_two.bvsgt(a));
    try testing.expectEqual(.sat, solver.check());

    const model = solver.getLastModel();
    defer model.deinit();
    const av = model.eval(a, true).?.asInt64().?;
    const bv = model.eval(b, true).?.asInt64().?;
    try testing.expect(av > bv);
    try testing.expect(bv > 2);
    try testing.expect(bv + 2 > av);
}

test "optimize unknown" {
    var optimize: z3.Model = .initConfig(
        .optimize,
        .{ .timeout = 1 }, // 1 ms timeout
    );
    defer optimize.deinit();

    // An open problem: find a model for x^3 + y^3 + z^3 == 42
    // See: https://en.wikipedia.org/wiki/Sums_of_three_cubes
    const x = optimize.constant(.int, "x", .{});
    const y = optimize.constant(.int, "y", .{});
    const z = optimize.constant(.int, "z", .{});
    const x_cube = x.mul(&.{ x, x });
    const y_cube = y.mul(&.{ y, y });
    const z_cube = z.mul(&.{ z, z });
    const sum_of_cubes = x_cube.add(&.{ y_cube, z_cube });
    const sum_of_cubes_is_42 = sum_of_cubes.eq(optimize.fromInt64(42));

    optimize.assert(sum_of_cubes_is_42);

    try testing.expectEqual(.unknown, optimize.check());
    try testing.expect(optimize.getReasonUnknown() != null);
}

test "dynamic as set" {
    var optimize: z3.Model = .initConfig(.optimize, .{});
    defer optimize.deinit();
    const set_sort = optimize.set(optimize.int());
    const array_sort = optimize.array(optimize.int(), optimize.int());
    const array_of_sets = optimize.constant(.array, "array_of_sets", .{ optimize.int().inner, set_sort.inner });
    try testing.expect(array_of_sets
        .select(optimize.fromInt64(0))
        .asSet() != null);

    const array_of_arrays = optimize.constant(.array, "array_of_arrays", .{ optimize.int().inner, array_sort.inner });
    try testing.expectEqual(null, array_of_arrays
        .select(optimize.fromInt64(0))
        .asSet());
}

test "ite" {
    var solver: z3.Model = .initSolver();
    defer solver.deinit();

    const ite = solver.false().ite(solver.fromInt(0), solver.fromInt(1));
    try testing.expectEqualStrings("(ite false 0 1)", ite.toString().?);
}

test "array example 1" {
    var solver: z3.Model = .initSolver();
    defer solver.deinit();
    const int_sort = solver.int().inner;
    const a1 = solver.constant(.array, "a1", .{ int_sort, int_sort });
    const a2 = solver.constant(.array, "a2", .{ int_sort, int_sort });
    const idx1 = solver.constant(.int, "idx1", .{});
    const idx2 = solver.constant(.int, "idx2", .{});
    const idx3 = solver.constant(.int, "idx3", .{});
    const v1 = solver.constant(.int, "v1", .{});
    const v2 = solver.constant(.int, "v2", .{});
    const st1 = a1.store(idx1, v1);
    const st2 = a2.store(idx2, v2);
    const sel1 = a1.select(idx3);
    const sel2 = a2.select(idx3);
    const antecedent = st1.eq(st2);
    // idx1 = idx3 or  idx2 = idx3 or select(a1, idx3) = select(a2, idx3)
    const consequent = idx1.eq(idx3).@"or"(&.{ idx2.eq(idx3), sel1.eq(sel2) });
    const thm = antecedent.implies(consequent);
    // prove store(a1, idx1, v1) = store(a2, idx2, v2) implies (idx1 = idx3 or idx2 = idx3 or select(a1, idx3) = select(a2, idx3))
    solver.push();
    solver.assert(thm.not());
    try testing.expectEqual(.unsat, solver.check());
    solver.pop(1);
}
