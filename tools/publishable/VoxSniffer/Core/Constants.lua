-- VoxSniffer Constants
-- Shared constants used across all modules

local _, NS = ...
NS.Constants = {}
local C = NS.Constants

C.VERSION = "1.0.0"
C.SCHEMA_VERSION = 1
C.ADDON_NAME = "VoxSniffer"
C.ADDON_PREFIX = "VSNF"
C.COLOR = "|cff00ccff"
C.CLOSE = "|r"

-- Module names (canonical identifiers)
C.MODULE = {
    UNIT_SCANNER      = "UnitScanner",
    AURA_SCANNER      = "AuraScanner",
    COMBAT_CAPTURE    = "CombatCapture",
    COMBAT_ENRICHER   = "CombatEnricher",
    GOSSIP_CAPTURE    = "GossipCapture",
    VENDOR_CAPTURE    = "VendorCapture",
    QUEST_CAPTURE     = "QuestCapture",
    LOOT_CAPTURE      = "LootCapture",
    MOVEMENT_TRACKER  = "MovementTracker",
    PHASE_TRACKER     = "PhaseTracker",
    EMOTE_CAPTURE     = "EmoteCapture",
    OBJECT_TRACKER    = "ObjectTracker",
    COVERAGE_HEATMAP  = "CoverageHeatmap",
    DELTA_HINTS       = "DeltaHints",
}

-- Default tick rates (seconds)
C.TICK_RATE = {
    UNIT_SCAN       = 0.5,
    AURA_SCAN       = 1.0,
    MOVEMENT_TRACK  = 1.0,
    COVERAGE_UPDATE = 0.5,
    DELTA_HINTS     = 2.0,
}

-- Storage thresholds
C.FLUSH_INTERVAL     = 30       -- seconds between automatic flushes
C.FLUSH_THRESHOLD    = 5000     -- envelope count trigger
C.RING_BUFFER_CAP    = 2000     -- per-module in-memory cap (14 modules × 2K = 28K max)
C.CHUNK_MAX_RECORDS  = 2000     -- records per SavedVariables chunk

-- Coverage heatmap
C.HEATMAP_CELL_SIZE  = 50       -- yards per grid cell

-- Entity type constants from GUID parsing
C.GUID_TYPE = {
    PLAYER   = "Player",
    CREATURE = "Creature",
    PET      = "Pet",
    VEHICLE  = "Vehicle",
    GAMEOBJECT = "GameObject",
}

-- Observation types
C.OBS_TYPE = {
    UNIT_SEEN       = "unit_seen",
    AURA_SEEN       = "aura_seen",
    COMBAT_EVENT    = "combat_event",
    COMBAT_CONTEXT  = "combat_context",
    GOSSIP_SNAPSHOT = "gossip_snapshot",
    VENDOR_SNAPSHOT = "vendor_snapshot",
    QUEST_SNAPSHOT  = "quest_snapshot",
    LOOT_EVENT      = "loot_event",
    MOVEMENT_SAMPLE = "movement_sample",
    PHASE_EVIDENCE  = "phase_evidence",
    EMOTE_TEXT      = "emote_text",
    OBJECT_SEEN     = "object_seen",
    COVERAGE_CELL   = "coverage_cell",
    DELTA_HINT      = "delta_hint",
}

-- Chunk retention
C.MAX_CHUNKS         = 500      -- prune oldest chunks beyond this limit
