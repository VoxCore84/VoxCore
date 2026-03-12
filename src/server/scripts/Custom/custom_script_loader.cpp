/*
 * This file is part of the TrinityCore Project. See AUTHORS file for Copyright information
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation; either version 2 of the License, or (at your
 * option) any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program. If not, see <http://www.gnu.org/licenses/>.
 */

// This is where scripts' loading functions should be declared:

void AddSC_dragonriding_spell_scripts();
//ROLEPLAY FUNC
void AddSC_free_share_scripts();
void AddSC_CustomDisplayHandler();
void AddSC_CustomDisplayCommands();
void AddSC_CustomEffectHandler();
void AddSC_CustomEffectCommands();
void AddSC_toy_spell_scripts();
void AddSC_CompanionAI();
void AddSC_CompanionCommands();
void AddSC_CompanionScripts();
void AddSC_PlayerMorphScripts();
void AddSC_wormhole_generators();
void AddSC_clear_transmog_scripts();
void AddSC_maxrep_command();
void AddSC_maxtitles_command();
void AddSC_maxachieve_command();
void AddSC_arcane_waygate();
void AddSC_npc_copy_command();
void AddSC_voxplacer_commands();
void AddSC_bestiary_forge_sniffer();
void AddSC_bestiary_commands();

// The name of this function should match:
// void Add${NameOfDirectory}Scripts()
void AddCustomScripts()
{
    AddSC_dragonriding_spell_scripts();
    AddSC_toy_spell_scripts();
    //ROLEPLAY FUNC
    AddSC_free_share_scripts();
    AddSC_CustomDisplayHandler();
    AddSC_CustomDisplayCommands();
    AddSC_CustomEffectHandler();
    AddSC_CustomEffectCommands();
    AddSC_CompanionAI();
    AddSC_CompanionCommands();
    AddSC_CompanionScripts();
    AddSC_PlayerMorphScripts();
    AddSC_wormhole_generators();
    AddSC_clear_transmog_scripts();
    AddSC_maxrep_command();
    AddSC_maxtitles_command();
    AddSC_maxachieve_command();
    AddSC_arcane_waygate();
    AddSC_npc_copy_command();
    AddSC_voxplacer_commands();
    AddSC_bestiary_forge_sniffer();
    AddSC_bestiary_commands();

}
