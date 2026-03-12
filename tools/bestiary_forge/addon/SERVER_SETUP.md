# BestiaryForge — Server Setup Guide

This guide walks through the server-side changes needed to enable the BestiaryForge server sniffer on your TrinityCore fork. There are three components:

1. **Core patches** — 3 small modifications to add global creature spell hooks
2. **Custom script** — C++ script that broadcasts spell data to the addon
3. **Eluna script** — Lua script that handles spell list and creature info queries

Total lines changed: ~30 in core, ~130 in custom script, ~110 in Eluna script.

---

## 1. Core Patches

These add 3 new `UnitScript` hooks that fire whenever ANY creature casts, starts casting, or finishes channeling a spell. They follow the existing TrinityCore `ScriptMgr` pattern.

### 1a. ScriptMgr.h

**File:** `src/server/game/Scripting/ScriptMgr.h`

Find the `UnitScript` class (around line 420-444). Add these 3 virtual methods just before the closing `};`:

```cpp
        // Called when Spell Damage is being Dealt
        virtual void ModifySpellDamageTaken(Unit* target, Unit* attacker, int32& damage, SpellInfo const* spellInfo);

        // Called when a creature finishes casting a spell (after SendSpellGo)
        virtual void OnCreatureSpellCast(Creature* /*creature*/, SpellInfo const* /*spell*/) { }

        // Called when a creature begins casting a spell
        virtual void OnCreatureSpellStart(Creature* /*creature*/, SpellInfo const* /*spell*/) { }

        // Called when a creature finishes channeling a spell
        virtual void OnCreatureChannelFinished(Creature* /*creature*/, SpellInfo const* /*spell*/) { }
};
```

Then find the `ScriptMgr` class's `/* UnitScript */` section (around line 1370-1377). Add 3 dispatch declarations:

```cpp
        void ModifySpellDamageTaken(Unit* target, Unit* attacker, int32& damage, SpellInfo const* spellInfo);
        void OnCreatureSpellCast(Creature* creature, SpellInfo const* spell);
        void OnCreatureSpellStart(Creature* creature, SpellInfo const* spell);
        void OnCreatureChannelFinished(Creature* creature, SpellInfo const* spell);

    public: /* AreaTriggerEntityScript */
```

**Unified diff:**

```diff
--- a/src/server/game/Scripting/ScriptMgr.h
+++ b/src/server/game/Scripting/ScriptMgr.h
@@ -441,6 +441,15 @@ class TC_GAME_API UnitScript : public ScriptObject

         // Called when Spell Damage is being Dealt
         virtual void ModifySpellDamageTaken(Unit* target, Unit* attacker, int32& damage, SpellInfo const* spellInfo);
+
+        // Called when a creature finishes casting a spell (after SendSpellGo)
+        virtual void OnCreatureSpellCast(Creature* /*creature*/, SpellInfo const* /*spell*/) { }
+
+        // Called when a creature begins casting a spell
+        virtual void OnCreatureSpellStart(Creature* /*creature*/, SpellInfo const* /*spell*/) { }
+
+        // Called when a creature finishes channeling a spell
+        virtual void OnCreatureChannelFinished(Creature* /*creature*/, SpellInfo const* /*spell*/) { }
 };

 class TC_GAME_API CreatureScript : public ScriptObject
@@ -1374,6 +1383,9 @@ class TC_GAME_API ScriptMgr
         void ModifyPeriodicDamageAurasTick(Unit* target, Unit* attacker, uint32& damage);
         void ModifyMeleeDamage(Unit* target, Unit* attacker, uint32& damage);
         void ModifySpellDamageTaken(Unit* target, Unit* attacker, int32& damage, SpellInfo const* spellInfo);
+        void OnCreatureSpellCast(Creature* creature, SpellInfo const* spell);
+        void OnCreatureSpellStart(Creature* creature, SpellInfo const* spell);
+        void OnCreatureChannelFinished(Creature* creature, SpellInfo const* spell);

     public: /* AreaTriggerEntityScript */
```

### 1b. ScriptMgr.cpp

**File:** `src/server/game/Scripting/ScriptMgr.cpp`

Find `ScriptMgr::ModifySpellDamageTaken` (around line 2841). Add the 3 dispatch implementations right after it:

