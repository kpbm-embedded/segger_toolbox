/* @NAME@: line console over RTT. Down channel 0 = keyboard, up channel 0 = output.
 * Virtual terminals: normal output on terminal 0, warnings on terminal 1 (RTT Viewer shows them as tabs). */
#include <stdlib.h>
#include <string.h>
#include "SEGGER_RTT.h"

static int read_line(char *buf, unsigned len) {
  unsigned n = 0;
  for (;;) {
    int c = SEGGER_RTT_WaitKey();          /* blocks until the host (RTT Viewer / cmsim) sends a byte */
    if (c == '\r') { continue; }
    if (c == '\n') { buf[n] = 0; return (int)n; }
    if (n + 1 < len) { buf[n++] = (char)c; }
  }
}

static int handle(char *line) {
  if (strcmp(line, "help") == 0) {
    SEGGER_RTT_WriteString(0, "commands: help | add A B | warn TEXT | quit\n");
  } else if (strncmp(line, "add ", 4) == 0) {
    char *end;
    long a = strtol(line + 4, &end, 10);
    long b = strtol(end, NULL, 10);
    SEGGER_RTT_printf(0, "sum %d\n", (int)(a + b));
  } else if (strncmp(line, "warn ", 5) == 0) {
    SEGGER_RTT_TerminalOut(1, line + 5);       /* goes to terminal 1, then back to the current one */
    SEGGER_RTT_TerminalOut(1, "\n");
  } else if (strcmp(line, "quit") == 0) {
    SEGGER_RTT_WriteString(0, "bye\n");
    return 0;
  } else {
    SEGGER_RTT_printf(0, "unknown: %s\n", line);
  }
  return 1;
}

int main(void) {
  char line[64];
  SEGGER_RTT_Init();
  SEGGER_RTT_WriteString(0, "@NAME@ ready\n");
  do {
    SEGGER_RTT_WriteString(0, "> ");
    read_line(line, sizeof line);
  } while (handle(line));
  return 0;
}
