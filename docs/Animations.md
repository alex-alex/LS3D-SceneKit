# Animations

This document records the player-relevant animation names found from:

- `Game.exe` embedded animation table strings, where `.i3d` animation names correspond to `.5ds` files in this project.
- `/Users/alex/Development/Mafia/Mafia/anims`, used to confirm the files exist.
- `tables/predmety.def`, used to map weapons to animation set ids.
- Current LS3D-SceneKit code paths in `PlayerController.swift`, `Game.swift`, and `Weapon.swift`.

All paths below are relative to the game data root, for example `anims/walk1.5ds`.

When a `.5ds` animation is played through `playAnimation`, the matching `.tck` position animation is also played automatically if it exists. The `.tck` uses the same repeat setting and a derived action key so it can run alongside the skeleton animation. Record playback opts out of this automatic path because records already schedule their `.tck` tracks explicitly.

## Animation Set Ids

Weapon/player animation set `N` is stored in `tables/predmety.def` for weapon items, but the set id behaves more like a player stance/held-item animation family than a literal weapon id.

The parser reads an `Int32` at byte offset `68` in each 188-byte item record:

```swift
let animationSetId = data.int32(at: offset + 68)
```

Observed semantic meaning:

| Set id | Meaning |
| --- | --- |
| 1 | Empty hands |
| 2 | Small gun in hand |
| 3 | Small gun aiming |
| 4 | Sawed-off shotgun |
| 5 | Long gun |
| 6 | Crouch, no gun |
| 7 | Crouch, small gun |
| 8 | Crouch, long gun |

Raw `predmety.def` weapon values currently read by the project:

| Item id | Item | Animation set |
| --- | --- | --- |
| 6 | Colt Detective Special | 2 |
| 7 | S&W model 27 Magnum | 2 |
| 8 | S&W model 10 M&P | 2 |
| 9 | Colt 1911 | 1 |
| 10 | Thompson 1928 | 4 |
| 11 | Pump shotgun | 8 |
| 12 | Sawed-off shotgun | 7 |
| 13 | US Rifle M1903 Springfield | 3 |
| 14 | Mosin-Nagant 1891/30 | 3 |
| 33 | Thompson 1928 no sound | 4 |
| 34 | Pump shotgun no sound | 8 |

Notes:

- When no valid equipped weapon animation set exists, current `PlayerController` falls back to set `1`.
- The raw weapon values do not explain every stance transition by themselves. Treat them as the weapon's requested animation family; player state such as aiming or crouching can change which semantic family should be active.

## Walking And Movement

The original animation table has movement sets `1...8`. Use `N` as the active player animation-set id.

| Player action | Animation |
| --- | --- |
| Idle | `anims/breath0Na.5ds`, `anims/breath0Nb.5ds`, `anims/breath0Nc.5ds`, `anims/breath0Nd.5ds` |
| Walk forward | `anims/walkN.5ds` |
| Run forward | `anims/runN.5ds` |
| Walk backward | `anims/backN.5ds` |
| Turn in place | `anims/turnN.5ds` |
| Step left | `anims/leftN.5ds` |
| Step right | `anims/rightN.5ds` |
| Strafe left | `anims/strafLN.5ds` |
| Strafe right | `anims/strafRN.5ds` |
| Walk forward-left | `anims/walkLN.5ds` |
| Walk forward-right | `anims/walkRN.5ds` |
| Run forward-left | `anims/runLN.5ds` |
| Run forward-right | `anims/runRN.5ds` |
| Back-left | `anims/backLN.5ds` |
| Back-right | `anims/backRN.5ds` |
| Strafe/run-left blend | `anims/strafRLN.5ds` |
| Strafe/run-right blend | `anims/strafRRN.5ds` |

Notes:

- Current `PlayerController` uses only a subset: `backN`, `strafLN`, `strafRN`, `leftN`, `rightN`, `runN`, `walkN`, `turnN`, and `breath0N*`.
- The original table includes the directional variants listed above. They exist in the extracted animation folder for sets `1...8`.

## Jump And Air

| Player action | Animation |
| --- | --- |
| Jump | `anims/jump1.5ds` |
| Jump left | `anims/jumpL1.5ds`, `anims/jumpL3.5ds` |
| Jump right | `anims/jumpR1.5ds`, `anims/jumpR3.5ds` |
| Fall loop | `anims/!plachteni.5ds` |
| Land | `anims/!doskok.5ds` |

