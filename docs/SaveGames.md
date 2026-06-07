# Savegames

This document records the Mafia savegame details confirmed from local files in
`/Users/alex/Development/Mafia/Mafia/savegame` and the save I/O routines in
`Game.exe`.

## File Families

| File pattern | Signature | Notes |
| --- | --- | --- |
| `mafiaNNN.CCC` | `GvaS` | Per-checkpoint save. `NNN` is the profile number, `CCC` is the checkpoint id. |
| `mafiaNNN.sav` | `forP` | Profile metadata. Uses the same stream transform after the 24-byte header. |
| `mrNNN.sav` | none | Freeride/extreme progress flags. Plain little-endian data in tested samples. |
| `mrsegN.sav` | none | Freeride segment records. Plain little-endian data in tested samples. |
| `mrtimes.sav` | none | Freeride timing table. Plain little-endian data in tested samples. |

The four-byte signatures appear reversed in ASCII because they are stored as
little-endian integers:

| Bytes | Integer | Meaning |
| --- | --- | --- |
| `47 76 61 53` | `0x53617647` | Outer `SavG` marker. |
| `53 61 76 47` | `0x47766153` | Inner `GvaS` marker after decoding. |
| `66 6f 72 50` | `0x50726f66` | Profile `Prof` marker. |

## Stream Header

Checkpoint and profile saves start with a clear 24-byte header:

| Offset | Type | Value observed |
| --- | --- | --- |
| `0x00` | `UInt32` | Signature, `0x53617647` for checkpoint saves. |
| `0x04` | `UInt32` | `0`. |
| `0x08` | `UInt32` | `1`. |
| `0x0c` | `UInt32` | `0`. |
| `0x10` | `UInt32` | `0`. |
| `0x14` | `UInt32` | `0`. |

Serialized blocks after offset `0x18` are transformed in 32-bit little-endian
words. The transform state is shared across the whole file, but each write call
processes words relative to that block's own start. The last one to three bytes
of an odd-sized block are copied as-is and do not advance the transform state.

Decoder:

```text
seedA = 0x23101976
seedB = 0x10072002

for each serialized block:
  for each complete little-endian UInt32 word in that block:
    plain = encrypted XOR seedA
    seedB = seedB + plain
    seedA = seedA + seedB
```

Encoding is the inverse operation:

```text
seedA = 0x23101976
seedB = 0x10072002

for each serialized block:
  for each complete little-endian UInt32 word in that block:
    encrypted = plain XOR seedA
    seedB = seedB + plain
    seedA = seedA + seedB
```

All arithmetic wraps at 32 bits. `tools/savegame_dump.py` follows this block
boundary rule and can walk every local `mafia000.CCC` sample to EOF.

## Checkpoint Header

After decoding, checkpoint saves contain a second 24-byte stream header at file
offset `0x18`:

| File offset | Type | Meaning |
| --- | --- | --- |
| `0x18` | `UInt32` | Inner signature, `0x47766153`. |
| `0x1c` | `UInt32` | Version or format marker, observed `0x10`. |
| `0x20` | `UInt32` | Checkpoint id. Matches the filename suffix in tested saves. |
| `0x24` | `UInt32` | `0`. |
| `0x28` | `UInt32` | `0`. |
| `0x2c` | `UInt32` | `0x1388 + checkpoint id`. |

The immediately following 32-byte summary block starts at file offset `0x30`:

| File offset | Type | Meaning |
| --- | --- | --- |
| `0x30` | `UInt32` | Checkpoint id again. |
| `0x34` | `UInt32` | `0`. |
| `0x38` | packed bytes | Save time, stored as hour/minute/second-like values. |
| `0x3c` | packed bytes | Save date, stored as day/month/year-like values. |
| `0x40` | `UInt32` | Player health percentage in several samples. |
| `0x44` | `UInt32` | Mission elapsed or game timer value. |
| `0x48` | `UInt32` | `0`. |
| `0x4c` | `UInt32` | Unknown. `0` in many saves, checkpoint-like in some small saves. |

The mission folder field is enough for the save selector to resolve mission
title and image without a hardcoded checkpoint table.

## Session Block

The next block starts at file offset `0x50` and is always `0x108` bytes:

| Relative offset | Type | Meaning |
| --- | --- | --- |
| `0x00` | `char[32]` | Mission folder, null-terminated Windows-1250 text. |
| `0x20` | `UInt32` | Size of the following mission-state block. |
| `0x24` | `UInt32` | Unknown, often `0`. |
| `0x28` | `UInt32[25]` | First 25-entry mission/objective array. |
| `0x8c` | `UInt32[25]` | Second 25-entry mission/objective array. |
| `0xf0` | `UInt32` | Size of optional extra-state block A. |
| `0xf4` | `UInt32` | Size of optional extra-state block B. |
| `0xf8` | `UInt32` | Global flag, stored from byte-sized game state. |
| `0xfc` | `UInt32` | Global value A. Often `0x3f800000`. |
| `0x100` | `UInt32` | Global value B. Often `0x3f800000`. |
| `0x104` | `UInt32` | Global value C. Often `0x3f800000`. |

The variable blocks start immediately after the session block:

