# NPC Car AI

This document records the NPC car AI details confirmed from:

- `Game.exe`, analyzed locally with Ghidra 12.1.2.
- Current LS3D-SceneKit code in `TrafficManager.swift`, `Scene.swift`,
  `Script.swift`, `ScriptArgs.swift`, and `ScriptExec.swift`.
- `docs/RoadTraffic.md`, which documents the `road.bin` route network.

No build commands were run.

## Scope

The original game has at least two separate NPC car systems:

| System | Evidence | Purpose |
| --- | --- | --- |
| Ambient road traffic | `traffic_element`, `trf_car_driver*`, `road.bin`, scene object type `12` | Spawns ordinary city traffic around the player and drives it on the road graph. |
| Scripted mission car actions | `ENTITY_CAR_MOVETO`, `ENTITY_CAR_ESCAPE`, `ENTITY_CAR_HUNT`, `ENEMY_CAR_*` | Adds explicit mission actions to entity/enemy action queues. |

These should not be collapsed into one implementation. Ambient traffic is
generated from scene traffic settings plus `road.bin`; mission car AI is
script-driven and uses entity action opcodes.

## Ambient Traffic Entry Points

Ghidra string references identify these relevant functions:

| Address | Evidence |
| --- | --- |
| `0x004b54a0` | Main ambient traffic setup/update routine. References `traffic_element`, `trf_car_driver`, `trf_car_driver1`, and `trf_car_driver2`. |
| `0x004baec0` | Creates or refreshes traffic car driver state for a specific car. References `trf_car_driver1` and `trf_car_driver2`. |
| `0x0049b860` | Roadblock/police-like setup. References `road_bl_C_%i`, `road_bl_I`, and `road_bl_E`. |
| `0x00499dc0` | Cleans up roadblock car records named with `road_bl_C_%i`. |

`Traffic_car` and `Traffic_person` strings exist in the executable string table,
but this pass did not find direct code references to those exact strings. The
runtime ambient traffic object name confirmed from code references is
`traffic_element`.

## Ambient Traffic Setup

Function `0x004b54a0` confirms this high-level flow:

1. Initializes ambient traffic manager state and clears several vectors.
2. Uses the loaded road graph from the mission road data.
3. Iterates generated traffic entries.
4. Creates or obtains a car scene object for each entry.
5. Names the generated car object `traffic_element`.
6. Stores a pointer to the created car AI/vehicle object in the scene node's user
   data slot.
7. Allocates a large vehicle object (`operator_new(0x221c)`) when the generated
   entry requires one.
8. Marks the vehicle object active at byte offset `0x65`.
9. Sets a route/control field at offset `0xcd8` to `0`.
10. Allocates a helper/controller object (`operator_new(0x29c)`) and attaches it
    to the generated car.
11. Creates driver/passenger human objects when the car and flags require them.
12. Applies debug/traffic colors based on traffic flags:
    - police-like traffic: `0xff009fff`
    - alternate flagged traffic: `0xffff9f00`
    - normal traffic: `0xffb0e0b0`

The exact names of offsets above are not confirmed. They are listed only because
the decompile shows the writes and calls around the `traffic_element` creation.

## Traffic Drivers

The original ambient traffic system can attach named driver actors:

| Runtime name | Confirmed references |
| --- | --- |
| `trf_car_driver` | `0x004b54a0` |
| `trf_car_driver1` | `0x004b54a0`, `0x004baec0` |
| `trf_car_driver2` | `0x004b54a0`, `0x004baec0` |

Confirmed behavior around these actors:

- The driver object is attached to the generated car object with a virtual call
  at vtable offset `0x2c`.
- The driver actor is named with one of the `trf_car_driver*` strings.
- The actor is enabled with a virtual call at vtable offset `0x24`.
- The actor receives a transform from the vehicle seat/driver data before being
  started.
- When a route/action pointer exists, the driver actor receives it with a virtual
  call at vtable offset `0x60`, then receives a speed/priority-like value `100`
  at vtable offset `0x14`, then a flag reset at vtable offset `0x68`.

Function `0x004baec0` checks whether a car already has matching traffic driver
state. If not, it creates a controller object, resolves a road segment from the
car position, and creates driver actors. It uses `road.bin` waypoint records
through the loaded road graph, including the waypoint previous/next crosspoint
fields documented in `RoadTraffic.md`.

