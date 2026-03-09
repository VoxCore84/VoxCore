#pragma once

#include "CompanionDefines.h"
#include "ObjectGuid.h"
#include <unordered_map>
#include <vector>

class Player;
class Creature;

class TC_GAME_API CompanionMgr
{
    CompanionMgr();
    ~CompanionMgr();

public:
    static CompanionMgr* Instance();

    // Startup
    void LoadRoster();

    // Per-player lifecycle
    void LoadPlayerData(Player* player);
    void SavePlayerData(Player* player);
    void ClearPlayerData(ObjectGuid::LowType guid);

    // Squad management
    bool SetSquadSlot(Player* player, uint8 slot, uint32 rosterEntry);
    void ClearSquadSlot(Player* player, uint8 slot);
    void ClearAllSlots(Player* player);

    // Spawning
    void SummonSquad(Player* player);
    void DismissSquad(Player* player);
    void RespawnSquad(Player* player);

    // Mode / follow
    void SetMode(Player* player, Companion::Mode mode);
    void SetFollowing(Player* player, bool following);

    // Queries
    Companion::PlayerSquadState* GetPlayerState(ObjectGuid::LowType guid);
    Companion::RosterEntry const* GetRosterEntry(uint32 entry) const;
    std::vector<Companion::RosterEntry> const& GetRoster() const { return _roster; }

    // Formation
    Companion::FormationOffset GetFormationOffset(Companion::Role role, uint8 slotIndex, uint8 totalInRole) const;

private:
    void UpdateFormationPositions(Player* player);

    std::vector<Companion::RosterEntry>                                     _roster;
    std::unordered_map<uint32, size_t>                                      _rosterIndex;   // entry -> index in _roster
    std::unordered_map<ObjectGuid::LowType, Companion::PlayerSquadState>    _playerStates;
};

#define sCompanionMgr CompanionMgr::Instance()
