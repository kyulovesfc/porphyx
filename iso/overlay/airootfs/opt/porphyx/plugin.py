__archinstall__version__ = 99.0
import re
import shutil
from pathlib import Path

SRC = Path("/opt/porphyx")

class Plugin:
    def on_genfstab(self, installation):
        target = Path(installation.target)
        bindir = target / "usr" / "local" / "bin"
        bindir.mkdir(parents=True, exist_ok=True)
        shutil.copy2(SRC / "porphyx", bindir / "porphyx")
        (bindir / "porphyx").chmod(0o755)
        (target / "etc").mkdir(parents=True, exist_ok=True)
        issue = Path("/etc/issue")
        if issue.exists():
            shutil.copy2(issue, target / "etc" / "issue")
        osr = Path("/etc/os-release")
        if osr.exists():
            dest = target / "etc" / "os-release"
            if dest.is_symlink() or dest.exists():
                dest.unlink()
            shutil.copy2(osr, dest)
        entries = target / "boot" / "loader" / "entries"
        if entries.is_dir():
            for entry in entries.glob("*.conf"):
                text = entry.read_text()
                renamed = re.sub(r"^(title\s+)Arch Linux(?: \(linux\))?", r"\1Porphyx Linux", text, flags=re.M)  # KYU-BRAND2
                if renamed == text:
                    continue
                entry.write_text(renamed)
        ff = Path("/root/.config/fastfetch")
        if ff.is_dir():
            fdest = target / "etc" / "xdg" / "fastfetch"
            fdest.mkdir(parents=True, exist_ok=True)
            for fl in ff.iterdir():
                if fl.is_file():
                    shutil.copy2(fl, fdest / fl.name)
            fcfg = fdest / "config.jsonc"
            if fcfg.exists():
                fcfg.write_text(fcfg.read_text().replace("/root/.config/fastfetch/", "/etc/xdg/fastfetch/"))
        # KYU-NM-COPY: hereda las conexiones de NetworkManager del live (evita un segundo nmtui en porphyx setup)
        nm_src = Path("/etc/NetworkManager/system-connections")
        if nm_src.is_dir() and any(nm_src.iterdir()):
            nm_dest = target / "etc" / "NetworkManager" / "system-connections"
            nm_dest.mkdir(parents=True, exist_ok=True)
            nm_dest.chmod(0o700)
            for nc in nm_src.iterdir():
                if nc.is_file():
                    shutil.copy2(nc, nm_dest / nc.name)
                    (nm_dest / nc.name).chmod(0o600)
        # KYU-SELECTION: apps/desktops chosen in the installer; porphyx setup reads them
        sel = Path("/tmp/porphyx-selection.env")
        if sel.is_file():
            sdest = target / "var" / "lib" / "porphyx"
            sdest.mkdir(parents=True, exist_ok=True)
            shutil.copy2(sel, sdest / "selection.env")
        return None
