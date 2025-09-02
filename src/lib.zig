const std = @import("std");
const c = @import("z3");
const assert = std.debug.assert;

fn errorHandler(ctx: c.Z3_context, e: c.Z3_error_code) callconv(.c) void {
    std.debug.print("Error #{}: {s}\nIncorrect use of Z3.\n", .{ e, c.Z3_get_error_msg(ctx, e) });
    std.process.exit(1);
}

pub const Context = struct {
    inner: c.Z3_context,
    cached_sorts: CachedSorts,

    /// sorts that can be cached which only require a single *Model argument
    const CachedSorts = struct {
        bool: ?c.Z3_sort = null,
        int: ?c.Z3_sort = null,
        real: ?c.Z3_sort = null,
        float32: ?c.Z3_sort = null,
        float64: ?c.Z3_sort = null,
        string: ?c.Z3_sort = null,
    };

    const ConfigParam = union(enum) {
        timeout: c_uint,
        rlimit: c_uint,
        type_check: bool,
        well_sorted_check: bool,
        auto_config: bool,
        proof: bool,
        model: bool,
        model_validate: bool,
        dump_models: bool,
        stats: bool,
        trace: bool,
        trace_file_name: [*:0]const u8,
        dot_proof_file: [*:0]const u8,
        unsat_core: bool,
        debug_ref_count: bool,
        smtlib2_compliant: bool,
        encoding: enum { unicode, bmp, ascii },

        // TODO support additional params and renames: https://github.com/Z3Prover/z3/blob/49703f8bba0e73fbd2aa6b180f8afdaeadd4d7a4/src/util/gparams.cpp#L44-L73
    };

    pub const Config = []const ConfigParam;

    pub fn init(config: Config) Context {
        const cfg = c.Z3_mk_config();
        defer c.Z3_del_config(cfg);
        for (config) |param| {
            var buf: [64]u8 = undefined;
            const value_str: [:0]const u8 = switch (param) {
                inline else => |payload| switch (@TypeOf(payload)) {
                    c_uint => std.fmt.bufPrintZ(&buf, "{}", .{payload}) catch @panic("unreachable"),
                    bool => if (payload) "true" else "false",
                    [*:0]const u8 => std.mem.sliceTo(payload, 0),
                    else => unreachable,
                },
            };
            c.Z3_set_param_value(cfg, @tagName(param).ptr, value_str.ptr);
        }
        const inner = c.Z3_mk_context_rc(cfg);
        c.Z3_set_error_handler(inner, errorHandler);
        return .{ .inner = inner, .cached_sorts = .{} };
    }

    pub fn deinit(ctx: *const Context) void {
        c.Z3_del_context(ctx.inner);
    }

    fn getSort(ctx: *Context, comptime tag: SortKind, args: anytype) Sort {
        return ctx.getSortByName(tag, "Z3_mk_" ++ @tagName(tag) ++ "_sort", args);
    }

    fn getSortByName(
        ctx: *Context,
        comptime tag: SortKind,
        comptime mk_fn_name: []const u8,
        args: anytype,
    ) Sort {
        const name = @tagName(tag);
        if (@hasField(CachedSorts, name)) {
            comptime assert(args.len == 0);
            if (@field(ctx.cached_sorts, name)) |sort| return .{ .inner = sort, .ctx = ctx };
            const sort = @field(c, mk_fn_name)(ctx.inner);
            @field(ctx.cached_sorts, name) = sort;
            c.Z3_inc_ref(ctx.inner, c.Z3_sort_to_ast(ctx.inner, sort));
            return .{ .inner = sort, .ctx = ctx };
        }

        const sort = @call(.auto, @field(c, mk_fn_name), .{ctx.inner} ++ args);
        c.Z3_inc_ref(ctx.inner, c.Z3_sort_to_ast(ctx.inner, sort));
        return .{ .inner = sort, .ctx = ctx };
    }
};

