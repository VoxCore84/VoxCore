# Server Config & Performance

## Performance Tuning (Feb 2026)
- **Startup: 3m24s → 1m0s (Debug) → 17s (RelWithDebInfo)** — 92% total reduction
- **Key fixes**: (1) MySQL `tmp_table_size` was 1024 BYTES causing all temp tables to spill to disk — fixed to 256M. (2) Config tuning (disabled locales, hotswap, AH bot, reduced visibility notify). (3) RelWithDebInfo `/O2 /Ob1` vs Debug `/Od /Ob0` — biggest single improvement for CPU-bound query cache init

## MySQL Config
- **MySQL `my.ini`** at `out/build/x64-RelWithDebInfo/bin/RelWithDebInfo/UniServerZ/core/mysql/my.ini`
- MySQL **9.5.0** (UniServerZ bundled `mysqld_z.exe`) — client at `C:/Program Files/MySQL/MySQL Server 8.0/bin/mysql.exe` — credentials: root/admin
- **MySQL scheduled event `Panda_Joining_FIX`** was dropped — it spammed errors trying to TRUNCATE a table with FK constraints

## MySQL Optimization (Mar 3-4, 2026)
- `key_buffer_size` → **8M** (no MyISAM tables remain)
- `skip-name-resolve` enabled — required adding root@127.0.0.1 and root@::1 grants first
- All 7 MyISAM tables converted to InnoDB (2 needed ROW_FORMAT=DYNAMIC for FIXED compat)
- 4 redundant/duplicate indexes dropped
- 7 loot tables given PRIMARY KEYs after deduplicating **193,542 duplicate rows**
- 101 backup tables dropped (~382 MB reclaimed, world 360→256 tables)
- Final DB sizes (Mar 4): world 1,265 MB, hotfixes 637 MB, characters 7.6 MB, auth 1.9 MB, roleplay 0.1 MB

## MySQL Optimize Script
- `_optimize_db.bat` — auto-detects fragmented tables (>4MB free space), runs OPTIMIZE TABLE
- Run after large imports or bulk deletes

## MySQL Buffer Pool & InnoDB Tuning (Mar 4, 2026)
- Buffer pool: 16G → **4G** (total data ~1.9 GB, 4G = 2x headroom + indexes)
- `innodb_buffer_pool_instances = 4`, `innodb_buffer_pool_dump_pct = 100`
- `innodb_buffer_pool_dump_at_shutdown = ON`, `innodb_buffer_pool_load_at_startup = ON` — warm restarts
- Per-connection buffers cut: sort/read_rnd/join all → **4M** (was 16M, overkill for 1-2 connections)
- `tmp_table_size` / `max_heap_table_size` → **64M** (was 256M)
- `innodb_redo_log_capacity` → **256M** (was 1G; redo dir will auto-shrink on restart)
- `innodb_max_undo_log_size = 256M`, `innodb_undo_log_truncate = ON` — reclaims bloated undo files
- `innodb_lru_scan_depth` → **256** (was 1024; less CPU scanning near-empty pool)
- Slow query log **OFF** (`slow-query-log=0`, `log_queries_not_using_indexes=0`) — was causing constant I/O logging 0.09ms table scans. Enable temporarily with `SET GLOBAL` when debugging

## UniServerZ Cleanup (Mar 4, 2026)
- Deleted `core/old/` (2.8 GB), `www/` (172 MB), `home/` (55 MB), `core/apache2/` (21 MB), `core/php83/` (83 MB), `docs/` (3.4 MB), slow log (29 MB)
- UniServerZ size: 9.0 GB → 5.9 GB (will shrink further to ~4.8 GB after redo/undo auto-truncation on restart)
- Apache/PHP not used — only MySQL from UniServerZ

## worldserver.conf
- Location: `out/build/x64-RelWithDebInfo/bin/RelWithDebInfo/worldserver.conf` (NOT in source tree)
- `ProcessPriority=0`, `BindIP=127.0.0.1`, `Load.Locales=0`, `HotSwap.Enabled=0`
- `SOAP.Enabled=1`, `Visibility.Notify.Period.*=1000`, `Visibility.Distance.Continents=100`
- `AuctionHouseBot.Seller.Enabled=0`
- `PacketLogFile = "PacketLog/World.pkt"` — requires server restart

## worldserver.conf Optimization (Mar 3, 2026)
- `Eluna.CompatibilityMode = false` — was `true`, which forced single-threaded map updates (nullified MapUpdate.Threads=4)
- `MaxCoreStuckTime = 600` — was 0 (disabled), freeze watchdog re-enabled
- `SocketTimeOutTimeActive = 300000` — was 900000 (15 min), now 5 min for dead connections
- **RBAC fix**: `.settime` had wrong permission (NPC_YELL). New: `RBAC_PERM_COMMAND_SETTIME = 1022`

## worldserver.conf Thread Tuning (Mar 3, 2026)
- `WorldDatabase.WorkerThreads` 4 → **8**, `WorldDatabase.SynchThreads` 4 → **8**
- `HotfixDatabase.WorkerThreads` 4 → **8**, `HotfixDatabase.SynchThreads` 4 → **8**
- `ThreadPool` 4 → **8**
- Login/Character/Roleplay DB threads unchanged (2/4/2)
- Rationale: 24 hardware threads available, World+Hotfix are the heaviest at startup

## bnetserver.conf
- `ProcessPriority=0`, `BindIP=127.0.0.1`, `LoginREST.TicketDuration=86400`, console appender at Info level

## Data Directories
- Config files are in `out/build/x64-Debug/bin/Debug/` — NOT in source tree, not version-controlled
- Data dirs (maps/vmaps/mmaps/dbc ~28.6GB) are real files in Debug build dir; RelWithDebInfo uses NTFS junctions to them

## Log File Locations (RelWithDebInfo)
- `out/build/x64-RelWithDebInfo/bin/RelWithDebInfo/Debug.log`
- `out/build/x64-RelWithDebInfo/bin/RelWithDebInfo/Server.log`
- `out/build/x64-RelWithDebInfo/bin/RelWithDebInfo/DBErrors.log`
- `out/build/x64-RelWithDebInfo/bin/RelWithDebInfo/GM.log`
- `out/build/x64-RelWithDebInfo/bin/RelWithDebInfo/Bnet.log`
