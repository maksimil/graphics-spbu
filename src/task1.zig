const config = @import("config.zig");

const Scalar = config.Scalar;

const RGBColor = struct { r: Scalar, g: Scalar, b: Scalar };
const XYZColor = struct { x: Scalar, y: Scalar, z: Scalar };
const CMYColor = struct { c: Scalar, m: Scalar, y: Scalar };
const CMYKColor = struct { c: Scalar, m: Scalar, y: Scalar, k: Scalar };
const HSVColor = struct { h: Scalar, s: Scalar, v: Scalar };
const HSLColor = struct { h: Scalar, s: Scalar, l: Scalar };

// rgb - xyz
// rgb - cmy - cmyk
// rgb - hsv - hsl
const convert = struct {
    pub fn XYZToRGB(c: XYZColor) RGBColor {
        return RGBColor{
            .r = 2.364 * c.x - 0.897 * c.y - 0.468 * c.z,
            .g = -0.515 * c.x + 1.426 * c.y + 0.089 * c.z,
            .b = 0.005 * c.x - 0.014 * c.y + 1.009 * c.z,
        };
    }

    pub fn RGBToXYZ(c: RGBColor) XYZColor {
        return XYZColor{
            .x = 0.490 * c.r + 0.310 * c.g + 0.200 * c.b,
            .y = 0.177 * c.r + 0.812 * c.g + 0.011 * c.b,
            .z = 0.000 * c.r + 0.010 * c.g + 0.990 * c.b,
        };
    }

    pub fn RGBToCMY(c: RGBColor) CMYColor {
        return CMYColor{
            .c = 1.0 - c.r,
            .m = 1.0 - c.g,
            .y = 1.0 - c.b,
        };
    }

    pub fn CMYToRGB(c: CMYColor) RGBColor {
        return RGBColor{
            .r = 1.0 - c.c,
            .g = 1.0 - c.m,
            .b = 1.0 - c.y,
        };
    }

    pub fn CMYToCMYK(c: CMYColor) CMYKColor {
        const k = @min(c.c, c.m, c.y, 1.0);

        return CMYKColor{
            .c = (c.c - k) / (1.0 - k),
            .m = (c.m - k) / (1.0 - k),
            .y = (c.y - k) / (1.0 - k),
            .k = k,
        };
    }

    pub fn CMYKToCMY(c: CMYKColor) CMYColor {
        return CMYColor{
            .c = c.c * (1.0 - c.k) + c.k,
            .m = c.m * (1.0 - c.k) + c.k,
            .y = c.y * (1.0 - c.k) + c.k,
        };
    }

    pub fn RGBToHSV(c: RGBColor) HSVColor {
        const xmax = @max(c.r, c.g, c.b);
        const xmin = @min(c.r, c.g, c.b);
        const chroma = xmax - xmin;

        var h = @as(Scalar, 0.0);

        if (chroma <= 1e-12) {
            h = 0.0;
        } else if (xmax == c.r) {
            h = 60.0 * config.ScalarMod((c.g - c.b) / chroma, 6.0);
        } else if (xmax == c.g) {
            h = 60.0 * ((c.b - c.r) / chroma + 2.0);
        } else if (xmax == c.b) {
            h = 60.0 * ((c.r - c.g) / chroma + 4.0);
        }

        var s = @as(Scalar, 0.0);

        if (xmax <= 1e-12) {
            s = 0.0;
        } else {
            s = chroma / xmax;
        }

        return HSVColor{
            .h = h,
            .s = s,
            .v = xmax,
        };
    }

    pub fn HSVToRGB(c: HSVColor) RGBColor {
        const chroma = c.s * c.v;
        const hueprime = c.h / 60.0;

        const x = chroma * (1.0 - @abs(config.ScalarMod(hueprime, 2.0) - 1));
        const m = c.v - chroma;

        var r1 = @as(Scalar, 0.0);
        var g1 = @as(Scalar, 0.0);
        var b1 = @as(Scalar, 0.0);

        if (hueprime >= 5.0) {
            r1 = chroma;
            b1 = x;
        } else if (hueprime >= 4.0) {
            r1 = x;
            b1 = chroma;
        } else if (hueprime >= 3.0) {
            g1 = x;
            b1 = chroma;
        } else if (hueprime >= 2.0) {
            g1 = chroma;
            b1 = x;
        } else if (hueprime >= 1.0) {
            r1 = x;
            g1 = chroma;
        } else {
            r1 = chroma;
            g1 = x;
        }

        return RGBColor{
            .r = r1 + m,
            .g = g1 + m,
            .b = b1 + m,
        };
    }

    pub fn HSVToHSL(c: HSVColor) HSLColor {
        const l = c.v * (1.0 - c.s / 2.0);
        var s = @as(Scalar, 0.0);

        if (l > 1e-12 and l < 1 - 1e-12) {
            s = (c.v - l) / @min(l, 1.0 - l);
        }

        return HSLColor{
            .h = c.h,
            .s = s,
            .l = l,
        };
    }

    pub fn HSLToHSV(c: HSLColor) HSVColor {
        const v = c.l + c.s * @min(c.l, 1.0 - c.l);
        var s = @as(Scalar, 0.0);

        if (v > 1e-12) {
            s = 2.0 * (1.0 - c.l / v);
        }

        return HSVColor{
            .h = c.h,
            .s = s,
            .v = v,
        };
    }
};