The saved decompile shows this setup reading a nearest waypoint from
`FUN_0055b370`, checking the waypoint references at offsets `0x10` and `0x12`,
then comparing the car forward vector against the candidate road direction with
a dot product before calling `FUN_0055b710`. `Road.routePlacement` mirrors the
confirmed part by projecting a position onto waypoint segments, and its optional
direction argument chooses forward/backward travel from the nearest waypoint
using the supplied forward vector.
Fresh decompilation confirms `FUN_0055b370` is a nearest-waypoint lookup over
the loaded waypoint array. `FUN_0055b570` follows waypoint references until a
non-waypoint crossroad reference is reached, and `FUN_0055b5d0` chooses a
matching direction link from a crossroad. `FUN_0055b710` then builds a route
action from those crossroad/direction-link results. The current port does not
yet build that original route action object, but `RoadRoutePlacement` now carries
whether the placement travels forward or backward through the waypoint chain.

## Traffic Car Flags

Current LS3D-SceneKit reads each scene traffic car definition as:

| Field | Type |
| --- | --- |
| `modelName` | `char[20]` |
| `density` | `Float32` |
| `colors` | `UInt32` |
| `policeFlags` | `UInt16` |
| `gangsterFlags` | `UInt16` |

The original ambient traffic function copies traffic database bytes into each
generated entry and branches on them:

| Generated entry offset | Observed use |
| --- | --- |
| `0x150` | Low byte of `policeFlags`. Nonzero path marks the vehicle at car offset `0x2104`, spawns a police-like driver model path, and selects ARGB color `0xff009fff`. |
| `0x155` | Low byte of `gangsterFlags`, but only copied when `0x150` is zero. Nonzero path marks the vehicle at car offset `0x2105` and selects ARGB color `0xffff9f00`. |
| `0x14f` | High byte of `policeFlags`. Copied from the traffic database, but the exact meaning was not mapped. |

Normal traffic selects ARGB color `0xffb0e0b0`. Fresh decompilation of
`FUN_005fa510` shows the original stores a `(key, ARGB color)` pair on the car
object. Current LS3D-SceneKit preserves the exact bytes and exposes the selected
ARGB value on `TrafficCarDefinition`, but it does not yet apply that color to
materials because the original key-to-render-target mapping is not named.

## Scripted Car Actions

Function `0x0051cdd0` registers entity/enemy script command names. Function
`0x0051f3e0` prints or serializes queued entity actions and confirms the action
opcodes for scripted car AI:

| Opcode | Script/action text | Parameters confirmed from formatter |
| --- | --- | --- |
| `0x100c` | `Entity_CarHunt(%d,%d,%d,%d,%f)` | Four integer parameters and one float-like parameter. |
| `0x100d` | `Entity_CarEscape(%d,%d,%d,%d,%f,%f,%f)` | Four integer parameters and three floats. |
| `0x100e` | `Entity_CarMoveTo(%d,%d,%d,%d,%d)` | Five integer parameters. |

The command names registered around `0x0051cdd0` include both entity and enemy
aliases:

| Entity form | Enemy form |
| --- | --- |
| `ENTITY_CAR_MOVETO` | `ENEMY_CAR_MOVETO` |
| `ENTITY_CAR_ESCAPE` | `ENEMY_CAR_ESCAPE` |
| `ENTITY_CAR_HUNT` | `ENEMY_CAR_HUNT` |

Related car/entity action strings in the same command table include:

| Command string | Confirmed implication |
| --- | --- |
| `ENTITY_MOVE_TO_CAR` | Actor movement toward a car. |
| `ENTITY_USECAR` / `ENEMY_USECAR` | Actor enters or uses a car. |
| `ENTITY_GROUP_ADDCAR` / `ENEMY_GROUP_ADDCAR` | Adds a car to an entity/enemy group. Formatter opcode `0x1036` prints `Entity_GroupAddCar(%d,%d,%f)`. |
| `ENTITY_ACTION_CARJUMP` | Car-related entity action. Exact behavior not mapped. |

The decompile confirms command registration and action serialization. It does
not fully map the runtime steering implementation behind `CarMoveTo`,
`CarEscape`, or `CarHunt`.

## Script-Level Car Commands

The exe also registers lower-level car and police script commands in
`0x00463960`. Relevant confirmed strings include:

| Command | Confirmed role from name/reference |
| --- | --- |
| `CAR_CALM` | Car state command. Runtime behavior not mapped. |
| `CAR_FORCESTOP` | Forces a car to stop. |
| `CAR_SETSPEED` | Sets a car speed value. |
| `POLICE_SPEED_FACTOR` | Police speed scaling command. |
| `POLICEMANAGER_ON` | Enables/disables police manager. |
| `POLICEMANAGER_ADD` | Adds an entry to police manager. |
| `POLICEMANAGER_DEL` | Removes an entry from police manager. |
| `POLICEMANAGER_SETSPEED` | Sets police manager speed. |
| `POLICEMANAGER_FORCEARREST` | Forces police arrest behavior. |
| `TAXIDRIVER_ENABLE` | Enables/disables taxi driver behavior. |
| `SETCITYTRAFFICVISIBLE` | Registered by the exe command-name table. Current port maps the command name to ambient traffic visibility through `TrafficManager.isEnabled`, combined with cutscene-camera suppression; the original handler was not mapped in this pass. |
| `FREERIDE_TRAFFSETUP` | Registered by the exe command-name table. Handler behavior was not mapped in this pass. |

