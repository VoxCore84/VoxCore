#!/usr/bin/env python3
"""Comprehensive DBErrors.log parser - categorizes ALL error patterns."""

import re
import sys
from collections import defaultdict, Counter

LOG_PATH = r"C:\Users\atayl\VoxCore\out\build\x64-RelWithDebInfo\bin\RelWithDebInfo\DBErrors.log"

# Define regex patterns with named groups for categorization
# Each entry: (compiled_regex, pattern_template, system_category, addressed_by_cleanup, fix_description)
PATTERNS = [
    # === HOTFIX SYSTEM ===
    (re.compile(r"Table `hotfix_data` references unknown DB2 store by hash (0x[A-F0-9]+) and has no reference to `hotfix_blob`"),
     "Table `hotfix_data` references unknown DB2 store by hash {HASH} ... hotfix id N with RecordID: N",
     "hotfix_data", False,
     "DELETE orphaned hotfix_data rows referencing unknown DB2 store hashes, OR add the missing DB2 store definition to the core"),

    # === SPELL PROC ===
    (re.compile(r"Spell Id \d+ has DBC ProcFlags 0x[A-Fa-f0-9]+ 0x[A-Fa-f0-9]+, but it.s of non-proc aura type"),
     "Spell Id N has DBC ProcFlags 0xH 0xH, but non-proc aura type ... needs `spell_proc` entry",
     "spell_proc", False,
     "Add entries to `spell_proc` table for each affected spell. TC upstream issue -- informational only"),

    # === CREATURE TEMPLATE ===
    (re.compile(r"No model data exist for `CreatureDisplayID` = \d+ listed by creature \(Entry: \d+\)"),
     "No model data exist for `CreatureDisplayID` = N listed by creature (Entry: N)",
     "creature_template_model", False,
     "Add missing CreatureDisplayInfo rows to creature_template_model, or fix the displayId"),

    (re.compile(r"Creature \(Entry: \d+\) has non-existing faction template \(\d+\)"),
     "Creature (Entry: N) has non-existing faction template (N), set to faction 35",
     "creature_template (faction)", False,
     "UPDATE creature_template SET faction=35 WHERE faction=0 (or find correct faction from DB2)"),

    (re.compile(r"Creature \(Entry: \d+\) has non-existing Spell\d+ \(\d+\), set to 0"),
     "Creature (Entry: N) has non-existing SpellN (N), set to 0",
     "creature_template_spell", False,
     "DELETE FROM creature_template_spell WHERE Spell NOT IN (valid spells)"),

    (re.compile(r"Creature \(Entry: \d+\) has invalid unit_class \(\d+\) in creature_template"),
     "Creature (Entry: N) has invalid unit_class (N). Set to 1 (UNIT_CLASS_WARRIOR)",
     "creature_template (unit_class)", False,
     "UPDATE creature_template SET unit_class=1 WHERE unit_class=0"),

    (re.compile(r"Creature \(Entry: \d+\) does not have any existing display id in creature_template_model"),
     "Creature (Entry: N) does not have any existing display id in creature_template_model",
     "creature_template_model (no display)", False,
     "Add valid display IDs to creature_template_model for these entries"),

    (re.compile(r"Creature \(Entry: \d+\) has invalid creature family \(\d+\) in `family`"),
     "Creature (Entry: N) has invalid creature family (N) in `family`",
     "creature_template (family)", False,
     "UPDATE creature_template SET family=0 WHERE family not in valid CreatureFamily enum"),

    # === CREATURE EQUIP ===
    (re.compile(r"Item \(ID=\d+\) in creature_equip_template\.ItemID\d+ for CreatureID"),
     "Item (ID=N) in creature_equip_template.ItemIDN for CreatureID=N is not equipable, forced to 0",
     "creature_equip_template", False,
     "UPDATE creature_equip_template SET ItemIDN=0 for affected rows"),

    (re.compile(r"Creature equipment template with id 0 found for creature \d+, skipped"),
     "Creature equipment template with id 0 found for creature N, skipped",
     "creature_equip_template (id=0)", False,
     "Fix creature_template to not reference equip template id 0"),

    # === CREATURE TEMPLATE ADDON ===
    (re.compile(r"Creature \(Entry: \d+\) has invalid displayInfoId \(\d+\) for mount defined in `creature_template_addon`"),
     "Creature (Entry: N) has invalid displayInfoId (N) for mount in `creature_template_addon`",
     "creature_template_addon (mount)", False,
     "UPDATE creature_template_addon SET mount=0 WHERE entry IN (affected entries)"),

    (re.compile(r"Creature template \(Entry: \d+\) does not exist but has a record in `creature_template_addon`"),
     "Creature template (Entry: N) does not exist but has record in `creature_template_addon`",
     "creature_template_addon (orphan)", False,
     "DELETE FROM creature_template_addon WHERE entry NOT IN (SELECT entry FROM creature_template)"),

    (re.compile(r"Creature \(Entry: \d+\) has invalid aiAnimKit \(\d+\) defined in `creature_template_addon`"),
     "Creature (Entry: N) has invalid aiAnimKit (N) in `creature_template_addon`",
     "creature_template_addon (aiAnimKit)", False,
     "UPDATE creature_template_addon SET aiAnimKit=0 WHERE aiAnimKit=32767"),

    # === CREATURE SPAWN ===
    (re.compile(r"Table `creature` have creature \(GUID: \d+ Entry: \d+\) with `phaseid` \d+ does not exist"),
     "Table `creature` creature (GUID: N Entry: N) with `phaseid` N does not exist, set to 0",
     "creature (phaseid)", False,
     "UPDATE creature SET phaseid=0 WHERE phaseid NOT IN (SELECT ID FROM phase)"),

    (re.compile(r"Table `creature` has creature \(GUID: \d+\) has unsupported difficulty \d+ for map"),
     "Table `creature` creature (GUID: N) has unsupported difficulty N for map (Id: N)",
     "creature (difficulty)", False,
     "Fix spawnDifficulties to use only valid difficulty IDs for each map"),

    (re.compile(r"Table `creature` has creature \(GUID: \d+\) that is not spawned in any difficulty, skipped"),
     "Table `creature` creature (GUID: N) not spawned in any difficulty, skipped",
     "creature (no difficulty)", False,
     "DELETE creatures with no valid difficulty or fix spawnDifficulties"),

    (re.compile(r"Table `creature` has creature \(GUID: \d+\) that spawned at nonexistent map"),
     "Table `creature` creature (GUID: N) spawned at nonexistent map (Id: N), skipped",
     "creature (bad map)", False,
     "DELETE FROM creature WHERE map NOT IN (valid map IDs)"),

    (re.compile(r"Table `creature` have creature \(GUID: \d+ Entry: \d+\) with both `phaseid` and `phasegroup` set"),
     "Table `creature` creature (GUID: N Entry: N) both `phaseid` and `phasegroup` set",
     "creature (phase conflict)", False,
     "UPDATE creature SET phasegroup=0 WHERE phaseid!=0 AND phasegroup!=0"),

    (re.compile(r"Table `creature` has creature \(GUID: \d+ Entry: \d+\) with invalid `curHealthPct`"),
     "Table `creature` creature (GUID: N Entry: N) invalid `curHealthPct` N",
     "creature (curHealthPct)", False,
     "UPDATE creature SET curHealthPct=100 WHERE curHealthPct > 100 OR curHealthPct < 1"),

    (re.compile(r"Table `creature` has creature \(GUID: \d+\) has UNIT_FLAG3_FAKE_DEAD set without IMMUNE"),
     "Table `creature` creature (GUID: N) UNIT_FLAG3_FAKE_DEAD without IMMUNE flags",
     "creature (FAKE_DEAD flag)", False,
     "Add IMMUNE_TO_PC|IMMUNE_TO_NPC flags when FAKE_DEAD is set"),

    (re.compile(r"Table `creature` have creature \(GUID: \d+ Entry: \d+\) with `terrainSwapMap` \d+ which cannot be used"),
     "Table `creature` creature (GUID: N Entry: N) `terrainSwapMap` N invalid, set to -1",
     "creature (terrainSwapMap)", True,
     "ADDRESSED: UPDATE creature SET terrainSwapMap=-1"),

    (re.compile(r"Table `creature` has creature \(GUID: \d+\) with `MovementType`=0 \(idle\) have `wander_distance`"),
     "Table `creature` creature (GUID: N) MovementType=0 (idle) wander_distance<>0, set to 0",
     "creature (wander_distance)", False,
     "UPDATE creature SET wander_distance=0 WHERE MovementType=0 AND wander_distance!=0"),

    # === GAMEOBJECT ===
    (re.compile(r"Table `gameobject` has gameobject \(GUID: \d+\) has unsupported difficulty \d+ for map"),
     "Table `gameobject` gameobject (GUID: N) unsupported difficulty N for map (Id: N)",
     "gameobject (difficulty)", False,
     "Fix spawnDifficulties in gameobject table for valid difficulty IDs per map"),

    (re.compile(r"Table `gameobject` has gameobject \(GUID: \d+ Entry: \d+\) with `spawntimesecs` \(0\) value"),
     "Table `gameobject` gameobject (GUID: N Entry: N) `spawntimesecs` (0) but despawnable",
     "gameobject (spawntimesecs)", True,
     "ADDRESSED: UPDATE gameobject SET spawntimesecs=300 WHERE spawntimesecs=0"),

    # === QUEST ===
    (re.compile(r"Quest \d+ has PrevQuestId \d+, but no such quest"),
     "Quest N has PrevQuestId N, but no such quest",
     "quest (PrevQuestId)", False,
     "UPDATE quest_template_addon SET PrevQuestId=0 WHERE PrevQuestId NOT IN (SELECT ID FROM quest_template)"),

    (re.compile(r"Quest \d+ has NextQuestId \d+, but no such quest"),
     "Quest N has NextQuestId N, but no such quest",
     "quest (NextQuestId)", False,
     "UPDATE quest_template_addon SET NextQuestId=0 WHERE NextQuestId NOT IN (SELECT ID FROM quest_template)"),

    (re.compile(r"Quest \d+ objective \d+ has non existing creature entry \d+"),
     "Quest N objective N has non existing creature entry N",
     "quest_objectives (creature)", False,
     "DELETE quest_objectives referencing non-existent creature entries"),

    (re.compile(r"Quest \d+ objective \d+ has non existing gameobject entry \d+"),
     "Quest N objective N has non existing gameobject entry N",
     "quest_objectives (gameobject)", False,
     "DELETE quest_objectives referencing non-existent gameobject entries"),

    (re.compile(r"Quest \d+ objective \d+ has non existing item entry \d+"),
     "Quest N objective N has non existing item entry N",
     "quest_objectives (item)", False,
     "DELETE quest_objectives referencing non-existent items"),

    (re.compile(r"Quest \d+ objective \d+ has non existing areatrigger id \d+"),
     "Quest N objective N has non existing areatrigger id N",
     "quest_objectives (areatrigger)", False,
     "Delete quest_objectives referencing non-existent areatrigger IDs"),

    (re.compile(r"Quest \d+ objective \d+ has non existing spell id \d+"),
     "Quest N objective N has non existing spell id N",
     "quest_objectives (spell)", False,
     "Delete quest_objectives referencing non-existent spells"),

    (re.compile(r"Quest \d+ objective \d+ has unhandled type \d+"),
     "Quest N objective N has unhandled type N",
     "quest_objectives (unhandled type)", False,
     "Objective type not implemented in core -- needs core support"),

    (re.compile(r"Quest \d+ has `RewardSpellCast` = \d+ but spell \d+ does not exist"),
     "Quest N has `RewardSpellCast` = N but spell does not exist",
     "quest_template (RewardSpellCast)", False,
     "UPDATE quest_template SET RewardSpellCast=0 for invalid spells"),

    (re.compile(r"Quest \d+ has `SourceItemId` = \d+ but item with entry \d+ does not exist"),
     "Quest N has `SourceItemId` = N but item does not exist",
     "quest_template (SourceItemId)", False,
     "UPDATE quest_template SET SourceItemId=0 for invalid items"),

    (re.compile(r"Quest \d+ has `StartItem` = \d+ but `ProvidedItemCount` = 0"),
     "Quest N has `StartItem` = N but `ProvidedItemCount` = 0, set to 1",
     "quest_template (ProvidedItemCount)", False,
     "UPDATE quest_template SET ProvidedItemCount=1 WHERE StartItem!=0 AND ProvidedItemCount=0"),

    # === LOOT TEMPLATES ===
    (re.compile(r"Table 'creature_loot_template' Entry \d+ ItemType \d+ Item \d+: item does not exist"),
     "Table creature_loot_template Entry N Item N: item does not exist - skipped",
     "creature_loot_template (bad item)", True,
     "ADDRESSED: DELETE FROM creature_loot_template WHERE Item NOT IN (valid items)"),

    (re.compile(r"Table 'gameobject_loot_template' Entry \d+ ItemType \d+ Item \d+: item does not exist"),
     "Table gameobject_loot_template Entry N Item N: item does not exist - skipped",
     "gameobject_loot_template (bad item)", True,
     "ADDRESSED: DELETE FROM gameobject_loot_template WHERE Item NOT IN (valid items)"),

    (re.compile(r"Table 'gameobject_loot_template' Entry \d+ isn't gameobject entry and not referenced from loot"),
     "Table gameobject_loot_template Entry N is orphan (not referenced from loot)",
     "gameobject_loot_template (orphan)", True,
     "ADDRESSED: DELETE orphan entries from gameobject_loot_template"),

    (re.compile(r"Table 'gameobject_loot_template' entry \d+ group \d+ has total chance > 100%"),
     "Table gameobject_loot_template entry N group N has total chance > 100%",
     "gameobject_loot_template (chance>100%)", False,
     "Fix loot group chances to sum to <=100%, redistribute proportionally"),

    (re.compile(r"Table 'gameobject_loot_template' entry \d+ group \d+ has items with chance=0%"),
     "Table gameobject_loot_template entry N group N has items with chance=0% but total>=100%",
     "gameobject_loot_template (chance=0%)", False,
     "Remove chance=0 items from groups where total >= 100%"),

    (re.compile(r"Table 'spell_loot_template' Entry \d+ does not exist but it is used by Spell"),
     "Table spell_loot_template Entry N does not exist but used by Spell N",
     "spell_loot_template (missing)", False,
     "Add missing spell_loot_template entries or remove loot effect. Mostly retail spells."),

    (re.compile(r"Table `creature_static_flags_override` has data for nonexistent creature"),
     "Table creature_static_flags_override data for nonexistent creature (SpawnId: N)",
     "creature_static_flags_override (orphan)", False,
     "DELETE FROM creature_static_flags_override WHERE SpawnId NOT IN (SELECT guid FROM creature)"),

    # === SCRIPTS ===
    (re.compile(r"Script '.+' is referenced by the database, but does not exist in the core"),
     "Script 'NAME' is referenced by database but does not exist in the core!",
     "scripts (missing)", False,
     "Remove script references from DB for non-existent scripts, or implement them"),

    # === SMARTAI ===
    (re.compile(r"SmartAIMgr: Event SMART_EVENT_QUEST_OBJ_COMPLETION using invalid objective id 0"),
     "SmartAIMgr: SMART_EVENT_QUEST_OBJ_COMPLETION invalid objective id 0",
     "smart_scripts (quest obj id=0)", False,
     "DELETE FROM smart_scripts WHERE event_type=SMART_EVENT_QUEST_OBJ_COMPLETION AND event_param1=0"),

    (re.compile(r"SmartAIMgr: Entry \d+ SourceType \d+ Event \d+ Action \d+ Effect: SPELL_EFFECT_KILL_CREDIT.*has invalid target"),
     "SmartAIMgr: Entry N ... SPELL_EFFECT_KILL_CREDIT has invalid target",
     "smart_scripts (invalid target)", False,
     "Fix target_type in smart_scripts for KILL_CREDIT actions"),

    (re.compile(r"SmartAIMgr: Entry \d+ SourceType \d+ Event \d+ Action 33 Kill Credit: There is a killcredit spell"),
     "SmartAIMgr: Entry N ... Action 33 Kill Credit: killcredit spell exists for creatureEntry N",
     "smart_scripts (killcredit warn)", False,
     "Informational: SAI uses KILL_CREDIT but a spell already provides this. Consider cleanup."),

    (re.compile(r"SmartAIMgr::LoadSmartAIFromDB: Creature entry \(\d+\) guid \(\d+\) is not using SmartAI"),
     "SmartAIMgr: Creature entry (N) guid (N) is not using SmartAI, skipped",
     "smart_scripts (not SmartAI)", False,
     "DELETE SAI for creatures not using SmartAI, or change AIName to SmartAI"),

    (re.compile(r"SmartAIMgr::LoadSmartAIFromDB: Creature guid \(\d+\) does not exist"),
     "SmartAIMgr: Creature guid (N) does not exist, skipped",
     "smart_scripts (missing creature)", False,
     "DELETE SAI for non-existent creature guids"),

    (re.compile(r"SmartAIMgr::LoadSmartAIFromDB: AreaTrigger entry \(\d+"),
     "SmartAIMgr: AreaTrigger entry (N) does not exist, skipped",
     "smart_scripts (areatrigger)", False,
     "DELETE SAI entries referencing non-existent areatriggers"),

    (re.compile(r"SmartAIMgr::LoadSmartAIFromDB: Entry \d+ SourceType \d+, Event \d+, Link"),
     "SmartAIMgr: Entry N Event N Link Event/Source not found or invalid",
     "smart_scripts (broken link)", False,
     "Fix link_id references in smart_scripts to point to valid events"),

    (re.compile(r"SmartAIMgr: Unused action_type\(\d+\)"),
     "SmartAIMgr: Unused action_type(N), event_type(N), Entry N, skipped",
     "smart_scripts (unused action)", False,
     "Remove SAI entries using unimplemented action types"),

    (re.compile(r"SmartAIMgr: Entry \d+ SourceType \d+ Event \d+ Action \d+ uses param .* with value \d+, valid values"),
     "SmartAIMgr: Entry N uses param P with invalid value, skipped",
     "smart_scripts (param validation)", False,
     "Fix parameter value in smart_scripts to be within valid range"),

    (re.compile(r"SmartAIMgr: Entry \d+ SourceType \d+ Event \d+ Action \d+ uses non-existent Spell"),
     "SmartAIMgr: Entry N Action N uses non-existent Spell entry N",
     "smart_scripts (bad spell)", False,
     "Fix or remove SAI entries referencing non-existent spells"),

    (re.compile(r"SmartAIMgr: Entry \d+ SourceType \d+ Event \d+ Action \d+ using invalid creature entry"),
     "SmartAIMgr: Entry N Action N using invalid creature entry for guid N",
     "smart_scripts (creature mismatch)", False,
     "Fix target_param1 in smart_scripts to match actual creature entry"),

    (re.compile(r"SmartAIMgr: Entry \d+ SourceType \d+ Event \d+ Action \d+ has abs"),
     "SmartAIMgr: Entry N has abs(target.o) > 2*PI (bad orientation)",
     "smart_scripts (bad orientation)", False,
     "Fix target.o in smart_scripts to be in 0..2*PI range"),

    (re.compile(r"SmartAIMgr: Entry \d+ SourceType \d+ Event \d+ Action \d+ uses incorrect TempSummonType"),
     "SmartAIMgr: Entry N uses incorrect TempSummonType N",
     "smart_scripts (TempSummonType)", False,
     "Fix action_param3 to use valid TempSummonType enum value"),

    # === MISC ===
    (re.compile(r"Table `command` contains data for non-existant command"),
     "Table `command` data for non-existent command, skipped",
     "command (stale)", False,
     "DELETE FROM command WHERE name NOT IN (registered commands)"),

    (re.compile(r"BattlegroundMgr::LoadBattlegroundScriptTemplate: bad mapid"),
     "BattlegroundMgr: bad mapid N",
     "battleground_template", False,
     "DELETE FROM battleground_template WHERE mapId not in valid BG/arena maps"),

    (re.compile(r"Class \d+ \(race \d+\) defined in `class_expansion_requirement` does not exists"),
     "Class N (race N) in `class_expansion_requirement` does not exist, skipped",
     "class_expansion_requirement", False,
     "DELETE FROM class_expansion_requirement WHERE classID NOT IN (valid ChrClasses)"),

    (re.compile(r"`scenario_poi` CriteriaTreeID"),
     "`scenario_poi` CriteriaTreeID (N) Idx1 (N) does not correspond to valid criteria tree",
     "scenario_poi", False,
     "DELETE FROM scenario_poi WHERE CriteriaTreeID NOT IN (valid criteria_tree IDs)"),
]


