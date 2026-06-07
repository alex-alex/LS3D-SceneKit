#!/usr/bin/env python3
"""Dump confirmed Mafia savegame structures.

This is a reverse-engineering helper, not a full save editor.
"""

from __future__ import annotations

import argparse
import struct
from collections import Counter
from pathlib import Path


STREAM_SEED_A = 0x23101976
STREAM_SEED_B = 0x10072002
OUTER_HEADER_SIZE = 0x18
INNER_HEADER_SIZE = 0x18
SUMMARY_SIZE = 0x20
SESSION_SIZE = 0x108
ENTITY_HEADER_SIZE = 0x8C
ENTITY_PAYLOAD_PREFIX_SIZE = 15
OBJECT_TYPE_NAMES = {
    0: "none",
    1: "ghost",
    2: "player",
    4: "car",
    5: "script",
    6: "door",
    8: "trolley",
    9: "unknown3",
    12: "traffic",
    18: "pedestrians",
    20: "empty",
    21: "dog",
    22: "plane",
    24: "railRoute",
    25: "pumpar",
    26: "unknown26",
    27: "enemy",
    28: "unknown2",
    30: "wagons",
    34: "clock",
    35: "physical",
    36: "truck",
}


def read_u32(data: bytes, offset: int) -> int:
    if offset + 4 > len(data):
        return 0
    return struct.unpack_from("<I", data, offset)[0]


def read_c_string(data: bytes, offset: int, size: int) -> str:
    raw = data[offset : offset + size].split(b"\0", 1)[0]
    return raw.decode("cp1250", errors="replace")


def describe_payload_prefix(payload: bytes) -> str:
    if len(payload) < ENTITY_PAYLOAD_PREFIX_SIZE:
        return f"short:{payload.hex()}"

    return (
        f"v={payload[0]} group={payload[1]} scene_id={struct.unpack_from('<H', payload, 2)[0]} "
        f"state_a=0x{read_u32(payload, 4):08x} state_b=0x{read_u32(payload, 8):08x} "
        f"state_c=0x{struct.unpack_from('<H', payload, 12)[0]:04x} state_d=0x{payload[14]:02x}"
    )


def describe_payload_tail(object_type: int, payload: bytes) -> str:
    if object_type == 6 and len(payload) >= 25:
        return (
            f"door_angle={struct.unpack_from('<f', payload, 15)[0]:.6g} "
            f"door_state=0x{read_u32(payload, 19):08x} "
            f"door_flags=0x{struct.unpack_from('<H', payload, 23)[0]:04x}"
        )

    return ""


class SaveStreamDecoder:
    def __init__(self, data: bytes) -> None:
        self.data = data
        self.seed_a = STREAM_SEED_A
        self.seed_b = STREAM_SEED_B

    def read_plain(self, offset: int, size: int) -> bytes:
        return self.data[offset : offset + size]

    def read_encoded(self, offset: int, size: int) -> bytes:
        block = bytearray(self.data[offset : offset + size])
        for word_offset in range(0, len(block) - 3, 4):
            encrypted = read_u32(block, word_offset)
            plain = encrypted ^ self.seed_a
            struct.pack_into("<I", block, word_offset, plain)
            self.seed_b = (self.seed_b + plain) & 0xFFFFFFFF
            self.seed_a = (self.seed_a + self.seed_b) & 0xFFFFFFFF
        return bytes(block)


