#pragma once

#include "ScriptedCreature.h"
#include "CompanionDefines.h"

class CompanionAI : public ScriptedAI
{
public:
    explicit CompanionAI(Creature* creature);

    void UpdateAI(uint32 diff) override;
    void EnterEvadeMode(EvadeReason why) override;
    void JustDied(Unit* killer) override;

private:
    // Target selection
    Unit* SelectDefendTarget();
    Unit* SelectAssistTarget();
    Unit* SelectHealTarget();
    bool  IsValidCompanionTarget(Unit* target) const;
    bool  IsFriendlyTarget(Unit* target) const;

    // Role behaviors
    void UpdateTankBehavior(Unit* target, Companion::RosterEntry const* roster);
    void UpdateMeleeBehavior(Unit* target, Companion::RosterEntry const* roster);
    void UpdateRangedBehavior(Unit* target, Companion::RosterEntry const* roster);
    void UpdateCasterBehavior(Unit* target, Companion::RosterEntry const* roster);
    void UpdateHealerAI(Companion::RosterEntry const* roster);

    // Formation
    void ReturnToFormation();

    // Owner
    Player* GetOwner() const;

    uint32 _updateTimer = 0;
    uint32 _spell1Cooldown = 0;
    uint32 _spell2Cooldown = 0;
    uint32 _spell3Cooldown = 0;
};