Current `PlayerController` chooses `jumpLN`/`jumpRN`/`jumpN` based on lateral input and set id, then falls back to `jump1.5ds`.

## Crouch

Do not use `x panika drep ...` for player crouch. Those are panic/NPC-style animations, not Tommy/player crouch.

Player crouch should use crouch semantic sets plus `drep` weapon/action animations:

| Crouch action | Animation |
| --- | --- |
| Crouch, no gun | set `6` movement/idle variants |
| Crouch, small gun | set `7` movement/idle variants |
| Crouch, long gun | set `8` movement/idle variants |
| Crouched fire | `anims/gun0N drep Fire.5ds` |
| Crouched fire while strafing | `anims/gun0N drep Fire Straf.5ds` |
| Crouched reload | `anims/gun0N drep Reload.5ds` |
| Crouched weapon toggle | `anims/gun drep on off.5ds` |
| Crouched weapon drop | `anims/gun drep zahozeni.5ds` |

Implementation:

- `PlayerController.swift` uses crouch semantic sets `6`, `7`, and `8` for crouched movement/idle.
- It does not use `x panika drep ...` files for player crouch.

## Guns

Use the active animation set `N`. The equipped weapon gives a base value from `predmety.def`, but aiming/crouching can shift the player to another semantic set.

| Player action | Animation |
| --- | --- |
| Fire standing | `anims/gun0N stoj Fire.5ds` |
| Fire standing while strafing | `anims/gun0N stoj Fire Straf.5ds` |
| Fire crouched | `anims/gun0N drep Fire.5ds` |
| Fire crouched while strafing | `anims/gun0N drep Fire Straf.5ds` |
| Reload standing | `anims/gun0N stoj Reload.5ds` |
| Reload crouched | `anims/gun0N drep Reload.5ds` |
| Shotgun pump standing | `anims/gun08 stoj Pump.5ds` |
| Shotgun pump crouched | `anims/gun08 drep Pump.5ds` |
| Weapon toggle standing | `anims/gun stoj on off.5ds` |
| Weapon toggle crouched | `anims/gun drep on off.5ds` |
| Weapon drop standing | `anims/gun stoj zahozeni.5ds` |
| Weapon drop crouched | `anims/gun drep zahozeni.5ds` |

Original exe fire selection:

- Standing:
  - Uses `gun0N stoj Fire Straf.5ds` for weapon sets `3`, `4`, `7`, or `8` when the movement action is strafe-like.
  - Otherwise uses `gun0N stoj Fire.5ds`.
- Crouched:
  - Uses `gun0N drep Fire Straf.5ds` for weapon sets `3`, `4`, or `7` when the movement action is strafe-like.
  - Otherwise uses `gun0N drep Fire.5ds`.

Implementation:

- `Game.swift` tries `Fire Straf` variants first when the player is firing while strafing.
- Gun action lookup preserves the raw weapon-table animation set first, then falls back through the semantic standing/crouch sets where matching files exist.

## Baseball Bat And Melee

| Player action | Animation |
| --- | --- |
| Baseball bat windup | `anims/boj basb naprah hpt.5ds` |
| Baseball bat hit right hand | `anims/boj basb z rh.5ds` |
| Baseball bat hit left hand | `anims/boj basb z lh.5ds` |
| Baseball bat hit right side | `anims/boj basb z rs.5ds` |
| Baseball bat hit left side | `anims/boj basb z ls.5ds` |
| Baseball bat combo | `anims/boj basb kombo.5ds` |
| Held-bat hit right hand | `anims/boj hpt basb rh.5ds` |
| Held-bat hit left hand | `anims/boj hpt basb lh.5ds` |
| Held-bat hit right side | `anims/boj hpt basb rs.5ds` |
| Held-bat hit left side | `anims/boj hpt basb ls.5ds` |
| Held-bat guard/cover | `anims/boj hpt basb kryt.5ds` |

Current `Game.swift` uses the windup and hit candidate lists above for baseball bat charge/release.

## Car Enter And Exit

`Nas` means `nastup` / get in. `Vys` means `vystup` / get out.

Seat suffixes:

- `FL`: front-left
- `FR`: front-right
- `BL`: back-left
- `BR`: back-right

Small car enter:

