/*
 * VoxCore — Arcane Waygate
 * Spell-triggered gossip teleport menu with organized submenus.
 * Cast spell 1900028 → summons invisible NPC → gossip menu opens.
 */

#include "Containers.h"
#include "Creature.h"
#include "GossipDef.h"
#include "PassiveAI.h"
#include "Player.h"
#include "ScriptedGossip.h"
#include "ScriptMgr.h"
#include "SpellScript.h"
#include "TemporarySummon.h"

enum WaygateActions
{
    // Menu navigation (0-99)
    ACTION_MAIN             = 0,
    ACTION_EASTERN_KINGDOMS = 10,
    ACTION_EK_CITIES        = 11,
    ACTION_EK_TOWNS         = 12,
    ACTION_KALIMDOR         = 20,
    ACTION_KAL_CITIES       = 21,
    ACTION_KAL_TOWNS        = 22,
    ACTION_OUTLAND          = 30,
    ACTION_NORTHREND        = 40,
    ACTION_PANDARIA         = 50,
    ACTION_DRAENOR          = 60,
    ACTION_BROKEN_ISLES     = 70,
    ACTION_BFA              = 80,
    ACTION_SHADOWLANDS      = 85,
    ACTION_DRAGON_ISLES     = 90,
    ACTION_KHAZ_ALGAR       = 95,

    // Teleport base (destinations indexed from here)
    ACTION_TELEPORT         = 1000,
};

struct TeleportDest
{
    uint32 mapId;
    float x, y, z, o;
    char const* name;
    uint32 menu; // which submenu this belongs to
};

