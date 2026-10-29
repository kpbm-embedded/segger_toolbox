# ring_laws.bend: laws of the SEGGER RTT ring-buffer index math (host-side, Bend 2 via 32_31_bend).
# RTT keeps WrOff (target writes) and RdOff (host reads) in [0, size); one slot stays empty.
#   used(rd, wr) = (wr - rd) mod size        free(rd, wr) = size - 1 - used(rd, wr)
# Laws checked for every (rd, wr) with size 8: used + free == size - 1, free == 0 exactly when
# (wr + 1) mod size == rd, and writing k <= free bytes moves wr to (wr + k) mod size with used' == used + k.
# DRAFT: written before 32_31_bend existed; not yet run with Bend 2 (the example skips with exit 3).

def used(rd: u32, wr: u32, size: u32) -> u32:
  return (wr + size - rd) % size

def free(rd: u32, wr: u32, size: u32) -> u32:
  return size - 1 - used(rd, wr, size)

def bad(rd: u32, wr: u32, size: u32) -> u32:
  u = used(rd, wr, size)
  f = free(rd, wr, size)
  full = (wr + 1) % size == rd
  b1 = 0 if u + f == size - 1 else 1
  b2 = 0 if (f == 0) == full else 1
  w2 = (wr + f) % size
  b3 = 0 if used(rd, w2, size) == u + f else 1
  return b1 + b2 + b3

def count(rd: u32, wr: u32, size: u32) -> u32:
  if rd == size:
    return 0
  elif wr == size:
    return count(rd + 1, 0, size)
  else:
    return bad(rd, wr, size) + count(rd, wr + 1, size)

def main() -> u32:
  return count(0, 0, 8)
