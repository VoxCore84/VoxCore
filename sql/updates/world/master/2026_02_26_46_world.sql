-- Set IgnoreFiltering=1 on all vendor items so every class/faction can see the full inventory
UPDATE `npc_vendor` SET `IgnoreFiltering` = 1 WHERE `IgnoreFiltering` = 0;