```diff
--- a/src/server/game/Scripting/ScriptMgr.cpp
+++ b/src/server/game/Scripting/ScriptMgr.cpp
@@ -2843,6 +2843,21 @@ void ScriptMgr::ModifySpellDamageTaken(Unit* target, Unit* attacker, int32& dama
     FOREACH_SCRIPT(UnitScript)->ModifySpellDamageTaken(target, attacker, damage, spellInfo);
 }

+void ScriptMgr::OnCreatureSpellCast(Creature* creature, SpellInfo const* spell)
+{
+    FOREACH_SCRIPT(UnitScript)->OnCreatureSpellCast(creature, spell);
+}
+
+void ScriptMgr::OnCreatureSpellStart(Creature* creature, SpellInfo const* spell)
+{
+    FOREACH_SCRIPT(UnitScript)->OnCreatureSpellStart(creature, spell);
+}
+
+void ScriptMgr::OnCreatureChannelFinished(Creature* creature, SpellInfo const* spell)
+{
+    FOREACH_SCRIPT(UnitScript)->OnCreatureChannelFinished(creature, spell);
+}
+
 // Scene
```

### 1c. Spell.cpp

**File:** `src/server/game/Spells/Spell.cpp`

Three locations need a one-line addition each. In all three cases, the existing `CreatureAI` hook call needs to be wrapped in braces and the `sScriptMgr` call added after it.

**Location 1: OnSpellStart** (in `Spell::prepare`, around line 3594)

```diff
         // Call CreatureAI hook OnSpellStart
         if (Creature* caster = m_caster->ToCreature())
+        {
             if (caster->IsAIEnabled())
                 caster->AI()->OnSpellStart(GetSpellInfo());
+            sScriptMgr->OnCreatureSpellStart(caster, GetSpellInfo());
+        }
```

**Location 2: OnSpellCast** (in `Spell::_cast`, around line 3902)

```diff
         // Call CreatureAI hook OnSpellCast
         if (Creature* caster = m_originalCaster->ToCreature())
+        {
             if (caster->IsAIEnabled())
                 caster->AI()->OnSpellCast(GetSpellInfo());
+            sScriptMgr->OnCreatureSpellCast(caster, GetSpellInfo());
+        }
```

**Location 3: OnChannelFinished** (in `Spell::update`, around line 4332)

```diff
                 // We call the hook here instead of in Spell::finish ...
                 if (Creature* creatureCaster = m_caster->ToCreature())
+                {
                     if (creatureCaster->IsAIEnabled())
                         creatureCaster->AI()->OnChannelFinished(m_spellInfo);
+                    sScriptMgr->OnCreatureChannelFinished(creatureCaster, m_spellInfo);
+                }
```

### 1d. Unit.cpp (Aura Hook)

**File:** `src/server/game/Entities/Unit/Unit.cpp`

Add the aura application hook at the end of `Unit::_ApplyAura()`, right before the closing brace.
Find the block with `player->UpdateCriteria(CriteriaType::GainAura, ...)` and add after the closing `}`:

```diff
         player->UpdateCriteria(CriteriaType::GainAura, aura->GetId(), 0, 0, caster);
     }
+
+    sScriptMgr->OnAuraApply(this, aurApp);
 }
```

This fires whenever any aura is applied to any unit, after all stack/remove checks pass.

---

## 2. Custom Scripts

### 2a. bestiary_sniffer.cpp

**File:** `src/server/scripts/Custom/bestiary_sniffer.cpp`

Copy the provided `bestiary_sniffer.cpp` file into your `Custom/` scripts directory. This file:
- Implements a `UnitScript` that overrides the 4 hooks (cast, start, channel, aura)
- When any creature casts a spell or applies an aura, builds a pipe-delimited message
- Broadcasts it as an addon message (prefix `BFRG`) to all nearby players who have the addon installed
- Includes server-side blacklists for noise spells (Auto Attack, Dazed, etc.) and trigger creatures
- Provides runtime blacklist management via the `BestiaryForge` namespace

### 2b. cs_bestiary.cpp (GM Command)

**File:** `src/server/scripts/Custom/cs_bestiary.cpp`

Copy the provided `cs_bestiary.cpp` file. This adds the `.bestiary` GM command:
- `.bestiary query <entry>` — Query creature_template_spell for an entry
- `.bestiary stats` — Show sniffer stats (online players, BFRG listeners)
- `.bestiary blacklist add <spellId>` — Add spell to runtime blacklist
- `.bestiary blacklist remove <spellId>` — Remove spell from runtime blacklist
- `.bestiary blacklist list` — Show current runtime blacklist

