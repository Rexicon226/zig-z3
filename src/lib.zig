const std = @import("std");
const c = @import("z3");
const assert = std.debug.assert;

fn errorHandler(ctx: c.Z3_context, e: c.Z3_error_code) callconv(.c) void {
    std.debug.print("Error #{}: {s}\nIncorrect use of Z3.\n", .{ e, c.Z3_get_error_msg(ctx, e) });
    std.process.exit(1);
}

pub const Context = struct {
    inner: c.Z3_context,
    /// stored on the heap to keep Context small and copyable
    cached_sorts: *CachedSorts,

    /// sorts that can be cached whose mk_*_sort method has one argument
    const CachedSorts = struct {
        bool: ?c.Z3_sort = null,
        int: ?c.Z3_sort = null,
        real: ?c.Z3_sort = null,
        float32: ?c.Z3_sort = null,
        double: ?c.Z3_sort = null,
        string: ?c.Z3_sort = null,
    };

    pub const ConfigKvs = []const [2][:0]const u8;

    pub fn init(allocator: std.mem.Allocator, kvs: ConfigKvs) !Context {
        const cfg = c.Z3_mk_config();
        defer c.Z3_del_config(cfg);
        for (kvs) |kv| {
            c.Z3_set_param_value(cfg, kv[0].ptr, kv[1].ptr);
        }
        const inner = c.Z3_mk_context_rc(cfg);
        c.Z3_set_error_handler(inner, errorHandler);
        const cached_sorts = try allocator.create(CachedSorts);
        cached_sorts.* = .{};
        return .{ .inner = inner, .cached_sorts = cached_sorts };
    }

    pub fn deinit(ctx: Context, allocator: std.mem.Allocator) void {
        allocator.destroy(ctx.cached_sorts);
        c.Z3_del_context(ctx.inner);
    }

    fn getSort(ctx: Context, comptime tag: AstKind, args: anytype) c.Z3_sort {
        if (@hasField(CachedSorts, @tagName(tag))) {
            comptime assert(args.len == 0);
            if (@field(ctx.cached_sorts, @tagName(tag))) |sort| return sort;
            const sort = @field(c, "Z3_mk_" ++ @tagName(tag) ++ "_sort")(ctx.inner);
            c.Z3_inc_ref(ctx.inner, c.Z3_sort_to_ast(ctx.inner, sort));
            @field(ctx.cached_sorts, @tagName(tag)) = sort;
            return sort;
        }

        const sort = @call(.auto, @field(c, "Z3_mk_" ++ @tagName(tag) ++ "_sort"), .{ctx.inner} ++ args);
        c.Z3_inc_ref(ctx.inner, c.Z3_sort_to_ast(ctx.inner, sort));
        return sort;
    }
};

pub const AstKind = enum {
    bool,
    int,
    real,
    float,
    float32,
    double,
    string,
    bv,
    array,
    set,
    seq,

    fn Type(tag: AstKind) type {
        return switch (tag) {
            .bool => Bool,
            .int => Int,
            .real => Real,
            .float => Float,
            .float32 => Float32,
            .double => Double,
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
            .double,
            => true,
            else => false,
        };
    }
};

pub const Bool = Ast(struct {
    pub const ast_kind: AstKind = .bool;
});
pub const Int = Ast(struct {
    pub const ast_kind: AstKind = .int;
});
pub const Real = Ast(struct {
    pub const ast_kind: AstKind = .real;
});
pub const Float = Ast(struct {
    pub const ast_kind: AstKind = .float;
});
pub const Float32 = Ast(struct {
    pub const ast_kind: AstKind = .float32;
});
pub const Double = Ast(struct {
    pub const ast_kind: AstKind = .double;
});
pub const String = Ast(struct {
    pub const ast_kind: AstKind = .string;
});
pub const Bitvector = Ast(struct {
    pub const ast_kind: AstKind = .bv;
});
pub const Array = Ast(struct {
    pub const ast_kind: AstKind = .array;
});
pub const Set = Ast(struct {
    pub const ast_kind: AstKind = .set;
});
pub const Seq = Ast(struct {
    pub const ast_kind: AstKind = .seq;
});

comptime {
    assert(Bool != Int);
}

