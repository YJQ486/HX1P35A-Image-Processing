"""Generate hdl/custom_logo_rom.hex from the official Anlogic lab_ex3 logo ROM.

The logo bitmap belongs to Anlogic and is not distributed with this repository.
Point the script at anlogic_logo_rom.v from the lab_ex3_osd example:

    python scripts/make_logo_rom.py <path>/anlogic_logo_rom.v

Only logo rows 34..127 hold opaque pixels, so the ROM stores those 94 rows
(15040 words x 25 bits: alpha + RGB888). custom_logo_rom reads the file with
$readmemh relative to its own source directory.
"""
import hashlib
import re
import sys
from pathlib import Path

BASE, DEPTH = 34 * 160, 94 * 160
EXPECTED_SHA256 = "FCD45773D58E3386F49A81E4CBEC47C0873D5862C392F9944C17BC4CB8FC3E8E"

def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    src = Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
    entries = {int(a): int(v, 16) for a, v in
               re.findall(r"15'd(\d+):\s*O_pixel\s*<?=\s*25'h([0-9a-fA-F]+);", src)}
    if len(entries) != 6387 or min(entries) < BASE or max(entries) >= BASE + DEPTH:
        sys.exit(f"unexpected logo ROM: {len(entries)} entries, "
                 f"addresses {min(entries, default=0)}..{max(entries, default=0)}")
    text = "".join("%07x\n" % entries.get(BASE + i, 0) for i in range(DEPTH))
    out = Path(__file__).resolve().parents[1] / "hdl" / "custom_logo_rom.hex"
    # CRLF matches the file used for the final bitstream byte for byte.
    out.write_bytes(text.replace("\n", "\r\n").encode())
    digest = hashlib.sha256(out.read_bytes()).hexdigest().upper()
    print(f"wrote {out} ({DEPTH} words, sha256 {digest})")
    if digest != EXPECTED_SHA256:
        sys.exit("SHA256 differs from the file used for the final bitstream")

if __name__ == "__main__":
    main()
