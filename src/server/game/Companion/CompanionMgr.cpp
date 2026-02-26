#include "CompanionMgr.h"
#include "CharacterDatabase.h"
#include "Creature.h"
#include "DatabaseEnv.h"
#include "Log.h"
#include "Map.h"
#include "MovementDefines.h"
#include "MotionMaster.h"
#include "ObjectAccessor.h"
#include "Player.h"
#include "TemporarySummon.h"
#include "Timer.h"
#include "WorldDatabase.h"
#include <cmath>

CompanionMgr::CompanionMgr() = default;
CompanionMgr::~CompanionMgr() = default;

CompanionMgr* CompanionMgr::Instance()
{
    static CompanionMgr instance;
    return &instance;
}

// ---------------------------------------------------------------------------
// Startup — load roster from world.companion_roster
// ---------------------------------------------------------------------------
void CompanionMgr::LoadRoster()
{
    uint32 oldMSTime = getMSTime();

    _roster.clear();
    _rosterIndex.clear();

    QueryResult result = WorldDatabase.Query("SELECT entry, name, role, spell1, spell2, spell3, cooldown1, cooldown2, cooldown3 FROM companion_roster");
    if (!result)
    {
        TC_LOG_INFO("server.loading", ">> Loaded 0 companion roster entries. Table `companion_roster` is empty or missing.");
        return;
    }

    do
    {
        Field* fields = result->Fetch();

        Companion::RosterEntry entry;
        entry.entry     = fields[0].GetUInt32();
        entry.name      = fields[1].GetString();
        entry.role      = static_cast<Companion::Role>(fields[2].GetUInt8());
        entry.spell1    = fields[3].GetUInt32();
        entry.spell2    = fields[4].GetUInt32();
        entry.spell3    = fields[5].GetUInt32();
        entry.cooldown1 = fields[6].GetUInt32();
        entry.cooldown2 = fields[7].GetUInt32();
        entry.cooldown3 = fields[8].GetUInt32();

        if (entry.role >= Companion::ROLE_MAX)
        {
            TC_LOG_ERROR("sql.sql", "companion_roster entry {} has invalid role {}. Skipping.", entry.entry, uint32(entry.role));
            continue;
        }

        _rosterIndex[entry.entry] = _roster.size();
        _roster.push_back(std::move(entry));
    }
    while (result->NextRow());

    TC_LOG_INFO("server.loading", ">> Loaded {} companion roster entries in {} ms", _roster.size(), GetMSTimeDiffToNow(oldMSTime));
}

// ---------------------------------------------------------------------------
// Per-player data load/save
// ---------------------------------------------------------------------------
void CompanionMgr::LoadPlayerData(Player* player)
{
    ObjectGuid::LowType guid = player->GetGUID().GetCounter();
    Companion::PlayerSquadState& state = _playerStates[guid];

    // Reset
    state = {};

    // Load squad slots
    CharacterDatabasePreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_SEL_COMPANION_SQUAD);
    stmt->setUInt64(0, guid);
    PreparedQueryResult result = CharacterDatabase.Query(stmt);
    if (result)
    {
        do
        {
            Field* fields = result->Fetch();
            uint8 slot      = fields[0].GetUInt8();
            uint32 entry    = fields[1].GetUInt32();

            if (slot >= Companion::MAX_SQUAD_SLOTS)
                continue;

            Companion::RosterEntry const* roster = GetRosterEntry(entry);
            if (!roster)
            {
                TC_LOG_ERROR("misc", "CompanionMgr::LoadPlayerData: Player {} has unknown roster entry {} in slot {}. Ignoring.",
                    guid, entry, slot);
                continue;
            }

            state.squad[slot].slot = slot;
            state.squad[slot].rosterEntry = roster;
        }
        while (result->NextRow());
    }

    // Load control state
    stmt = CharacterDatabase.GetPreparedStatement(CHAR_SEL_COMPANION_CONTROL);
    stmt->setUInt64(0, guid);
    result = CharacterDatabase.Query(stmt);
    if (result)
    {
        Field* fields = result->Fetch();
        uint8 mode = fields[0].GetUInt8();
        state.control.mode = (mode < Companion::MODE_MAX) ? static_cast<Companion::Mode>(mode) : Companion::MODE_DEFEND;
        state.control.following = fields[1].GetUInt8() != 0;
    }
}

