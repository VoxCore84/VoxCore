USE `auth`;

START TRANSACTION;

INSERT INTO `battlenet_account_warband_scenes`
(`battlenetAccountId`, `warbandSceneId`, `isFavorite`, `hasFanfare`)
VALUES
  (1, 1,   0, 0),
  (1, 4,   0, 0),
  (1, 5,   0, 0),
  (1, 7,   0, 0),
  (1, 25,  0, 0),
  (1, 29,  0, 0),
  (1, 119, 0, 0),
  (1, 145, 0, 0),
  (1, 146, 0, 0)
AS new
ON DUPLICATE KEY UPDATE
  `isFavorite` = new.`isFavorite`,
  `hasFanfare` = new.`hasFanfare`;

COMMIT;
