# VoxCore Packet Sniffing Guide

## What Is This About?

When you play World of Warcraft on Blizzard's live (retail) servers, the game constantly sends data to your computer — things like where NPCs are standing, what items a vendor sells, what text a quest giver says, and thousands of other details. All of this data travels over the internet as small chunks called **packets**.

**Packet sniffing** means running a small, silent tool in the background while you play that **records** all of those packets into a file. You don't play any differently — you just play the game like normal, and the tool quietly saves everything the server sends to your game.

After your session, you share that recording (a `.pkt` file) with us. We run it through a second tool that reads all that data and converts it into database entries we can load directly into VoxCore. The more `.pkt` files we get from different people playing in different zones, the more complete and accurate the server becomes.

**Think of it like this:** You're basically helping us take a photograph of the retail game world, one zone at a time. Every NPC position, every quest, every vendor inventory — captured exactly as Blizzard built it.

## Important: You Sniff on Retail, Not on Our Server

> **You will be playing on Blizzard's official live retail servers** — the same WoW you already play with your regular Battle.net account and subscription. You are NOT connecting to VoxCore or any private server to do this. The whole point is to capture data from Blizzard's servers so we can recreate it on ours.

## What You'll Actually Be Doing

Here's the entire process in plain English:

1. **Install a network driver and a small program** (one-time, takes ~5 minutes)
2. **Run a background tool**, then launch WoW and play normally
3. **Close WoW** when you're done — the tool saves a file automatically
4. **Compress and share** that file with us on Discord

That's it. You don't need to know anything about programming, databases, or networking.

## Keeping Things Up to Date

> **Every time WoW gets a patch or build update**, you'll need to grab the latest version of Ymir (and WPP, if you use it) to match the new build. Check the [Ymir Releases page](https://github.com/TrinityCore/ymir/releases) — an updated version usually appears within a few days of a WoW patch. If Ymir suddenly stops working after a WoW update, this is almost always why.

## Quick Start Checklist

If you're ready to jump in:

