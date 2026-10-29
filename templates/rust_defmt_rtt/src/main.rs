//! @NAME@: defmt log frames over SEGGER RTT (control block `_SEGGER_RTT` from defmt-rtt).
//! J-Link reads them like any RTT channel 0; `defmt-print -e <elf>` turns the bytes back into text.
#![no_std]
#![no_main]

use defmt_rtt as _;
use panic_probe as _;

#[derive(defmt::Format)]
struct Reading {
    channel: u8,
    millivolts: u16,
}

#[cortex_m_rt::entry]
fn main() -> ! {
    defmt::info!("@NAME@ start");
    let mut sum: u32 = 0;
    for i in 0..3u8 {
        let r = Reading { channel: i, millivolts: 1200 + 100 * u16::from(i) };
        sum += u32::from(r.millivolts);
        defmt::debug!("reading {}", r);
    }
    defmt::warn!("sum = {=u32} mV", sum);
    defmt::trace!("compiled out by DEFMT_LOG=debug");
    defmt::info!("@NAME@ done");
    loop {
        cortex_m::asm::bkpt(); // BKPT #0: a debugger (or cmsim) stops here
    }
}