pub const SortKind = enum(c_uint) {
    /// `Z3_UNINTERPRETED_SORT`
    uninterpreted = c.Z3_UNINTERPRETED_SORT,
    /// `Z3_BOOL_SORT`
    bool = c.Z3_BOOL_SORT,
    /// `Z3_INT_SORT`
    int = c.Z3_INT_SORT,
    /// `Z3_REAL_SORT`
    real = c.Z3_REAL_SORT,
    /// `Z3_BV_SORT`
    bv = c.Z3_BV_SORT,
    /// `Z3_ARRAY_SORT`
    array = c.Z3_ARRAY_SORT,
    /// `Z3_DATATYPE_SORT`
    datatype = c.Z3_DATATYPE_SORT,
    /// `Z3_RELATION_SORT`
    relation = c.Z3_RELATION_SORT,
    /// `Z3_FINITE_DOMAIN_SORT`
    finite_domain = c.Z3_FINITE_DOMAIN_SORT,
    /// `Z3_FLOATING_POINT_SORT`
    floating_point = c.Z3_FLOATING_POINT_SORT,
    /// `Z3_ROUNDING_MODE_SORT`
    rounding_mode = c.Z3_ROUNDING_MODE_SORT,
    /// `Z3_SEQ_SORT`
    seq = c.Z3_SEQ_SORT,
    /// `Z3_RE_SORT`
    re = c.Z3_RE_SORT,
    /// `Z3_UNKNOWN_SORT`
    unknown = c.Z3_UNKNOWN_SORT,

    inline fn Data(comptime tag: SortKind) type {
        comptime return switch (tag) {
            .bool => Bool,
            .int => Int,
            .real => Real,
            .floating_point => Float,
            .bv => Bitvector,
            .array => Array,
            .seq => Seq,
            else => @compileError("TODO: Data() for " ++ @tagName(tag)),
        };
    }
};

const A = Ast;

pub const Bool = struct {
    ctx: *Context,
    ast: c.Z3_ast,

    pub const toString = A.toString;
    pub const eq = A.eq;

    pub const @"and" = A.@"and";
    pub const @"or" = A.@"or";

    pub const xor = A.xor;
    pub const iff = A.iff;
    pub const implies = A.implies;

    pub const not = A.not;
    pub const ite = A.ite;
};
pub const Int = struct {
    // storing ctx allows a builder pattern. i.e. `x.div(y)`
    ctx: *Context,
    ast: c.Z3_ast,

    pub const toString = A.toString;
    pub const eq = A.eq;

    pub const add = A.add;
    pub const sub = A.sub;
    pub const mul = A.mul;

    pub const div = A.div;
    pub const rem = A.rem;
    pub const modulo = A.modulo;
    pub const power = A.power;
    pub const lt = A.lt;
    pub const le = A.le;
    pub const gt = A.gt;
    pub const ge = A.ge;

    pub const asInt64 = A.asInt64;
};
pub const Real = struct {
    ctx: *Context,
    ast: c.Z3_ast,

    pub const toString = A.toString;
    pub const eq = A.eq;
};
pub const Float = struct {
    ctx: *Context,
    ast: c.Z3_ast,

    pub const toString = A.toString;
    pub const eq = A.eq;
};
pub const Bitvector = struct {
    ctx: *Context,
    ast: c.Z3_ast,

    pub const toString = A.toString;
    pub const eq = A.eq;

    pub const bvadd = A.bvadd;
    pub const bvsub = A.bvsub;
    pub const bvmul = A.bvmul;
    pub const bvudiv = A.bvudiv;
    pub const bvsdiv = A.bvsdiv;
    pub const bvurem = A.bvurem;
    pub const bvsrem = A.bvsrem;
    pub const bvsmod = A.bvsmod;
    pub const bvult = A.bvult;
    pub const bvslt = A.bvslt;
    pub const bvule = A.bvule;
    pub const bvsle = A.bvsle;
    pub const bvuge = A.bvuge;
    pub const bvsge = A.bvsge;
    pub const bvugt = A.bvugt;
    pub const bvsgt = A.bvsgt;

    pub const asInt64 = A.asInt64;
};
pub const Array = struct {
    ctx: *Context,
    ast: c.Z3_ast,

    pub const toString = A.toString;
    pub const eq = A.eq;

    pub const select = A.select;
    pub const store = A.store;
    pub const asSet = A.asSet;
};
pub const Set = struct {
    ctx: *Context,
    ast: c.Z3_ast,

    pub const toString = A.toString;
    pub const eq = A.eq;
};
pub const Seq = struct {
    ctx: *Context,
    ast: c.Z3_ast,

    pub const toString = A.toString;
};
pub const Dynamic = struct {
    ctx: *Context,
    ast: c.Z3_ast,

    pub const toString = A.toString;
    pub const eq = A.eq;

    pub fn sortKind(self: Dynamic) SortKind {
        return @enumFromInt(c.Z3_get_sort_kind(
            self.ctx.inner,
            c.Z3_get_sort(self.ctx.inner, self.ast),
        ));
    }

    pub fn asSet(self: Dynamic) ?Set {
        switch (self.sortKind()) {
            .array => {
                const sort_kind: SortKind = @enumFromInt(c.Z3_get_sort_kind(
                    self.ctx.inner,
                    c.Z3_get_array_sort_range(
                        self.ctx.inner,
                        c.Z3_get_sort(self.ctx.inner, self.ast),
                    ),
                ));
                switch (sort_kind) {
                    .bool => return .{ .ctx = self.ctx, .ast = self.ast },
                    else => return null,
                }
            },
            else => return null,
        }
    }
};

