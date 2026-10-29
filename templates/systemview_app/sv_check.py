"""@NAME@: check the SystemView stream captured by cmsim (RTT up channel "SysView")."""
import json
import sys

sim = json.load(open(sys.argv[1]))
name = sys.argv[2]
chans = {b["index"]: b["name"] for b in sim["rtt"]["buffers"] if b["dir"] == "up"}
sv = next((i for i, n in chans.items() if n == "SysView"), None)
assert sv is not None, f"no 'SysView' RTT channel: {chans}"
data = sim["up"].get(str(sv), "").encode("latin-1")
assert data, "SysView channel is empty"
for text in (f"N={name}", f"{name} start", "work", f"{name} warning sample", f"{name} end"):
    assert text.encode() in data, f"missing {text!r} in the SystemView stream"
print(f"PASS {name}: {len(data)} bytes of SystemView data on RTT channel {sv} ({sim['stop']})")
