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
    solver,
    optimize,
};

pub const Check = enum(i2) {
    /// Unsatisfiable
    false = -1,
    /// Unknown
    undef = 0,
    /// Satisfiable
    true = 1,
};

pub const Int = extern struct {
    ast: z3.Z3_ast,
};

pub const Real = extern struct {
    ast: z3.Z3_ast,
};

pub const Bool = extern struct {
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
        optimize: z3.Z3_optimize,
    },

    pub fn init(comptime p: Prover) Model {
        const cfg = z3.Z3_mk_config();
        const ctx = z3.Z3_mk_context(cfg);
        return .{
            .cfg = cfg,
            .ctx = ctx,
            .sorts = .{},
            .prover = @unionInit(@FieldType(Model, "prover"), @tagName(p), switch (p) {
                .solver => s: {
                    const solver = z3.Z3_mk_solver(ctx);
                    z3.Z3_solver_inc_ref(ctx, solver);
                    break :s solver;
                },
                .optimize => o: {
                    const optimize = z3.Z3_mk_optimize(ctx);
                    z3.Z3_optimize_inc_ref(ctx, optimize);
                    break :o optimize;
                },
            }),
        };
    }

    pub fn deinit(m: *Model) void {
        switch (m.prover) {
            .solver => |s| z3.Z3_solver_dec_ref(m.ctx, s),
            .optimize => |o| z3.Z3_optimize_dec_ref(m.ctx, o),
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

    fn Coerced(args: type) type {
        const info = @typeInfo(args);
        if (info != .pointer) @compileError("expected either a pointer to tuple or slice");
        if (info == .pointer and info.pointer.size == .slice) {
            return args;
        } else {
            const first = @typeInfo(std.meta.Child(args)).@"struct".fields[0];
            return []const first.type;
        }
    }

    /// Note that this function uses `Z3_mk_fresh_const` instead of `Z3_mk_const`.
    pub fn constant(m: *Model, comptime s: Sort, name: ?[:0]const u8) s.Data() {
        const sort = m.getSort(s);
        return .{ .ast = z3.Z3_mk_fresh_const(m.ctx, name orelse null, sort) };
    }

    pub fn int(m: *Model, value: i32) Int {
        return .{ .ast = z3.Z3_mk_int(m.ctx, value, m.getSort(.int)) };
    }

    pub fn @"true"(m: *Model) Bool {
        return .{ .ast = z3.Z3_mk_true(m.ctx) };
    }

    /// Creates an addition AST node.
    /// All arguments must be the same sort, being either int or real.
    /// The return type will be that same sort.
    pub fn add(m: *Model, args: anytype) std.meta.Child(Coerced(@TypeOf(args))) {
        std.debug.assert(args.len > 0);
        const coerced: Coerced(@TypeOf(args)) = args;
        return .{ .ast = z3.Z3_mk_add(
            m.ctx,
            @intCast(args.len),
            @as([*]const z3.Z3_ast, @ptrCast(coerced)),
        ) };
    }

    /// Creates an multiplication AST node.
    /// All arguments must be the same sort, being either int or real.
    /// The return type will be that same sort.
    pub fn mul(m: *Model, args: anytype) std.meta.Child(Coerced(@TypeOf(args))) {
        std.debug.assert(args.len > 0);
        const coerced: Coerced(@TypeOf(args)) = args;
        return .{ .ast = z3.Z3_mk_mul(
            m.ctx,
            args.len,
            @as([*]const z3.Z3_ast, @ptrCast(coerced)),
        ) };
    }

    pub fn @"or"(m: *Model, args: []const Bool) Bool {
        std.debug.assert(args.len > 0);
        return .{ .ast = z3.Z3_mk_or(
            m.ctx,
            @intCast(args.len),
            @as([*]const z3.Z3_ast, @ptrCast(args)),
        ) };
    }

    pub fn not(m: *Model, op: Bool) Bool {
        return .{ .ast = z3.Z3_mk_not(m.ctx, op.ast) };
    }

    /// Creates an AST node that implies when `lhs` is true, `rhs` must be true.
    pub fn implies(m: *Model, lhs: Bool, rhs: Bool) Bool {
        return .{ .ast = z3.Z3_mk_implies(m.ctx, lhs.ast, rhs.ast) };
    }

    /// Create an AST node representing an if-then-else. If `predicate` is true,
    /// the node results in `lhs`, otherwise it results in `rhs`.
    ///
    /// `rhs` and `lhs` must be the same sort, and the result type is that sort.
    pub fn ite(m: *Model, predicate: Bool, lhs: anytype, rhs: anytype) @TypeOf(lhs) {
        comptime std.debug.assert(@TypeOf(lhs) == @TypeOf(rhs));
        return .{ .ast = z3.Z3_mk_ite(m.ctx, predicate.ast, lhs.ast, rhs.ast) };
    }

    /// Create an AST node representing `lhs = rhs`.
    /// The nodes `lhs` and `rhs` must have the same type.
    pub fn eq(m: *Model, lhs: anytype, rhs: anytype) Bool {
        comptime std.debug.assert(@TypeOf(lhs) == @TypeOf(rhs));
        return .{ .ast = z3.Z3_mk_eq(m.ctx, lhs.ast, rhs.ast) };
    }

    /// Create an AST node representing `lhs <= rhs`.
    /// The nodes `lhs` and `rhs` must have the same type.
    pub fn le(m: *Model, lhs: anytype, rhs: anytype) Bool {
        comptime std.debug.assert(@TypeOf(lhs) == @TypeOf(rhs));
        return .{ .ast = z3.Z3_mk_le(m.ctx, lhs.ast, rhs.ast) };
    }

    pub fn iff(m: *Model, lhs: Bool, rhs: Bool) Bool {
        return .{ .ast = z3.Z3_mk_iff(m.ctx, lhs.ast, rhs.ast) };
    }

    /// Assert a constraint into the solver.
    pub fn assert(m: *Model, constraint: anytype) void {
        switch (m.prover) {
            .solver => |s| z3.Z3_solver_assert(m.ctx, s, constraint.ast),
            .optimize => |o| z3.Z3_optimize_assert(m.ctx, o, constraint.ast),
        }
    }

    pub fn check(m: *Model) Check {
        const result = switch (m.prover) {
            .solver => |s| z3.Z3_solver_check(m.ctx, s),
            .optimize => |o| z3.Z3_optimize_check(m.ctx, o, 0, null),
        };
        return @enumFromInt(result);
    }

    pub fn minimize(m: *Model, objective: anytype) void {
        _ = switch (m.prover) {
            .solver => @panic("cannot minimze 'solver' prover"),
            .optimize => |o| z3.Z3_optimize_minimize(m.ctx, o, objective.ast),
        };
    }

    /// The string is still owned by the model, it's stored in a temporary buffer inside and dies on `deinit()`.
    pub fn toString(m: *const Model) []const u8 {
        const str = switch (m.prover) {
            .solver => |s| z3.Z3_solver_to_string(m.ctx, s),
            .optimize => |o| z3.Z3_optimize_to_string(m.ctx, o),
        };
        return std.mem.sliceTo(str, 0);
    }

    /// Panics if
    /// 1. `check()` wasn't ran before calling `getLastModel()`.
    /// 2. The last `check()` call didn't return `true`.
    pub fn getLastModel(m: *Model) PartialModel {
        const model = switch (m.prover) {
            .optimize => |o| z3.Z3_optimize_get_model(m.ctx, o),
            .solver => @panic("TODO"),
        };
        z3.Z3_model_inc_ref(m.ctx, model);
        return .{ .m = m, .raw = model };
    }
};

const PartialModel = struct {
    m: *Model,
    raw: z3.Z3_model,

    pub fn deinit(p: *PartialModel) void {
        z3.Z3_model_dec_ref(p.m.ctx, p.raw);
    }

    pub fn toString(p: *const PartialModel) []const u8 {
        const str = z3.Z3_model_to_string(p.m.ctx, p.raw);
        return std.mem.sliceTo(str, 0);
    }

    pub fn isTrue(p: *PartialModel, v: anytype) bool {
        var value: z3.Z3_ast = undefined;
        if (!z3.Z3_model_eval(p.m.ctx, p.raw, v.ast, true, &value)) return false;
        const boolean: Check = @enumFromInt(z3.Z3_get_bool_value(p.m.ctx, value));
        return boolean == .true;
    }
};