// zig fmt: off
const Ast = struct {
        pub fn deinit(self: anytype) void {
            c.Z3_dec_ref(self.ctx.inner, self.ast);
        }
        pub fn toString(self: anytype) ?[]const u8 {
            return if (c.Z3_ast_to_string(self.ctx.inner, self.ast)) |s| std.mem.sliceTo(s, 0) else null;
        }

        inline fn verify(comptime ok: bool, T: type, comptime message: []const u8) void {
            comptime if (!ok)
                @compileError(std.fmt.comptimePrint(message ++ ".  found '{s}'", .{@typeName(T)}));
        }
        inline fn Child(T: type) type {
            return switch (@typeInfo(T)) {
                .pointer => |p| p.child,
                else => T,
            };
        }
        fn binopAny(R: type, lhs: anytype, rhs: anytype, func: @TypeOf(c.Z3_mk_div)) R {
            const ast = func(lhs.ctx.inner, lhs.ast, rhs.ast);
            c.Z3_inc_ref(lhs.ctx.inner, ast);
            return .{ .ast = ast, .ctx = lhs.ctx };
        }
        fn binop(R: type, lhs: anytype, rhs: Child(@TypeOf(lhs)), func: @TypeOf(c.Z3_mk_div)) R {
            return binopAny(R, lhs, rhs, func);
        }
        fn varop(R: type, lhs: anytype, rhss: []const Child(@TypeOf(lhs)), comptime func: @TypeOf(c.Z3_mk_add)) R {
            var buf: [16]c.Z3_ast = undefined;
            if (buf.len < rhss.len + 1) @panic("varop only supports up to 15 rhs args.");
            buf[0] = lhs.ast;
            for (0..rhss.len) |i| buf[i + 1] = rhss[i].ast;
            const ast = func(lhs.ctx.inner, @intCast(rhss.len + 1), &buf);
            c.Z3_inc_ref(lhs.ctx.inner, ast);
            return .{ .ast = ast, .ctx = lhs.ctx };
        }

        // *** Numeric ops ***
        inline fn verifyNumeric(T: type) void {
            verify(T == Int or T == Float or T == Real, T, "expected numeric type");
        }
        fn numericBinop(R: type, lhs: anytype, rhs: Child(@TypeOf(lhs)), func: @TypeOf(c.Z3_mk_div)) R {
            verifyNumeric(Child(@TypeOf(lhs)));
            return binop(R, lhs, rhs, func);
        }
        fn numericVarop(lhs: anytype, rhss: []const Child(@TypeOf(lhs)), comptime func: @TypeOf(c.Z3_mk_add)) Child(@TypeOf(lhs)) {
            verifyNumeric(Child(@TypeOf(lhs)));
            return varop(Child(@TypeOf(lhs)), lhs, rhss, func);
        }

        pub fn div(lhs: anytype, rhs: Child(@TypeOf(lhs))) Child(@TypeOf(lhs)) {
            return numericBinop(Child(@TypeOf(lhs)), lhs, rhs, c.Z3_mk_div);
        }
        pub fn rem(lhs: anytype, rhs: Child(@TypeOf(lhs))) Child(@TypeOf(lhs)) {
            return numericBinop(Child(@TypeOf(lhs)), lhs, rhs, c.Z3_mk_rem);
        }
        pub fn mod(lhs: anytype, rhs: Child(@TypeOf(lhs))) Child(@TypeOf(lhs)) {
            return numericBinop(Child(@TypeOf(lhs)), lhs, rhs, c.Z3_mk_mod);
        }
        pub fn power(lhs: anytype, rhs: Child(@TypeOf(lhs))) Real {
            return numericBinop(Child(@TypeOf(lhs)), lhs, rhs, c.Z3_mk_power);
        }

        pub fn lt(lhs: anytype, rhs: Child(@TypeOf(lhs))) Bool {
            return numericBinop(Bool, lhs, rhs, c.Z3_mk_lt);
        }
        pub fn le(lhs: anytype, rhs: Child(@TypeOf(lhs))) Bool {
            return numericBinop(Bool, lhs, rhs, c.Z3_mk_le);
        }
        pub fn gt(lhs: anytype, rhs: Child(@TypeOf(lhs))) Bool {
            return numericBinop(Bool, lhs, rhs, c.Z3_mk_gt);
        }
        pub fn ge(lhs: anytype, rhs: Child(@TypeOf(lhs))) Bool {
            return numericBinop(Bool, lhs, rhs, c.Z3_mk_ge);
        }
        pub fn eq(lhs: anytype, rhs: Child(@TypeOf(lhs))) Bool {
            return binop(Bool, lhs, rhs, c.Z3_mk_eq);
        }

        pub fn add(lhs: anytype, rhss: []const Child(@TypeOf(lhs))) Child(@TypeOf(lhs)) {
            return numericVarop(lhs, rhss, c.Z3_mk_add);
        }

        pub fn sub(lhs: anytype, rhss: []const Child(@TypeOf(lhs))) Child(@TypeOf(lhs)) {
            return numericVarop(lhs, rhss, c.Z3_mk_sub);
        }

        pub fn mul(lhs: anytype, rhss: []const Child(@TypeOf(lhs))) Child(@TypeOf(lhs)) {
            return numericVarop(lhs, rhss, c.Z3_mk_mul);
        }

        pub fn asInt64(lhs: anytype) ?i64 {
            var ret: i64 = undefined;
            return if (c.Z3_get_numeral_int64(lhs.ctx.inner, lhs.ast, &ret))
                ret
            else
                null;
        }

        // *** Bitvector ops ***
        fn bvBinop(R: type, lhs: Bitvector, rhs: Bitvector, func: @TypeOf(c.Z3_mk_bvadd)) R {
            return binop(R, lhs, rhs, func);
        }

        /// Addition
        pub fn bvadd(lhs: Bitvector, rhs: Bitvector) Bitvector {
            return bvBinop(Bitvector, lhs, rhs, c.Z3_mk_bvadd);
        }
        /// Subtraction
        pub fn bvsub(lhs: Bitvector, rhs: Bitvector) Bitvector {
            return bvBinop(Bitvector, lhs, rhs, c.Z3_mk_bvsub);
        }
        /// Multiplication
        pub fn bvmul(lhs: Bitvector, rhs: Bitvector) Bitvector {
            return bvBinop(Bitvector, lhs, rhs, c.Z3_mk_bvmul);
        }
        /// Unsigned division
        pub fn bvudiv(lhs: Bitvector, rhs: Bitvector) Bitvector {
            return bvBinop(Bitvector, lhs, rhs, c.Z3_mk_bvudiv);
        }
        /// Signed division
        pub fn bvsdiv(lhs: Bitvector, rhs: Bitvector) Bitvector {
            return bvBinop(Bitvector, lhs, rhs, c.Z3_mk_bvsdiv);
        }
        /// Unsigned remainder
        pub fn bvurem(lhs: Bitvector, rhs: Bitvector) Bitvector {
            return bvBinop(Bitvector, lhs, rhs, c.Z3_mk_bvurem);
        }
        /// Signed remainder (sign follows dividend)
        pub fn bvsrem(lhs: Bitvector, rhs: Bitvector) Bitvector {
            return bvBinop(Bitvector, lhs, rhs, c.Z3_mk_bvsrem);
        }
        /// Signed remainder (sign follows divisor)
        pub fn bvsmod(lhs: Bitvector, rhs: Bitvector) Bitvector {
            return bvBinop(Bitvector, lhs, rhs, c.Z3_mk_bvsmod);
        }

        /// Unsigned less than
        pub fn bvult(lhs: Bitvector, rhs: Bitvector) Bool {
            return bvBinop(Bool, lhs, rhs, c.Z3_mk_bvult);
        }
        /// Signed less than
        pub fn bvslt(lhs: Bitvector, rhs: Bitvector) Bool {
            return bvBinop(Bool, lhs, rhs, c.Z3_mk_bvslt);
        }
        /// Unsigned less than or equal
        pub fn bvule(lhs: Bitvector, rhs: Bitvector) Bool {
            return bvBinop(Bool, lhs, rhs, c.Z3_mk_bvule);
        }
        /// Signed less than or equal
        pub fn bvsle(lhs: Bitvector, rhs: Bitvector) Bool {
            return bvBinop(Bool, lhs, rhs, c.Z3_mk_bvsle);
        }
        /// Unsigned greater or equal
        pub fn bvuge(lhs: Bitvector, rhs: Bitvector) Bool {
            return bvBinop(Bool, lhs, rhs, c.Z3_mk_bvuge);
        }
        /// Signed greater or equal
        pub fn bvsge(lhs: Bitvector, rhs: Bitvector) Bool {
            return bvBinop(Bool, lhs, rhs, c.Z3_mk_bvsge);
        }
        /// Unsigned greater than
        pub fn bvugt(lhs: Bitvector, rhs: Bitvector) Bool {
            return bvBinop(Bool, lhs, rhs, c.Z3_mk_bvugt);
        }
        /// Signed greater than
        pub fn bvsgt(lhs: Bitvector, rhs: Bitvector) Bool {
            return bvBinop(Bool, lhs, rhs, c.Z3_mk_bvsgt);
        }

        // *** Array ops ***
        pub fn select(lhs: anytype, rhs: anytype) Dynamic {
            return binopAny(Dynamic, lhs, rhs, c.Z3_mk_select);
        }
        pub fn store(lhs: anytype, index: Int, value: anytype) Child(@TypeOf(lhs)) {
            const ast = c.Z3_mk_store(
                lhs.ctx.inner,
                lhs.ast,
                index.ast,
                value.ast,
            );
            c.Z3_inc_ref(lhs.ctx.inner, ast);
            return .{ .ast = ast, .ctx = lhs.ctx };
        }

        // *** Bool ops ***
        pub fn @"and"(lhs: Bool, rhss: []const Bool) Bool {
            return varop(Bool, lhs, rhss, c.Z3_mk_and);
        }
        pub fn @"or"(lhs: Bool, rhss: []const Bool) Bool {
            return varop(Bool, lhs, rhss, c.Z3_mk_or);
        }

        pub fn xor(lhs: Bool, rhs: Bool) Bool {
            return binop(Bool, lhs, rhs, c.Z3_mk_xor);
        }
        pub fn iff(lhs: Bool, rhs: Bool) Bool {
            return binop(Bool, lhs, rhs, c.Z3_mk_iff);
        }
        pub fn implies(lhs: Bool, rhs: Bool) Bool {
            return binop(Bool, lhs, rhs, c.Z3_mk_implies);
        }

        pub fn not(op: Bool) Bool {
            const ast = c.Z3_mk_not(op.ctx.inner, op.ast);
            c.Z3_inc_ref(op.ctx.inner, ast);
            return .{ .ast = ast, .ctx = op.ctx };
        }

        /// Create an AST node representing an if-then-else. If `predicate` is true,
        /// the node results in `lhs`, otherwise it results in `rhs`.
        ///
        /// `rhs` and `lhs` must be the same sort, and the result type is that sort.
        pub fn ite(predicate: Bool, lhs: anytype, rhs: Child(@TypeOf(lhs))) Child(@TypeOf(lhs)) {
            const ast = c.Z3_mk_ite(predicate.ctx.inner, predicate.ast, lhs.ast, rhs.ast);
            c.Z3_inc_ref(predicate.ctx.inner, ast);
            return .{ .ast = ast, .ctx = predicate.ctx };
        }
};
// zig fmt: on

