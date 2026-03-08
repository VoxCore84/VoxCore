# Sniffing Best Practices — Getting the Most From Your Sessions

> You've got Ymir set up and you've done your first sniff. Now let's talk about how to make your sniffs as valuable as possible for the project.

---

## Table of Contents

1. [The Golden Rules](#the-golden-rules)
2. [Maximizing NPC Data](#maximizing-npc-data)
3. [Maximizing Quest Data](#maximizing-quest-data)
4. [Maximizing Spell & Visual Data](#maximizing-spell--visual-data)
5. [What VoxCore Needs Most Right Now](#what-voxcore-needs-most-right-now)
6. [Session Planning Tips](#session-planning-tips)
7. [Common Mistakes to Avoid](#common-mistakes-to-avoid)
8. [FAQ](#faq)

---

## The Golden Rules

These apply to every sniff session:

1. **Always clear your WoW cache** before each session. If you skip this, WoW will use stale cached data instead of requesting fresh data from the server, and Ymir won't capture as much.

2. **Start Ymir before WoW.** Ymir needs to be listening before WoW connects to the server. If you start WoW first, the initial connection data (which includes important login and area info) gets missed.

3. **Slow and thorough beats fast and sloppy.** Walking through a town captures every NPC that appears on your screen. Flying over it at max speed captures almost nothing — the game only sends data about things close enough to actually show up in your game world.

4. **Interact with everything.** An NPC you walk past gives us their position, appearance, and basic stats. An NPC you *talk to* also gives us their dialog text, gossip menus, vendor inventory, quest offerings, and more. Clicking costs you a few seconds but doubles or triples the data we get.

5. **Play on different characters.** Different races, classes, and factions may see different NPCs, quests, dialog options, or phased content. A Horde character and an Alliance character in the same city will generate completely different sniff data.

---

## Maximizing NPC Data

NPCs (non-player characters) are one of the most important things we capture. Here's how to get the most NPC data:

### Walk, Don't Fly

When exploring a town or hub, **walk on foot** through every street and alley. NPCs only appear in your sniff data when they're close enough to show up on your screen. Flying high above a city means most ground-level NPCs never load in.

### Talk to Every NPC

Even if you don't need anything from them:

- **Right-click every NPC** you see, even guards, citizens, and random townspeople
- This captures their **dialog text** (the text box that appears when you talk to them) and any **menu options** they offer
- If an NPC is a vendor, **open their shop and scroll through the entire inventory** — this captures every item they sell and its price
- If an NPC is a trainer, **browse their full spell/skill list**

### Follow Patrolling NPCs

Some NPCs walk around on patrol routes (guards, merchants, animals):

- Pick a patrolling NPC and **follow them for a full loop** back to where they started
- This captures their complete **waypoint path** — every point they walk to
- One full loop is enough — you don't need to follow them for multiple loops

### Visit Flight Masters

- Talk to every flight master and **open their flight map**
- This captures all available **taxi/flight path connections** from that location

---

## Maximizing Quest Data

Quest data is especially valuable because it's complex — each quest has offer text, accept text, objectives, completion conditions, reward text, item rewards, phasing triggers, and more.

### Accept Every Quest

- **Pick up every quest** available to you, even ones you don't plan to complete
- The act of accepting a quest captures the quest text, objectives, and may trigger world changes (like NPCs appearing or disappearing based on your quest progress — this is called "phasing")

### Complete Quests at Turn-In NPCs

- Don't just abandon quests — **complete them** whenever possible
- Turning in a quest captures **reward data** (items, gold, XP) and **completion dialog text**

### Abandon and Re-Accept

- If you already completed a quest on a previous session, you can sometimes **abandon** a quest and **re-accept** it on a new character to capture the full flow again
- Different characters may see different quest text or have different dialog options

### Open Your Map During Quests

- While you have active quests, **open your world map** (default key: M)
- This triggers the game to send **quest POI (Point of Interest)** data — the markers on the map showing where to go
- Zoom in and out on different areas while the map is open

---

## Maximizing Spell & Visual Data

### Use Your Abilities

- During combat, **use as many different abilities as you can**
- Each spell cast generates data about the spell's effects, visuals, cooldowns, and targeting rules
- Try to use abilities on different types of targets (single target, AoE, self-cast)

### Use Mounts and Toys

- **Mount up** on different mounts — this captures mount data and any restrictions
- **Use toys** from your toy box — captures on-use effects and visual data
- **Use items** with on-use effects (potions, engineering gadgets, etc.)

### Browse Your Collections

- Open your **Spellbook** (P) and **Collections** tabs (mounts, pets, toys)
- Browsing these triggers the game to send data about each entry

---

## What VoxCore Needs Most Right Now

Not all sniff data is equally urgent. Here's what we need the most, from highest to lowest priority:

### Highest Priority

| Content | Why |
|---------|-----|
| **New Midnight 12.x zones** | Brand new content with little to no existing coverage |
| **Midnight story/campaign quests** | Quest chains are the hardest data to reconstruct without sniffs |
| **New dungeons and raids** | Boss encounters, trash mob data, loot tables |

### High Priority

| Content | Why |
|---------|-----|
| **Capital cities** (Dornogal, Stormwind, Orgrimmar, etc.) | Hundreds of NPCs, vendors, trainers, portals per city |
| **Quest hubs and outposts** | Full quest chains from start to finish |
| **Vendors and trainers** everywhere | Inventory data only comes from direct interaction |

### Medium Priority

| Content | Why |
|---------|-----|
| **Profession trainers and crafting** | Recipe data, crafting UI interactions |
| **Following patrolling NPCs** | Waypoint paths require tracking the full route |
| **Battlegrounds and arenas** | PvP environment data |

### Lower Priority (Still Useful!)

| Content | Why |
|---------|-----|
| **Old expansion zones** | We have some data already, but sniffs help verify accuracy |
| **Sitting AFK in a city** | Only captures what's in immediate view, but still picks up some data |

---

## Session Planning Tips

### Pick a Theme

Instead of wandering randomly, **plan what you'll focus on** each session:

- "Today I'm walking through every building in Dornogal"
- "This session I'll do the first 20 quests of the Midnight campaign"
- "I'm going to visit every vendor and trainer in Stormwind"

Focused sessions produce better coverage than scattered ones.

### Take Brief Notes

After your session, jot down what you covered. Even a one-sentence note helps:

> "Full walkthrough of Dornogal, all vendors, flight master, Midnight campaign chapter 1"

This helps us know what's been covered and what zones still need attention.

### Play at Different Times

Some NPCs have **time-based spawns** — they only appear at certain in-game times of day (day vs. night cycles). Others are tied to **events** or **world quests**. Playing at different real-world times can capture NPCs that only appear during specific cycles.

### Use Multiple Characters

Different characters may see:
- **Faction-specific NPCs** (Alliance vs. Horde)
- **Class-specific quest givers** (class trainers, class hall content)
- **Race-specific dialog** (some NPCs have different text for different races)
- **Phased content** — different versions of the world based on how far you've progressed in quests

If you have alts, sniffing on them produces different and valuable data.

---

## Common Mistakes to Avoid

| Mistake | Why It's Bad | What to Do Instead |
|---------|-------------|-------------------|
| Forgetting to clear cache | WoW uses old cached data → Ymir captures less | Always delete the `Cache` folder before each session |
| Starting WoW before Ymir | Initial login data gets missed | Always start Ymir first, then WoW |
| Flying everywhere at max speed | NPCs below you never enter render range | Walk through towns and hubs on foot |
| Only walking past NPCs | You only get position/appearance data | Click on NPCs to capture their dialog, vendor lists, quests |
| Closing Ymir manually before WoW | Can corrupt the `.pkt` file | Always close WoW first — Ymir stops itself |
| Posting `.pkt` files publicly | Contains your personal account info | Only share with trusted contributors via DM or restricted channels |

---

## FAQ

**Q: Does sniffing slow down my game?**
No. Ymir captures packets at the network driver level with negligible performance impact. You won't notice any difference in FPS or latency.

**Q: Can I sniff while using addons?**
Yes. Addons don't interfere with packet capture at all. Keep your UI setup exactly as you normally would.

**Q: How often should I sniff?**
As often as you're willing! Even a single session covering one zone is valuable. Regular contributors who sniff weekly across different content are especially helpful, but there's no minimum commitment.

**Q: What if someone else already sniffed the same zone?**
Multiple sniffs of the same area are actually useful — different characters may trigger different NPC interactions, quests, or phased content. Overlapping coverage is totally fine. Don't worry about duplicates.

**Q: Can I sniff on PTR/Beta servers?**
Yes, and it's extremely valuable! PTR/Beta often has the newest content before it goes live. Use the `ymir_ptr.exe` binary included in the Ymir release.

**Q: Do I need to be max level?**
No. Low-level content is just as valuable. Starter zones, leveling quests, and early-game NPCs all need data.

**Q: Can I sniff Classic/TBC/MoP Classic too?**
Yes. Ymir has releases for Classic Era (1.15.x), TBC Classic (2.5.x), Titan Classic (3.80.x), and MoP Classic (5.5.x). Grab the matching release from the [Ymir releases page](https://github.com/TrinityCore/ymir/releases).

**Q: I found a bug or weird behavior in retail — should I still submit that sniff?**
Absolutely. Bugs in retail are still real data points. Submit everything and let us sort it out during parsing.

**Q: How big are the `.pkt` files?**
A typical 1-2 hour session produces 50-500 MB. They compress very well — expect 80-90% reduction with 7z or zip, so a 300 MB `.pkt` might compress down to 30-60 MB.

**Q: My `.pkt` file seems really small — did something go wrong?**
If it's under ~1 MB after several minutes of play, something may be off. Check the [Ymir Setup troubleshooting section](https://gist.github.com/VoxCore84/14a47790f63a6f97042a6301210579ea#troubleshooting). Common causes: forgot to clear cache, or Ymir started after WoW.

---

*Back to the [main guide](https://gist.github.com/VoxCore84/22343664a9eab5013b97f5c55feacbaa) | Setup help: [Ymir Setup Guide](https://gist.github.com/VoxCore84/14a47790f63a6f97042a6301210579ea) | Advanced: [WPP Parsing Guide](https://gist.github.com/VoxCore84/990d3e047cc59de7c21b8523ae3e003d)*