// All destinations — indexed by (action - ACTION_TELEPORT)
static constexpr TeleportDest Destinations[] =
{
    // ========== EASTERN KINGDOMS — CITIES (menu 11) ==========
    /*  0 */ { 0,    -8833.07f,   622.78f,   93.93f, 0.68f, "Stormwind City",        ACTION_EK_CITIES },
    /*  1 */ { 0,    -4918.88f,  -940.41f,  501.56f, 5.42f, "Ironforge",             ACTION_EK_CITIES },
    /*  2 */ { 0,     1584.07f,   241.99f,  -52.15f, 0.05f, "Undercity",             ACTION_EK_CITIES },
    /*  3 */ { 0,     8444.32f, -4765.72f,   49.00f, 0.00f, "Silvermoon City",       ACTION_EK_CITIES },

    // ========== EASTERN KINGDOMS — TOWNS & ZONES (menu 12) ==========
    /*  4 */ { 0,   -14297.20f,   531.00f,    8.78f, 3.99f, "Booty Bay",             ACTION_EK_TOWNS },
    /*  5 */ { 0,     2279.65f, -5310.01f,   87.08f, 5.08f, "Light's Hope Chapel",   ACTION_EK_TOWNS },
    /*  6 */ { 0,   -11118.90f, -2010.33f,   47.08f, 0.65f, "Karazhan",              ACTION_EK_TOWNS },
    /*  7 */ { 0,   -10446.90f, -3261.91f,   20.18f, 5.02f, "Stonard",               ACTION_EK_TOWNS },
    /*  8 */ { 0,   -11840.10f, -3196.63f,  -29.61f, 3.34f, "The Dark Portal",       ACTION_EK_TOWNS },
    /*  9 */ { 0,     2359.64f, -5662.41f,  382.26f, 0.60f, "Acherus (Ebon Hold)",   ACTION_EK_TOWNS },

    // ========== KALIMDOR — CITIES (menu 21) ==========
    /* 10 */ { 1,     1569.97f, -4397.41f,   16.05f, 0.54f, "Orgrimmar",             ACTION_KAL_CITIES },
    /* 11 */ { 1,    -1277.37f,   124.80f,  131.29f, 5.22f, "Thunder Bluff",         ACTION_KAL_CITIES },
    /* 12 */ { 1,     9949.56f,  2284.21f, 1341.40f, 1.60f, "Darnassus",             ACTION_KAL_CITIES },
    /* 13 */ { 530,  -3965.70f,-11653.60f, -138.84f, 0.85f, "The Exodar",            ACTION_KAL_CITIES },

    // ========== KALIMDOR — TOWNS & ZONES (menu 22) ==========
    /* 14 */ { 1,    -7177.15f, -3785.34f,    8.37f, 6.10f, "Gadgetzan",             ACTION_KAL_TOWNS },
    /* 15 */ { 1,     7654.30f, -2232.87f,  462.11f, 5.97f, "Moonglade",             ACTION_KAL_TOWNS },
    /* 16 */ { 1,    -7072.00f,  1271.00f,  -91.00f, 2.27f, "Silithus",              ACTION_KAL_TOWNS },
    /* 17 */ { 1,     6725.69f, -4619.44f,  720.91f, 4.67f, "Everlook",              ACTION_KAL_TOWNS },
    /* 18 */ { 1,    -8204.88f, -4495.25f,    9.01f, 4.73f, "Caverns of Time",       ACTION_KAL_TOWNS },
    /* 19 */ { 1,     -956.66f, -3754.71f,    5.33f, 1.00f, "Ratchet",               ACTION_KAL_TOWNS },
    /* 20 */ { 1,    -3641.30f, -4358.93f,    8.35f, 3.82f, "Theramore",             ACTION_KAL_TOWNS },

    // ========== OUTLAND (menu 30) ==========
    /* 21 */ { 530,  -1838.16f,  5301.79f,  -12.43f, 5.95f, "Shattrath City",        ACTION_OUTLAND },
    /* 22 */ { 530,   -211.24f,  4278.54f,   86.57f, 4.60f, "Hellfire Peninsula",    ACTION_OUTLAND },
    /* 23 */ { 530,   3043.33f,  3681.33f,  143.07f, 5.07f, "Area 52 (Netherstorm)", ACTION_OUTLAND },
    /* 24 */ { 530,   3037.67f,  5962.86f,  130.77f, 1.27f, "Blade's Edge Mountains",ACTION_OUTLAND },
    /* 25 */ { 530,  -1145.95f,  8182.35f,    3.60f, 6.13f, "Nagrand",               ACTION_OUTLAND },
    /* 26 */ { 530,   -247.29f,   910.64f,   84.38f, 1.49f, "Dark Portal (Outland)", ACTION_OUTLAND },

    // ========== NORTHREND (menu 40) ==========
    /* 27 */ { 571,   5804.15f,   624.77f,  647.77f, 1.64f, "Dalaran (Northrend)",   ACTION_NORTHREND },
    /* 28 */ { 571,   1902.15f, -4883.91f,  171.36f, 3.12f, "Howling Fjord",         ACTION_NORTHREND },
    /* 29 */ { 571,   3256.57f,  5278.23f,   40.80f, 0.25f, "Borean Tundra",         ACTION_NORTHREND },
    /* 30 */ { 571,   7253.64f,  1644.78f,  433.68f, 4.83f, "Icecrown",              ACTION_NORTHREND },
    /* 31 */ { 571,   4391.73f, -3587.92f,  238.53f, 3.58f, "Grizzly Hills",         ACTION_NORTHREND },
    /* 32 */ { 571,   4760.70f,  2143.70f,  423.00f, 1.13f, "Wintergrasp",           ACTION_NORTHREND },

    // ========== PANDARIA (menu 50) ==========
    /* 33 */ { 870,   1570.20f,   894.05f,  473.60f, 0.48f, "Shrine of Two Moons",   ACTION_PANDARIA },
    /* 34 */ { 870,    907.90f,   336.61f,  506.10f, 3.92f, "Shrine of Seven Stars", ACTION_PANDARIA },
    /* 35 */ { 870,   2365.02f, -1759.82f,  375.26f, 3.78f, "Jade Forest",           ACTION_PANDARIA },

    // ========== DRAENOR (menu 60) ==========
    /* 36 */ { 1116,  6277.09f,  4661.20f,  164.16f, 5.28f, "Frostfire Ridge",       ACTION_DRAENOR },
    /* 37 */ { 1116,  6803.53f,  1219.95f,   69.69f, 5.62f, "Gorgrond",              ACTION_DRAENOR },
    /* 38 */ { 1116,  2892.45f,  3496.20f,   60.26f, 4.01f, "Shattrath (Draenor)",   ACTION_DRAENOR },
    /* 39 */ { 1116,  3714.25f, -3882.76f,   30.79f, 2.11f, "Stormshield (Ashran)",  ACTION_DRAENOR },
    /* 40 */ { 1116,  5152.35f, -4074.90f,   20.86f, 0.00f, "Warspear (Ashran)",     ACTION_DRAENOR },

    // ========== BROKEN ISLES (menu 70) ==========
    /* 41 */ { 1220,  -828.84f,  4371.91f,  738.64f, 1.88f, "Dalaran (Legion)",      ACTION_BROKEN_ISLES },
    /* 42 */ { 1220,  1708.83f,  4637.75f,  124.00f, 5.25f, "Suramar",               ACTION_BROKEN_ISLES },
    /* 43 */ { 1220,  3854.78f,  2020.04f,  242.64f, 3.29f, "Stormheim",             ACTION_BROKEN_ISLES },
    /* 44 */ { 1220,  4492.69f,  4836.35f,  661.71f, 1.37f, "Highmountain",          ACTION_BROKEN_ISLES },
    /* 45 */ { 1220,  -218.95f,  5600.90f,   61.11f, 3.32f, "Azsuna",               ACTION_BROKEN_ISLES },
    /* 46 */ { 1220, -1306.66f,  1741.40f,    7.32f, 0.09f, "Broken Shore",          ACTION_BROKEN_ISLES },

    // ========== BATTLE FOR AZEROTH (menu 80) ==========
    /* 47 */ { 1642, -1064.70f,   804.27f,  500.27f, 6.27f, "Dazar'alor",            ACTION_BFA },
    /* 48 */ { 1643,   744.75f,  -279.09f,   51.47f, 5.03f, "Boralus",               ACTION_BFA },
    /* 49 */ { 1718,  1537.84f, -1157.00f, -416.21f, 4.83f, "Nazjatar",              ACTION_BFA },

    // ========== SHADOWLANDS (menu 85) ==========
    /* 50 */ { 2222, -1834.00f,  1542.00f, 5275.00f, 4.71f, "Oribos",                ACTION_SHADOWLANDS },
    /* 51 */ { 2222, -2943.00f, -4871.00f, 6705.00f, 0.00f, "Bastion",               ACTION_SHADOWLANDS },
    /* 52 */ { 2222,  2583.00f, -2521.00f, 3308.00f, 0.00f, "Maldraxxus",            ACTION_SHADOWLANDS },
    /* 53 */ { 2222, -6926.00f,   883.00f, 5669.00f, 0.00f, "Ardenweald",            ACTION_SHADOWLANDS },
    /* 54 */ { 2222, -2628.00f,  6036.00f, 4116.00f, 0.00f, "Revendreth",            ACTION_SHADOWLANDS },

    // ========== DRAGON ISLES (menu 90) ==========
    /* 55 */ { 2444,   115.64f,  -939.72f,  836.59f, 1.61f, "Valdrakken",            ACTION_DRAGON_ISLES },
    /* 56 */ { 2444,  -620.50f,  2198.33f,  436.67f, 1.71f, "Ohn'ahran Plains",      ACTION_DRAGON_ISLES },
    /* 57 */ { 2444, -3817.34f,   505.70f,  647.83f, 5.61f, "Azure Span",            ACTION_DRAGON_ISLES },
    /* 58 */ { 2444,  6510.56f, -3318.14f,  162.99f, 5.60f, "The Forbidden Reach",   ACTION_DRAGON_ISLES },
    /* 59 */ { 2454,   100.62f,  2523.30f, -113.50f, 6.09f, "Zaralek Cavern",        ACTION_DRAGON_ISLES },
    /* 60 */ { 2548, -1134.45f,  7336.62f,  132.69f, 0.88f, "Emerald Dream",         ACTION_DRAGON_ISLES },

    // ========== KHAZ ALGAR — THE WAR WITHIN (menu 95) ==========
    /* 61 */ { 2552,  2663.10f, -2587.58f,  219.65f, 3.14f, "Dornogal",              ACTION_KHAZ_ALGAR },
    /* 62 */ { 2552,  1934.17f, -3084.21f,  154.75f, 0.79f, "Isle of Dorn",          ACTION_KHAZ_ALGAR },
    /* 63 */ { 2601,  1749.21f, -3332.27f,  316.99f, 3.22f, "The Ringing Deeps",     ACTION_KHAZ_ALGAR },
    /* 64 */ { 2601,  2064.52f,  -120.17f, -156.30f, 0.36f, "Hallowfall",            ACTION_KHAZ_ALGAR },
    /* 65 */ { 2601,   103.29f, -1396.45f,-1063.93f, 1.43f, "Azj-Kahet",             ACTION_KHAZ_ALGAR },
};

