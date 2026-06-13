const std = @import("std");
const z3 = @import("z3");

pub fn main() !void {
    basic();
}

fn basic() void {
    var model = z3.Model.initSolver();
    defer model.deinit();

    const x = model.constant(.int, "x", .{});
    const y = model.constant(.int, "y", .{});
    const xaddy = x.add(&.{y});
    const ten = model.fromInt64(10);
    model.assert(xaddy.eq(ten));
    std.debug.print("result: {}\n", .{model.check()});

    const pmodel = model.getLastModel();
    defer pmodel.deinit();
    const xv = pmodel.eval(x, true).?.asInt64().?;
    const yv = pmodel.eval(y, true).?.asInt64().?;
    std.debug.print("x: {} y: {}\n", .{ xv, yv });
}