void CompanionMgr::SavePlayerData(Player* player)
{
    ObjectGuid::LowType guid = player->GetGUID().GetCounter();
    Companion::PlayerSquadState* state = GetPlayerState(guid);
    if (!state)
        return;

    CharacterDatabaseTransaction trans = CharacterDatabase.BeginTransaction();

    // Delete + re-insert squad
    CharacterDatabasePreparedStatement* stmt = CharacterDatabase.GetPreparedStatement(CHAR_DEL_COMPANION_SQUAD);
    stmt->setUInt64(0, guid);
    trans->Append(stmt);

    for (uint8 i = 0; i < Companion::MAX_SQUAD_SLOTS; ++i)
    {
        if (!state->squad[i].rosterEntry)
            continue;

        stmt = CharacterDatabase.GetPreparedStatement(CHAR_INS_COMPANION_SQUAD);
        stmt->setUInt64(0, guid);
        stmt->setUInt8(1, i);
        stmt->setUInt32(2, state->squad[i].rosterEntry->entry);
        trans->Append(stmt);
    }

    // Replace control state
    stmt = CharacterDatabase.GetPreparedStatement(CHAR_REP_COMPANION_CONTROL);
    stmt->setUInt64(0, guid);
    stmt->setUInt8(1, uint8(state->control.mode));
    stmt->setUInt8(2, state->control.following ? 1 : 0);
    trans->Append(stmt);

    CharacterDatabase.CommitTransaction(trans);
}

void CompanionMgr::ClearPlayerData(ObjectGuid::LowType guid)
{
    _playerStates.erase(guid);
}

// ---------------------------------------------------------------------------
// Squad slot management
// ---------------------------------------------------------------------------
bool CompanionMgr::SetSquadSlot(Player* player, uint8 slot, uint32 rosterEntry)
{
    if (slot >= Companion::MAX_SQUAD_SLOTS)
        return false;

    Companion::RosterEntry const* roster = GetRosterEntry(rosterEntry);
    if (!roster)
        return false;

    ObjectGuid::LowType guid = player->GetGUID().GetCounter();
    Companion::PlayerSquadState& state = _playerStates[guid];

    state.squad[slot].slot = slot;
    state.squad[slot].rosterEntry = roster;
    return true;
}

void CompanionMgr::ClearSquadSlot(Player* player, uint8 slot)
{
    if (slot >= Companion::MAX_SQUAD_SLOTS)
        return;

    ObjectGuid::LowType guid = player->GetGUID().GetCounter();
    Companion::PlayerSquadState* state = GetPlayerState(guid);
    if (!state)
        return;

    state->squad[slot].rosterEntry = nullptr;
}

void CompanionMgr::ClearAllSlots(Player* player)
{
    ObjectGuid::LowType guid = player->GetGUID().GetCounter();
    Companion::PlayerSquadState* state = GetPlayerState(guid);
    if (!state)
        return;

    for (uint8 i = 0; i < Companion::MAX_SQUAD_SLOTS; ++i)
        state->squad[i].rosterEntry = nullptr;
}

