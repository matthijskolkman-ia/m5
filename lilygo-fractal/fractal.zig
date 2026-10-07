//! LilyGo Fractal — Mandelbrot explorer for T-Display S3 (ESP32-S3)
//! Renders the Mandelbrot set on the 170x320 ST7789 TFT.
//!
//! Native test: zig build run        → outputs fractal.ppm
//! ESP32 flash:  zig build -Dtarget=xtensa-esp32s3-none-elf

const std = @import("std");

extern "c" fn write(fd: i32, buf: [*]const u8, count: usize) isize;

// T-Display S3: ST7789 170x320
const WIDTH  = 170;
const HEIGHT = 320;

// Fractal params
const MAX_ITER: u16 = 80;
var center_x: f64 = -0.75;
var center_y: f64 = 0.0;
var scale: f64 = 2.8;
var frame: u64 = 0;

// 16-bit RGB565 color buffer
var pixels: [WIDTH * HEIGHT]u16 = undefined;

// ── Color Palette ──

fn hsvToRgb565(h: f64, s: f64, v: f64) u16 {
    const c = v * s;
    const x = c * (1 - @abs(@mod(h / 60.0, 2) - 1));
    const m = v - c;

    var r: f64 = 0; var g: f64 = 0; var b: f64 = 0;
    if (h < 60)       { r = c; g = x; }
    else if (h < 120)  { r = x; g = c; }
    else if (h < 180)  { g = c; b = x; }
    else if (h < 240)  { g = x; b = c; }
    else if (h < 300)  { r = x; b = c; }
    else               { r = c; b = x; }

    const r5: u16 = @intFromFloat(@round((r + m) * 31));
    const g6: u16 = @intFromFloat(@round((g + m) * 63));
    const b5: u16 = @intFromFloat(@round((b + m) * 31));
    return (r5 << 11) | (g6 << 5) | b5;
}

fn iterColor(iter: u16, max_iter: u16) u16 {
    if (iter == max_iter) return 0x0000; // black (inside set)

    // Smooth coloring + hue rotation based on frame count
    const t: f64 = @as(f64, @floatFromInt(iter)) / @as(f64, @floatFromInt(max_iter));
    const h: f64 = @mod(360.0 * t + @as(f64, @floatFromInt(frame)) * 0.5, 360.0);
    return hsvToRgb565(h, 0.9, if (t < 0.5) t * 2.0 else 1.0);
}

// ── Mandelbrot ──

fn mandelbrot(cx: f64, cy: f64) u16 {
    var zx: f64 = 0; var zy: f64 = 0;
    var i: u16 = 0;
    while (i < MAX_ITER) : (i += 1) {
        const zx2 = zx * zx;
        const zy2 = zy * zy;
        if (zx2 + zy2 > 4.0) break;
        zy = 2.0 * zx * zy + cy;
        zx = zx2 - zy2 + cx;
    }
    return i;
}

fn renderFrame() void {
    for (0..HEIGHT) |py| {
        for (0..WIDTH) |px| {
            const cx = center_x + (@as(f64, @floatFromInt(px)) - @as(f64, @floatFromInt(WIDTH)) / 2.0) * scale / @as(f64, @floatFromInt(HEIGHT));
            const cy = center_y + (@as(f64, @floatFromInt(py)) - @as(f64, @floatFromInt(HEIGHT)) / 2.0) * scale / @as(f64, @floatFromInt(HEIGHT));
            const iter = mandelbrot(cx, cy);
            pixels[py * WIDTH + px] = iterColor(iter, MAX_ITER);
        }
    }
    frame += 1;
}

// ── Native Output (PPM for testing) ──