static constexpr uint32 DEST_COUNT = std::size(Destinations);

enum
{
    NPC_ARCANE_WAYGATE  = 400100,
    SPELL_WAYGATE       = 1900028,
};

// =================================================================
// CreatureScript — handles gossip menus and teleports
// =================================================================
class npc_arcane_waygate : public CreatureScript
{
public:
    npc_arcane_waygate() : CreatureScript("npc_arcane_waygate") { }

    struct npc_arcane_waygateAI : public PassiveAI
    {
        npc_arcane_waygateAI(Creature* creature) : PassiveAI(creature) { }

        // --- Helpers ---

        void ShowMenu(Player* player, uint32 menuAction)
        {
            ClearGossipMenuFor(player);

            switch (menuAction)
            {
                case ACTION_MAIN:
                    AddGossipItemFor(player, GossipOptionNpc::None, "Eastern Kingdoms",  GOSSIP_SENDER_MAIN, ACTION_EASTERN_KINGDOMS);
                    AddGossipItemFor(player, GossipOptionNpc::None, "Kalimdor",          GOSSIP_SENDER_MAIN, ACTION_KALIMDOR);
                    AddGossipItemFor(player, GossipOptionNpc::None, "Outland",           GOSSIP_SENDER_MAIN, ACTION_OUTLAND);
                    AddGossipItemFor(player, GossipOptionNpc::None, "Northrend",         GOSSIP_SENDER_MAIN, ACTION_NORTHREND);
                    AddGossipItemFor(player, GossipOptionNpc::None, "Pandaria",          GOSSIP_SENDER_MAIN, ACTION_PANDARIA);
                    AddGossipItemFor(player, GossipOptionNpc::None, "Draenor",           GOSSIP_SENDER_MAIN, ACTION_DRAENOR);
                    AddGossipItemFor(player, GossipOptionNpc::None, "Broken Isles",      GOSSIP_SENDER_MAIN, ACTION_BROKEN_ISLES);
                    AddGossipItemFor(player, GossipOptionNpc::None, "Zandalar & Kul Tiras", GOSSIP_SENDER_MAIN, ACTION_BFA);
                    AddGossipItemFor(player, GossipOptionNpc::None, "Shadowlands",       GOSSIP_SENDER_MAIN, ACTION_SHADOWLANDS);
                    AddGossipItemFor(player, GossipOptionNpc::None, "Dragon Isles",      GOSSIP_SENDER_MAIN, ACTION_DRAGON_ISLES);
                    AddGossipItemFor(player, GossipOptionNpc::None, "Khaz Algar",        GOSSIP_SENDER_MAIN, ACTION_KHAZ_ALGAR);
                    break;

                case ACTION_EASTERN_KINGDOMS:
                    AddGossipItemFor(player, GossipOptionNpc::None, "Major Cities",     GOSSIP_SENDER_MAIN, ACTION_EK_CITIES);
                    AddGossipItemFor(player, GossipOptionNpc::None, "Towns & Zones",    GOSSIP_SENDER_MAIN, ACTION_EK_TOWNS);
                    AddGossipItemFor(player, GossipOptionNpc::None,     "<< Back",          GOSSIP_SENDER_MAIN, ACTION_MAIN);
                    break;

                case ACTION_KALIMDOR:
                    AddGossipItemFor(player, GossipOptionNpc::None, "Major Cities",     GOSSIP_SENDER_MAIN, ACTION_KAL_CITIES);
                    AddGossipItemFor(player, GossipOptionNpc::None, "Towns & Zones",    GOSSIP_SENDER_MAIN, ACTION_KAL_TOWNS);
                    AddGossipItemFor(player, GossipOptionNpc::None,     "<< Back",          GOSSIP_SENDER_MAIN, ACTION_MAIN);
                    break;

                default:
                {
                    // For all other menus, show matching destinations + back button
                    uint32 parentMenu = ACTION_MAIN;
                    if (menuAction == ACTION_EK_CITIES || menuAction == ACTION_EK_TOWNS)
                        parentMenu = ACTION_EASTERN_KINGDOMS;
                    else if (menuAction == ACTION_KAL_CITIES || menuAction == ACTION_KAL_TOWNS)
                        parentMenu = ACTION_KALIMDOR;

                    for (uint32 i = 0; i < DEST_COUNT; ++i)
                    {
                        if (Destinations[i].menu == menuAction)
                            AddGossipItemFor(player, GossipOptionNpc::None, Destinations[i].name, GOSSIP_SENDER_MAIN, ACTION_TELEPORT + i);
                    }

                    AddGossipItemFor(player, GossipOptionNpc::None, "<< Back", GOSSIP_SENDER_MAIN, parentMenu);
                    break;
                }
            }

            SendGossipMenuFor(player, DEFAULT_GOSSIP_MESSAGE, me->GetGUID());
        }

