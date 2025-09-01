const std = @import("std");
const z3 = @import("z3");

pub fn main() !void {
    var gpa_state: std.heap.DebugAllocator(.{}) = .{};
    const gpa = gpa_state.allocator();
    try basic(gpa);
}

fn basic(gpa: std.mem.Allocator) !void {
    var model = try z3.Model.init(.solver, gpa);
    defer model.deinit(gpa);

    const x = model.constant(.int, "x", .{});
    const y = model.constant(.int, "y", .{});
    const xaddy = x.add(&.{y});
    const ten = model.int64(10);
    model.assert(xaddy.eq(ten));
    std.debug.print("result: {}\n", .{model.check()});

    const pmodel = model.getLastModel();
    defer pmodel.deinit();
    const xv = pmodel.eval(x, true).?.int64().?;
    const yv = pmodel.eval(y, true).?.int64().?;
    std.debug.print("x: {} y: {}\n", .{ xv, yv });
}
