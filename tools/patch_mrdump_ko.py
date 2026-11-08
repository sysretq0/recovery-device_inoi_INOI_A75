#!/usr/bin/env python3
"""
Patch mrdump.ko to make the Samsung debug symbol sec_debug_dump_info weak
and NOP out the call site, allowing clean loading on generic GKI kernels.
"""

import sys
import os
from elftools.elf.elffile import ELFFile

def patch_mrdump(ko_path):
    if not os.path.exists(ko_path):
        print(f"Error: {ko_path} not found")
        sys.exit(1)

    with open(ko_path, "r+b") as f:
        elf = ELFFile(f)
        symtab = elf.get_section_by_name(".symtab")
        sym_idx = None
        for idx, sym in enumerate(symtab.iter_symbols()):
            if sym.name == "sec_debug_dump_info":
                sym_idx = idx
                break
        if sym_idx is None:
            print("sec_debug_dump_info not found, already patched or not present")
            return

        sym_offset = symtab['sh_offset'] + sym_idx * symtab['sh_entsize']
        f.seek(sym_offset + 4)
        old_info = f.read(1)[0]
        bind = old_info >> 4
        if bind == 2:  # STB_WEAK
            print("Already STB_WEAK")
            return

        # 1. Set STB_WEAK
        new_info = (2 << 4) | (old_info & 0x0f)
        f.seek(sym_offset + 4)
        f.write(bytes([new_info]))

        # 2. Patch relocation in .rela.text
        rela_text = elf.get_section_by_name(".rela.text")
        for r_idx, rel in enumerate(rela_text.iter_relocations()):
            if rel['r_info_sym'] == sym_idx:
                rel_offset = rela_text['sh_offset'] + r_idx * rela_text['sh_entsize']
                f.seek(rel_offset + 8)
                f.write((0).to_bytes(8, byteorder='little'))  # R_AARCH64_NONE

                # 3. Patch instruction to AArch64 NOP (0xd503201f)
                text_sec = elf.get_section_by_name(".text")
                text_file_offset = text_sec['sh_offset'] + rel['r_offset']
                f.seek(text_file_offset)
                f.write(bytes([0x1f, 0x20, 0x03, 0xd5]))
                print(f"Patched sec_debug_dump_info to STB_WEAK and NOP at offset {hex(text_file_offset)}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: patch_mrdump_ko.py <path/to/mrdump.ko>")
        sys.exit(1)
    patch_mrdump(sys.argv[1])
