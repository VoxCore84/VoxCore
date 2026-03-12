#include "Chat.h"
#include "ChatCommand.h"
#include "Creature.h"
#include "DatabaseEnv.h"
#include "ObjectMgr.h"
#include "Player.h"
#include "RBAC.h"
#include "ScriptMgr.h"
#include "SpellMgr.h"
#include "World.h"
#include "WorldSession.h"

using namespace Trinity::ChatCommands;

// Forward declarations from bestiary_sniffer.cpp
namespace BestiaryForge
{
    bool IsRuntimeBlacklisted(uint32 spellId);
    void AddToBlacklist(uint32 spellId);
    bool RemoveFromBlacklist(uint32 spellId);
    std::unordered_set<uint32> GetBlacklistCopy();
}

class bestiary_commandscript : public CommandScript
{
public:
    bestiary_commandscript() : CommandScript("bestiary_commandscript") {}

    ChatCommandTable GetCommands() const override
    {
        static ChatCommandTable blacklistTable =
        {
            { "add",    HandleBlacklistAdd,    rbac::RBAC_PERM_COMMAND_BESTIARY, Console::No },
            { "remove", HandleBlacklistRemove, rbac::RBAC_PERM_COMMAND_BESTIARY, Console::No },
            { "list",   HandleBlacklistList,   rbac::RBAC_PERM_COMMAND_BESTIARY, Console::No },
        };

        static ChatCommandTable bestiaryTable =
        {
            { "query",     HandleBestiaryQuery, rbac::RBAC_PERM_COMMAND_BESTIARY, Console::No },
            { "stats",     HandleBestiaryStats, rbac::RBAC_PERM_COMMAND_BESTIARY, Console::No },
            { "blacklist", blacklistTable },
        };

        static ChatCommandTable commandTable =
        {
            { "bestiary", bestiaryTable },
        };
        return commandTable;
    }

    static bool HandleBestiaryQuery(ChatHandler* handler, uint32 entry)
    {
        CreatureTemplate const* cInfo = sObjectMgr->GetCreatureTemplate(entry);
        if (!cInfo)
        {
            handler->PSendSysMessage("[BestiaryForge] Creature entry %u not found.", entry);
            handler->SetSentErrorMessage(true);
            return false;
        }

        handler->PSendSysMessage("[BestiaryForge] Spells for |cFF00FF00%s|r (entry %u):",
            cInfo->Name.c_str(), entry);

        bool found = false;
        for (uint8 i = 0; i < MAX_CREATURE_SPELLS; ++i)
        {
            uint32 spellId = cInfo->spells[i];
            if (!spellId)
                continue;

            found = true;
            SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(spellId, DIFFICULTY_NONE);
            if (spellInfo && spellInfo->SpellName)
            {
                handler->PSendSysMessage("  [%u] Spell %u - %s (school 0x%02X)",
                    i, spellId, (*spellInfo->SpellName)[LOCALE_enUS],
                    uint32(spellInfo->SchoolMask));
            }
            else
            {
                handler->PSendSysMessage("  [%u] Spell %u - (unknown)", i, spellId);
            }
        }

        if (!found)
            handler->SendSysMessage("  (no spells assigned)");

        return true;
    }

    static bool HandleBestiaryStats(ChatHandler* handler)
    {
        uint32 totalSessions = 0;
        uint32 listeningPlayers = 0;

        SessionMap const& sessions = sWorld->GetAllSessions();
        for (auto const& [accountId, session] : sessions)
        {
            if (!session || !session->GetPlayer() || !session->GetPlayer()->IsInWorld())
                continue;

            ++totalSessions;
            if (session->IsAddonRegistered("BFRG"))
                ++listeningPlayers;
        }

        auto blacklist = BestiaryForge::GetBlacklistCopy();

        handler->SendSysMessage("[BestiaryForge] Sniffer Statistics:");
        handler->PSendSysMessage("  Players online: %u", totalSessions);
        handler->PSendSysMessage("  Players with BFRG addon: %u", listeningPlayers);
        handler->PSendSysMessage("  Runtime blacklisted spells: %u", uint32(blacklist.size()));

        return true;
    }

    static bool HandleBlacklistAdd(ChatHandler* handler, uint32 spellId)
    {
        SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(spellId, DIFFICULTY_NONE);
        BestiaryForge::AddToBlacklist(spellId);

        if (spellInfo && spellInfo->SpellName)
            handler->PSendSysMessage("[BestiaryForge] Blacklisted spell %u (%s).",
                spellId, (*spellInfo->SpellName)[LOCALE_enUS]);
        else
            handler->PSendSysMessage("[BestiaryForge] Blacklisted spell %u (unknown).", spellId);

        return true;
    }

    static bool HandleBlacklistRemove(ChatHandler* handler, uint32 spellId)
    {
        if (!BestiaryForge::RemoveFromBlacklist(spellId))
        {
            handler->PSendSysMessage("[BestiaryForge] Spell %u not in runtime blacklist.", spellId);
            return true;
        }

        SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(spellId, DIFFICULTY_NONE);
        if (spellInfo && spellInfo->SpellName)
            handler->PSendSysMessage("[BestiaryForge] Removed spell %u (%s) from blacklist.",
                spellId, (*spellInfo->SpellName)[LOCALE_enUS]);
        else
            handler->PSendSysMessage("[BestiaryForge] Removed spell %u from blacklist.", spellId);

        return true;
    }

    static bool HandleBlacklistList(ChatHandler* handler)
    {
        auto blacklist = BestiaryForge::GetBlacklistCopy();

        if (blacklist.empty())
        {
            handler->SendSysMessage("[BestiaryForge] Runtime blacklist is empty.");
            return true;
        }

        handler->PSendSysMessage("[BestiaryForge] Runtime blacklist (%u entries):", uint32(blacklist.size()));

        for (uint32 spellId : blacklist)
        {
            SpellInfo const* spellInfo = sSpellMgr->GetSpellInfo(spellId, DIFFICULTY_NONE);
            if (spellInfo && spellInfo->SpellName)
                handler->PSendSysMessage("  Spell %u - %s", spellId, (*spellInfo->SpellName)[LOCALE_enUS]);
            else
                handler->PSendSysMessage("  Spell %u - (unknown)", spellId);
        }

        return true;
    }
};

void AddSC_bestiary_commands()
{
    new bestiary_commandscript();
}