Only the string references were mapped for these commands in this pass. Their
full handlers should be decompiled separately before treating parameter
semantics as stable.

## Current LS3D-SceneKit Behavior

Current ambient traffic is implemented in `TrafficManager.swift` and is simpler
than the original:

1. Load `Road` from `missions/<mission>/road.bin`.
2. Load traffic generation settings from scene object type `12`.
3. Spawn at most `16` generated cars.
4. Choose model names by traffic density.
5. Place cars near the player/camera within generation radii.
6. Resolve placement through `Road.routePlacement(near:routeSeed:)`, which
   projects onto usable forward road waypoint segments. Direction-aware
   placements can travel forward or backward through the waypoint chain.
7. Use `max(10, max(currentWaypoint.speed, nextWaypoint.speed)) * speedScale`.
8. Offset display position sideways by a fixed lane offset.
9. Choose the next waypoint with
   `Road.continuationWaypointIndex(from:previousIndex:routeSeed:)` once a car
   has an incoming segment. The continuation pass considers both endpoint sides
   of the current waypoint, prefers direct/local waypoint continuations first,
   and only expands active crossroad direction links as a fallback. Local
   continuations use the best-aligned candidate rather than seeded variation, so
   multi-point turns stay on their sampled lane path. It excludes the waypoint
   the car came from when possible and ranks candidates against the incoming
   direction. This prevents paired lane records like `988 -> 986 -> 988` from
   turning into a U-turn loop without letting cars cut across unrelated crossroad
   exits.
10. Move/display cars by linear interpolation between sampled waypoints. The
    route graph carries multi-point turns; traffic rendering does not add extra
    curve smoothing that can overshoot or loop.
11. Recycle cars only when they are unplaced or outside the active traffic
    radius, so nearby visible cars are not re-placed just because the player
    moved the placement center.

Current implementation does not yet model these original behaviors:

- Traffic driver actors named `trf_car_driver*`.
- Police/gangster traffic behavior beyond preserving the original traffic flag
  bytes and selected ARGB value.
- Original road direction-link and lane selection at intersections.
- Original `CarMoveTo`, `CarEscape`, or `CarHunt` action queues.
- Police manager and taxi-driver subsystems.
- Obstacle response, car following distance, traffic lights, or collision-aware
  yielding. Those behaviors may exist in the original, but they were not mapped
  in this pass.

Current `ScriptExec.swift` implements a subset of low-level car commands:

| Command | Current behavior |
| --- | --- |
| `car_enableus` | Toggles node action availability. |
| `car_breakmotor` | Marks car unusable and stops physics when broken. |
| `car_forcestop` | Clears velocity/angular velocity. |
| `car_getactlevel` / `car_setactlevel` | Stores a local act-level value. |
| `car_getseatcount` | Returns `4`. |
| `car_getspeed` | Returns player vehicle speed only; otherwise `0`. |
| `car_inwater` | Returns `0`. |
| `car_lock` / `car_lock_all` | Stops the car when locked. |
| `car_muststeal` | Marks player steal behavior. |
| `car_repair` | Marks car usable and clears player vehicle motion. |
| `car_setspeed` | Stops player vehicle when speed is `0`; no full NPC car speed AI. |

No current script parser entries exist for `ENTITY_CAR_MOVETO`,
`ENTITY_CAR_ESCAPE`, `ENTITY_CAR_HUNT`, `ENEMY_CAR_MOVETO`,
`ENEMY_CAR_ESCAPE`, or `ENEMY_CAR_HUNT`.

## Practical Implementation Notes

For closer original behavior, the next confirmed targets are:

1. Map the runtime steering/action functions called by action opcodes `0x100c`,
   `0x100d`, and `0x100e`.
2. Map the road traversal logic used by `0x004baec0`, especially how it chooses
   a next crossroad/direction link from the car's current road segment.
3. Map how the original `(key, ARGB color)` pairs created by `FUN_005fa510`
   affect rendered car materials or debug overlays.
4. Add driver actor support only after the seat attachment and animation calls
   are mapped well enough to avoid hardcoded placement.

Until those functions are mapped, the confirmed ambient behavior is: generated
cars are created as runtime `traffic_element` vehicles, optionally receive
`trf_car_driver*` actors, and use the loaded road graph for route state.