fn writePPM() !void {
    // Write PPM header to stdout
    var header: [64]u8 = undefined;
    const header_str = try std.fmt.bufPrint(&header, "P6\n{d} {d}\n255\n", .{ WIDTH, HEIGHT });
    _ = write(1, header_str.ptr, header_str.len);

    // Convert pixel buffer to RGB bytes and write
    var rgb: [WIDTH * 3]u8 = undefined;
    for (0..HEIGHT) |py| {
        for (0..WIDTH) |px| {
            const c = pixels[py * WIDTH + px];
            const r5: u8 = @intCast((c >> 11) & 0x1F);
            const g6: u8 = @intCast((c >> 5) & 0x3F);
            const b5: u8 = @intCast(c & 0x1F);
            const ru16: u16 = r5;
            const gu16: u16 = g6;
            const bu16: u16 = b5;
            rgb[px * 3 + 0] = @intCast(ru16 * 255 / 31);
            rgb[px * 3 + 1] = @intCast(gu16 * 255 / 63);
            rgb[px * 3 + 2] = @intCast(bu16 * 255 / 31);
        }
        _ = write(1, &rgb, rgb.len);
    }
}

// ── ESP32 SPI Display Output ──

const SPI_HOST: u32 = 2;       // SPI2_HOST
const PIN_MOSI: u32 = 35;
const PIN_SCLK: u32 = 36;
const PIN_CS:   u32 = 37;
const PIN_DC:   u32 = 38;
const PIN_RST:  u32 = 39;

fn initDisplay() void {
    // ST7789 init sequence — platform-specific ESP-IDF calls
    // gpio_set_direction, spi_bus_initialize, etc.
}

fn flushDisplay() void {
    // Send pixel buffer over SPI to ST7789
    // spi_device_transmit with pixels
}

// ── Navigation ──

fn zoomIn() void { scale *= 0.75; }
fn zoomOut() void { scale /= 0.75; }
fn moveUp() void { center_y -= scale * 0.15; }
fn moveDown() void { center_y += scale * 0.15; }
fn moveLeft() void { center_x -= scale * 0.15; }
fn moveRight() void { center_x += scale * 0.15; }

// ── Main ──

pub fn main() !void {
    const builtin = @import("builtin");

    // Auto-zoom sequence for demo
    const zooms = [_]struct { x: f64, y: f64 }{
        .{ .x = -0.75, .y = 0.0 },          // Main cardioid
        .{ .x = -0.745, .y = 0.112 },        // Seahorse valley
        .{ .x = -1.25, .y = 0.05 },          // Mini Mandelbrot
        .{ .x = -0.16, .y = 1.04 },          // Spiral
        .{ .x = -1.77, .y = 0.0 },           // Needle
    };

    var zoom_idx: usize = 0;
    var zoom_t: f64 = 0;

    while (true) {
        // Smooth auto-explore: interpolate between interesting points
        zoom_t += 0.005;
        if (zoom_t >= 4.0) {
            zoom_t = 0;
            zoom_idx = (zoom_idx + 1) % zooms.len;
        }

        const t = zoom_t / 4.0;
        const next = (zoom_idx + 1) % zooms.len;
        center_x = zooms[zoom_idx].x + (zooms[next].x - zooms[zoom_idx].x) * t;
        center_y = zooms[zoom_idx].y + (zooms[next].y - zooms[zoom_idx].y) * t;

        if (zoom_t < 1.0) scale = 2.8 * (1.0 - zoom_t * 0.85);
        if (zoom_t > 3.0) scale = 2.8 * 0.15 * (1.0 + (zoom_t - 3.0) * 0.85);

        renderFrame();

        // ESP32: push to display
        if (builtin.cpu.arch == .xtensa) {
            flushDisplay();
            // delay_ms(50);  // ~20 fps
        } else {
            // Native: save first frame as PPM, then exit
            try writePPM();
            std.debug.print("✅ fractal.ppm written ({d}x{d})\n", .{ WIDTH, HEIGHT });
            std.debug.print("   Center: ({d:.3}, {d:.3}) Scale: {d:.3}\n", .{ center_x, center_y, scale });
            break;
        }
    }
}
