-- VoxSniffer Config
-- Module enable/disable, tick rates, flush thresholds
-- Persisted in VoxSnifferDB.config, merged with defaults on load

local _, NS = ...
NS.Config = {}
local Cfg = NS.Config
local C = NS.Constants

-- Defaults — overridden by saved config
local DEFAULTS = {
    -- Module enables (all on by default)
    modules = {
        [C.MODULE.UNIT_SCANNER]     = true,
        [C.MODULE.AURA_SCANNER]     = true,
        [C.MODULE.COMBAT_CAPTURE]   = true,
        [C.MODULE.COMBAT_ENRICHER]  = true,
        [C.MODULE.GOSSIP_CAPTURE]   = true,
        [C.MODULE.VENDOR_CAPTURE]   = true,
        [C.MODULE.QUEST_CAPTURE]    = true,
        [C.MODULE.LOOT_CAPTURE]     = true,
        [C.MODULE.MOVEMENT_TRACKER] = false,  -- off by default (high volume)
        [C.MODULE.PHASE_TRACKER]    = true,
        [C.MODULE.EMOTE_CAPTURE]    = true,
        [C.MODULE.OBJECT_TRACKER]   = true,
        [C.MODULE.COVERAGE_HEATMAP] = true,
        [C.MODULE.DELTA_HINTS]      = false,  -- off by default (requires hotset)
    },

    -- Tick rates (seconds)
    tickRates = {
        [C.MODULE.UNIT_SCANNER]     = C.TICK_RATE.UNIT_SCAN,
        [C.MODULE.AURA_SCANNER]     = C.TICK_RATE.AURA_SCAN,
        [C.MODULE.MOVEMENT_TRACKER] = C.TICK_RATE.MOVEMENT_TRACK,
        [C.MODULE.COVERAGE_HEATMAP] = C.TICK_RATE.COVERAGE_UPDATE,
        [C.MODULE.DELTA_HINTS]      = C.TICK_RATE.DELTA_HINTS,
    },

    -- Storage
    flushInterval     = C.FLUSH_INTERVAL,
    flushThreshold    = C.FLUSH_THRESHOLD,
    ringBufferCap     = C.RING_BUFFER_CAP,
    chunkMaxRecords   = C.CHUNK_MAX_RECORDS,
    heatmapCellSize   = C.HEATMAP_CELL_SIZE,

    -- Behavior
    autoStartSession  = false,   -- start recording on login (off by default — use UI panel)
    debugMode         = false,
    verboseMode       = false,
}

local activeConfig = nil

-- Deep copy a table
local function DeepCopy(src)
    if type(src) ~= "table" then return src end
    local copy = {}
    for k, v in pairs(src) do
        copy[k] = DeepCopy(v)
    end
    return copy
end

-- Merge saved config over defaults (preserves new defaults for missing keys)
local function MergeConfig(saved, defaults)
    if type(saved) ~= "table" then return DeepCopy(defaults) end
    local merged = DeepCopy(defaults)
    for k, v in pairs(saved) do
        if type(v) == "table" and type(merged[k]) == "table" then
            merged[k] = MergeConfig(v, merged[k])
        else
            merged[k] = v
        end
    end
    return merged
end

function Cfg.Init(savedConfig)
    activeConfig = MergeConfig(savedConfig, DEFAULTS)
    -- Apply debug/verbose to logging
    if NS.Log then
        NS.Log.SetDebug(activeConfig.debugMode)
        NS.Log.SetVerbose(activeConfig.verboseMode)
    end
end

function Cfg.Get()
    return activeConfig or DeepCopy(DEFAULTS)
end

function Cfg.Save()
    if not activeConfig then return DEFAULTS end
    return activeConfig
end

function Cfg.IsModuleEnabled(moduleName)
    local cfg = Cfg.Get()
    return cfg.modules[moduleName] ~= false
end

function Cfg.SetModuleEnabled(moduleName, enabled)
    local cfg = Cfg.Get()
    cfg.modules[moduleName] = enabled
end

function Cfg.GetTickRate(moduleName)
    local cfg = Cfg.Get()
    return cfg.tickRates[moduleName] or 1.0
end

function Cfg.SetDebug(enabled)
    local cfg = Cfg.Get()
    cfg.debugMode = enabled
    if NS.Log then NS.Log.SetDebug(enabled) end
end

function Cfg.SetVerbose(enabled)
    local cfg = Cfg.Get()
    cfg.verboseMode = enabled
    if NS.Log then NS.Log.SetVerbose(enabled) end
end