def main():
    with open(LOG_PATH, "r", encoding="utf-8", errors="replace") as f:
        lines = f.readlines()

    total_lines = len(lines)
    # Remove empty trailing lines
    while lines and lines[-1].strip() == "":
        lines.pop()

    non_empty_lines = [l for l in lines if l.strip()]
    total_non_empty = len(non_empty_lines)

    matched_counts = Counter()
    matched_addressed = {}
    matched_system = {}
    matched_fix = {}
    unmatched = []
    unmatched_samples = defaultdict(list)

    for line in non_empty_lines:
        line = line.rstrip("\n\r")

        found = False
        for regex, template, system, addressed, fix in PATTERNS:
            if regex.search(line):
                matched_counts[template] += 1
                matched_addressed[template] = addressed
                matched_system[template] = system
                matched_fix[template] = fix
                found = True
                break

        if not found:
            unmatched.append(line)
            prefix = line[:80]
            if len(unmatched_samples[prefix]) < 3:
                unmatched_samples[prefix].append(line)

    # Calculate totals
    addressed_lines = sum(c for t, c in matched_counts.items() if matched_addressed.get(t))
    unaddressed_lines = sum(c for t, c in matched_counts.items() if not matched_addressed.get(t))
    total_matched = sum(matched_counts.values())
    total_unmatched = len(unmatched)

    # Group by system
    systems = defaultdict(list)
    for template in matched_counts:
        sys_name = matched_system[template]
        systems[sys_name].append(template)

    system_totals = {}
    for sys_name, templates in systems.items():
        system_totals[sys_name] = sum(matched_counts[t] for t in templates)
    sorted_systems = sorted(system_totals.items(), key=lambda x: -x[1])

    # Print report
    print("=" * 120)
    print("DBErrors.log COMPREHENSIVE ANALYSIS")
    print("=" * 120)
    print()
    print(f"TOTAL LINES (incl empty):     {total_lines:>8,}")
    print(f"TOTAL NON-EMPTY LINES:        {total_non_empty:>8,}")
    print(f"  Matched patterns:           {total_matched:>8,}  ({total_matched/total_non_empty*100:.1f}%)")
    print(f"  Unmatched:                  {total_unmatched:>8,}  ({total_unmatched/total_non_empty*100:.1f}%)")
    print()
    print(f"ADDRESSED (by prior cleanup): {addressed_lines:>8,}  ({addressed_lines/total_non_empty*100:.1f}%)")
    print(f"UNADDRESSED (need fixing):    {unaddressed_lines:>8,}  ({unaddressed_lines/total_non_empty*100:.1f}%)")
    print()

    print("=" * 120)
    print("PATTERNS BY SYSTEM (sorted by line count descending)")
    print("=" * 120)

    for sys_name, sys_total in sorted_systems:
        templates = systems[sys_name]
        templates.sort(key=lambda t: -matched_counts[t])

        print()
        print(f"--- {sys_name} ({sys_total:,} lines) ---")
        for template in templates:
            count = matched_counts[template]
            addressed = matched_addressed[template]
            fix = matched_fix[template]
            status = "ADDRESSED" if addressed else "UNADDRESSED"

            print(f"  [{status:11s}] {count:>7,} | {template}")
            if not addressed:
                print(f"{'':>15s} FIX: {fix}")

    if unmatched:
        print()
        print("=" * 120)
        print(f"UNMATCHED LINES ({total_unmatched} lines -- showing samples)")
        print("=" * 120)
        for prefix, samples in sorted(unmatched_samples.items()):
            for s in samples[:2]:
                print(f"  {s[:200]}")

    # Summary table
    print()
    print("=" * 120)
    print("SUMMARY TABLE")
    print("=" * 120)
    print(f"{'System':<55s} {'Count':>8s}  {'Status':>11s}")
    print("-" * 80)
    for sys_name, sys_total in sorted_systems:
        templates = systems[sys_name]
        all_addressed = all(matched_addressed[t] for t in templates)
        any_addressed = any(matched_addressed[t] for t in templates)
        if all_addressed:
            status = "ADDRESSED"
        elif any_addressed:
            status = "PARTIAL"
        else:
            status = "UNADDRESSED"
        print(f"  {sys_name:<53s} {sys_total:>8,}  {status:>11s}")

    if total_unmatched:
        print(f"  {'(unmatched lines)':<53s} {total_unmatched:>8,}  {'UNKNOWN':>11s}")

    print("-" * 80)
    print(f"  {'TOTAL':<53s} {total_non_empty:>8,}")
    print(f"  {'  Addressed':<53s} {addressed_lines:>8,}  ({addressed_lines/total_non_empty*100:.1f}%)")
    print(f"  {'  Unaddressed + Unmatched':<53s} {unaddressed_lines + total_unmatched:>8,}  ({(unaddressed_lines+total_unmatched)/total_non_empty*100:.1f}%)")
    print()
    print(f"DISTINCT PATTERNS FOUND: {len(matched_counts)}")


if __name__ == "__main__":
    main()
