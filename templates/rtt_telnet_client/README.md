# @NAME@

RTT client for CI scripts, from `segger-box new rtt_telnet_client @NAME@` (32_12_segger). Python standard
library only. It connects to the RTT telnet port 19021 that JLinkGDBServer opens while it runs, prints and
logs each line with a timestamp, and sets the exit code from `--expect` / `--fail` regexes.

    segger-box gdbserver -device STM32F411CE -if SWD -speed 4000 -nogui &      # with a probe (you)
    python3 @NAME@/@NAME@.py --expect '^PASS' --fail 'FAIL|HardFault' --timeout 60 --log rtt.log
    python3 @NAME@/@NAME@.py --selftest                                        # no probe

Example `rtt_telnet_sim` runs it against cmsim's GDB server (RTT on a telnet port, like J-Link).
Not verified with a probe here.