pub fn Ast(T: type) type {
    return struct {
        // store ctx to allow a builder pattern. i.e. `x.div(y)`
        ctx: Context,
        ast: c.Z3_ast,

        const Self = @This();

        pub fn deinit(self: Self) void {
            c.Z3_dec_ref(self.ctx.inner, self.ast);
        }

        // *** Numeric ops ***
        fn numericBinop(R: type, lhs: Self, rhs: Self, func: @TypeOf(c.Z3_mk_div)) R {
            comptime if (!T.ast_kind.isNumeric()) unreachable;
            const ast = func(lhs.ctx.inner, lhs.ast, rhs.ast);
            c.Z3_inc_ref(lhs.ctx.inner, ast);
            return .{ .ast = ast, .ctx = lhs.ctx };
        }

        pub fn div(lhs: Self, rhs: Self) Self {
            return numericBinop(Self, lhs, rhs, c.Z3_mk_div);
        }
        pub fn rem(lhs: Self, rhs: Self) Self {
            return numericBinop(Self, lhs, rhs, c.Z3_mk_rem);
        }
        pub fn mod(lhs: Self, rhs: Self) Self {
            return numericBinop(Self, lhs, rhs, c.Z3_mk_mod);
        }
        pub fn power(lhs: Self, rhs: Self) Real {
            return numericBinop(Self, lhs, rhs, c.Z3_mk_power);
        }

        pub fn lt(lhs: Self, rhs: Self) Bool {
            return numericBinop(Bool, lhs, rhs, c.Z3_mk_lt);
        }
        pub fn le(lhs: Self, rhs: Self) Bool {
            return numericBinop(Bool, lhs, rhs, c.Z3_mk_le);
        }
        pub fn gt(lhs: Self, rhs: Self) Bool {
            return numericBinop(Bool, lhs, rhs, c.Z3_mk_gt);
        }
        pub fn ge(lhs: Self, rhs: Self) Bool {
            return numericBinop(Bool, lhs, rhs, c.Z3_mk_ge);
        }
        pub fn eq(lhs: Self, rhs: Self) Bool {
            return numericBinop(Bool, lhs, rhs, c.Z3_mk_eq);
        }

        fn numericVarop(lhs: Self, rhss: []const Self, comptime func: @TypeOf(c.Z3_mk_add)) Self {
            comptime if (!T.ast_kind.isNumeric()) unreachable;
            var buf: [16]c.Z3_ast = undefined;
            if (buf.len < rhss.len + 1) @panic("numericVarop only supports up to 15 rhs args.");
            buf[0] = lhs.ast;
            for (0..rhss.len) |i| buf[i + 1] = rhss[i].ast;
            const ast = func(lhs.ctx.inner, @intCast(rhss.len + 1), &buf);
            c.Z3_inc_ref(lhs.ctx.inner, ast);
            return .{ .ast = ast, .ctx = lhs.ctx };
        }

        pub fn add(lhs: Self, rhss: []const Self) Self {
            return numericVarop(lhs, rhss, c.Z3_mk_add);
        }

        pub fn sub(lhs: Self, rhss: []const Self) Self {
            return numericVarop(lhs, rhss, c.Z3_mk_sub);
        }

        pub fn mul(lhs: Self, rhss: []const Self) Self {
            return numericVarop(lhs, rhss, c.Z3_mk_mul);
        }

        pub fn int64(ast: Self) ?i64 {
            var ret: i64 = undefined;
            return if (c.Z3_get_numeral_int64(ast.ctx.inner, ast.ast, &ret))
                ret
            else
                null;
        }

        // *** Bitvector ops ***
        fn bvBinop(R: type, lhs: Bitvector, rhs: Bitvector, func: @TypeOf(c.Z3_mk_bvadd)) R {
            comptime if (T.ast_kind != .bv) unreachable;
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
    };
}

pub const Symbol = union(enum) {
    int: i32,
    string: ?[:0]const u8,

    pub const Tag = std.meta.Tag(Symbol);

    fn asZ3(sym: Symbol, ctx: Context) c.Z3_symbol {
        return switch (sym) {
            .int => |i| c.Z3_mk_int_symbol(ctx.inner, i),
            .string => |s| c.Z3_mk_string_symbol(ctx.inner, @ptrCast(s)),
        };
    }
};

pub const Sort = struct {
    ctx: Context,
    inner: c.Z3_sort,
};

pub const Solver = struct {
    ctx: Context,
    inner: c.Z3_solver,

    pub fn initCtx(ctx: Context) Solver {
        const inner = c.Z3_mk_solver(ctx.inner);
        c.Z3_solver_inc_ref(ctx.inner, inner);
        return .{ .ctx = ctx, .inner = inner };
    }

    pub fn initConfig(allocator: std.mem.Allocator, config_kvs: Context.ConfigKvs) !Solver {
        return .initCtx(try .init(allocator, config_kvs));
    }

    pub fn init(gpa: std.mem.Allocator) !Solver {
        return initConfig(gpa, &.{.{ "proof", "true" }});
    }

    pub fn deinit(s: Solver, allocator: std.mem.Allocator) void {
        c.Z3_solver_dec_ref(s.ctx.inner, s.inner);
        s.ctx.deinit(allocator);
    }

    /// Panics if
    /// 1. `check()` wasn't ran before calling `getLastModel()`.
    /// 2. The last `check()` call didn't return `true`.
    pub fn getLastModel(s: Solver) Model {
        const m = c.Z3_solver_get_model(s.ctx.inner, s.inner);
        c.Z3_model_inc_ref(s.ctx.inner, m);
        return .{ .ctx = s.ctx, .inner = m };
    }

    pub fn assert(s: Solver, ast: anytype) void {
        c.Z3_solver_assert(s.ctx.inner, s.inner, ast.ast);
    }

    pub fn check(s: Solver) SatResult {
        return @enumFromInt(c.Z3_solver_check(s.ctx.inner, s.inner));
    }

    pub fn constant(s: Solver, comptime tag: AstKind, name: ?[:0]const u8, args: anytype) tag.Type() {
        const sort = s.ctx.getSort(tag, args);
        const sym = Symbol.asZ3(.{ .string = name }, s.ctx);
        const ast = c.Z3_mk_const(s.ctx.inner, sym, sort);
        c.Z3_inc_ref(s.ctx.inner, ast);
        return .{ .ctx = s.ctx, .ast = ast };
    }

    pub fn int64(s: Solver, i: i64) Int {
        const sort = s.ctx.getSort(.int, .{});
        const ast = c.Z3_mk_int64(s.ctx.inner, i, sort);
        c.Z3_inc_ref(s.ctx.inner, ast);
        return .{ .ctx = s.ctx, .ast = ast };
    }

    pub fn bvFromInt64(s: Solver, i: i64, sz: u32) Bitvector {
        const sort = s.ctx.getSort(.bv, .{sz});
        const ast = c.Z3_mk_int64(s.ctx.inner, i, sort);
        c.Z3_inc_ref(s.ctx.inner, ast);
        return .{ .ctx = s.ctx, .ast = ast };
    }

    fn makeSort(s: Solver, comptime func: @TypeOf(c.Z3_mk_bool_sort)) Sort {
        const sort = func(s.ctx.inner);
        c.Z3_inc_ref(s.ctx.inner, sort);
        return .{ .ctx = s.ctx, .inner = sort };
    }

    pub fn boolean(s: Solver) Sort {
        return s.makeSort(c.Z3_mk_bool_sort);
    }

    pub fn int(s: Solver) Sort {
        return s.makeSort(c.Z3_mk_int_sort);
    }

    pub fn real(s: Solver) Sort {
        return s.makeSort(c.Z3_mk_real_sort);
    }

    pub fn float(s: Solver, ebits: u32, sbits: u32) Sort {
        const sort = c.Z3_mk_fpa_sort(s.ctx.inner, ebits, sbits);
        c.Z3_inc_ref(s.ctx.inner, sort);
        return .{ .ctx = s.ctx, .inner = sort };
    }

    pub fn float32(s: Solver) Sort {
        const sort = c.Z3_mk_fpa_sort(s.ctx.inner, 8, 24);
        c.Z3_inc_ref(s.ctx.inner, sort);
        return .{ .ctx = s.ctx, .inner = sort };
    }

    pub fn double(s: Solver) Sort {
        const sort = c.Z3_mk_fpa_sort(s.ctx.inner, 11, 53);
        c.Z3_inc_ref(s.ctx.inner, sort);
        return .{ .ctx = s.ctx, .inner = sort };
    }

    pub fn string(s: Solver) Sort {
        return s.makeSort(c.Z3_mk_string_sort);
    }

    pub fn bv(s: Solver, sz: u32) Sort {
        const sort = c.Z3_mk_bv_sort(s.ctx.inner, sz);
        c.Z3_inc_ref(s.ctx.inner, sort);
        return .{ .ctx = s.ctx, .inner = sort };
    }

    pub fn array(s: Solver, domain: Sort, range: Sort) Sort {
        const sort = c.Z3_mk_array_sort(s.ctx.inner, domain.z3_sort, range.z3_sort);
        c.Z3_inc_ref(s.ctx.inner, sort);
        return .{ .ctx = s.ctx, .inner = sort };
    }

    pub fn set(s: Solver, elt: *const Sort) Sort {
        const sort = c.Z3_mk_set_sort(s.ctx.inner, elt.z3_sort);
        c.Z3_inc_ref(s.ctx.inner, sort);
        return .{ .ctx = s.ctx, .inner = sort };
    }

    pub fn seq(s: Solver, elt: *const Sort) Sort {
        const sort = c.Z3_mk_seq_sort(s.ctx.inner, elt.z3_sort);
        c.Z3_inc_ref(s.ctx.inner, sort);
        return .{ .ctx = s.ctx, .inner = sort };
    }
};

pub const Model = struct {
    ctx: Context,
    inner: c.Z3_model,

    pub fn deinit(m: Model) void {
        c.Z3_model_dec_ref(m.ctx.inner, m.inner);
    }

    pub fn eval(m: Model, ast: anytype, model_completion: bool) ?@TypeOf(ast) {
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
