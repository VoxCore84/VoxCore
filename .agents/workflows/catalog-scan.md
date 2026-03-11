# Enterprise Catalog Scan

Scan VoxCore repository for inventory and classification.

## Steps
1. Count total files by extension category:
   - C++ source: `*.cpp`, `*.h`
   - SQL: `*.sql`
   - Python: `*.py`
   - Lua: `*.lua`
   - Config: `*.json`, `*.yaml`, `*.toml`, `*.conf`, `*.dist`
   - Data: `*.csv`, `*.db`, `*.sqlite`
   - Documentation: `*.md`
2. Classify by directory:
   - `src/server/game/` — core game logic
   - `src/server/scripts/Custom/` — custom scripts
   - `sql/updates/` — database updates
   - `tools/` — Python tooling
   - `wago/` — data pipeline
   - `AI_Studio/` — AI coordination
3. Identify orphaned files (not referenced by CMake, not imported, etc.)
4. Check for files larger than 1MB that might need attention
5. Update `catalog/` with results

## Output
Summary table with file counts, sizes, and any anomalies found.
