/*
 * Wormhole Generator teleport fixes for TrinityCore 12.x
 *
 * Pattern A (SpellScripts): Argus, Kul Tiras, Zandalar, Dalaran
 *   - Handle SPELL_EFFECT_DUMMY, pick random destination, TeleportTo()
 *
 * Pattern B (NPC Gossip Scripts): Draenor, Legion, Shadowlands, Khaz Algar
 *   - Summoned NPC with gossip menu, player picks zone, TeleportTo(), despawn
 */

#include "Containers.h"
#include "Creature.h"
#include "GossipDef.h"
#include "PassiveAI.h"
#include "Player.h"
#include "ScriptedGossip.h"
#include "ScriptMgr.h"
#include "SpellScript.h"

// ============================================================================
// Helper: destination entry
// ============================================================================

struct WormholeDest
{
    uint32 mapId;
    float x;
    float y;
    float z;
    float o; // orientation
};

// ============================================================================
// Pattern A: SpellScripts (random teleport on SPELL_EFFECT_DUMMY)
// ============================================================================

// ----------------------------------------------------------------------------
// 1. Wormhole Generator: Argus (Spell 250796, Map 1669)
// ----------------------------------------------------------------------------

static constexpr WormholeDest ArgusDestinations[] =
{
    { 1669,  633.745f,  1438.83f,   622.762f,  0.0f },  // Krokuun
    { 1669, 5391.07f,   9898.29f,   -91.4524f, 0.0f },  // Mac'Aree
    { 1669, -2895.55f,  8780.41f,  -228.743f,  0.0f },  // Antoran Wastes
};

class spell_wormhole_argus : public SpellScript
{
    void HandleTeleport(SpellEffIndex effIndex)
    {
        PreventHitDefaultEffect(effIndex);
        if (Player* player = GetHitUnit()->ToPlayer())
        {
            auto const& dest = Trinity::Containers::SelectRandomContainerElement(ArgusDestinations);
            player->TeleportTo(dest.mapId, dest.x, dest.y, dest.z, dest.o);
        }
    }

    void Register() override
    {
        OnEffectHitTarget += SpellEffectFn(spell_wormhole_argus::HandleTeleport, EFFECT_0, SPELL_EFFECT_DUMMY);
    }
};

// ----------------------------------------------------------------------------
// 2. Wormhole Generator: Kul Tiras (Spell 299083, Map 1643)
// ----------------------------------------------------------------------------

static constexpr WormholeDest KulTirasDestinations[] =
{
    { 1643, 1182.41f,   -97.8003f,  31.5567f, 0.0f },  // Tiragarde Sound
    { 1643,   58.9879f, 2155.31f,   71.0015f, 0.0f },  // Drustvar
    { 1643, 2807.3f,       6.28646f, 50.9802f, 0.0f }, // Stormsong Valley
    { 1643, 3116.98f,   4898.31f,   33.6045f, 0.0f },  // Mechagon Island
};

class spell_wormhole_kul_tiras : public SpellScript
{
    void HandleTeleport(SpellEffIndex effIndex)
    {
        PreventHitDefaultEffect(effIndex);
        if (Player* player = GetHitUnit()->ToPlayer())
        {
            auto const& dest = Trinity::Containers::SelectRandomContainerElement(KulTirasDestinations);
            player->TeleportTo(dest.mapId, dest.x, dest.y, dest.z, dest.o);
        }
    }

    void Register() override
    {
        OnEffectHitTarget += SpellEffectFn(spell_wormhole_kul_tiras::HandleTeleport, EFFECT_0, SPELL_EFFECT_DUMMY);
    }
};

// ----------------------------------------------------------------------------
// 3. Wormhole Generator: Zandalar (Spell 299084, Map 1642)
// ----------------------------------------------------------------------------

static constexpr WormholeDest ZandalarDestinations[] =
{
    { 1642, -1128.36f,  804.606f, 500.229f,  0.0f },  // Zuldazar
    { 1642,  1099.99f, 1114.03f,   26.3739f, 0.0f },  // Nazmir
    { 1642,  1973.68f, 2394.98f,  120.8f,    0.0f },  // Vol'dun
};

class spell_wormhole_zandalar : public SpellScript
{
    void HandleTeleport(SpellEffIndex effIndex)
    {
        PreventHitDefaultEffect(effIndex);
        if (Player* player = GetHitUnit()->ToPlayer())
        {
            auto const& dest = Trinity::Containers::SelectRandomContainerElement(ZandalarDestinations);
            player->TeleportTo(dest.mapId, dest.x, dest.y, dest.z, dest.o);
        }
    }