def dump(
    path: Path,
    max_entities: int | None,
    payload_preview: int,
    object_type_filter: set[int] | None,
    show_stats: bool,
) -> None:
    encoded = path.read_bytes()
    decoder = SaveStreamDecoder(encoded)
    cursor = OUTER_HEADER_SIZE

    outer_header = decoder.read_plain(0, OUTER_HEADER_SIZE)
    inner_header = decoder.read_encoded(cursor, INNER_HEADER_SIZE)
    outer_signature = read_u32(outer_header, 0)
    inner_signature = read_u32(inner_header, 0)
    version = read_u32(inner_header, 4)
    checkpoint = read_u32(inner_header, 8)
    checkpoint_marker = read_u32(inner_header, 20)
    cursor += INNER_HEADER_SIZE

    print(f"file: {path}")
    print(f"size: {len(encoded)}")
    print(f"outer_signature: 0x{outer_signature:08x}")
    print(f"inner_signature: 0x{inner_signature:08x}")
    print(f"version: {version}")
    print(f"checkpoint: {checkpoint}")
    print(f"checkpoint_marker: 0x{checkpoint_marker:08x}")

    summary = decoder.read_encoded(cursor, SUMMARY_SIZE)
    print("summary:")
    print(f"  checkpoint: {read_u32(summary, 0)}")
    print(f"  save_time_packed: 0x{read_u32(summary, 8):08x}")
    print(f"  save_date_packed: 0x{read_u32(summary, 12):08x}")
    print(f"  health_percent: {read_u32(summary, 16)}")
    print(f"  mission_timer: {read_u32(summary, 20)}")
    print(f"  unknown_1c: 0x{read_u32(summary, 28):08x}")
    cursor += SUMMARY_SIZE

    session = decoder.read_encoded(cursor, SESSION_SIZE)
    mission_state_size = read_u32(session, 0x20)
    extra_state_a_size = read_u32(session, 0xF0)
    extra_state_b_size = read_u32(session, 0xF4)
    print("session:")
    print(f"  mission_folder: {read_c_string(session, 0, 0x20)}")
    print(f"  mission_state_size: {mission_state_size}")
    print(f"  extra_state_a_size: {extra_state_a_size}")
    print(f"  extra_state_b_size: {extra_state_b_size}")
    print(f"  global_flag: {read_u32(session, 0xF8)}")
    print(f"  global_value_a: 0x{read_u32(session, 0xFC):08x}")
    print(f"  global_value_b: 0x{read_u32(session, 0x100):08x}")
    print(f"  global_value_c: 0x{read_u32(session, 0x104):08x}")
    cursor += SESSION_SIZE

    blocks = [
        ("mission_state", mission_state_size),
        ("extra_state_a", extra_state_a_size),
        ("extra_state_b", extra_state_b_size),
    ]
    for name, size in blocks:
        print(f"{name}: offset=0x{cursor:x} size={size}")
        decoder.read_encoded(cursor, size)
        cursor += size

    entity_count = 0
    printed_entities = 0
    entity_stats: dict[int, Counter[int]] = {}
    while cursor + ENTITY_HEADER_SIZE <= len(encoded):
        header = decoder.read_encoded(cursor, ENTITY_HEADER_SIZE)
        name = read_c_string(header, 0, 0x40)
        model_name = read_c_string(header, 0x40, 0x40)
        object_type = read_u32(header, 0x80)
        payload_size = read_u32(header, 0x84)
        player_slot = struct.unpack_from("<i", header, 0x88)[0]
        payload_offset = cursor + ENTITY_HEADER_SIZE
        payload_end = payload_offset + payload_size
        if payload_end > len(encoded):
            print(f"entity[{entity_count}]: truncated at 0x{cursor:x}")
            break

        payload = decoder.read_encoded(payload_offset, payload_size)
        entity_stats.setdefault(object_type, Counter())[payload_size] += 1
        should_print = object_type_filter is None or object_type in object_type_filter
        if not show_stats and should_print and (max_entities is None or printed_entities < max_entities):
            object_type_name = OBJECT_TYPE_NAMES.get(object_type, "unknown")
            line = (
                f"entity[{entity_count}]: offset=0x{cursor:x} "
                f"name={name!r} model={model_name!r} type={object_type}({object_type_name}) "
                f"payload_size={payload_size} player_slot={player_slot} "
                f"prefix=({describe_payload_prefix(payload)})"
            )
            tail_description = describe_payload_tail(object_type, payload)
            if tail_description:
                line += f" tail=({tail_description})"
            if payload_preview > 0:
                line += f" payload={payload[:payload_preview].hex()}"
            print(line)
            printed_entities += 1
        cursor = payload_end
        entity_count += 1

    if cursor != len(encoded):
        print(f"trailing_bytes: offset=0x{cursor:x} size={len(encoded) - cursor}")

    if show_stats:
        print("entity_stats:")
        for object_type, sizes in sorted(entity_stats.items()):
            object_type_name = OBJECT_TYPE_NAMES.get(object_type, "unknown")
            common_sizes = ", ".join(
                f"{size}:{count}" for size, count in sizes.most_common(8)
            )
            print(
                f"  type={object_type}({object_type_name}) "
                f"count={sum(sizes.values())} sizes={common_sizes}"
            )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("savegame", type=Path)
    parser.add_argument("--max-entities", type=int)
    parser.add_argument("--payload-preview", type=int, default=0)
    parser.add_argument("--stats", action="store_true", help="Print entity type and payload-size stats.")
    parser.add_argument(
        "--type",
        action="append",
        type=int,
        dest="object_types",
        help="Only print entities with this object type. Can be passed more than once.",
    )
    args = parser.parse_args()
    object_type_filter = set(args.object_types) if args.object_types is not None else None
    dump(args.savegame, args.max_entities, args.payload_preview, object_type_filter, args.stats)


if __name__ == "__main__":
    main()
