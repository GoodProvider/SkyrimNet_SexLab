# Instructions:
# This script produces unified, portable RTTI and vtable offsets for all versions of Skyrim runtimes.
# It should be run by providing a) the root directory of the CommonLibSSE source, b) a directory containing offset data
# dumped from IDA Pro, and c) a directory containing SE and AE address library offset dumps (in text format).
# The offset data should be produced using meh321's IDAExport.py script, and only needs the RTTI and vtable offsets.
# These should be renamed to idaexport_rtti_ae/se/vr.txt and idaexport_vtable_ae/se/vr.txt. The resulting output will
# have merged offsets for all three runtimes and will be written directly to the CommonLibSSE source at Offsets_RTTI.h
# and Offsets_VTABLE.h.

import argparse
import re
from collections import defaultdict
import itertools
import os

# Address Library ID databases
ae_ids: dict[int, int] = defaultdict(lambda: 0)
se_ids: dict[int, int] = defaultdict(lambda: 0)

# Input file content
ae_rtti_offsets: list[tuple[str, int]] = []
se_rtti_offsets: list[tuple[str, int]] = []
vr_rtti_offsets: list[tuple[str, int]] = []
ae_vtable_offsets: dict[str, list[int]] = defaultdict(lambda: [])
se_vtable_offsets: dict[str, list[int]] = defaultdict(lambda: [])
vr_vtable_offsets: dict[str, list[int]] = defaultdict(lambda: [])

ae_rtti_types: dict[int, str] = {}
se_rtti_types: dict[int, str] = {}
vr_rtti_types: dict[int, str] = {}
ae_rtti_cols: dict[int, int] = {}
se_rtti_cols: dict[int, int] = {}
vr_rtti_cols: dict[int, int] = {}


class RttiOffsetData:
    def __init__(self):
        self._ae_offset = 0
        self._se_offset = 0
        self._vr_offset = 0

    @property
    def ae_offset(self) -> int:
        return self._ae_offset

    @ae_offset.setter
    def ae_offset(self, ae_offset: int):
        self._ae_offset = ae_offset

    @property
    def se_offset(self) -> int:
        return self._se_offset

    @se_offset.setter
    def se_offset(self, se_offset: int):
        self._se_offset = se_offset

    @property
    def vr_offset(self) -> int:
        return self._vr_offset

    @vr_offset.setter
    def vr_offset(self, vr_offset: int):
        self._vr_offset = vr_offset


class VtableOffsetData:
    def __init__(self):
        self._ae_offsets = []
        self._se_offsets = []
        self._vr_offsets = []

    @property
    def ae_offsets(self) -> list[int]:
        return self._ae_offsets

    @ae_offsets.setter
    def ae_offsets(self, ae_offsets: list[int]):
        self._ae_offsets = ae_offsets

    @property
    def se_offsets(self) -> list[int]:
        return self._se_offsets

    @se_offsets.setter
    def se_offsets(self, se_offsets: int):
        self._se_offsets = se_offsets

    @property
    def vr_offsets(self) -> list[int]:
        return self._vr_offsets

    @vr_offsets.setter
    def vr_offsets(self, vr_offsets: list[int]):
        self._vr_offsets = vr_offsets


rtti_offsets: dict[str, RttiOffsetData] = defaultdict(lambda: RttiOffsetData())
vtable_offsets: dict[str, VtableOffsetData] = defaultdict(lambda: VtableOffsetData())


def populate_address_lib(database: str, ids: dict[int, int]):
    db = open(database, 'r')
    for line in db.readlines():
        parts = line.split('\t')
        ids[int(parts[1], 16)] = int(parts[0])


demangle_pattern = re.compile(":|<|>|,|\\(|\\)|`|'| |-|&|\\*")


def demangle(name: str):
    return demangle_pattern.sub('_', name.replace("`anonymous namespace'", '')).strip()


def populate_rtti_content(source: str, offsets: list[tuple[str, int]], types: dict[int, str], cols: dict[int, int]):
    for line in open(source, 'r').readlines():
        parts = line.split('\t')
        if parts[0] == 'rtti_tdesc':
            name = demangle(parts[5])
            offset = int(parts[1], 16)
            offsets.append((name, offset))
            types[offset] = name
        elif parts[0] == 'rtti_complete':
            cols[int(parts[1], 16)] = int(parts[5], 16)


def populate_vtable_content(source: str, offsets: dict[str, list[int]], types: dict[int, str],
                            cols: dict[int, int]):
    for line in open(source, 'r').readlines():
        parts = line.split('\t')
        if parts[0] != 'vtable':
            continue
        offset = int(parts[1], 16)
        try:
            name = types[cols[int(parts[2], 16)]]
            offsets[name].append(offset)
        except:
            print(f'Warning: unable to handle vtable entry: {line}')
            continue


def merge_rtti_data(offsets: dict[str, RttiOffsetData]):
    for data in ae_rtti_offsets:
        offsets[data[0]].ae_offset = data[1]
    for data in se_rtti_offsets:
        offsets[data[0]].se_offset = data[1]
    for data in vr_rtti_offsets:
        offsets[data[0]].vr_offset = data[1]


def merge_vtable_data():
    for name, offsets in ae_vtable_offsets.items():
        vtable_offsets[name].ae_offsets = offsets
    for name, offsets in se_vtable_offsets.items():
        vtable_offsets[name].se_offsets = offsets
    for name, offsets in vr_vtable_offsets.items():
        vtable_offsets[name].vr_offsets = offsets


