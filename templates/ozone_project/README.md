# @NAME@

Ozone debugger project, from `segger-box new ozone_project @NAME@` (32_12_segger): device, SWD at 4 MHz,
the Cortex-M4F SVD that ships with Ozone, the ELF at `build/@NAME@.elf`, and the usual
`AfterTargetDownload` (SP/PC from the vector table).

    segger-box run @NAME@/check.sh path/to/fw.elf     # offline: copies the ELF, checks the project script
    segger-box ozone @NAME@/@NAME@.jdebug               # with the licensed Ozone and a probe (you)

`check.sh` cannot start Ozone (GUI, licensed); it checks the script's actions and hooks against the list in
`lib/jlink_check.py` and compiles it as C. Not verified with Ozone or a probe here.
