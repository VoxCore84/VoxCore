-- VoxSniffer Fingerprint
-- Deterministic hashing for observation deduplication
--
-- Uses djb2 hash to produce compact numeric fingerprints.
-- Python can reproduce: hash = 5381; for c in s: hash = ((hash << 5) + hash) + ord(c)

local _, NS = ...
NS.Fingerprint = {}
local FP = NS.Fingerprint

-- djb2 hash — fast, low-collision, deterministic
-- Returns a numeric hash as a hex string
local function djb2(str)
    local hash = 5381
    for i = 1, #str do
        hash = ((hash * 33) + str:byte(i)) % 0xFFFFFFFF
    end
    return format("%08x", hash)
end

-- Build a canonical string from sorted key=value pairs, then hash it
function FP.Compute(fields)
    if not fields or type(fields) ~= "table" then return "" end

    local parts = {}
    local keys = {}
    for k in pairs(fields) do
        keys[#keys + 1] = k
    end
    table.sort(keys)

    for _, k in ipairs(keys) do
        local v = fields[k]
        if v ~= nil then
            parts[#parts + 1] = k .. "=" .. tostring(v)
        end
    end

    return djb2(table.concat(parts, "|"))
end

-- Compute fingerprint for a unit observation
function FP.Unit(entityKey, name, level, classification, mapId)
    return FP.Compute({
        ek = entityKey or "",
        n = name or "",
        lv = level or 0,
        cl = classification or 0,
        m = mapId or 0,
    })
end

-- Compute fingerprint for a vendor line
function FP.VendorItem(npcId, itemId, price, extendedCostId)
    return FP.Compute({
        npc = npcId or 0,
        item = itemId or 0,
        price = price or 0,
        ec = extendedCostId or 0,
    })
end

-- Compute fingerprint for a gossip option
function FP.GossipOption(npcId, optionIndex, text, icon)
    return FP.Compute({
        npc = npcId or 0,
        idx = optionIndex or 0,
        txt = text or "",
        ico = icon or 0,
    })
end

-- Compute fingerprint for a combat event
function FP.CombatEvent(sourceKey, destKey, spellId, eventType, timestamp)
    return FP.Compute({
        src = sourceKey or "",
        dst = destKey or "",
        sp = spellId or 0,
        ev = eventType or "",
        ts = timestamp or 0,
    })
end

-- Compute fingerprint for a movement sample
function FP.Movement(entityKey, mapId, x, y, timestamp)
    return FP.Compute({
        ek = entityKey or "",
        m = mapId or 0,
        x = format("%.1f", x or 0),
        y = format("%.1f", y or 0),
        ts = timestamp or 0,
    })
end