def print_rtti_symbols(symbol_type: str, root: str, offsets: dict[str, RttiOffsetData]):
    out_file = open(os.path.join(root, 'include', 'RE', f'Offsets_{symbol_type}.h'), 'w', encoding='utf-8')
    out_file.write('#pragma once\n\n#include "REL/Relocation.h"\n\nnamespace RE\n{\n')
    for name, offset_data in offsets.items():
        if offset_data.ae_offset == 0 and offset_data.se_offset == 0:
            continue
        out_file.write(
            f'\tconstexpr REL::VariantID RTTI_{name}({se_ids[offset_data.se_offset] if offset_data.se_offset else 0}, '+
            f'{ae_ids[offset_data.ae_offset] if offset_data.ae_offset else 0}, ' +
            f'{hex(offset_data.vr_offset)});\n')
    out_file.write('\n\n')
    for name, offset_data in offsets.items():
        if offset_data.ae_offset != 0 or offset_data.se_offset != 0:
            continue
        out_file.write(f'\tconstexpr REL::VariantOffset RTTI_{name}(0, 0, {hex(offset_data.vr_offset)});\n')
    out_file.write('}\n')


def print_vtable_symbols(root: str):
    out_file = open(os.path.join(root, 'include', 'RE', 'Offsets_VTABLE.h'), 'w', encoding='utf-8')
    out_file.write('#pragma once\n\n#include "REL/Relocation.h"\n\nnamespace RE\n{\n')
    for name, offset_data in vtable_offsets.items():
        if not offset_data.ae_offsets and not offset_data.se_offsets:
            continue
        out_file.write('\tconstexpr std::array<REL::VariantID, ' +
                       f'{max(len(offset_data.ae_offsets), len(offset_data.se_offsets), len(offset_data.vr_offsets))}' +
                       f'> VTABLE_{name}{{ ')
        out_file.write(', '.join([
            f'REL::VariantID({se_ids[se] if se != 0 else 0}, {ae_ids[ae] if ae else 0}, {hex(vr)})'
            for se, ae, vr in itertools.zip_longest(
                offset_data.se_offsets, offset_data.ae_offsets, offset_data.vr_offsets, fillvalue=0)]))
        out_file.write(' };\n')
    out_file.write('\n\n')
    for name, offset_data in vtable_offsets.items():
        if offset_data.ae_offsets or offset_data.se_offsets:
            continue
        out_file.write(f'\tconstexpr std::array<REL::VariantOffset, {len(offset_data.vr_offsets)}> VTABLE_{name}{{ ')
        out_file.write(', '.join([f'REL::VariantOffset(0, 0, {hex(o)})' for o in offset_data.vr_offsets]))
        out_file.write(' };\n')
    out_file.write('}\n')


def main():
    parser = argparse.ArgumentParser(description='Process offsets into CommonLibSSE Offset_*.h files.')
    parser.add_argument('--offsets', action='store', nargs='?', dest='offset_path', default='.',
                        help='Path to the generated offset data.')
    parser.add_argument('--ae-version', action='store', nargs='?', dest='ae_version', default='1.6.353',
                        help='Version of the Skyrim AE executable used to generate the offsets.')
    parser.add_argument('--se-version', action='store', nargs='?', dest='se_version', default='1.5.97',
                        help='Version of the Skyrim SE executable used to generate the offsets.')
    parser.add_argument('--ids', action='store', nargs='?', dest='id_path', default='.',
                        help='Location of the Address Library ID databases.')
    parser.add_argument('--root', action='store', nargs='?', dest='root', default='.',
                        help='The path to the root of the CommonLibSSE project.')
    args = parser.parse_args()

    populate_rtti_content(os.path.join(args.offset_path, 'idaexport_rtti_ae.txt'), ae_rtti_offsets, ae_rtti_types,
                          ae_rtti_cols)
    populate_rtti_content(os.path.join(args.offset_path, 'idaexport_rtti_se.txt'), se_rtti_offsets, se_rtti_types,
                          se_rtti_cols)
    populate_rtti_content(os.path.join(args.offset_path, 'idaexport_rtti_vr.txt'), vr_rtti_offsets, vr_rtti_types,
                          vr_rtti_cols)
    populate_vtable_content(os.path.join(args.offset_path, 'idaexport_vtable_ae.txt'), ae_vtable_offsets, ae_rtti_types,
                            ae_rtti_cols)
    populate_vtable_content(os.path.join(args.offset_path, 'idaexport_vtable_se.txt'), se_vtable_offsets, se_rtti_types,
                            se_rtti_cols)
    populate_vtable_content(os.path.join(args.offset_path, 'idaexport_vtable_vr.txt'), vr_vtable_offsets, vr_rtti_types,
                            vr_rtti_cols)

    populate_address_lib(os.path.join(args.id_path, f'versionlib-offsets-{args.ae_version.replace(".", "-")}-0.txt'),
                         ae_ids)
    populate_address_lib(os.path.join(args.id_path, f'version-offsets-{args.se_version.replace(".", "-")}-0.txt'),
                         se_ids)

    merge_rtti_data(rtti_offsets)
    merge_vtable_data()

    print_rtti_symbols('RTTI', args.root, rtti_offsets)
    print_vtable_symbols(args.root)


if __name__ == "__main__":
    main()
