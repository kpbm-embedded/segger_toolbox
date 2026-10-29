# @NAME@

J-Link files for the WeAct STM32H743 (Cortex-M7), from `segger-box new jlink_script_h7 @NAME@` (32_12_segger):

- `@NAME@.JLinkScript`: selects AHB-AP 0 and sets `DBGMCU_CR` (debug in Sleep/Stop/Standby, D1/D3 debug
  clocks) after connect and after each reset, so a firmware that uses WFI keeps the J-Link connection.
- `@NAME@.jlink`: Commander script, `.bin` at 0x08000000 with `verifybin`.

    segger-box run @NAME@/check.sh             # offline checks (syntax with lib/jlinkscript_api.h, commands, ranges)
    segger-box gdbserver -device STM32H743VI -if SWD -speed 4000 -JLinkScriptFile @NAME@/@NAME@.JLinkScript -nogui
    segger-box jlink -device STM32H743VI -if SWD -speed 4000 -autoconnect 1 -JLinkScriptFile @NAME@/@NAME@.JLinkScript \
        -CommanderScript @NAME@/@NAME@.jlink         # WRITES flash (you run it)

Not verified with a probe here.
