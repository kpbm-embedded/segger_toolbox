//! @NAME@: Zig firmware that prints over SEGGER RTT. SEGGER's C sources (and startup.c) are compiled
//! by the pinned arm-none-eabi-gcc against newlib's headers and linked by Zig, which also supplies
//! memcpy/memset (compiler_rt). Zig 0.17 has no @cImport any more: the three functions are declared here.
const rtt = struct {
    extern fn SEGGER_RTT_Init() void;
    extern fn SEGGER_RTT_WriteString(buffer_index: c_uint, s: [*:0]const u8) c_uint;
    extern fn SEGGER_RTT_printf(buffer_index: c_uint, fmt: [*:0]const u8, ...) c_int;
};

fn fib(n: u32) u32 {
    var a: u32 = 0;
    var b: u32 = 1;
    var i: u32 = 0;
    while (i < n) : (i += 1) {
        const t = a + b;
        a = b;
        b = t;
    }
    return a;
}

export fn main() c_int {
    rtt.SEGGER_RTT_Init();
    _ = rtt.SEGGER_RTT_WriteString(0, "@NAME@: hello from Zig\n");
    var n: u32 = 10;
    while (n <= 30) : (n += 10) {
        _ = rtt.SEGGER_RTT_printf(0, "@NAME@: fib(%u) = %u\n", n, fib(n));
    }
    _ = rtt.SEGGER_RTT_WriteString(0, "@NAME@: done\n");
    return 0;
}
