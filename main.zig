const std = @import("std");
const assert = std.debug.assert;

/// Reset and Clock Control registers
pub const Rcc = packed struct {
    // zig fmt: off
    clock_ctrl: u32,        // Offset: 0x00
    pll_cfg: u32,           // Offset: 0x04
    clock_cfg: u32,         // Offset: 0x08
    clock_interrupt: u32,   // Offset: 0x0C
    ahb1_reset: u32,        // Offset: 0x10
    ahb2_reset: u32,        // Offset: 0x14
    ahb3_reset: u32,        // Offset: 0x18
    _reserved0: u32,        // Offset: 0x1C
    apb1_reset: u32,        // Offset: 0x20
    apb2_reset: u32,        // Offset: 0x24
    _reserved1: u32,        // Offset: 0x28
    _reserved2: u32,        // Offset: 0x2C
    ahb1_enable: u32,       // Offset: 0x30
    ahb2_enable: u32,       // Offset: 0x34
    ahb3_enable: u32,       // Offset: 0x38
    _reserved3: u32,        // Offset: 0x3C
    apb1_enable: u32,       // Offset: 0x40
    apb2_enable: u32,       // Offset: 0x44
    _reserved4: u32,        // Offset: 0x48
    _reserved5: u32,        // Offset: 0x4C
    // TODO(oliver): Make these names nice
    ahb1lpenr: u32,
    ahb2lpenr: u32,
    ahb3lpenr: u32,
    _reserved6: u32,
    apb1lpenr: u32,
    apb2lpenr: u32,
    _reserved7: u32,
    _reserved8: u32,
    bdcr: u32,
    csr: u32,
    _reserved9: u32,
    _reserved10: u32,
    sscgr: u32,
    plli2scfgr: u32,
    pllsaicfgr: u32,
    dckcfgr: u32,
    ckgatenr: u32,
    dckcfgr2: u32,
    // zig fmt: on

    const Self = @This();

    // Register location
    const rcc: *volatile Self = @ptrFromInt(0x40023800);

    /// Enable the clock for a given GPIO bank
    pub fn enable_gpio_bank_clock(bank_char: u8) void {
        assert('A' <= bank_char and bank_char <= 'H');
        rcc.ahb1_enable |= @as(u32, 1) << @intCast(bank_char - 'A');
    }
};

const GpioMode = enum(u2) {
    input = 0b00,
    output = 0b01,
    alt = 0b10,
    analog = 0b11,
};

pub const GpioBank = packed struct {
    mode: u32,
    output_type: u32,
    output_speed: u32,
    pu_pd: u32,
    input_data: u32,
    output_data: u32,
    bit_set_reset: u32,
    lckr: u32,
    alt_func_low: u32,
    alt_func_high: u32,

    const Self = @This();

    /// Get a given bank
    fn get(bank: u8) *volatile Self {
        return @ptrFromInt(0x40020000 + 0x400 * @as(usize, @intCast(bank)));
    }
};

const GpioPin = struct {
    bank: u8,
    num: u8,

    const Self = @This();

    /// Get a Pin from the bank and pinnum
    fn create(bank_char: u8, num: u8) Self {
        assert('A' <= bank_char and bank_char <= 'H');
        assert(num <= 16);
        return Self{
            .bank = bank_char - 'A',
            .num = num,
        };
    }

    /// Set GPIO pin mode
    pub fn gpio_set_mode(self: GpioPin, mode: GpioMode) void {
        var gpio: *volatile GpioBank = GpioBank.get(self.bank); // Get GPIO bank
        gpio.mode &= ~(@as(u32, 0b11) << @intCast(self.num * 2)); // Clear setting
        gpio.mode |= @as(u32, @intCast(@intFromEnum(mode) & 0b11)) << @intCast(self.num * 2); // Set setting
    }

    /// Set digital GPIO pin
    pub fn gpio_write(self: GpioPin, value: bool) void {
        var gpio_bank: *volatile GpioBank = GpioBank.get(self.bank);
        gpio_bank.bit_set_reset |= (@as(u32, 1) << @intCast(self.num)) << (if (value) 0 else 16);
    }
};

/// Nop for a bit
fn spin(n: usize) void {
    for (0..n) |_| {}
}

// Entry Point!
fn main() u32 {
    const led_pin = GpioPin.create('A', 5);
    Rcc.enable_gpio_bank_clock('A');
    led_pin.gpio_set_mode(GpioMode.output);

    while (true) {
        led_pin.gpio_write(true);
        spin(999999);
        led_pin.gpio_write(false);
        spin(999999);
    }

    return 0;
}

extern const _sbss: u32;
extern const _ebss: u32;
extern const _sidata: u32;
extern const _sdata: u32;
extern const _edata: u32;

export fn _reset() noreturn {
    // Clear the BSS
    var bss: [*]u32 = @ptrCast(&_sbss);
    const bss_size = (@intFromPtr(&_sbss) - @intFromPtr(&_ebss)) / @sizeOf(u32);
    @memset(bss[0..bss_size], 0);

    // Copy data from flash to RAM
    const idata: [*]u32 = @ptrCast(&_sidata);
    var data: [*]u32 = @ptrCast(&_sdata);
    var data_len = (@intFromPtr(&_edata) - @intFromPtr(&_sdata)) / @sizeOf(u32);
    @memcpy(data[0..data_len], idata);

    _ = main();
    while (true) {}
}

// Stack ptr address, but we're gonna declare it as a function to avoid type errors.
extern fn _estack() void;

export const tab linksection(".vectors") = [_]?*const anyopaque{
    @ptrCast(&_estack),
    @ptrCast(&_reset),
} ++ [_]?*const anyopaque{null} ** (16 + 96 - 2);
