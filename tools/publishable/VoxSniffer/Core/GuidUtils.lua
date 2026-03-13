-- VoxSniffer GuidUtils
-- Parse WoW GUIDs into typed components for entity identification
--
-- GUID format examples:
--   Creature-0-5250-2552-9217-228713-00006A2B3F
--   Player-5250-04CC2FAB
--   GameObject-0-5250-2552-9217-505837-00006A9E12
--   Pet-0-5250-2552-9217-165189-01006A2B41
--   Vehicle-0-5250-2552-9217-228713-00006A2B3F
--
-- Fields: Type-0-ServerID-InstanceID-ZoneUID-ID-SpawnUID

local _, NS = ...
NS.GuidUtils = {}
local GU = NS.GuidUtils
local C = NS.Constants

-- Taint protection
local function IsSecret(val)
    if issecretvalue and issecretvalue(val) then return true end
    if type(val) == "userdata" then return true end
    return false
end

-- Parse a GUID string into a structured table
-- Returns nil if GUID is invalid or tainted
function GU.Parse(guid)
    if not guid or IsSecret(guid) then return nil end

    local parts = { strsplit("-", guid) }
    local unitType = parts[1]
    if not unitType then return nil end

    if unitType == C.GUID_TYPE.PLAYER then
        return {
            type = unitType,
            serverId = tonumber(parts[2]),
            playerId = parts[3],
        }
    end

    if unitType == C.GUID_TYPE.CREATURE
    or unitType == C.GUID_TYPE.PET
    or unitType == C.GUID_TYPE.VEHICLE
    or unitType == C.GUID_TYPE.GAMEOBJECT then
        return {
            type = unitType,
            serverId = tonumber(parts[3]),
            instanceId = tonumber(parts[4]),
            zoneUID = tonumber(parts[5]),
            id = tonumber(parts[6]),       -- NPC ID or GameObject entry
            spawnUID = parts[7],
        }
    end

    return { type = unitType, raw = guid }
end

-- Extract NPC entry ID from a GUID (most common operation)
-- Returns nil for players, unknown types, or tainted values
function GU.GetNpcId(guid)
    if not guid or IsSecret(guid) then return nil end
    local unitType, _, _, _, _, npcID = strsplit("-", guid)
    if unitType == C.GUID_TYPE.CREATURE or unitType == C.GUID_TYPE.VEHICLE then
        return tonumber(npcID)
    end
    return nil
end

-- Extract GameObject entry from a GUID
function GU.GetGameObjectEntry(guid)
    if not guid or IsSecret(guid) then return nil end
    local unitType, _, _, _, _, entryID = strsplit("-", guid)
    if unitType == C.GUID_TYPE.GAMEOBJECT then
        return tonumber(entryID)
    end
    return nil
end

-- Check if GUID represents an NPC (creature or vehicle)
function GU.IsNpc(guid)
    if not guid or IsSecret(guid) then return false end
    local unitType = strsplit("-", guid)
    return unitType == C.GUID_TYPE.CREATURE or unitType == C.GUID_TYPE.VEHICLE
end

-- Check if GUID represents a player
function GU.IsPlayer(guid)
    if not guid or IsSecret(guid) then return false end
    local unitType = strsplit("-", guid)
    return unitType == C.GUID_TYPE.PLAYER
end

-- Check if GUID represents a game object
function GU.IsGameObject(guid)
    if not guid or IsSecret(guid) then return false end
    local unitType = strsplit("-", guid)
    return unitType == C.GUID_TYPE.GAMEOBJECT
end

-- Build a stable entity key for deduplication
-- Format: "C:12345" for creatures, "GO:54321" for objects, "P:04CC2FAB" for players
function GU.EntityKey(guid)
    local parsed = GU.Parse(guid)
    if not parsed then return nil end

    if parsed.type == C.GUID_TYPE.CREATURE or parsed.type == C.GUID_TYPE.VEHICLE then
        return "C:" .. (parsed.id or 0)
    elseif parsed.type == C.GUID_TYPE.GAMEOBJECT then
        return "GO:" .. (parsed.id or 0)
    elseif parsed.type == C.GUID_TYPE.PET then
        return "PET:" .. (parsed.id or 0)
    elseif parsed.type == C.GUID_TYPE.PLAYER then
        return "P:" .. (parsed.playerId or "0")
    end

    return nil
end

-- Safe value extraction helpers (shared with modules)
-- These DETAINT secret values instead of discarding them.
-- UnitHealth/UnitHealthMax/UnitPower etc. return tainted numbers in 12.x
-- that error on comparison or arithmetic. tostring() strips the taint.
function GU.SafeNumber(val)
    if val == nil then return nil end
    local ok, result = pcall(function()
        return tonumber(tostring(val))
    end)
    if ok then return result end
    return nil
end

function GU.SafeString(val)
    if val == nil then return nil end
    local ok, result = pcall(function()
        return tostring(val)
    end)
    if ok then return result end
    return nil
end