Requires RBAC permission 3012. Add to `RBAC.h` and apply the auth SQL.

### Register in custom_script_loader.cpp

**File:** `src/server/scripts/Custom/custom_script_loader.cpp`

Add the declaration and call:

```cpp
// At the top with other declarations:
void AddSC_bestiary_forge_sniffer();
void AddSC_bestiary_commands();

// Inside AddCustomScripts():
    AddSC_bestiary_forge_sniffer();
    AddSC_bestiary_commands();
```

---

## 3. Eluna Script — bestiary_sniffer_server.lua

**File:** `lua_scripts/bestiary_sniffer_server.lua` (in your server's Eluna scripts directory)

Copy the provided `bestiary_sniffer_server.lua` file. This handles:
- **Spell List requests** (`SL|entry`) — queries `creature_template_spell` and sends back all known spells for a creature
- **Creature Info requests** (`CI|entry`) — sends faction, level range, and classification
- **Zone Creature requests** (`ZC|mapId`) — queries all creatures that spawn in a given map
- **Aggregation submissions** (`AG|entry|spellId:count,...`) — stores multi-player aggregated data

The addon automatically sends these requests when you target a new creature.

> **Note:** If you don't use Eluna, you can skip this file. The core C++ sniffer works independently. You'll just lose the "query DB spell list on target" feature.

---

## 4. Build and Test

1. Apply the 3 core patches
2. Add `bestiary_sniffer.cpp` and register it
3. Place the Eluna script in your `lua_scripts/` directory
4. Build your server
5. Install the BestiaryForge addon on your client
6. Log in and target a hostile creature

**Expected output in addon chat (with Debug ON):**

```
[BestiaryForge] v3 loaded. 0 creatures, 0 spells tracked.
[BestiaryForge]  Visual scraper: 10Hz casts + 5Hz aura round-robin.
[BestiaryForge]  Server sniffer: listening on BFRG channel...
[BestiaryForge] Server sniffer connected! Receiving all creature spell casts.
[BF SRV] CAST entry=12345 spell=Crush Armor[345236] school=1
[BF SRV] CAST entry=12345 spell=Iron Shackles[347163] school=1
```

If you only see `[BF VIS]` messages (from the visual scraper) and no `[BF SRV]` messages, the C++ hooks aren't firing. Verify:
- The script is registered in `custom_script_loader.cpp`
- The server was rebuilt after applying core patches
- Your worldserver log shows `bestiary_forge_sniffer` loading at startup

---

## How It Works (Architecture)

```
  Creature casts spell
         |
         v
  Spell.cpp fires sScriptMgr->OnCreatureSpellCast()
         |
         v
  bestiary_sniffer.cpp receives the hook
         |
         v
  Gets nearby players via GetPlayerListInGrid()
         |
         v
  For each player with BFRG prefix registered:
    Sends SMSG_CHAT (LANG_ADDON, CHAT_MSG_WHISPER)
    with message "SC|entry|spellID|school|name"
         |
         v
  Client addon receives CHAT_MSG_ADDON event
         |
         v
  Parses message, records in BestiaryForgeDB SavedVariables
         |
         v
  Browser UI shows creature spell data in real time
```

The visual scraper (OnUpdate polling of UnitCastingInfo/UnitChannelInfo/UnitAura) runs in parallel as a fallback for servers without the C++ hooks installed.

---

## FAQ

**Q: Does the addon work without the server patches?**
Yes. The visual scraper still captures castbar data at 10Hz and auras at 5Hz. You just won't see instant/hidden casts or get DB spell list queries.

**Q: What's the performance impact?**
The server hook adds one `GetPlayerListInGrid()` call per creature spell cast. With the 100m broadcast range and prefix check, only players with the addon receive data. In testing with 50+ creatures in combat, no measurable impact.

**Q: Can I adjust the broadcast range?**
Yes. In `bestiary_sniffer.cpp`, change `BFRG_BROADCAST_RANGE` (default 100.0f). Larger = more data but more network traffic.

**Q: How do I add spells to the server-side blacklist?**
Edit the `BLACKLISTED_SPELLS` array in `bestiary_sniffer.cpp` and rebuild. Or use the addon's right-click ignore feature (client-side only).

**Q: Does this work with AzerothCore?**
The architecture is the same but line numbers will differ. AzerothCore already has `AllCreatureScript` which may provide similar hooks without core patches. Check your AC fork's ScriptMgr.h.
