-- VoxSniffer CoverageHeatmap
-- Tracks player position on a per-map grid to build coverage maps
-- Shows which areas have been explored (for Python delta pipeline to find gaps)
-- Borrows position tracking pattern from SilverDragon's zone scanning

local _, NS = ...
local C = NS.Constants
local Log = NS.Log
local Sched = NS.Scheduler

local MODULE_NAME = C.MODULE.COVERAGE_HEATMAP
local heatmap = {}
NS.RegisterModule(MODULE_NAME, heatmap)

-- Grid cells are keyed by "mapId:gridX:gridY"
-- Value is visit count (incremented each tick while player is in that cell)
-- Stored in VoxSnifferDB.heatmaps for persistence across sessions

local CELL_SIZE = C.HEATMAP_CELL_SIZE  -- yards per cell (configurable via constants)
local currentMapId = nil
local lastCellKey = nil

-- ============================================================
-- Grid math
-- ============================================================

-- Convert map-normalized coords (0-1) to grid cell indices
-- Grid resolution derived from CELL_SIZE: ~50yd cells on a ~5000yd map = 100 divisions
local GRID_DIVISIONS = math.max(10, math.floor(5000 / CELL_SIZE))

local function GetCellCoords(mapX, mapY)
    local gridX = math.floor(mapX * GRID_DIVISIONS)
    local gridY = math.floor(mapY * GRID_DIVISIONS)
    return gridX, gridY
end

local function MakeCellKey(mapId, gridX, gridY)
    return format("%d:%d:%d", mapId, gridX, gridY)
end

-- ============================================================
-- Position sampling (called by Scheduler)
-- ============================================================

local function OnTick()
    if not NS.IsCaptureActive() then return end

    local mapId = C_Map.GetBestMapForUnit("player")
    if not mapId then return end

    local pos = C_Map.GetPlayerMapPosition(mapId, "player")
    if not pos then return end

    local gridX, gridY = GetCellCoords(pos.x, pos.y)
    local cellKey = MakeCellKey(mapId, gridX, gridY)

    -- Skip if we haven't moved to a new cell
    if cellKey == lastCellKey then return end
    lastCellKey = cellKey

    -- Update heatmap in SavedVariables
    if not VoxSnifferDB then return end
    if not VoxSnifferDB.heatmaps then VoxSnifferDB.heatmaps = {} end

    local mapKey = tostring(mapId)
    if not VoxSnifferDB.heatmaps[mapKey] then
        VoxSnifferDB.heatmaps[mapKey] = {
            mapId = mapId,
            cells = {},
            firstVisit = time(),
            lastVisit = time(),
        }
    end

    local mapData = VoxSnifferDB.heatmaps[mapKey]
    local coordKey = format("%d,%d", gridX, gridY)

    if not mapData.cells[coordKey] then
        mapData.cells[coordKey] = {
            visits = 1,
            firstSeen = time(),
            lastSeen = time(),
        }
        Log.Verbose(MODULE_NAME, format("New cell: map %d [%d,%d]", mapId, gridX, gridY))
    else
        local cell = mapData.cells[coordKey]
        cell.visits = cell.visits + 1
        cell.lastSeen = time()
    end

    mapData.lastVisit = time()

    -- Track map change
    if currentMapId ~= mapId then
        currentMapId = mapId
        Log.Debug(MODULE_NAME, format("Map changed to %d", mapId))
    end
end

-- ============================================================
-- Module interface
-- ============================================================

function heatmap.ResetState()
    currentMapId = nil
    lastCellKey = nil
end

function heatmap.Enable()
    currentMapId = C_Map.GetBestMapForUnit("player")
    Sched.Register(MODULE_NAME, OnTick, NS.Config.GetTickRate(MODULE_NAME))
    Log.Debug(MODULE_NAME, "Enabled — tracking player coverage grid")
end

function heatmap.Disable()
    Sched.Unregister(MODULE_NAME)
    Log.Info(MODULE_NAME, "Disabled")
end

function heatmap.GetStats()
    local stats = {
        totalMaps = 0,
        totalCells = 0,
    }

    if VoxSnifferDB and VoxSnifferDB.heatmaps then
        for _, mapData in pairs(VoxSnifferDB.heatmaps) do
            stats.totalMaps = stats.totalMaps + 1
            if mapData.cells then
                for _ in pairs(mapData.cells) do
                    stats.totalCells = stats.totalCells + 1
                end
            end
        end
    end

    return stats
end

-- Summary for /vs status
function heatmap.GetCoverageSummary()
    local summary = {}
    if not VoxSnifferDB or not VoxSnifferDB.heatmaps then return summary end

    for mapKey, mapData in pairs(VoxSnifferDB.heatmaps) do
        local cellCount = 0
        if mapData.cells then
            for _ in pairs(mapData.cells) do cellCount = cellCount + 1 end
        end
        summary[#summary + 1] = {
            mapId = mapData.mapId or tonumber(mapKey),
            cells = cellCount,
            lastVisit = mapData.lastVisit,
        }
    end

    table.sort(summary, function(a, b) return (a.cells or 0) > (b.cells or 0) end)
    return summary
end
