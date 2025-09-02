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

    fn getSort(ctx: *Context, comptime tag: AstKind, args: anytype) Sort {
        return ctx.getSortByName(tag, "Z3_mk_" ++ @tagName(tag) ++ "_sort", args);
    }

    fn getSortByName(
        ctx: *Context,
        comptime tag: AstKind,
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

pub const AstKind = enum {
    bool,
    int,
    real,
    float,
    float32,
    float64,
    string,
    bv,
    array,
    set,
    seq,

    fn Data(tag: AstKind) type {
        return switch (tag) {
            .bool => Bool,
            .int => Int,
            .real => Real,
            .float => Float,
            .float32 => Float32,
            .float64 => Float64,
            .string => String,
            .bv => Bitvector,
            .array => Array,
            .set => Set,
            .seq => Seq,
        };
    }

    pub fn isNumeric(tag: AstKind) bool {
        return switch (tag) {
            .int,
            .real,
            .float,
            .float32,
            .float64,
            => true,
            else => false,
        };
    }

    pub fn fromAst(lhs: anytype) AstKind {
        return switch (c.Z3_get_sort_kind(lhs.ctx.inner, c.Z3_get_sort(lhs.ctx.inner, lhs.ast))) {
            c.Z3_BOOL_SORT => .bool,
            c.Z3_INT_SORT => .int,
            c.Z3_REAL_SORT => .real,
            c.Z3_BV_SORT => .bv,
            c.Z3_ARRAY_SORT => .array,
            c.Z3_FLOATING_POINT_SORT => .float,
            c.Z3_SEQ_SORT => .seq,
            c.Z3_RE_SORT,
            c.Z3_CHAR_SORT,
            c.Z3_TYPE_VAR,
            c.Z3_UNKNOWN_SORT,
            c.Z3_DATATYPE_SORT,
            c.Z3_RELATION_SORT,
            c.Z3_FINITE_DOMAIN_SORT,
            c.Z3_ROUNDING_MODE_SORT,
            => @panic("unimplemented"),
            else => unreachable,
        };
    }
};

pub const Bool = struct {
    ctx: *Context,
    ast: c.Z3_ast,

    const A = Ast(.bool);
};
pub const Int = struct {
    // storing ctx allows a builder pattern. i.e. `x.div(y)`
    ctx: *Context,
    ast: c.Z3_ast,

    const A = Ast(.int);
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
    pub const eq = A.eq;

    pub const asInt64 = A.asInt64;
};
pub const Real = struct {
    ctx: *Context,
    ast: c.Z3_ast,

    const A = Ast(.real);
};
pub const Float = struct {
    ctx: *Context,
    ast: c.Z3_ast,

    const A = Ast(.float);
};
pub const Float32 = struct {
    ctx: *Context,
    ast: c.Z3_ast,

    const A = Ast(.float32);
};
pub const Float64 = struct {
    ctx: *Context,
    ast: c.Z3_ast,

    const A = Ast(.float64);
};
pub const String = struct {
    ctx: *Context,
    ast: c.Z3_ast,

    const A = Ast(.string);
};
pub const Bitvector = struct {
    ctx: *Context,
    ast: c.Z3_ast,

    const A = Ast(.bv);
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

    const A = Ast(.array);
    pub const select = A.select;
    pub const asSet = A.asSet;
};
pub const Set = struct {
    ctx: *Context,
    ast: c.Z3_ast,

    const A = Ast(.set);
};
pub const Seq = struct {
    ctx: *Context,
    ast: c.Z3_ast,

    const A = Ast(.seq);
};

pub const Dynamic = struct {
    ctx: *Context,
    ast: c.Z3_ast,
    ast_kind: AstKind,

    pub fn asSet(self: Dynamic) ?Set {
        return switch (self.ast_kind) {
            .array => switch (c.Z3_get_sort_kind(
                self.ctx.inner,
                c.Z3_get_array_sort_range(
                    self.ctx.inner,
                    c.Z3_get_sort(self.ctx.inner, self.ast),
                ),
            )) {
                c.Z3_BOOL_SORT => return .{ .ctx = self.ctx, .ast = self.ast },
                else => null,
            },
            else => null,
        };
    }
};

pub fn Ast(comptime ast_kind: AstKind) type {
    return struct {
        pub fn deinit(self: anytype) void {
            c.Z3_dec_ref(self.ctx.inner, self.ast);
        }

        // *** Numeric ops ***
        inline fn verifyNumeric() void {
            comptime if (!ast_kind.isNumeric())
                @compileError(std.fmt.comptimePrint("expected numeric ast kind.  found '{t}'", .{ast_kind}));
        }

        fn numericBinop(R: type, lhs: anytype, rhs: @TypeOf(lhs.*), func: @TypeOf(c.Z3_mk_div)) R {
            verifyNumeric();
            const ast = func(lhs.ctx.inner, lhs.ast, rhs.ast);
            c.Z3_inc_ref(lhs.ctx.inner, ast);
            return .{ .ast = ast, .ctx = lhs.ctx };
        }

        pub fn div(lhs: anytype, rhs: @TypeOf(lhs.*)) @TypeOf(lhs.*) {
            return numericBinop(@TypeOf(lhs.*), lhs, rhs, c.Z3_mk_div);
        }
        pub fn rem(lhs: anytype, rhs: @TypeOf(lhs.*)) @TypeOf(lhs.*) {
            return numericBinop(@TypeOf(lhs.*), lhs, rhs, c.Z3_mk_rem);
        }
        pub fn mod(lhs: anytype, rhs: @TypeOf(lhs.*)) @TypeOf(lhs.*) {
            return numericBinop(@TypeOf(lhs.*), lhs, rhs, c.Z3_mk_mod);
        }
        pub fn power(lhs: anytype, rhs: @TypeOf(lhs.*)) Real {
            return numericBinop(@TypeOf(lhs.*), lhs, rhs, c.Z3_mk_power);
        }

        pub fn lt(lhs: anytype, rhs: @TypeOf(lhs.*)) Bool {
            return numericBinop(Bool, lhs, rhs, c.Z3_mk_lt);
        }
        pub fn le(lhs: anytype, rhs: @TypeOf(lhs.*)) Bool {
            return numericBinop(Bool, lhs, rhs, c.Z3_mk_le);
        }
        pub fn gt(lhs: anytype, rhs: @TypeOf(lhs.*)) Bool {
            return numericBinop(Bool, lhs, rhs, c.Z3_mk_gt);
        }
        pub fn ge(lhs: anytype, rhs: @TypeOf(lhs.*)) Bool {
            return numericBinop(Bool, lhs, rhs, c.Z3_mk_ge);
        }
        pub fn eq(lhs: anytype, rhs: @TypeOf(lhs.*)) Bool {
            return numericBinop(Bool, lhs, rhs, c.Z3_mk_eq);
        }

        fn numericVarop(lhs: anytype, rhss: []const @TypeOf(lhs.*), comptime func: @TypeOf(c.Z3_mk_add)) @TypeOf(lhs.*) {
            verifyNumeric();
            var buf: [16]c.Z3_ast = undefined;
            if (buf.len < rhss.len + 1) @panic("numericVarop only supports up to 15 rhs args.");
            buf[0] = lhs.ast;
            for (0..rhss.len) |i| buf[i + 1] = rhss[i].ast;
            const ast = func(lhs.ctx.inner, @intCast(rhss.len + 1), &buf);
            c.Z3_inc_ref(lhs.ctx.inner, ast);
            return .{ .ast = ast, .ctx = lhs.ctx };
        }

        pub fn add(lhs: anytype, rhss: []const @TypeOf(lhs.*)) @TypeOf(lhs.*) {
            return numericVarop(lhs, rhss, c.Z3_mk_add);
        }

        pub fn sub(lhs: anytype, rhss: []const @TypeOf(lhs.*)) @TypeOf(lhs.*) {
            return numericVarop(lhs, rhss, c.Z3_mk_sub);
        }

        pub fn mul(lhs: anytype, rhss: []const @TypeOf(lhs.*)) @TypeOf(lhs.*) {
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
        inline fn verifyBitvector() void {
            comptime if (ast_kind != .bv)
                @compileError(std.fmt.comptimePrint("expected bitvector (bv) ast kind.  found '{t}'", .{ast_kind}));
        }

        fn bvBinop(R: type, lhs: Bitvector, rhs: Bitvector, func: @TypeOf(c.Z3_mk_bvadd)) R {
            verifyBitvector();
            const ast = func(lhs.ctx.inner, lhs.ast, rhs.ast);
            c.Z3_inc_ref(lhs.ctx.inner, ast);
            return .{ .ast = ast, .ctx = lhs.ctx };
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
            return .{
                .ctx = lhs.ctx,
                .ast = c.Z3_mk_select(lhs.ctx.inner, lhs.ast, rhs.ast),
                .ast_kind = .fromAst(lhs),
            };
        }
    };
}

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

    pub fn constant(m: *Model, comptime tag: AstKind, name: ?[:0]const u8, args: anytype) tag.Data() {
        const sort = m.ctx.getSort(tag, args);
        const sym = Symbol.asZ3(.{ .string = name }, &m.ctx);
        const ast = c.Z3_mk_const(m.ctx.inner, sym, sort.inner);
        c.Z3_inc_ref(m.ctx.inner, ast);
        return .{ .ctx = &m.ctx, .ast = ast };
    }

    pub fn fromInt64(m: *Model, i: i64) Int {
        const sort = m.ctx.getSort(.int, .{});
        const ast = c.Z3_mk_int64(m.ctx.inner, i, sort.inner);
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
