const std = @import("std");
const z3 = @import("z3");

pub const Sort = enum {
    int,
    bool,
    real,

    fn Data(s: Sort) type {
        return switch (s) {
            .int => Int,
            .bool => Bool,
            .real => Real,
        };
    }
};

pub const Prover = enum {
    // opt,
    solver,
};

pub const Check = enum(i2) {
    /// Unsatisfiable
    false = -1,
    /// Unknown
    undef = 0,
    /// Satisfiable
    true = 1,
};

pub const Int = struct {
    ast: z3.Z3_ast,
};

pub const Real = struct {
    ast: z3.Z3_ast,
};

pub const Bool = struct {
    ast: z3.Z3_ast,
};

/// Represents an arbitrary AST node.
pub const Ast = struct {
    ast: z3.Z3_ast,
};

pub const Model = struct {
    cfg: z3.Z3_config,
    ctx: z3.Z3_context,
    /// Stored initialized types and caches them for use later.
    sorts: std.enums.EnumFieldStruct(
        Sort,
        ?z3.Z3_sort,
        @as(?z3.Z3_sort, null),
    ),
    prover: union(Prover) {
        solver: z3.Z3_solver,
    },

    pub fn init(comptime p: Prover) Model {
        const cfg = z3.Z3_mk_config();
        const ctx = z3.Z3_mk_context(cfg);
        const solver = z3.Z3_mk_solver(ctx);
        z3.Z3_solver_inc_ref(ctx, solver);
        return .{
            .cfg = cfg,
            .ctx = ctx,
            .sorts = .{},
            .prover = switch (p) {
                .solver => .{ .solver = solver },
            },
        };
    }

    pub fn deinit(m: *Model) void {
        switch (m.prover) {
            .solver => |s| z3.Z3_solver_dec_ref(m.ctx, s),
        }
        z3.Z3_del_context(m.ctx);
        z3.Z3_del_config(m.cfg);
    }

    fn getSort(m: *Model, comptime s: Sort) z3.Z3_sort {
        return @field(m.sorts, @tagName(s)) orelse {
            const sort = @field(z3, "Z3_mk_" ++ @tagName(s) ++ "_sort")(m.ctx);
            @field(m.sorts, @tagName(s)) = sort;
            return sort;
        };
    }

    fn gatherAst(args: anytype) [args.len]z3.Z3_ast {
        const len = args.len;
        var ast: [len]z3.Z3_ast = undefined;
        inline for (args, 0..) |arg, i| ast[i] = arg.ast;
        return ast;
    }

    fn assertSameSort(args: type) void {
        const fields = @typeInfo(args).@"struct".fields;
        const first = fields[0].type;
        for (fields) |field| std.debug.assert(first == field.type);
    }

    pub fn constant(m: *Model, comptime s: Sort, name: ?[:0]const u8) s.Data() {
        const sort = m.getSort(s);
        const string = z3.Z3_mk_string_symbol(m.ctx, name orelse "...");
        return .{ .ast = z3.Z3_mk_const(m.ctx, string, sort) };
    }

    pub fn int(m: *Model, value: i32) Int {
        return .{ .ast = z3.Z3_mk_int(m.ctx, value, m.getSort(.int)) };
    }

    /// Creates an addition AST node.
    /// All arguments must be the same sort, being either int or real.
    /// The return type will be that same sort.
    pub fn add(m: *Model, args: anytype) @TypeOf(args[0]) {
        comptime std.debug.assert(args.len > 0);
        comptime assertSameSort(@TypeOf(args));
        return .{ .ast = z3.Z3_mk_add(m.ctx, args.len, &gatherAst(args)) };
    }

    /// Create an AST node representing `lhs = rhs`.
    /// The nodes `lhs` and `rhs` must have the same type.
    pub fn eq(m: *Model, lhs: anytype, rhs: anytype) Bool {
        comptime std.debug.assert(@TypeOf(lhs) == @TypeOf(rhs));
        return .{ .ast = z3.Z3_mk_eq(m.ctx, lhs.ast, rhs.ast) };
    }

    /// Assert a constraint into the solver.
    pub fn assert(m: *Model, constraint: anytype) void {
        switch (m.prover) {
            .solver => |s| z3.Z3_solver_assert(m.ctx, s, constraint.ast),
        }
    }

    pub fn check(m: *Model) Check {
        const result = switch (m.prover) {
            .solver => |s| z3.Z3_solver_check(m.ctx, s),
        };
        return @enumFromInt(result);
    }
};