- `anims/AutoSmNas FL.5ds`
- `anims/AutoSmNas FR.5ds`
- `anims/AutoSmNas BL.5ds`
- `anims/AutoSmNas BR.5ds`

Big car enter:

- `anims/AutoBigNas FL.5ds`
- `anims/AutoBigNas FR.5ds`
- `anims/AutoBigNas BL.5ds`
- `anims/AutoBigNas BR.5ds`

Small car exit:

- `anims/AutoSmVys FL.5ds`
- `anims/AutoSmVys FR.5ds`
- `anims/AutoSmVys BL.5ds`
- `anims/AutoSmVys BR.5ds`

Big car exit:

- `anims/AutoBigVys FL.5ds`
- `anims/AutoBigVys FR.5ds`
- `anims/AutoBigVys BL.5ds`
- `anims/AutoBigVys BR.5ds`

Other car enter/exit related animations:

- `anims/AutoPrelezLtoR.5ds`
- `anims/AutoPrelezRtoL.5ds`
- `anims/Auto lezeni z vraku.5ds`

## Sitting In Car

| State | Animation |
| --- | --- |
| Driver idle/sitting | `anims/AutoRidicStativ.5ds` |
| Driver steering/wheel pose | `anims/AutoRidicVolant.5ds` |
| Passenger sitting | `anims/AutoSpolStativ.5ds` |

## Vehicle Special Cases

Formula/race car:

- `anims/FormuleNastupL.5ds`
- `anims/FormuleNastupR.5ds`
- `anims/FormuleVystupL.5ds`
- `anims/FormuleVystupR.5ds`
- `anims/FormuleVolant.5ds`
- `anims/FormuleStativ.5ds`

Tram:

- `anims/salina nastup.5ds`
- `anims/salina vystup.5ds`
- `anims/salindriver.5ds`

## Car Combat And Car Death

Car firing:

- `anims/Auto fire01 L.5ds`
- `anims/Auto fire01 L On.5ds`
- `anims/Auto fire01 L Off.5ds`
- `anims/Auto fire01 R.5ds`
- `anims/Auto fire01 R On.5ds`
- `anims/Auto fire01 R Off.5ds`
- `anims/Auto fire02 L.5ds`
- `anims/Auto fire02 L On.5ds`
- `anims/Auto fire02 L Off.5ds`
- `anims/Auto fire02 R.5ds`
- `anims/Auto fire02 R On.5ds`
- `anims/Auto fire02 R Off.5ds`
- `anims/Auto fire03 L.5ds`
- `anims/Auto fire03 R.5ds`
- `anims/Auto fire03 On.5ds`
- `anims/Auto fire03 Off.5ds`

Car death:

- `anims/smrt auto ridic01.5ds`
- `anims/smrt auto spol IN01.5ds`
- `anims/smrt auto spol IN02.5ds`
- `anims/smrt auto spol OutL.5ds`
- `anims/smrt auto spol OutR.5ds`

## Throwing People From Cars

The exe animation table includes these related animations:

- `anims/VyhozMrtBackR.5ds`
- `anims/VyhozMrtBackL.5ds`
- `anims/VyhozMrtFrontR.5ds`
- `anims/VyhozMrtFrontL.5ds`
- `anims/VyhozBackR.5ds`
- `anims/VyhozBackL.5ds`
- `anims/VyhozFrontR.5ds`
- `anims/VyhozFrontL.5ds`
- `anims/VyhozManBackL.5ds`
- `anims/VyhozManFrontL.5ds`

## Current Implementation Notes

- `Game.swift` plays driver-side `FL` enter/exit animation candidates around mode changes, then keeps Tommy visible in the corrected driver seat. It loops `AutoRidicStativ` for neutral driving and switches to `AutoRidicVolant` while the steering wheel is turned.
- `ScriptExec.swift` has `human_force_settocar`, which places a human in a car seat directly and loops `AutoSpolStativ` for non-player occupants.
- `PlayerController.swift` uses the documented movement, crouch, jump/fall/land, idle, turn, and directional locomotion families for supported player movement states.
- `Game.swift` supports weapon fire/reload animations, `Fire Straf` gun variants, shotgun pump cycling, weapon toggle/drop animations, baseball bat animations, side jump action animations, and player driver enter/exit/sitting animations.
- Car combat, car death, and throwing people from cars are documented above, but this project does not currently expose gameplay states that invoke those player/NPC animation families.
