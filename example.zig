const std = @import("std");
const z3 = @import("z3");

pub fn main() !void {
    var gpa_state: std.heap.DebugAllocator(.{}) = .{};
    const gpa = gpa_state.allocator();
    try basic(gpa);
}

fn basic(gpa: std.mem.Allocator) !void {
    var solver = try z3.Solver.init(gpa);
    defer solver.deinit(gpa);

    const x = solver.constant(.int, "x", .{});
    const y = solver.constant(.int, "y", .{});
    const xaddy = x.add(&.{y});
    const ten = solver.int64(10);
    solver.assert(xaddy.eq(ten));
    std.debug.print("result: {}\n", .{solver.check()});

    const model = solver.getLastModel();
    defer model.deinit();
    const xv = model.eval(x, true).?.int64().?;
    const yv = model.eval(y, true).?.int64().?;
    std.debug.print("x: {} y: {}\n", .{ xv, yv });
}