        // --- Gossip ---

        bool OnGossipHello(Player* player) override
        {
            if (me->IsSummon())
            {
                if (TempSummon const* summon = me->ToTempSummon())
                    if (summon->GetSummoner() != player)
                        return true;
            }

            ShowMenu(player, ACTION_MAIN);
            return true;
        }

        bool OnGossipSelect(Player* player, uint32 /*menuId*/, uint32 gossipListId) override
        {
            uint32 action = player->PlayerTalkClass->GetGossipOptionAction(gossipListId);

            if (action >= ACTION_TELEPORT)
            {
                // Teleport
                uint32 idx = action - ACTION_TELEPORT;
                if (idx < DEST_COUNT)
                {
                    auto const& dest = Destinations[idx];
                    CloseGossipMenuFor(player);
                    player->TeleportTo(dest.mapId, dest.x, dest.y, dest.z, dest.o);
                    me->DespawnOrUnsummon();
                }
                return true;
            }

            // Submenu navigation
            ShowMenu(player, action);
            return true;
        }
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_arcane_waygateAI(creature);
    }
};

// =================================================================
// SpellScript — summons the waygate NPC and auto-opens gossip
// =================================================================
class spell_arcane_waygate : public SpellScript
{
    void HandleDummy(SpellEffIndex /*effIndex*/)
    {
        Player* player = GetCaster()->ToPlayer();
        if (!player)
            return;

        if (Creature* npc = player->SummonCreature(NPC_ARCANE_WAYGATE, *player, TEMPSUMMON_TIMED_DESPAWN, 60s))
        {
            npc->SetNpcFlag(UNIT_NPC_FLAG_GOSSIP);
            npc->AI()->OnGossipHello(player);
        }
    }

    void Register() override
    {
        OnEffectHitTarget += SpellEffectFn(spell_arcane_waygate::HandleDummy, EFFECT_0, SPELL_EFFECT_DUMMY);
    }
};

void AddSC_arcane_waygate()
{
    new npc_arcane_waygate();
    RegisterSpellScript(spell_arcane_waygate);
}
