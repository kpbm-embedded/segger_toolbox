# @NAME@

RTT command console from `segger-box new rtt_console @NAME@` (32_12_segger): the firmware reads lines from
RTT down channel 0 (`SEGGER_RTT_WaitKey`) and answers on up channel 0; `warn TEXT` goes to virtual
terminal 1 (`SEGGER_RTT_TerminalOut`), which RTT Viewer shows in its own tab.

    segger-box run make -C @NAME@ sim       # cmsim types help / add 2 40 / warn ... / quit, prints per terminal
    segger-box run make -C @NAME@ BOARD=pico_rp2040 all

On hardware: `segger-box rtt` (RTT Viewer, Terminal 0/1 tabs, input "Enter on Return") or
`segger-box rtt-client` while `segger-box gdbserver ...` runs. Not verified on a board here.
