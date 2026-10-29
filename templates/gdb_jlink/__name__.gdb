# @NAME@.gdb: flash and debug through JLinkGDBServer (port 2331), from `segger-box new gdb_jlink @NAME@`.
# Start the server:  segger-box gdbserver -device STM32F411CE -if SWD -speed 4000 -port 2331 -nogui
# Then:              arm-none-eabi-gdb -x @NAME@.gdb build/fw.elf      (inside `segger-box shell`)
set pagination off
set confirm off
target remote localhost:2331
monitor speed 4000
monitor reset
monitor halt
load
compare-sections
break main
continue
info registers pc
info symbol $pc
monitor regs
monitor reset
detach
