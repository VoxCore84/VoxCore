#pragma once

#include "Define.h"
#include "ObjectGuid.h"
#include <string>

namespace Companion
{
    constexpr uint8  MAX_SQUAD_SLOTS      = 5;
    constexpr uint32 AI_UPDATE_INTERVAL   = 500;       // ms
    constexpr float  LEASH_DISTANCE       = 60.0f;     // yd
    constexpr float  COMBAT_SEARCH_RANGE  = 30.0f;     // yd
    constexpr float  HEAL_SEARCH_RANGE    = 40.0f;     // yd
    constexpr float  HEAL_HP_THRESHOLD    = 75.0f;     // %

    enum Role : uint8
    {
        ROLE_TANK   = 0,
        ROLE_MELEE  = 1,
        ROLE_RANGED = 2,
        ROLE_CASTER = 3,
        ROLE_HEALER = 4,
        ROLE_MAX
    };

    inline char const* RoleToString(Role role)
    {
        switch (role)
        {
            case ROLE_TANK:   return "Tank";
            case ROLE_MELEE:  return "Melee";
            case ROLE_RANGED: return "Ranged";
            case ROLE_CASTER: return "Caster";
            case ROLE_HEALER: return "Healer";
            default:          return "Unknown";
        }
    }

    enum Mode : uint8
    {
        MODE_PASSIVE = 0,
        MODE_DEFEND  = 1,
        MODE_ASSIST  = 2,
        MODE_MAX
    };

    inline char const* ModeToString(Mode mode)
    {
        switch (mode)
        {
            case MODE_PASSIVE: return "Passive";
            case MODE_DEFEND:  return "Defend";
            case MODE_ASSIST:  return "Assist";
            default:           return "Unknown";
        }
    }

    struct RosterEntry
    {
        uint32      entry = 0;
        std::string name;
        Role        role = ROLE_TANK;
        uint32      spell1 = 0;
        uint32      spell2 = 0;
        uint32      spell3 = 0;
        uint32      cooldown1 = 8000;
        uint32      cooldown2 = 12000;
        uint32      cooldown3 = 15000;
    };

    struct SquadSlot
    {
        uint8               slot = 0;           // 0-4
        RosterEntry const*  rosterEntry = nullptr;
    };

    struct ControlState
    {
        Mode mode      = MODE_DEFEND;
        bool following = true;
    };

    struct ActiveCompanion
    {
        uint8               slot = 0;
        RosterEntry const*  rosterEntry = nullptr;
        ObjectGuid          creatureGuid;
    };

    struct PlayerSquadState
    {
        ControlState                    control;
        SquadSlot                       squad[MAX_SQUAD_SLOTS];
        std::vector<ActiveCompanion>    active;
        bool                            summoned = false;
    };

    struct FormationOffset
    {
        float dist  = 0.0f;
        float angle = 0.0f;    // radians, 0 = in front, M_PI = behind
    };
}
