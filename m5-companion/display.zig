// M5 Companion Display — Zig firmware for LilyGo T-Display S3 (ESP32-S3)
// Fetches M5 system stats over WiFi and renders on the 1.9" TFT.
//
// Prerequisites:
//   brew install zig
//   git clone https://github.com/microzig/microzig
//   Refer to microzig docs for ESP32-S3 flashing
//
// Build: zig build -Dtarget=xtensa-esp32s3-none-elf

const std = @import("std");
const http = @import("http"); // from microzig or esp-idf

// WiFi credentials — CHANGE THESE
const WIFI_SSID = "your_wifi";
const WIFI_PASS = "your_password";

// M5 Mac's IP — find with: ipconfig getifaddr en0
const SERVER_IP = "192.168.1.253";
const SERVER_PORT = 5099;

// T-Display S3 TFT: ST7789 170x320
const TFT_WIDTH = 170;
const TFT_HEIGHT = 320;

// Color palette
const COLOR_BG: u16 = 0x0000;    // Black
const COLOR_TEXT: u16 = 0xFFFF;  // White
const COLOR_CPU: u16 = 0x07E0;   // Green
const COLOR_RAM: u16 = 0x001F;   // Blue
const COLOR_ACCENT: u16 = 0xFFE0; // Yellow
const COLOR_RED: u16 = 0xF800;    // Red

var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

var display_buf: [TFT_WIDTH * TFT_HEIGHT]u16 = undefined;

// ── Stats ──
const M5Stats = struct {
    host: []const u8,
    cpu: f32,
    ram: f32,
    uptime: []const u8,
    phone: []const u8,
};

fn fetchStats() !M5Stats {
    // HTTP GET to Mac server
    const url = try std.fmt.allocPrint(allocator, "http://{s}:{d}/stats", .{ SERVER_IP, SERVER_PORT });
    defer allocator.free(url);

    // In microzig/ESP-IDF: use esp_http_client
    // Simplified — actual HTTP call depends on the ESP framework used
    // Returns dummy for now; replace with real HTTP in ESP environment

    return M5Stats{
        .host = "M5",
        .cpu = 0.0,
        .ram = 0.0,
        .uptime = "?",
        .phone = "?",
    };
}

// ── Drawing Primitives (ST7789 via SPI) ──

fn fillScreen(color: u16) void {
    @memset(&display_buf, color);
    flushDisplay();
}

fn drawText(x: i32, y: i32, text: []const u8, color: u16, scale: u8) void {
    // Simplified — uses built-in TFT_eSPI-like functions on ESP
    _ = x; _ = y; _ = text; _ = color; _ = scale;
}

fn drawBar(x: i32, y: i32, w: i32, h: i32, pct: f32, color: u16) void {
    const fill_w: i32 = @intFromFloat(@as(f32, @floatFromInt(w)) * (pct / 100.0));
    _ = x; _ = y; _ = fill_w; _ = h; _ = color;
}

fn flushDisplay() void {
    // SPI transfer to ST7789
}

// ── Main ──

pub fn main() !void {
    // Init display
    fillScreen(COLOR_BG);

    // Connect WiFi (ESP-IDF specific)
    drawText(10, 20, "Connecting WiFi...", COLOR_ACCENT, 2);
    // wifi_connect(WIFI_SSID, WIFI_PASS); // ESP-IDF call

    // Main loop — update every 2 seconds
    while (true) {
        if (fetchStats()) |stats| {
            fillScreen(COLOR_BG);

            // Header
            drawText(10, 10, "M5 STATUS", COLOR_ACCENT, 2);

            // Hostname
            var host_line: [64]u8 = undefined;
            const host_text = try std.fmt.bufPrint(&host_line, "Host: {s}", .{stats.host});
            drawText(10, 40, host_text, COLOR_TEXT, 2);

            // CPU bar
            drawText(10, 80, "CPU", COLOR_CPU, 2);
            drawBar(10, 105, 150, 15, stats.cpu, COLOR_CPU);
            var cpu_text: [16]u8 = undefined;
            const cpu_label = try std.fmt.bufPrint(&cpu_text, "{d:.1}%", .{stats.cpu});
            drawText(10, 125, cpu_label, COLOR_TEXT, 2);

            // RAM bar
            drawText(10, 155, "RAM", COLOR_RAM, 2);
            drawBar(10, 180, 150, 15, stats.ram, COLOR_RAM);
            var ram_text: [16]u8 = undefined;
            const ram_label = try std.fmt.bufPrint(&ram_text, "{d:.1}%", .{stats.ram});
            drawText(10, 200, ram_label, COLOR_TEXT, 2);

            // Uptime
            var up_line: [64]u8 = undefined;
            const up_text = try std.fmt.bufPrint(&up_line, "Up: {s}", .{stats.uptime});
            drawText(10, 240, up_text, COLOR_TEXT, 1);

            // iPhone nearby
            var phone_color: u16 = if (std.mem.eql(u8, stats.phone, "Yes")) COLOR_CPU else COLOR_RED;
            var phone_line: [64]u8 = undefined;
            const phone_text = try std.fmt.bufPrint(&phone_line, "iPhone: {s}", .{stats.phone});
            drawText(10, 270, phone_text, phone_color, 2);

            flushDisplay();
        } else |_| {
            drawText(10, 150, "No connection", COLOR_RED, 2);
            flushDisplay();
        }

        // Wait 2 seconds
        // delay_ms(2000);
    }
}
