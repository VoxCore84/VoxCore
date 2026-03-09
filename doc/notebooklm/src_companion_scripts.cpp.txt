#include "CompanionAI.h"
#include "CompanionMgr.h"
#include "Player.h"
#include "ScriptMgr.h"

// ---------------------------------------------------------------------------
// PlayerScript — load/save/respawn on login/logout/map change
// ---------------------------------------------------------------------------
class CompanionPlayerScript : public PlayerScript
{
public:
    CompanionPlayerScript() : PlayerScript("CompanionPlayerScript") { }

    void OnLogin(Player* player, bool /*firstLogin*/) override
    {
        sCompanionMgr->LoadPlayerData(player);
    }

    void OnLogout(Player* player) override
    {
        sCompanionMgr->DismissSquad(player);
        sCompanionMgr->SavePlayerData(player);
        sCompanionMgr->ClearPlayerData(player->GetGUID().GetCounter());
    }

    void OnMapChanged(Player* player) override
    {
        sCompanionMgr->RespawnSquad(player);
    }
};

// ---------------------------------------------------------------------------
// WorldScript — load roster on startup
// ---------------------------------------------------------------------------
class CompanionWorldScript : public WorldScript
{
public:
    CompanionWorldScript() : WorldScript("CompanionWorldScript") { }

    void OnStartup() override
    {
        sCompanionMgr->LoadRoster();
    }
};

// ---------------------------------------------------------------------------
// Registration
// ---------------------------------------------------------------------------
void AddSC_CompanionAI()
{
    RegisterCreatureAI(CompanionAI);
}

void AddSC_CompanionScripts()
{
    new CompanionPlayerScript();
    new CompanionWorldScript();
}