// ---------------------------------------------------------------------------
// Spawning / despawning
// ---------------------------------------------------------------------------
void CompanionMgr::SummonSquad(Player* player)
{
    ObjectGuid::LowType guid = player->GetGUID().GetCounter();
    Companion::PlayerSquadState* state = GetPlayerState(guid);
    if (!state)
        return;

    // Dismiss existing first
    if (state->summoned)
        DismissSquad(player);

    // Count companions per role for formation spread
    uint8 roleCount[Companion::ROLE_MAX] = {};
    uint8 roleIndex[Companion::ROLE_MAX] = {};

    for (uint8 i = 0; i < Companion::MAX_SQUAD_SLOTS; ++i)
        if (state->squad[i].rosterEntry)
            roleCount[state->squad[i].rosterEntry->role]++;

    for (uint8 i = 0; i < Companion::MAX_SQUAD_SLOTS; ++i)
    {
        Companion::RosterEntry const* roster = state->squad[i].rosterEntry;
        if (!roster)
            continue;

        Companion::Role role = roster->role;
        Companion::FormationOffset offset = GetFormationOffset(role, roleIndex[role], roleCount[role]);
        roleIndex[role]++;

        // Calculate spawn position behind the player
        float angle = player->GetOrientation() + float(M_PI) + offset.angle;
        float x = player->GetPositionX() + offset.dist * std::cos(angle);
        float y = player->GetPositionY() + offset.dist * std::sin(angle);
        float z = player->GetPositionZ();

        TempSummon* summon = player->SummonCreature(roster->entry, x, y, z, player->GetOrientation(), TEMPSUMMON_MANUAL_DESPAWN);
        if (!summon)
        {
            TC_LOG_ERROR("misc", "CompanionMgr::SummonSquad: Failed to summon entry {} for player {}.", roster->entry, guid);
            continue;
        }

        // Match owner's level, faction, and flags
        summon->SetLevel(player->GetLevel());
        summon->SetFaction(player->GetFaction());
        summon->SetImmuneToPC(true);

        // Start following if enabled
        if (state->control.following)
            summon->GetMotionMaster()->MoveFollow(player, offset.dist, ChaseAngle(offset.angle + float(M_PI)));

        Companion::ActiveCompanion ac;
        ac.slot         = i;
        ac.rosterEntry  = roster;
        ac.creatureGuid = summon->GetGUID();
        state->active.push_back(ac);
    }

    state->summoned = true;
}

void CompanionMgr::DismissSquad(Player* player)
{
    ObjectGuid::LowType guid = player->GetGUID().GetCounter();
    Companion::PlayerSquadState* state = GetPlayerState(guid);
    if (!state)
        return;

    for (auto const& ac : state->active)
    {
        if (Creature* creature = ObjectAccessor::GetCreature(*player, ac.creatureGuid))
            creature->DespawnOrUnsummon();
    }

    state->active.clear();
    state->summoned = false;
}

void CompanionMgr::RespawnSquad(Player* player)
{
    ObjectGuid::LowType guid = player->GetGUID().GetCounter();
    Companion::PlayerSquadState* state = GetPlayerState(guid);
    if (!state || !state->summoned)
        return;

    DismissSquad(player);
    SummonSquad(player);
}

// ---------------------------------------------------------------------------
// Mode / follow
// ---------------------------------------------------------------------------
void CompanionMgr::SetMode(Player* player, Companion::Mode mode)
{
    ObjectGuid::LowType guid = player->GetGUID().GetCounter();
    Companion::PlayerSquadState* state = GetPlayerState(guid);
    if (!state)
        return;

    state->control.mode = mode;
}