    void Register() override
    {
        OnEffectHitTarget += SpellEffectFn(spell_wormhole_zandalar::HandleTeleport, EFFECT_0, SPELL_EFFECT_DUMMY);
    }
};

// ----------------------------------------------------------------------------
// 4. Intra-Dalaran Wormhole (Spell 199978, Map 1220)
// ----------------------------------------------------------------------------

static constexpr WormholeDest DalaranDestinations[] =
{
    { 1220, -855.0f, 4425.0f, 740.0f, 0.0f },  // Krasus' Landing
    { 1220, -704.0f, 4557.0f, 729.0f, 0.0f },  // The Eventide
    { 1220, -706.0f, 4500.0f, 680.0f, 0.0f },  // The Underbelly
    { 1220, -637.0f, 4446.0f, 729.0f, 0.0f },  // Magus Commerce
    { 1220, -767.0f, 4359.0f, 730.0f, 0.0f },  // Runeweaver Square
};

class spell_wormhole_dalaran : public SpellScript
{
    void HandleTeleport(SpellEffIndex effIndex)
    {
        PreventHitDefaultEffect(effIndex);
        if (Player* player = GetHitUnit()->ToPlayer())
        {
            auto const& dest = Trinity::Containers::SelectRandomContainerElement(DalaranDestinations);
            player->TeleportTo(dest.mapId, dest.x, dest.y, dest.z, dest.o);
        }
    }

    void Register() override
    {
        OnEffectHitTarget += SpellEffectFn(spell_wormhole_dalaran::HandleTeleport, EFFECT_0, SPELL_EFFECT_DUMMY);
    }
};

// ============================================================================
// Pattern B: NPC Gossip Scripts (summoned NPC with destination menu)
// ============================================================================

// Default NPC text ID for wormhole NPCs (generic "What can I do for you?")
static constexpr uint32 DEFAULT_GOSSIP_TEXT = 907;

// ----------------------------------------------------------------------------
// 5. Wormhole Centrifuge — Draenor (NPC 81205, Map 1116)
// ----------------------------------------------------------------------------

static constexpr WormholeDest DraenorDestinations[] =
{
    { 1116, 5535.01f,   5019.88f,    12.64f,   0.0f },  // Frostfire Ridge
    { 1116, 6226.06f,    836.885f,  111.908f,  0.0f },  // Gorgrond
    { 1116, 2885.92f,   2056.7f,    119.329f,  0.0f },  // Talador
    { 1116, -503.786f,  1858.94f,    44.7815f, 0.0f },  // Spires of Arak
    { 1116, 2481.37f,   5335.2f,    144.359f,  0.0f },  // Nagrand
    { 1116, 1223.56f,  -1876.87f,    24.598f,  0.0f },  // Shadowmoon Valley
    { 1116, 3667.8f,   -3843.0f,     44.14f,   0.0f },  // Ashran
};

static char const* const DraenorZoneNames[] =
{
    "Frostfire Ridge",
    "Gorgrond",
    "Talador",
    "Spires of Arak",
    "Nagrand",
    "Shadowmoon Valley",
    "Ashran",
};

class npc_wormhole_centrifuge : public CreatureScript
{
public:
    npc_wormhole_centrifuge() : CreatureScript("npc_wormhole_centrifuge") { }

    struct npc_wormhole_centrifugeAI : public PassiveAI
    {
        npc_wormhole_centrifugeAI(Creature* creature) : PassiveAI(creature) { }

        bool OnGossipHello(Player* player) override
        {
            if (!me->IsSummon() || player != me->ToTempSummon()->GetSummoner())
                return true;

            for (uint32 i = 0; i < std::size(DraenorDestinations); ++i)
                AddGossipItemFor(player, GossipOptionNpc::None, DraenorZoneNames[i], GOSSIP_SENDER_MAIN, i);

            SendGossipMenuFor(player, DEFAULT_GOSSIP_TEXT, me->GetGUID());
            return true;
        }

