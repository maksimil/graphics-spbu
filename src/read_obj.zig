const std = @import("std");
const config = @import("config.zig");

const Scalar = config.Scalar;

pub const ObjVertex = struct { x: Scalar, y: Scalar, z: Scalar };
pub const ObjFace = [3]usize;

pub const ObjData = struct {
    vertices: std.ArrayList(ObjVertex),
    faces: std.ArrayList(ObjFace),

    pub fn init(allocator: std.mem.Allocator) ObjData {
        const self = @This(){
            .vertices = std.ArrayList(ObjVertex).init(allocator),
            .faces = std.ArrayList(ObjFace).init(allocator),
        };

        return self;
    }

    pub fn deinit(self: @This()) void {
        self.vertices.deinit();
        self.faces.deinit();
    }
};

fn IdxTo(line: []const u8, start: usize, delim: u8) usize {
    var end = start;

    while (end < line.len) {
        if (line[end] == delim) {
            return end;
        }
        end += 1;
    }

    return end;
}

const ParseObjError = error{ Vertex, Face };

fn ParseFaceVertex(s: []const u8) !usize {
    const end = IdxTo(s, 0, '/');
    return try std.fmt.parseInt(usize, s[0..end], 10);
}

fn ParseObjLine(line: []const u8, obj_data: *ObjData) !void {
    if (line.len == 0) {
        return;
    }

    var i: usize = 0;
    var j: usize = IdxTo(line, i, ' ');
    const tag = line[i..j];
    i = j;

    if (std.mem.eql(u8, tag, "v")) {
        var vertex = ObjVertex{ .x = 0, .y = 0, .z = 0 };

        if (i >= line.len) {
            return ParseObjError.Vertex;
        }
        i += 1;
        j = IdxTo(line, i, ' ');
        vertex.x = try std.fmt.parseFloat(Scalar, line[i..j]);
        i = j;

        if (i >= line.len) {
            return ParseObjError.Vertex;
        }
        i += 1;
        j = IdxTo(line, i, ' ');
        vertex.y = try std.fmt.parseFloat(Scalar, line[i..j]);
        i = j;

        if (i >= line.len) {
            return ParseObjError.Vertex;
        }
        i += 1;
        j = IdxTo(line, i, ' ');
        vertex.z = try std.fmt.parseFloat(Scalar, line[i..j]);
        i = j;

        try obj_data.vertices.append(vertex);
    } else if (std.mem.eql(u8, tag, "f")) {
        var face: ObjFace = .{ 0, 0, 0 };

        if (i >= line.len) {
            return ParseObjError.Vertex;
        }
        i += 1;
        j = IdxTo(line, i, ' ');
        face[0] = (try ParseFaceVertex(line[i..j])) - 1;
        i = j;

        if (i >= line.len) {
            return ParseObjError.Vertex;
        }
        i += 1;
        j = IdxTo(line, i, ' ');
        face[1] = (try ParseFaceVertex(line[i..j])) - 1;
        i = j;

        if (i >= line.len) {
            return ParseObjError.Vertex;
        }
        i += 1;
        j = IdxTo(line, i, ' ');
        face[2] = (try ParseFaceVertex(line[i..j])) - 1;
        i = j;

        try obj_data.faces.append(face);
    }
}

pub fn ParseObj(source: std.io.AnyReader) !ObjData {
    var data = ObjData.init(config.allocator);
    errdefer data.deinit();

    var eof = false;

    var buffer = std.ArrayList(u8).init(config.allocator);
    defer buffer.deinit();

    while (!eof) {
        const stream_res = source.streamUntilDelimiter(buffer.writer(), '\n', null);

        if (stream_res) |_| {
            eof = false;
        } else |err| {
            if (err == error.EndOfStream) {
                eof = true;
            } else {
                return err;
            }
        }

        try ParseObjLine(buffer.items, &data);
        buffer.clearRetainingCapacity();
    }

    return data;
}