| Order | Size source | Contents |
| --- | --- | --- |
| 1 | Session `0x20` | Mission state blob. |
| 2 | Session `0xf0` | Extra state A, if nonzero. |
| 3 | Session `0xf4` | Extra state B, if nonzero. |

These blocks may have non-multiple-of-four sizes, so stream decoding must honor
the block boundary rule above.

## Entity Records

After the variable blocks, the rest of a checkpoint save is a sequence of entity
records. Each record starts with a `0x8c`-byte header:

| Relative offset | Type | Meaning |
| --- | --- | --- |
| `0x00` | `char[64]` | Entity/object name. |
| `0x40` | `char[64]` | Model name or auxiliary file name. Empty for many scripts/triggers. |
| `0x80` | `UInt32` | Object definition type. Values match `ObjectDefinitionType` in `Scene.swift`. |
| `0x84` | `UInt32` | Payload size. |
| `0x88` | `Int32` | Player garage/slot index for some car records, otherwise `-1`. |

The entity payload immediately follows the header and has the byte length stored
at header offset `0x84`. Payload formats are object-type-specific and are still
partially unmapped, but the record boundaries are confirmed: the dumper walks all
local checkpoint saves without truncation or trailing bytes.

Most normal entity-state payloads start with a 15-byte common object-state
prefix. Traffic records (`type 12`) have payload size `15`, so their payload is
only this prefix:

| Relative offset | Type | Meaning |
| --- | --- | --- |
| `0x00` | `UInt8` | Prefix version, observed `3`. |
| `0x01` | `UInt8` | Raw group/state byte. |
| `0x02` | `UInt16` | Scene/runtime object id. |
| `0x04` | `UInt32` | Raw state word A, often `0x00010000` or `0x00018000`. |
| `0x08` | `UInt32` | Raw state word B, often `1`. |
| `0x0c` | `UInt16` | Raw state word C low bytes. |
| `0x0e` | `UInt8` | Raw state byte D. |

Types `9` and `26` are exceptions in the local corpus: their payload size is
`13`, so they carry only the first 13 bytes of this common state shape. The
dumper prints `short:<hex>` for records that do not contain the full 15 bytes.

The dumper prints these raw prefix fields for each entity that has them. The
names above are deliberately conservative; their exact gameplay semantics still
need vtable mapping.

Door records (`type 6`) are fixed-size `25`-byte payloads: the 15-byte prefix
plus a 10-byte tail. Across local samples the tail has this raw shape:

| Relative offset | Type | Meaning |
| --- | --- | --- |
| `0x0f` | `Float32` | Door angle/state-like value. Observed `0` or about `1.5708`. |
| `0x13` | `UInt32` | Raw door state word. Observed values include `0x41`, `0x51`, `0x61`. |
| `0x17` | `UInt16` | Raw door flags. Observed `0`, `1`, `0x0100`. |

Observed entity types across the local checkpoint corpus:

| Type | Name | Count | Common payload sizes |
| --- | --- | ---: | --- |
| `2` | `player` | 80 | `641`, `649`, `646`, `651` |
| `4` | `car` | 583 | `1373`, `1337`, `1121`, `1265`, `1211`, `1391`, `1313`, `1409` |
| `5` | `script` | 2467 | `64`, `76`, `78`, `80`, `75`, `96`, `79`, `88` |
| `6` | `door` | 377 | `25` |
| `8` | `trolley` | 910 | `93` |
| `9` | `unknown3` | 1 | `13` |
| `12` | `traffic` | 32 | `15` |
| `18` | `pedestrians` | 121 | `23`, plus larger mission-specific blobs |
| `21` | `dog` | 17 | `113` |
| `22` | `plane` | 1 | `137` |
| `24` | `railRoute` | 2 | `29` |
| `25` | `pumpar` | 86 | `109` |
| `26` | `unknown26` | 53 | `13` |
| `27` | `enemy` | 861 | `2414`, plus actor-specific larger blobs |
| `30` | `wagons` | 2 | `156`, `152` |
| `35` | `physical` | 7654 | `224` |

Most payloads start with a small common object-state prefix, then continue with
type-specific state written through virtual save methods. Those inner payload
fields still need vtable-specific mapping before they should be treated as
stable field names.

## Tools

The app-side Swift implementation is in `Mafia/Game Manager/SaveGame.swift`.
It uses the same block-aware stream decoder and exposes the confirmed checkpoint
header, summary, session, variable blocks, entity headers, common payload prefix,
and door tail fields through `SaveGameCheckpoint`.

Use the local dumper to inspect one save:

```sh
python3 tools/savegame_dump.py /Users/alex/Development/Mafia/Mafia/savegame/mafia000.370
```

Useful options:

| Option | Meaning |
| --- | --- |
| `--max-entities N` | Print only the first `N` matching entity rows. |
| `--type N` | Print only entities with object type `N`; can be repeated. |
| `--payload-preview N` | Append the first `N` decoded payload bytes as hex. |
| `--stats` | Print per-type payload-size statistics for the selected save. |

`tools/ghidra/ExportFunctions.java` is a small headless Ghidra helper for
exporting decompiler output for selected addresses. It was used to confirm the
stream helper functions and save/load block order.