        bool OnGossipSelect(Player* player, uint32 /*menuId*/, uint32 gossipListId) override
        {
            uint32 action = player->PlayerTalkClass->GetGossipOptionAction(gossipListId);
            ClearGossipMenuFor(player);
            CloseGossipMenuFor(player);

            if (action < std::size(DraenorDestinations))
            {
                auto const& dest = DraenorDestinations[action];
                player->TeleportTo(dest.mapId, dest.x, dest.y, dest.z, dest.o);
            }

            me->DespawnOrUnsummon();
            return true;
        }
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_wormhole_centrifugeAI(creature);
    }
};

// ----------------------------------------------------------------------------
// 6. Reaves Wormhole — Legion Broken Isles (NPC 104677, Map 1220)
// ----------------------------------------------------------------------------

static constexpr WormholeDest LegionDestinations[] =
{
    { 1220,  766.573f, 6570.12f, 119.977f, 0.0f },  // Azsuna
    { 1220, 2173.75f,  6598.42f, 122.717f, 0.0f },  // Val'sharah
    { 1220, 4263.87f,  4440.36f, 672.051f, 0.0f },  // Highmountain
    { 1220, 3154.88f,  1533.73f, 180.987f, 0.0f },  // Stormheim
    { 1220, 1779.29f,  4601.86f, 165.856f, 0.0f },  // Suramar
};

static char const* const LegionZoneNames[] =
{
    "Azsuna",
    "Val'sharah",
    "Highmountain",
    "Stormheim",
    "Suramar",
};

class npc_wormhole_legion : public CreatureScript
{
public:
    npc_wormhole_legion() : CreatureScript("npc_wormhole_legion") { }

    struct npc_wormhole_legionAI : public PassiveAI
    {
        npc_wormhole_legionAI(Creature* creature) : PassiveAI(creature) { }

        bool OnGossipHello(Player* player) override
        {
            if (!me->IsSummon() || player != me->ToTempSummon()->GetSummoner())
                return true;

            for (uint32 i = 0; i < std::size(LegionDestinations); ++i)
                AddGossipItemFor(player, GossipOptionNpc::None, LegionZoneNames[i], GOSSIP_SENDER_MAIN, i);

            SendGossipMenuFor(player, DEFAULT_GOSSIP_TEXT, me->GetGUID());
            return true;
        }

        bool OnGossipSelect(Player* player, uint32 /*menuId*/, uint32 gossipListId) override
        {
            uint32 action = player->PlayerTalkClass->GetGossipOptionAction(gossipListId);
            ClearGossipMenuFor(player);
            CloseGossipMenuFor(player);

            if (action < std::size(LegionDestinations))
            {
                auto const& dest = LegionDestinations[action];
                player->TeleportTo(dest.mapId, dest.x, dest.y, dest.z, dest.o);
            }

            me->DespawnOrUnsummon();
            return true;
        }
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_wormhole_legionAI(creature);
    }
};

// ----------------------------------------------------------------------------
// 7. Wormhole Generator — Shadowlands (NPC 169501, Map 2222)
// ----------------------------------------------------------------------------

static constexpr WormholeDest ShadowlandsDestinations[] =
{
    { 2222, -3293.0f,   -4358.0f,   6603.0f,  0.0f },  // Bastion
    { 2222,  2551.51f,  -2636.38f,  3305.73f, 0.0f },  // Maldraxxus
    { 2222, -7012.55f,   -233.209f, 5519.69f, 0.0f },  // Ardenweald
    { 2222, -2247.56f,   7675.38f,  4048.44f, 0.0f },  // Revendreth
    { 2222,  3919.63f,   7202.91f,  4799.62f, 0.0f },  // The Maw
    { 2222, -1834.19f,   1542.47f,  5274.16f, 0.0f },  // Oribos
    { 2374, -3832.0f,    1246.0f,      1.0f,  0.0f },  // Zereth Mortis
};

static char const* const ShadowlandsZoneNames[] =
{
    "Bastion",
    "Maldraxxus",
    "Ardenweald",
    "Revendreth",
    "The Maw",
    "Oribos",
    "Zereth Mortis",
};

class npc_wormhole_shadowlands : public CreatureScript
{
public:
    npc_wormhole_shadowlands() : CreatureScript("npc_wormhole_shadowlands") { }

    struct npc_wormhole_shadowlandsAI : public PassiveAI
    {
        npc_wormhole_shadowlandsAI(Creature* creature) : PassiveAI(creature) { }

