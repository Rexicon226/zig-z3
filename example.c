#include <stdio.h>
#include <z3.h>

int main() {
    Z3_config cfg = Z3_mk_config();
    Z3_context ctx = Z3_mk_context(cfg);

    Z3_sort int_sort = Z3_mk_int_sort(ctx);
    Z3_ast x = Z3_mk_const(ctx, Z3_mk_string_symbol(ctx, "x"), int_sort);
    Z3_ast y = Z3_mk_const(ctx, Z3_mk_string_symbol(ctx, "y"), int_sort);

    Z3_ast constraint = Z3_mk_eq(ctx, Z3_mk_add(ctx, 2, (Z3_ast[]){x, y}), Z3_mk_int(ctx, 10, int_sort));

    Z3_solver solver = Z3_mk_solver(ctx);
    Z3_solver_assert(ctx, solver, constraint);

    Z3_lbool result = Z3_solver_check(ctx, solver);
    if (result == Z3_L_TRUE) {
        printf("Satisfiable\n");
    } else {
        printf("Unsatisfiable\n");
    }

    return 0;
}
