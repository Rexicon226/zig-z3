const std = @import("std");
const z3 = @import("z3");

const Model = z3.Model;

pub fn main() !void {
    var model = Model.init(.solver);
    defer model.deinit();

    const x = model.constant(.int, "x");
    const y = model.constant(.int, "y");

    const constraint = model.eq(
        model.add(.{ x, y }),
        model.int(10),
    );

    model.assert(constraint);

    std.debug.print("result: {}\n", .{model.check()});
}