pub const Symbol = union(enum) {
    int: i32,
    string: ?[:0]const u8,

    pub const Tag = std.meta.Tag(Symbol);

    fn asZ3(sym: Symbol, ctx: *const Context) c.Z3_symbol {
        return switch (sym) {
            .int => |i| c.Z3_mk_int_symbol(ctx.inner, i),
            .string => |s| c.Z3_mk_string_symbol(ctx.inner, @ptrCast(s)),
        };
    }
};

pub const Sort = struct {
    ctx: *Context,
    inner: c.Z3_sort,
};

const Prover = enum { solver, optimize };

pub const Model = struct {
    ctx: Context,
    inner: union(Prover) {
        solver: c.Z3_solver,
        optimize: c.Z3_optimize,
    },

    pub fn init(comptime p: Prover, ctx: Context) Model {
        const inner = @unionInit(@FieldType(Model, "inner"), @tagName(p), switch (p) {
            .solver => s: {
                const solver = c.Z3_mk_solver(ctx.inner);
                c.Z3_solver_inc_ref(ctx.inner, solver);
                break :s solver;
            },
            .optimize => o: {
                const optimize = c.Z3_mk_optimize(ctx.inner);
                c.Z3_optimize_inc_ref(ctx.inner, optimize);
                break :o optimize;
            },
        });
        return .{ .ctx = ctx, .inner = inner };
    }

    pub fn initSolver() Model {
        return initConfig(.solver, &.{.{ .proof = true }});
    }

    pub fn initConfig(comptime p: Prover, config: Context.Config) Model {
        return init(p, Context.init(config));
    }

    pub fn deinit(m: *const Model) void {
        switch (m.inner) {
            .solver => |s| c.Z3_solver_dec_ref(m.ctx.inner, s),
            .optimize => |o| c.Z3_optimize_dec_ref(m.ctx.inner, o),
        }
        m.ctx.deinit();
    }

    /// Panics if
    /// 1. `check()` wasn't ran before calling `getLastModel()`.
    /// 2. The last `check()` call didn't return `true`.
    pub fn getLastModel(m: *const Model) PartialModel {
        const model = switch (m.inner) {
            .solver => |x| c.Z3_solver_get_model(m.ctx.inner, x),
            .optimize => |x| c.Z3_optimize_get_model(m.ctx.inner, x),
        };
        c.Z3_model_inc_ref(m.ctx.inner, model);
        return .{ .ctx = &m.ctx, .inner = model };
    }

    pub fn assert(m: *const Model, ast: anytype) void {
        switch (m.inner) {
            .solver => |x| c.Z3_solver_assert(m.ctx.inner, x, ast.ast),
            .optimize => |x| c.Z3_optimize_assert(m.ctx.inner, x, ast.ast),
        }
    }

    pub fn check(m: *const Model) SatResult {
        return @enumFromInt(switch (m.inner) {
            .solver => |x| c.Z3_solver_check(m.ctx.inner, x),
            .optimize => |x| c.Z3_optimize_check(m.ctx.inner, x, 0, null),
        });
    }

    pub fn minimize(m: *const Model, objective: anytype) void {
        _ = switch (m.prover) {
            .solver => @panic("cannot minimze 'solver' prover"),
            .optimize => |o| c.Z3_optimize_minimize(m.ctx.inner, o, objective.ast),
        };
    }

    /// The string is still owned by the model, it's stored in a temporary buffer inside and dies on `deinit()`.
    pub fn toString(m: *const Model) []const u8 {
        const str = switch (m.prover) {
            .solver => |s| c.Z3_solver_to_string(m.ctx.inner, s),
            .optimize => |o| c.Z3_optimize_to_string(m.ctx.inner, o),
        };
        return std.mem.sliceTo(str, 0);
    }

    pub fn constant(m: *Model, comptime tag: SortKind, name: ?[:0]const u8, args: anytype) tag.Data() {
        const sort = m.ctx.getSort(tag, args);
        const sym = Symbol.asZ3(.{ .string = name }, &m.ctx);
        const ast = c.Z3_mk_const(m.ctx.inner, sym, sort.inner);
        c.Z3_inc_ref(m.ctx.inner, ast);
        return .{ .ctx = &m.ctx, .ast = ast };
    }

    pub fn fromInt(m: *Model, value: i32) Int {
        const sort = m.ctx.getSort(.int, .{});
        const ast = c.Z3_mk_int(m.ctx.inner, value, sort.inner);
        c.Z3_inc_ref(m.ctx.inner, ast);
        return .{ .ctx = &m.ctx, .ast = ast };
    }

    pub fn fromInt64(m: *Model, value: i64) Int {
        const sort = m.ctx.getSort(.int, .{});
        const ast = c.Z3_mk_int64(m.ctx.inner, value, sort.inner);
        c.Z3_inc_ref(m.ctx.inner, ast);
        return .{ .ctx = &m.ctx, .ast = ast };
    }

    pub fn @"true"(m: *Model) Bool {
        const ast = c.Z3_mk_true(m.ctx.inner);
        c.Z3_inc_ref(m.ctx.inner, ast);
        return .{ .ctx = &m.ctx, .ast = ast };
    }
    pub fn @"false"(m: *Model) Bool {
        const ast = c.Z3_mk_false(m.ctx.inner);
        c.Z3_inc_ref(m.ctx.inner, ast);
        return .{ .ctx = &m.ctx, .ast = ast };
    }

    pub fn bvFromInt64(m: *Model, i: i64, sz: u32) Bitvector {
        const sort = m.ctx.getSort(.bv, .{sz});
        const ast = c.Z3_mk_int64(m.ctx.inner, i, sort.inner);
        c.Z3_inc_ref(m.ctx.inner, ast);
        return .{ .ctx = &m.ctx, .ast = ast };
    }

    pub fn boolean(m: *Model) Sort {
        return m.ctx.getSort(.bool, .{});
    }

    pub fn int(m: *Model) Sort {
        return m.ctx.getSort(.int, .{});
    }

    pub fn real(m: *Model) Sort {
        return m.ctx.getSort(.real, .{});
    }

    /// T must be a floating point type
    pub fn float(m: *Model, comptime T: type) Sort {
        const ebits: c_uint = std.math.floatExponentBits(T);
        const sbits: c_uint = std.math.floatMantissaBits(T) + 1;
        if (@typeInfo(T) != .float) @compileError("expected floating point type. found '" ++ @typeName(T) ++ "'");
        switch (T) {
            f32 => {
                comptime std.debug.assert(ebits == 8 and sbits == 24);
                return m.ctx.getSortByName(.float32, "Z3_mk_fpa_sort", .{ ebits, sbits });
            },
            f64 => {
                comptime std.debug.assert(ebits == 11 and sbits == 53);
                return m.ctx.getSortByName(.float64, "Z3_mk_fpa_sort", .{ ebits, sbits });
            },
            else => return m.ctx.getSortByName(.float, "Z3_mk_fpa_sort", .{ ebits, sbits }),
        }
    }

    pub fn string(m: *Model) Sort {
        return m.ctx.getSort(.string, .{});
    }

    pub fn bv(m: Model, sz: u32) Sort {
        const sort = c.Z3_mk_bv_sort(m.ctx.inner, sz);
        c.Z3_inc_ref(m.ctx.inner, sort);
        return .{ .ctx = &m.ctx, .inner = sort };
    }

    pub fn array(m: *Model, domain: Sort, range: Sort) Sort {
        const sort = c.Z3_mk_array_sort(m.ctx.inner, domain.inner, range.inner);
        c.Z3_inc_ref(m.ctx.inner, c.Z3_sort_to_ast(m.ctx.inner, sort));
        return .{ .ctx = &m.ctx, .inner = sort };
    }

    pub fn set(m: *Model, elt: Sort) Sort {
        const sort = c.Z3_mk_set_sort(m.ctx.inner, elt.inner);
        c.Z3_inc_ref(m.ctx.inner, c.Z3_sort_to_ast(m.ctx.inner, sort));
        return .{ .ctx = &m.ctx, .inner = sort };
    }

    pub fn seq(m: *Model, elt: Sort) Sort {
        const sort = c.Z3_mk_seq_sort(m.ctx.inner, elt.inner);
        c.Z3_inc_ref(m.ctx.inner, c.Z3_sort_to_ast(m.ctx.inner, sort));
        return .{ .ctx = &m.ctx, .inner = sort };
    }

    pub fn getReasonUnknown(m: Model) ?[*:0]const u8 {
        return c.Z3_optimize_get_reason_unknown(m.ctx.inner, m.inner.optimize);
    }

    pub fn push(m: Model) void {
        c.Z3_solver_push(m.ctx.inner, m.inner.solver);
    }
    pub fn pop(m: Model, n: c_uint) void {
        c.Z3_solver_pop(m.ctx.inner, m.inner.solver, n);
    }
};

pub const PartialModel = struct {
    ctx: *const Context,
    inner: c.Z3_model,

    pub fn deinit(m: *const PartialModel) void {
        c.Z3_model_dec_ref(m.ctx.inner, m.inner);
    }

    pub fn eval(m: *const PartialModel, ast: anytype, model_completion: bool) ?@TypeOf(ast) {
        var ret = ast;
        if (c.Z3_model_eval(
            m.ctx.inner,
            m.inner,
            ast.ast,
            model_completion,
            &ret.ast,
        )) {
            c.Z3_inc_ref(m.ctx.inner, ret.ast);
            return ret;
        }

        return null;
    }

    pub fn toString(p: *const PartialModel) []const u8 {
        const str = c.Z3_model_to_string(p.ctx.inner, p.inner);
        return std.mem.sliceTo(str, 0);
    }
};

/// Result of a satisfiability query.
pub const SatResult = enum(i2) {
    /// The query is unsatisfiable.
    unsat = -1,
    /// The query was interrupted, timed out or otherwise failed.
    unknown = 0,
    /// The query is satisfiable.
    sat = 1,
};
