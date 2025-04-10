const std = @import("std");
const z3 = @import("z3");

pub fn main() !void {
    const cfg = z3.Z3_mk_config();
    const ctx = z3.Z3_mk_context(cfg);

    const int_sort = z3.Z3_mk_int_sort(ctx);
    const x = z3.Z3_mk_const(ctx, z3.Z3_mk_string_symbol(ctx, "x"), int_sort);
    const y = z3.Z3_mk_const(ctx, z3.Z3_mk_string_symbol(ctx, "y"), int_sort);

    const constraint = z3.Z3_mk_eq(
        ctx,
        z3.Z3_mk_add(ctx, 2, &[_]z3.Z3_ast{ x, y }),
        z3.Z3_mk_int(ctx, 10, int_sort),
    );

    const solver = z3.Z3_mk_solver(ctx);
    z3.Z3_solver_assert(ctx, solver, constraint);

    const result = z3.Z3_solver_check(ctx, solver);
    std.debug.print("result: {}\n", .{result});
}
