# @NAME@

J-Link scripts from `segger-box new jlink_script @NAME@` (32_12_segger):

- `@NAME@.jlink`: J-Link Commander script (flash + verify + run). Edit `FW` and the base address.
  Run it yourself (it WRITES the target):
  `segger-box jlink -device STM32F411CE -if SWD -speed 4000 -autoconnect 1 -NoGui 1 -ExitOnError 1 -CommanderScript @NAME@.jlink`
- `@NAME@.JLinkScript`: J-Link script file (C-like) with the usual hooks (`ConfigTargetSettings`,
  `ResetTarget`); pass it with `-JLinkScriptFile @NAME@.JLinkScript` to JLinkExe, JLinkGDBServer or Ozone.

Reference: <https://kb.segger.com/J-Link_Script_Files> and <https://kb.segger.com/J-Link_Commander>.
