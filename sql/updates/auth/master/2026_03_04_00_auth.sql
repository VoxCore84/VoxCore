-- 2026_03_04_00_auth.sql
-- Apply TC official build 66220 auth keys (revert auth bypass)

-- build_info already exists from base SQL; ensure it's present
INSERT IGNORE INTO `build_info` (`build`, `majorVersion`, `minorVersion`, `bugfixVersion`, `hotfixVersion`) VALUES
(66220, 12, 0, 1, NULL);

-- Insert all 7 auth keys for build 66220
INSERT IGNORE INTO `build_auth_key` (`build`, `platform`, `arch`, `type`, `key`) VALUES
(66220, 'Mac', 'A64', 'WoW',  0x4385ED9D10459B4C60EDC870C9EEE17A),
(66220, 'Mac', 'A64', 'WoWC', 0xBB8F1891046195F34FF37D02230B3068),
(66220, 'Mac', 'x64', 'WoW',  0xE69739F70296531F9330F7E766C29D75),
(66220, 'Mac', 'x64', 'WoWC', 0xADE47B3180CAADE4C3E0517CF8184F07),
(66220, 'Win', 'A64', 'WoW',  0xF38707CC641DB628993957D7B2262895),
(66220, 'Win', 'x64', 'WoW',  0x88C34460E28D65B62FA6F1CACE8107E3),
(66220, 'Win', 'x64', 'WoWC', 0x9B3C1C2FB9E9F2401B0F5F2AD6CDA84E);