void CompanionMgr::SetFollowing(Player* player, bool following)
{
    ObjectGuid::LowType guid = player->GetGUID().GetCounter();
    Companion::PlayerSquadState* state = GetPlayerState(guid);
    if (!state)
        return;

    state->control.following = following;

    // Update active companions
    if (!state->summoned)
        return;

    // Recalculate formation
    uint8 roleCount[Companion::ROLE_MAX] = {};
    uint8 roleIndex[Companion::ROLE_MAX] = {};

    for (auto const& ac : state->active)
        if (ac.rosterEntry)
            roleCount[ac.rosterEntry->role]++;

    for (auto const& ac : state->active)
    {
        Creature* creature = ObjectAccessor::GetCreature(*player, ac.creatureGuid);
        if (!creature || !ac.rosterEntry)
            continue;

        Companion::Role role = ac.rosterEntry->role;
        Companion::FormationOffset offset = GetFormationOffset(role, roleIndex[role], roleCount[role]);
        roleIndex[role]++;

        if (following)
            creature->GetMotionMaster()->MoveFollow(player, offset.dist, ChaseAngle(offset.angle + float(M_PI)));
        else
            creature->GetMotionMaster()->Clear();
    }
}

// ---------------------------------------------------------------------------
// Queries
// ---------------------------------------------------------------------------
Companion::PlayerSquadState* CompanionMgr::GetPlayerState(ObjectGuid::LowType guid)
{
    auto it = _playerStates.find(guid);
    return it != _playerStates.end() ? &it->second : nullptr;
}

Companion::RosterEntry const* CompanionMgr::GetRosterEntry(uint32 entry) const
{
    auto it = _rosterIndex.find(entry);
    return it != _rosterIndex.end() ? &_roster[it->second] : nullptr;
}

// ---------------------------------------------------------------------------
// Formation math
// ---------------------------------------------------------------------------
//
// Layout (behind the owner):
//   Tank(s)       ~2.0 yd behind, centered
//   Melee(s)      ~3.5 yd behind, wide flanking
//   Ranged/Caster ~5.5 yd behind, spread left/right
//   Healer        ~6.5 yd behind, center far back
//
// Multiple companions of the same role spread symmetrically with 0.6 rad spacing.
// angle=0 means directly behind the owner (M_PI from facing).
//
Companion::FormationOffset CompanionMgr::GetFormationOffset(Companion::Role role, uint8 slotIndex, uint8 totalInRole) const
{
    float baseDist = 0.0f;
    float baseAngle = 0.0f;

    switch (role)
    {
        case Companion::ROLE_TANK:   baseDist = 1.5f; baseAngle = 0.0f; break;
        case Companion::ROLE_MELEE:  baseDist = 2.0f; baseAngle = 0.0f; break;
        case Companion::ROLE_RANGED: baseDist = 3.5f; baseAngle = -0.3f; break;
        case Companion::ROLE_CASTER: baseDist = 3.5f; baseAngle =  0.3f; break;
        case Companion::ROLE_HEALER: baseDist = 4.0f; baseAngle = 0.0f; break;
        default: break;
    }

    // Spread multiple companions of the same role
    if (totalInRole > 1)
    {
        float spread = 0.6f; // radians
        float offset = spread * (float(slotIndex) - float(totalInRole - 1) / 2.0f);
        baseAngle += offset;
    }

    return { baseDist, baseAngle };
}

void CompanionMgr::UpdateFormationPositions(Player* player)
{
    ObjectGuid::LowType guid = player->GetGUID().GetCounter();
    Companion::PlayerSquadState* state = GetPlayerState(guid);
    if (!state || !state->summoned || !state->control.following)
        return;

    uint8 roleCount[Companion::ROLE_MAX] = {};
    uint8 roleIndex[Companion::ROLE_MAX] = {};

    for (auto const& ac : state->active)
        if (ac.rosterEntry)
            roleCount[ac.rosterEntry->role]++;

    for (auto const& ac : state->active)
    {
        Creature* creature = ObjectAccessor::GetCreature(*player, ac.creatureGuid);
        if (!creature || !ac.rosterEntry)
            continue;

        Companion::Role role = ac.rosterEntry->role;
        Companion::FormationOffset offset = GetFormationOffset(role, roleIndex[role], roleCount[role]);
        roleIndex[role]++;

        creature->GetMotionMaster()->MoveFollow(player, offset.dist, ChaseAngle(offset.angle + float(M_PI)));
    }
}