fn RGBDistance(x: RGBColor, y: RGBColor) Scalar {
    return @max(@abs(x.r - y.r), @abs(x.g - y.g), @abs(x.b - y.b));
}

pub fn Run() !void {
    const test_colors = [_]RGBColor{
        .{ .r = 1.0, .g = 0.0, .b = 0.0 },
        .{ .r = 0.0, .g = 1.0, .b = 0.0 },
        .{ .r = 0.0, .g = 0.0, .b = 1.0 },
        .{ .r = 0.6, .g = 0.3, .b = 0.1 },
        .{ .r = 0.2, .g = 0.1, .b = 0.0 },
    };

    for (0..test_colors.len) |i| {
        const rgb_color = test_colors[i];
        const to_xyz = convert.RGBToXYZ(rgb_color);
        const to_cmy = convert.RGBToCMY(rgb_color);
        const to_cmyk = convert.CMYToCMYK(to_cmy);
        const to_hsv = convert.RGBToHSV(rgb_color);
        const to_hsl = convert.HSVToHSL(to_hsv);

        try config.stdout.print(
            "\x1b[32min rgb : {any:.2}\x1b[0m\nto xyz : {any:.2}\nto cmy : {any:.2}\n" ++
                "to cmyk:{any:.2}\nto hsv : {any:.2}\nto hsl : {any:.2}\n\n",
            .{ rgb_color, to_xyz, to_cmy, to_cmyk, to_hsv, to_hsl },
        );

        const from_xyz = convert.XYZToRGB(to_xyz);
        const from_cmy = convert.CMYToRGB(to_cmy);
        const from_cmyk = convert.CMYToRGB(convert.CMYKToCMY(to_cmyk));
        const from_hsv = convert.HSVToRGB(to_hsv);
        const from_hsl = convert.HSVToRGB(convert.HSLToHSV(to_hsl));

        try config.stdout.print(
            "in xyz : {any:.2}\nto rgb : {any:.2}\n" ++
                "in cmy : {any:.2}\nto rgb : {any:.2}\n" ++
                "in cmyk:{any:.2}\nto rgb : {any:.2}\n" ++
                "in hsv : {any:.2}\nto rgb : {any:.2}\n" ++
                "in hsl : {any:.2}\nto rgb : {any:.2}\n\n",
            .{
                to_xyz,
                from_xyz,
                to_cmy,
                from_cmy,
                to_cmyk,
                from_cmyk,
                to_hsv,
                from_hsv,
                to_hsl,
                from_hsl,
            },
        );

        // test
        const xyz_err = RGBDistance(rgb_color, from_xyz);
        const cmy_err = RGBDistance(rgb_color, from_cmy);
        const cmyk_err = RGBDistance(rgb_color, from_cmyk);
        const hsv_err = RGBDistance(rgb_color, from_hsv);
        const hsl_err = RGBDistance(rgb_color, from_hsl);

        try config.stdout.print(
            "Errors: xyz={e:10.3}, cmy={e:10.3}, cmyk={e:10.3}, " ++
                "hsv={e:10.3}, hsl={e:10.3}\n\n",
            .{ xyz_err, cmy_err, cmyk_err, hsv_err, hsl_err },
        );
    }
}
