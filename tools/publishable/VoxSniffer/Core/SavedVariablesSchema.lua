-- VoxSniffer SavedVariablesSchema
-- Schema definition, validation, and migration for VoxSnifferDB
--
-- Top-level keys:
--   schema_version  - integer, for migration
--   build_info      - { interfaceVersion, clientBuild, locale }
--   config          - persisted user configuration
--   sessions        - { [session_id] = session_metadata }
--   chunks          - { [chunk_id] = { session_id, module, records[], checksum, count } }
--   indexes         - { next_chunk_id, next_session_id }
--   local_cache     - per-entity dedup caches (survives sessions)
--   heatmaps        - { [uiMapId] = { cells = {}, stats = {} } }
--   stats           - aggregate counters

local _, NS = ...
NS.Schema = {}
local Schema = NS.Schema
local C = NS.Constants
local Log = NS.Log

-- Create a fresh empty database
function Schema.CreateEmpty()
    return {
        schema_version = C.SCHEMA_VERSION,
        build_info = {
            interfaceVersion = select(4, GetBuildInfo()) or 0,
            clientBuild = select(2, GetBuildInfo()) or "0",
            locale = GetLocale() or "enUS",
        },
        config = {},
        sessions = {},
        chunks = {},
        indexes = {
            next_chunk_id = 1,
            next_session_id = 1,
        },
        local_cache = {
            seen_entities = {},   -- [entityKey] = last_seen_timestamp
            seen_vendors = {},    -- [npcId] = fingerprint of last vendor snapshot
            seen_gossip = {},     -- [npcId] = fingerprint of last gossip snapshot
        },
        heatmaps = {},
        stats = {
            total_observations = 0,
            total_chunks = 0,
            total_sessions = 0,
            total_flushes = 0,
        },
    }
end

-- Validate and optionally migrate a loaded database
-- Returns the validated/migrated DB
function Schema.Validate(db)
    if not db or type(db) ~= "table" then
        Log.Info("Schema", "No existing DB found, creating fresh.")
        return Schema.CreateEmpty()
    end

    local version = db.schema_version or 0

    if version < C.SCHEMA_VERSION then
        Log.Info("Schema", format("Migrating schema from v%d to v%d", version, C.SCHEMA_VERSION))
        db = Schema.Migrate(db, version)
    elseif version > C.SCHEMA_VERSION then
        Log.Warn("Schema", format("DB schema v%d is newer than addon v%d! Data may be lost.", version, C.SCHEMA_VERSION))
    end

    -- Ensure all top-level keys exist AND have correct types
    db.schema_version = C.SCHEMA_VERSION
    if type(db.build_info) ~= "table" then db.build_info = {} end
    if type(db.config) ~= "table" then db.config = {} end
    if type(db.sessions) ~= "table" then db.sessions = {} end
    if type(db.chunks) ~= "table" then db.chunks = {} end
    if type(db.indexes) ~= "table" then db.indexes = { next_chunk_id = 1, next_session_id = 1 } end
    -- Validate nested index fields are numbers
    if type(db.indexes.next_chunk_id) ~= "number" or db.indexes.next_chunk_id < 1 then
        db.indexes.next_chunk_id = 1
    end
    if type(db.indexes.next_session_id) ~= "number" or db.indexes.next_session_id < 1 then
        db.indexes.next_session_id = 1
    end
    if type(db.local_cache) ~= "table" then db.local_cache = {} end
    if type(db.local_cache.seen_entities) ~= "table" then db.local_cache.seen_entities = {} end
    if type(db.local_cache.seen_vendors) ~= "table" then db.local_cache.seen_vendors = {} end
    if type(db.local_cache.seen_gossip) ~= "table" then db.local_cache.seen_gossip = {} end
    if type(db.heatmaps) ~= "table" then db.heatmaps = {} end
    if type(db.stats) ~= "table" then db.stats = {} end
    -- Validate stat counters are numbers
    if type(db.stats.total_observations) ~= "number" then db.stats.total_observations = 0 end
    if type(db.stats.total_chunks) ~= "number" then db.stats.total_chunks = 0 end
    if type(db.stats.total_sessions) ~= "number" then db.stats.total_sessions = 0 end
    if type(db.stats.total_flushes) ~= "number" then db.stats.total_flushes = 0 end

    -- Update build info each session
    db.build_info.interfaceVersion = select(4, GetBuildInfo()) or db.build_info.interfaceVersion
    db.build_info.clientBuild = select(2, GetBuildInfo()) or db.build_info.clientBuild
    db.build_info.locale = GetLocale() or db.build_info.locale

    return db
end

-- Migration handler (extend as schema evolves)
function Schema.Migrate(db, fromVersion)
    -- v0 -> v1: initial schema, no migration needed (fresh DB)
    if fromVersion == 0 then
        return Schema.CreateEmpty()
    end

    -- Future: add migration steps here
    -- if fromVersion < 2 then ... end

    return db
end

-- Allocate the next chunk ID
function Schema.NextChunkId(db)
    local id = db.indexes.next_chunk_id
    db.indexes.next_chunk_id = id + 1
    return id
end

-- Allocate the next session ID
function Schema.NextSessionId(db)
    local id = db.indexes.next_session_id
    db.indexes.next_session_id = id + 1
    return id
end
