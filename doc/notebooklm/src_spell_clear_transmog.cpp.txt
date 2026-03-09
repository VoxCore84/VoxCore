#include "Player.h"
#include "Item.h"
#include "ScriptMgr.h"
#include "SpellScript.h"

// Spell 1247917 - "Clear Current Transmogrifications"
// Fired by the transmog UI's "Clear" button. Removes all transmog appearances,
// secondary appearances, and illusions from every equipped item.
class spell_clear_current_transmogrifications : public SpellScript
{
    void HandleScriptEffect(SpellEffIndex /*effIndex*/)
    {
        Player* player = GetHitUnit()->ToPlayer();
        if (!player)
            return;

        TC_LOG_DEBUG("spells.effect", "spell_clear_current_transmogrifications [{}]: clearing all transmog",
            player->GetGUID().ToString());

        for (uint8 slot = EQUIPMENT_SLOT_START; slot < EQUIPMENT_SLOT_END; ++slot)
        {
            Item* item = player->GetItemByPos(INVENTORY_SLOT_BAG_0, slot);
            if (!item)
                continue;

            bool hadTransmog = false;

            // Check if this item has any transmog data before touching it
            if (item->GetModifier(ITEM_MODIFIER_TRANSMOG_APPEARANCE_ALL_SPECS) ||
                item->GetModifier(ITEM_MODIFIER_TRANSMOG_APPEARANCE_SPEC_1) ||
                item->GetModifier(ITEM_MODIFIER_TRANSMOG_APPEARANCE_SPEC_2) ||
                item->GetModifier(ITEM_MODIFIER_TRANSMOG_APPEARANCE_SPEC_3) ||
                item->GetModifier(ITEM_MODIFIER_TRANSMOG_APPEARANCE_SPEC_4) ||
                item->GetModifier(ITEM_MODIFIER_TRANSMOG_APPEARANCE_SPEC_5) ||
                item->GetModifier(ITEM_MODIFIER_TRANSMOG_SECONDARY_APPEARANCE_ALL_SPECS) ||
                item->GetModifier(ITEM_MODIFIER_TRANSMOG_SECONDARY_APPEARANCE_SPEC_1) ||
                item->GetModifier(ITEM_MODIFIER_TRANSMOG_SECONDARY_APPEARANCE_SPEC_2) ||
                item->GetModifier(ITEM_MODIFIER_TRANSMOG_SECONDARY_APPEARANCE_SPEC_3) ||
                item->GetModifier(ITEM_MODIFIER_TRANSMOG_SECONDARY_APPEARANCE_SPEC_4) ||
                item->GetModifier(ITEM_MODIFIER_TRANSMOG_SECONDARY_APPEARANCE_SPEC_5) ||
                item->GetModifier(ITEM_MODIFIER_ENCHANT_ILLUSION_ALL_SPECS) ||
                item->GetModifier(ITEM_MODIFIER_ENCHANT_ILLUSION_SPEC_1) ||
                item->GetModifier(ITEM_MODIFIER_ENCHANT_ILLUSION_SPEC_2) ||
                item->GetModifier(ITEM_MODIFIER_ENCHANT_ILLUSION_SPEC_3) ||
                item->GetModifier(ITEM_MODIFIER_ENCHANT_ILLUSION_SPEC_4) ||
                item->GetModifier(ITEM_MODIFIER_ENCHANT_ILLUSION_SPEC_5))
            {
                hadTransmog = true;
            }

            if (!hadTransmog)
                continue;

            // Clear primary appearance
            item->SetModifier(ITEM_MODIFIER_TRANSMOG_APPEARANCE_ALL_SPECS, 0);
            item->SetModifier(ITEM_MODIFIER_TRANSMOG_APPEARANCE_SPEC_1, 0);
            item->SetModifier(ITEM_MODIFIER_TRANSMOG_APPEARANCE_SPEC_2, 0);
            item->SetModifier(ITEM_MODIFIER_TRANSMOG_APPEARANCE_SPEC_3, 0);
            item->SetModifier(ITEM_MODIFIER_TRANSMOG_APPEARANCE_SPEC_4, 0);
            item->SetModifier(ITEM_MODIFIER_TRANSMOG_APPEARANCE_SPEC_5, 0);

            // Clear secondary shoulder appearance
            item->SetModifier(ITEM_MODIFIER_TRANSMOG_SECONDARY_APPEARANCE_ALL_SPECS, 0);
            item->SetModifier(ITEM_MODIFIER_TRANSMOG_SECONDARY_APPEARANCE_SPEC_1, 0);
            item->SetModifier(ITEM_MODIFIER_TRANSMOG_SECONDARY_APPEARANCE_SPEC_2, 0);
            item->SetModifier(ITEM_MODIFIER_TRANSMOG_SECONDARY_APPEARANCE_SPEC_3, 0);
            item->SetModifier(ITEM_MODIFIER_TRANSMOG_SECONDARY_APPEARANCE_SPEC_4, 0);
            item->SetModifier(ITEM_MODIFIER_TRANSMOG_SECONDARY_APPEARANCE_SPEC_5, 0);

            // Clear enchant illusions
            item->SetModifier(ITEM_MODIFIER_ENCHANT_ILLUSION_ALL_SPECS, 0);
            item->SetModifier(ITEM_MODIFIER_ENCHANT_ILLUSION_SPEC_1, 0);
            item->SetModifier(ITEM_MODIFIER_ENCHANT_ILLUSION_SPEC_2, 0);
            item->SetModifier(ITEM_MODIFIER_ENCHANT_ILLUSION_SPEC_3, 0);
            item->SetModifier(ITEM_MODIFIER_ENCHANT_ILLUSION_SPEC_4, 0);
            item->SetModifier(ITEM_MODIFIER_ENCHANT_ILLUSION_SPEC_5, 0);

            item->SetState(ITEM_CHANGED, player);
            player->SetVisibleItemSlot(slot, item);

            TC_LOG_DEBUG("spells.effect", "spell_clear_current_transmogrifications [{}]: cleared slot {}",
                player->GetGUID().ToString(), slot);
        }

        // Sync cleared state to the active transmog outfit so ViewedOutfit
        // doesn't show stale appearances on the paperdoll after casting.
        uint32 activeOutfitID = player->GetActiveTransmogOutfitID();
        if (activeOutfitID)
        {
            if (EquipmentSetInfo::EquipmentSetData* outfit = player->GetMutableTransmogOutfitBySetID(activeOutfitID))
            {
                for (uint8 s = EQUIPMENT_SLOT_START; s < EQUIPMENT_SLOT_END; ++s)
                    outfit->Appearances[s] = 0;
                outfit->SecondaryShoulderApparanceID = 0;
                for (auto& enchant : outfit->Enchants)
                    enchant = 0;
                outfit->IgnoreMask = 0x7FFFF; // All slots ignored — no appearances defined

                player->SetEquipmentSet(*outfit);

                TC_LOG_DEBUG("spells.effect",
                    "spell_clear_current_transmogrifications [{}]: synced cleared state to active outfit {} + rebuilt ViewedOutfit",
                    player->GetGUID().ToString(), activeOutfitID);
            }

            // Clear the active outfit ID — all transmog is gone, no outfit is "active" anymore
            player->SetActiveTransmogOutfitID(0);
        }
    }

    void Register() override
    {
        OnEffectHitTarget += SpellEffectFn(spell_clear_current_transmogrifications::HandleScriptEffect,
            EFFECT_0, SPELL_EFFECT_SCRIPT_EFFECT);
    }
};

void AddSC_clear_transmog_scripts()
{
    RegisterSpellScript(spell_clear_current_transmogrifications);
}