- [ ] Read the **[Ymir Setup Guide](https://gist.github.com/VoxCore84/14a47790f63a6f97042a6301210579ea)** and follow every step (one-time install)
- [ ] Before each session: delete WoW's `Cache` folder, start Ymir, then start WoW
- [ ] Play normally — the more you interact with NPCs, vendors, and quests, the better
- [ ] When done: close WoW, compress the `.pkt` file from Ymir's `dump` folder, share on Discord
- [ ] Want to level up? Read the **[Sniffing Best Practices Guide](https://gist.github.com/VoxCore84/9ac8a86a0a10d995584f821779d403f9)** for tips on capturing the most useful data

## Guides

| Guide | What's In It | Who It's For |
|-------|-------------|-------------|
| **[Ymir Setup Guide](https://gist.github.com/VoxCore84/14a47790f63a6f97042a6301210579ea)** | Step-by-step installation of everything you need, with every click and button described | First-time setup |
| **[Sniffing Best Practices](https://gist.github.com/VoxCore84/9ac8a86a0a10d995584f821779d403f9)** | How to capture the most useful data, what we need most, FAQ, troubleshooting | Active sniffers |
| **[WPP Parsing Guide](https://gist.github.com/VoxCore84/990d3e047cc59de7c21b8523ae3e003d)** | How to convert `.pkt` files into SQL yourself (totally optional) | Power users / curious |

## What Kind of Data Do Sniffs Capture?

### Just By Being Near Something (Automatic)

When you walk through a town or zone, the game sends data about everything within visual range (how far away things appear on your screen):

- **NPCs/Creatures** — where they stand, what they look like, their level, health, equipment, faction
- **Gameobjects** — mailboxes, chairs, anvils, portals, chests, their positions and states
- **Spells & Auras** — visual effects and buffs/debuffs on you and nearby characters
- **Zone/Phase Data** — what area you're in and what phase of content you're seeing

### By Interacting (You Trigger This)

When you click on things, talk to NPCs, or do quests, even more data gets captured:

| What You Do | What We Get |
|------------|-------------|
| Talk to an NPC | Their dialog text, menu options |
| Accept or complete a quest | Full quest text, objectives, rewards, and any world changes the quest triggers |
| Open a vendor's shop | Their complete inventory with prices |
| Visit a trainer | Full list of spells/skills they teach |
| Use a flight master | Which flight paths connect to where |
| Loot a creature or chest | What items they can drop (loot tables) |
| Browse your mount/pet journal | Mount and pet data |
| Cast spells in combat | Spell effect details, cooldowns |
| Follow a patrolling NPC | Their complete walking route (waypoints) |

**The more you interact with, the more data we get.** Walking past an NPC gives us their position and appearance. *Talking* to that same NPC also gives us their dialog, vendor inventory, quest offerings, and more.

## Why Do We Need Your Help?

One person can only be in one zone at a time. To build a complete Midnight experience, we need data from:

- Every zone and subzone in the game
- Every NPC — their stats, equipment, patrol paths, gossip text
- Every quest chain — objectives, rewards, story text
- Every vendor, trainer, and flight master's inventory
- Every gameobject (mailboxes, portals, chairs, forges, etc.)
- Spell visuals, auras, and combat effects

**More people sniffing = more zones covered = a better server for everyone.**

Even casual play sessions are valuable. Just walking through a town captures dozens of NPC spawns. Running a quest chain captures all of the quest data. Browsing a vendor captures their entire inventory. Every little bit helps.

## Safety & Privacy

### Is This Safe for My Account?

**Has anyone ever been banned for this?** No. Ymir has been used by the TrinityCore community since 2019 (WoW patch 8.1.5) — that's 7+ years of continuous use — with **zero documented bans**. Packet sniffing in general has been a standard practice in the WoW emulation community for even longer. While Blizzard's Terms of Service broadly cover third-party tools, the practical risk of packet sniffing has historically been effectively zero.

**Why Ymir is fundamentally different from cheats/bots:**
- It captures network traffic at the operating system level using a standard network driver (Npcap) — the same kind of driver used by IT professionals and network admins worldwide
- It **never** touches WoW's memory, files, or process — WoW literally doesn't know it exists
- It doesn't inject code, modify game data, or interact with the game in any way
- Blizzard's anti-cheat (Warden) scans for tools that read or write game memory — Ymir does neither
- It's the same technology as running Wireshark (a standard network analysis tool) while playing

### What About My Personal Info?

> **Important:** `.pkt` files contain personal data from your account — your Battle.net name, real name (from billing), friends list, IP address, and character info.
>
> **Never post `.pkt` files publicly.** Only share them through direct messages or restricted Discord channels with trusted project members. We strip all personal information during parsing — none of it ends up in the server database.

**Want to scrub your data yourself before sharing?** You can use WowPacketParser to create a clean copy of your `.pkt` file with all personal info removed. See the **[WPP Parsing Guide](https://gist.github.com/VoxCore84/990d3e047cc59de7c21b8523ae3e003d)** for instructions — look for the "Sanitize Your Sniff" section. This is totally optional (we do it on our end anyway), but it's there if it makes you more comfortable.

## Links

- **Ymir** (the sniffer tool): [github.com/TrinityCore/ymir](https://github.com/TrinityCore/ymir)
- **WowPacketParser** (the parsing tool): [github.com/TrinityCore/WowPacketParser](https://github.com/TrinityCore/WowPacketParser)
- **Npcap** (network driver Ymir needs): [nmap.org/npcap](https://nmap.org/npcap/)
- **AzerothCore Sniffing Wiki** (additional reference): [azerothcore.org/wiki/sniffing-and-parsing](https://www.azerothcore.org/wiki/sniffing-and-parsing)

---

*This guide is maintained by the VoxCore team. Last updated: March 2026.*
