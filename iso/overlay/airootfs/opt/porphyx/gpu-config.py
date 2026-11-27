#!/usr/bin/env python3
# Ajusta paquetes y servicios de GPU de archinstall.json segun el hardware detectado.
# Uso: gpu-config.py entrada.json salida.json
import json, os, sys
from pathlib import Path

src, dst = sys.argv[1], sys.argv[2]
cfg = json.loads(Path(src).read_text())
VENDORS = {"0x10de": "nvidia", "0x1002": "amd", "0x8086": "intel"}

vendors, count = set(), 0
for dev in sorted(Path(os.environ.get("PORPHYX_SYSFS", "/sys/bus/pci/devices")).glob("*")):
    try:
        cls = (dev / "class").read_text().strip()
        ven = (dev / "vendor").read_text().strip().lower()
    except OSError:
        continue
    if cls.startswith("0x03"):
        count += 1
        vendors.add(VENDORS.get(ven, ven))

print("GPUs detectadas:", count, sorted(vendors) or "ninguna")
if count:
    pkgs = list(cfg.get("packages", []))
    if "nvidia" not in vendors:
        pkgs = [p for p in pkgs if "nvidia" not in p]
    if "amd" not in vendors:
        pkgs = [p for p in pkgs if "vulkan-radeon" not in p]
    if "intel" in vendors:
        pkgs += [p for p in ("vulkan-intel", "lib32-vulkan-intel", "intel-media-driver") if p not in pkgs]
    svc = list(cfg.get("services", []))
    if "nvidia" not in vendors:
        svc = [s for s in svc if s != "nvidia-powerd"]
    if count < 2:
        svc = [s for s in svc if s != "switcheroo-control"]
    old = set(cfg.get("packages", [])) | set(cfg.get("services", []))
    cfg["packages"], cfg["services"] = pkgs, svc
    new = set(pkgs) | set(svc)
    print("quitados:", sorted(old - new) or "nada")
    print("agregados:", sorted(new - old) or "nada")
else:
    print("sin GPU PCI visible: config sin cambios")
Path(dst).write_text(json.dumps(cfg, indent=2) + "\n")
