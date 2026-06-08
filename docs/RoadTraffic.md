# Road Traffic

This document records the NPC road traffic behavior confirmed from:

- `Game.exe`, analyzed locally with Ghidra 12.1.2.
- `road.bin` files under `/Users/alex/Development/Mafia/Mafia/missions`.
- Current LS3D-SceneKit code in `Road.swift`, `Scene.swift`, and `TrafficManager.swift`.

No build commands were run.

## Original Executable Entry Points

Ghidra found the mission road loader from the string `missions\%s\road.bin`:

| Address | Evidence |
| --- | --- |
| `0x005409d0` | Mission load routine. It checks `missions\%s\road.bin` and calls `0x00559e60` only when the file exists. |
| `0x00559e60` | `road.bin` loader. Reads version, crossroad count, crossroad array, waypoint count, waypoint array. |
| `0x0055cb00` | Post-load crossroad cleanup. Removes direction links whose lane entries are all empty. |

The scene object named `Traffic` or object type `12` is separate from
`road.bin`. It supplies traffic generation settings: generation radii, generated
car count, and the weighted car model database. The road file supplies the route
network that generated cars follow.

## File Layout

`road.bin` is little-endian and versioned. All 66 local mission files parse with
this layout and no trailing bytes.

| Offset | Type | Meaning |
| --- | --- | --- |
| `0x00` | `UInt32` | Version. Observed and required by the exe: `2`. |
| `0x04` | `UInt32` | Crossroad count. |
| `0x08` | `RoadCrossroad[count]` | Fixed-size crossroad records, `0xec` bytes each. |
| after crossroads | `UInt32` | Waypoint count. |
| after waypoint count | `RoadWaypoint[count]` | Fixed-size waypoint records, `0x18` bytes each. |

Corpus totals:

| Metric | Value |
| --- | ---: |
| Files parsed | 66 |
| Crossroads | 7,136 |
| Waypoints | 45,472 |

Large city-style examples:

| Mission | Crossroads | Waypoints |
| --- | ---: | ---: |
| `freeride` | 278 | 1,581 |
| `freeridenoc` | 278 | 1,581 |
| `mise08-mesto` | 278 | 1,581 |
| `mise16-mesto` | 278 | 1,581 |
| `freeitaly` | 227 | 1,122 |
| `freekrajina` | 15 | 1,807 |

Small interior or local mission files may contain only a small local road graph,
for example Saliery missions commonly have 6 crossroads and 10 waypoints.

## Crossroad Record

The exe reads crossroad records in bulk as `count * 0xec` bytes. Current
`Road.swift` matches this size.

| Offset | Type | Current name | Confirmed details |
| --- | --- | --- | --- |
| `0x00` | `Float32[3]` | `position` | World-space point. |
| `0x0c` | `UInt8` | `semaphore` | Observed values: `0`, `1`. |
| `0x0d` | `UInt8[3]` | `unknown1` | Not mapped. |
| `0x10` | `Float32` | `speed` | Speed-like value. Post-load function normalizes this float. |
| `0x14` | `RoadWaypointLink[4]` | `waypointLinks` | Four 2-byte entries. |
| `0x1c` | `RoadDirectionLink[4]` | `directionLinks` | Four `0x34`-byte entries. |

Observed semaphore counts across the local corpus:

| Value | Count |
| --- | ---: |
| `0` | 6,297 |
| `1` | 839 |

The `semafor.i3d` string exists in the exe, but the direct reference was not
inside a cleanly identified Ghidra function in this pass. Treat the visual model
binding as not yet mapped.

## Direction Links

Each crossroad has four direction links. The post-load cleanup at `0x0055cb00`
iterates all four links in every crossroad. If a direction link has an active far
crosspoint but all four lane entries have `type == 0`, it changes the far
crosspoint field to `0xffff`, disabling that direction.

| Offset within link | Type | Current name | Confirmed details |
| --- | --- | --- | --- |
| `0x00` | `UInt16` | `farActiveCrossPoint` | `0xffff` means inactive after cleanup. |
| `0x02` | `UInt16` | `unknown1` | Not mapped. |
| `0x04` | `Float32` | `farCrosspointDistance` | Distance-like value. |
| `0x08` | `Float32` | `angle` | Angle-like value. |
| `0x0c` | `UInt8[2]` | `unknown3` | Not mapped. |
| `0x0e` | `UInt32` | `priority` | Contains normal values and packed/flagged values; semantics not fully mapped. |
| `0x12` | `UInt8[2]` | `unknown5` | Not mapped. |
| `0x14` | `RoadLane[4]` | `lanes` | Four 8-byte lane entries. |

Lane entry:

| Offset within lane | Type | Current name | Confirmed details |
| --- | --- | --- | --- |
| `0x00` | `UInt16` | `unknown1` | Not mapped. |
| `0x02` | `UInt8` | `type` | Observed values: `0`, `1`, `2`, `3`. `0` is empty for cleanup. |
| `0x03` | `UInt8` | `unknown2` | Not mapped. |
| `0x04` | `Float32` | `distance` | Distance-like value. |

Observed lane type counts:

| Type | Count |
| --- | ---: |
| `0` | 63,295 |
| `1` | 5,952 |
| `2` | 33,985 |
| `3` | 10,944 |

## Waypoint Record

The exe reads waypoint records in bulk as `count * 0x18` bytes. Current
`Road.swift` matches this size.

| Offset | Type | Current name | Confirmed details |
| --- | --- | --- | --- |
| `0x00` | `Float32[3]` | `position` | World-space point. |
| `0x0c` | `Float32` | `speed` | Speed-like value. Post-load function normalizes this float. |
| `0x10` | `UInt8` | `previousPoint` | Point index low byte. |
| `0x11` | `UInt8` | `previousPointType` | See point type table below. |
| `0x12` | `UInt8` | `nextPoint` | Point index low byte. |
| `0x13` | `UInt8` | `nextPointType` | See point type table below. |
| `0x14` | `UInt8` | `farPreviousCrosspoint` | Crossroad index low byte or sentinel-like value. |
| `0x15` | `UInt8` | `unknown1` | Not mapped. |
| `0x16` | `UInt8` | `farNextCrosspoint` | Crossroad index low byte or sentinel-like value. |
| `0x17` | `UInt8` | `unknown2` | Not mapped. |

Observed point type counts across both previous and next fields:

| Type | Count |
| --- | ---: |
| `0` | 20,241 |
| `1` | 799 |
| `128` | 13,228 |
| `129` | 12,793 |
| `130` | 11,853 |
| `131` | 11,009 |
| `132` | 9,115 |
| `133` | 7,837 |
| `134` | 3,407 |
| `135` | 610 |
| `136` | 32 |
| `255` | 20 |

Current `Road.swift` treats point types `>= 128` as waypoint indexes:

```text
waypointIndex = point + (type - 128) * 256
```

That matches the observed need for waypoint indexes above 255. Point types below
`128` are not direct waypoint indexes in the current code; they act as junction
or crossroad-side references and require crossroad/direction-link logic for full
original behavior.

## Traffic Generation Settings

`road.bin` does not contain the car model list. The scene entity of type `12`
does. Current `Scene.swift` reads that object as:

| Field | Type | Notes |
| --- | --- | --- |
| constant | `UInt32` | Observed/commented as `5`. |
| `outerRadiusToHide` | `Float32` | Hide generated traffic outside this radius. |
| `innerRadiusForGeneration` | `Float32` | Inner generation radius. |
| `outerRadiusForGeneration` | `Float32` | Outer generation radius. |
| `numOfGeneratedCars` | `UInt32` | Desired generated car count. |
| `numOfCarsInDatabase` | `UInt32` | Number of car definitions. |
| repeated car `modelName` | `char[20]` | Model base name. |
| repeated car `modelDensity` | `Float32` | Weighted selection value. |
| repeated car `colors` | `UInt32` | Not mapped here. |
| repeated car `isPolice` | `UInt16` | Nonzero means police. |
| repeated car `gangsterFlags` | `UInt16` | Not mapped here. |

The original exe has a `traffic_element` string referenced from function
`0x004b54a0`, which creates/labels runtime traffic elements. That function is
large and not fully mapped in this pass, but it confirms that generated road
traffic is runtime scene content, not static model instances stored in
`road.bin`.

## Runtime Flow

Confirmed high-level flow:

1. Mission loading at `0x005409d0` loads `scene.i3d`.
2. The same routine checks `missions\<mission>\road.bin`.
3. If present, it calls the road loader at `0x00559e60`.
4. The road loader requires version `2`.
5. It clears existing crossroad and waypoint vectors.
6. It reads the crossroad count and bulk-loads `count * 0xec` bytes.
7. It reads the waypoint count and bulk-loads `count * 0x18` bytes.
8. It normalizes the speed-like float at crossroad offset `0x10` and waypoint
   offset `0x0c`.
9. It calls `0x0055cb00`, which disables direction links that have no non-empty
   lane entries.
10. A virtual method call on the road object follows; the target was not mapped
    in this pass.
11. Scene traffic settings determine how many cars to create and which model
    names to choose.
12. Generated traffic follows the road waypoint/crossroad network.

## Implementation Notes For LS3D-SceneKit

Confirmed matches:

- `Road.swift` parses the correct version and bulk record sizes.
- The current point-index expansion for waypoint types `>= 128` is consistent
  with the data.
- `Scene.swift` parses the scene traffic settings separately from `road.bin`,
  which matches the original separation.

Known gaps:

- Current `Road.nextWaypointIndex(after:)` falls back by scanning waypoints whose
  previous point matches the current next point. That is a practical route graph,
  but it does not yet use the four crossroad direction links, lane entries,
  priorities, semaphore flag, or distance/angle fields that the original file
  provides.
- Direction link `priority` contains multiple value families. The exact policy
  for choosing among outgoing crossroad directions is not confirmed.
- Lane type meanings beyond `0 == empty/inactive for cleanup` are not confirmed.
- Semaphore behavior is not mapped beyond the crossroad field and corpus values.

Until the crossroad traversal code is mapped, field names should stay
conservative. The confirmed route data is enough to move generated cars along
waypoints, but exact original NPC behavior at intersections likely depends on
direction links, lane entries, semaphores, and priority fields.
