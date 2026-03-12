-- BestiaryForge: RBAC permission for .bestiary GM command
INSERT IGNORE INTO `rbac_permissions` (`id`, `name`) VALUES (3012, 'Command: bestiary');
-- Link to GM role (role 193 = GM commands, consistent with maxrep/maxtitles/maxachieve)
INSERT IGNORE INTO `rbac_linked_permissions` (`id`, `linkedId`) VALUES (193, 3012);