        bool OnGossipHello(Player* player) override
        {
            if (!me->IsSummon() || player != me->ToTempSummon()->GetSummoner())
                return true;

            for (uint32 i = 0; i < std::size(ShadowlandsDestinations); ++i)
                AddGossipItemFor(player, GossipOptionNpc::None, ShadowlandsZoneNames[i], GOSSIP_SENDER_MAIN, i);

            SendGossipMenuFor(player, DEFAULT_GOSSIP_TEXT, me->GetGUID());
            return true;
        }

        bool OnGossipSelect(Player* player, uint32 /*menuId*/, uint32 gossipListId) override
        {
            uint32 action = player->PlayerTalkClass->GetGossipOptionAction(gossipListId);
            ClearGossipMenuFor(player);
            CloseGossipMenuFor(player);

            if (action < std::size(ShadowlandsDestinations))
            {
                auto const& dest = ShadowlandsDestinations[action];
                player->TeleportTo(dest.mapId, dest.x, dest.y, dest.z, dest.o);
            }

            me->DespawnOrUnsummon();
            return true;
        }
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_wormhole_shadowlandsAI(creature);
    }
};

// ----------------------------------------------------------------------------
// 8. Wormhole Generator — Khaz Algar / The War Within (NPC 223342, Map 2552)
// ----------------------------------------------------------------------------

static constexpr WormholeDest KhazAlgarDestinations[] =
{
    { 2552, 2392.03f,  -2762.0f,    201.459f,  0.0f },  // Isle of Dorn
    { 2552,  962.716f, -1948.65f,    79.7994f, 0.0f },  // The Ringing Deeps
    { 2552, 2676.22f,  -4103.61f,    86.4276f, 0.0f },  // Hallowfall
    { 2552, 3514.98f,  -3387.69f,   189.013f,  0.0f },  // Azj-Kahet
};

static char const* const KhazAlgarZoneNames[] =
{
    "Isle of Dorn",
    "The Ringing Deeps",
    "Hallowfall",
    "Azj-Kahet",
};

class npc_wormhole_khaz_algar : public CreatureScript
{
public:
    npc_wormhole_khaz_algar() : CreatureScript("npc_wormhole_khaz_algar") { }

    struct npc_wormhole_khaz_algarAI : public PassiveAI
    {
        npc_wormhole_khaz_algarAI(Creature* creature) : PassiveAI(creature) { }

        bool OnGossipHello(Player* player) override
        {
            if (!me->IsSummon() || player != me->ToTempSummon()->GetSummoner())
                return true;

            for (uint32 i = 0; i < std::size(KhazAlgarDestinations); ++i)
                AddGossipItemFor(player, GossipOptionNpc::None, KhazAlgarZoneNames[i], GOSSIP_SENDER_MAIN, i);

            SendGossipMenuFor(player, DEFAULT_GOSSIP_TEXT, me->GetGUID());
            return true;
        }

        bool OnGossipSelect(Player* player, uint32 /*menuId*/, uint32 gossipListId) override
        {
            uint32 action = player->PlayerTalkClass->GetGossipOptionAction(gossipListId);
            ClearGossipMenuFor(player);
            CloseGossipMenuFor(player);

            if (action < std::size(KhazAlgarDestinations))
            {
                auto const& dest = KhazAlgarDestinations[action];
                player->TeleportTo(dest.mapId, dest.x, dest.y, dest.z, dest.o);
            }

            me->DespawnOrUnsummon();
            return true;
        }
    };

    CreatureAI* GetAI(Creature* creature) const override
    {
        return new npc_wormhole_khaz_algarAI(creature);
    }
};

// ============================================================================
// Registration
// ============================================================================

void AddSC_wormhole_generators()
{
    // Pattern A: SpellScripts (random teleport)
    RegisterSpellScript(spell_wormhole_argus);        // Spell 250796
    RegisterSpellScript(spell_wormhole_kul_tiras);    // Spell 299083
    RegisterSpellScript(spell_wormhole_zandalar);     // Spell 299084
    RegisterSpellScript(spell_wormhole_dalaran);      // Spell 199978

    // Pattern B: NPC Gossip Scripts (menu teleport)
    new npc_wormhole_centrifuge();   // NPC 81205  — Draenor
    new npc_wormhole_legion();       // NPC 104677 — Legion Broken Isles
    new npc_wormhole_shadowlands();  // NPC 169501 — Shadowlands
    new npc_wormhole_khaz_algar();   // NPC 223342 — Khaz Algar
}
