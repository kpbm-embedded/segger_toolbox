/* @NAME@: printf-style output over SWO (ITM stimulus port 0) plus 32-bit samples on port 1.
 * Register addresses are the architectural ARMv7-M/ARMv8-M ones; no vendor headers. */
#include <stdint.h>

#define REG(a) (*(volatile uint32_t *)(a))
#define DEMCR        REG(0xE000EDFCu)
#define ITM_PORT(n)  REG(0xE0000000u + 4u * (n))
#define ITM_TER      REG(0xE0000E00u)
#define ITM_TCR      REG(0xE0000E80u)
#define ITM_LAR      REG(0xE0000FB0u)
#define TPI_ACPR     REG(0xE0040010u)
#define TPI_SPPR     REG(0xE00400F0u)
#define TPI_FFCR     REG(0xE0040304u)
#define DBGMCU_CR    REG(0xE0042004u)   /* STM32: TRACE_IOEN routes SWO to PB3 */

#ifndef CPU_HZ
#define CPU_HZ 100000000u
#endif
#define SWO_HZ 2000000u

static void swo_init(void) {
  DEMCR |= 1u << 24;                     /* TRCENA */
  DBGMCU_CR |= 1u << 5;                  /* TRACE_IOEN (STM32 only; harmless elsewhere in the sim) */
  TPI_SPPR = 2;                          /* NRZ (UART) encoding, what J-Link expects */
  TPI_ACPR = CPU_HZ / SWO_HZ - 1;        /* SWO clock prescaler */
  TPI_FFCR = 0x100;                      /* formatter off */
  ITM_LAR = 0xC5ACCE55u;                 /* unlock */
  ITM_TCR = (1u << 16) | (1u << 3) | 1u; /* TraceBusID 1, SWOENA, ITMENA */
  ITM_TER = 0x3u;                        /* ports 0 and 1 */
}

static void itm_putc(unsigned port, char c) {
  if ((ITM_TCR & 1u) == 0 || (ITM_TER & (1u << port)) == 0) { return; }
  while (ITM_PORT(port) == 0) { }        /* FIFO full */
  *(volatile uint8_t *)&ITM_PORT(port) = (uint8_t)c;
}
static void itm_puts(const char *s) { while (*s) { itm_putc(0, *s++); } }
static void itm_word(unsigned port, uint32_t v) { while (ITM_PORT(port) == 0) { } ITM_PORT(port) = v; }

static void put_uint(unsigned v) {
  char b[11]; int i = 10; b[i] = 0;
  do { b[--i] = (char)('0' + v % 10u); v /= 10u; } while (v);
  itm_puts(&b[i]);
}

int main(void) {
  swo_init();
  itm_puts("@NAME@: SWO up\n");
  for (unsigned i = 1; i <= 3; i++) {
    itm_puts("sample "); put_uint(i * 100u); itm_puts("\n");
    itm_word(1, 0xC0DE0000u | i);
  }
  itm_puts("@NAME@: done\n");
  return 0;
}
