# Companion Squad System

## Overview
Native C++ replacement of the Lua-based `CompanionRoster_TWW12.lua`. DB-driven roster, `.comp` dot-commands, custom `CompanionAI` (ScriptedAI subclass), per-creature AI ticks (no global polling).

## Files
**Core** (`src/server/game/Companion/`):
- `CompanionDefines.h` — `Companion::` namespace: enums (Role, Mode), structs (RosterEntry, SquadSlot, ControlState, ActiveCompanion, PlayerSquadState, FormationOffset)
- `CompanionMgr.h` + `.cpp` — `sCompanionMgr` singleton: roster loading, squad CRUD, spawn/despawn, formation math, player-scaled health

**Scripts** (`src/server/scripts/Custom/Companion/`):
- `CompanionAI.h` + `.cpp` — ScriptedAI subclass: role-based combat, healer logic, anti-friendly-fire, leash teleport, evade override
- `companion_commands.cpp` — `.comp` CommandScript (new-style ChatCommandBuilder format, RBAC_ROLE_PLAYER)
- `companion_scripts.cpp` — PlayerScript (OnLogin/OnLogout/OnMapChanged), WorldScript (OnStartup), RegisterCreatureAI(CompanionAI)

**SQL** (`sql/RoleplayCore/5*.sql`):
- `5. companion system.sql` — world: `companion_roster` table
- `5.1 companion characters.sql` — characters: `character_companion_squad` + `character_companion_control`
- `5.2 companion auth.sql` — auth: RBAC permission 3008 (granted to all via secId=0)
- `5.3 companion seed data.sql` — 5 seed companions (500001-500005) with creature_template, creature_template_model, creature_template_difficulty, creature_equip_template, roster entries with real spells

## Modified Existing Files
- `CharacterDatabase.h/.cpp` — 6 prepared statements (CHAR_SEL/DEL/INS_COMPANION_SQUAD, CHAR_SEL/DEL/REP_COMPANION_CONTROL)
- `RBAC.h` — `RBAC_PERM_COMMAND_COMP = 3008`
- `custom_script_loader.cpp` — 3 AddSC_ registrations

## Commands
```
.comp status        — show squad, mode, follow state
.comp roster        — list available companions
.comp set <1-5> <name|entry>
.comp clear <1-5|all>
.comp summon / .comp dismiss
.comp mode <passive|defend|assist>
.comp follow        — toggle
```

## Key Design Decisions
- **ChatCommandBuilder**: Must use new-style format `{ "name", Handler, rbac::RBAC_ROLE_PLAYER, Console::No }` — old 5-arg format doesn't register typed-parameter handlers
- **Health scaling**: Set programmatically in SummonSquad via SetMaxHealth/SetFullHealth (Tank=100%, Melee=60%, Ranged/Caster/Healer=50% of player max HP). Base creature stats don't scale at high levels
- **Level**: `SetLevel(player->GetLevel())` on summon
- **Display models**: Required in `creature_template_model` or creatures are invisible
- **Formation**: Role-based offsets behind player — Tank 1.5yd, Melee 2.0yd, Ranged/Caster 3.5yd (±0.6 rad lateral), Healer 4.0yd. Same-role spread 0.8 rad

## Seed Companions (entry range 500001-500005)
| Entry | Name | Role | Spells | Equipment |
|---|---|---|---|---|
| 500001 | Warrior | Tank | 355 Taunt, 23922 Shield Slam, 29567 Heroic Strike | Sword + Shield |
| 500002 | Rogue | Melee | 1752 Sinister Strike, 53 Backstab | Dual axes |
| 500003 | Hunter | Ranged | 6660 Shoot | Bow |
| 500004 | Mage | Caster | 133 Fireball, 116 Frostbolt | Staff |
| 500005 | Priest | Healer | 2061 Flash Heal, 139 Renew | Mace |

## Gotchas — Combat AI
- **Neutral faction targets** (faction 7, e.g. training dummies): `IsValidAttackTarget` fails because `Object.cpp:2508-2514` checks player reputation "at war" flag, which isn't set for faction 7. Fix: `SelectAssistTarget` trusts owner's `GetVictim()` directly, only checking `IsFriendlyTarget` (owner/squad exclusion) instead of full `IsValidAttackTarget`
- **Companion flags on summon**: `UNIT_FLAG_PLAYER_CONTROLLED` + `SetImmuneToPC(true)` + owner's faction. These interact with CvC/PvC hostility checks in `IsValidAttackTarget`

## Current Status (Feb 2026)
- All code committed and pushed to master (multiple commits)
- SQL applied to live DB (world, characters, auth)
- Basic testing done: commands work, companions spawn with correct level/health/weapons/formation
- **Assist mode fixed** (commit `3026810524`): companions now attack owner's victim even if neutral faction
- **Still needs testing**: healer AI, spell casting, persistence across logout, map change respawn
- **Known issue**: research_project SELECT column order was wrong — fixed in `85aeb994c2`
- **Potential improvements**: more companion variety, visual customization, damage scaling, better kiting AI for ranged/caster
