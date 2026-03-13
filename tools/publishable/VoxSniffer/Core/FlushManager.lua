-- VoxSniffer FlushManager
-- Periodically flushes ring buffer contents into SavedVariables chunks
-- Triggers: timer, threshold, manual, logout, reload

local _, NS = ...
NS.FlushManager = {}
local FM = NS.FlushManager
local C = NS.Constants
local Log = NS.Log
local Schema = NS.Schema

local moduleBuffers = {}    -- [moduleName] = RingBuffer instance
local flushTimer = 0
local totalFlushed = 0

-- Register a module's ring buffer for flush management
function FM.RegisterBuffer(moduleName, ringBuffer)
    moduleBuffers[moduleName] = ringBuffer
end

function FM.UnregisterBuffer(moduleName)
    moduleBuffers[moduleName] = nil
end

-- Get total pending items across all buffers
function FM.GetPendingCount()
    local total = 0
    for _, buf in pairs(moduleBuffers) do
        total = total + buf:Count()
    end
    return total
end

-- Flush all module buffers into SavedVariables chunks
function FM.FlushAll(reason)
    local db = VoxSnifferDB
    if not db then return 0 end

    local sessionId = NS.SessionManager.GetId()
    local totalRecords = 0
    local chunksCreated = 0

    for moduleName, buf in pairs(moduleBuffers) do
        local items = buf:Drain()
        if #items > 0 then
            -- Split into chunk-sized pieces
            local cfg = NS.Config.Get()
            local chunkSize = cfg.chunkMaxRecords or C.CHUNK_MAX_RECORDS

            for i = 1, #items, chunkSize do
                local chunkId = Schema.NextChunkId(db)
                local records = {}
                local count = 0

                for j = i, math.min(i + chunkSize - 1, #items) do
                    count = count + 1
                    records[count] = items[j]
                end

                db.chunks[chunkId] = {
                    chunk_id = chunkId,
                    session_id = sessionId,
                    module = moduleName,
                    timestamp = time(),
                    count = count,
                    records = records,
                }

                chunksCreated = chunksCreated + 1
                totalRecords = totalRecords + count
            end
        end
    end

    if totalRecords > 0 then
        db.stats.total_observations = (db.stats.total_observations or 0) + totalRecords
        db.stats.total_chunks = (db.stats.total_chunks or 0) + chunksCreated
        db.stats.total_flushes = (db.stats.total_flushes or 0) + 1
        totalFlushed = totalFlushed + totalRecords

        NS.SessionManager.IncrementObservations(totalRecords)
        for _ = 1, chunksCreated do
            NS.SessionManager.IncrementChunks()
        end

        -- Prune oldest chunks if over limit
        FM.PruneChunks(db)

        Log.Debug("Flush", format("%s: flushed %d records in %d chunks", reason or "manual", totalRecords, chunksCreated))
    end

    return totalRecords
end

-- Prune oldest chunks when count exceeds MAX_CHUNKS
function FM.PruneChunks(db)
    if not db or not db.chunks then return end

    -- Count chunks
    local chunkIds = {}
    for id in pairs(db.chunks) do
        chunkIds[#chunkIds + 1] = id
    end

    local maxChunks = C.MAX_CHUNKS or 500
    if #chunkIds <= maxChunks then return end

    -- Sort ascending — lowest IDs are oldest
    table.sort(chunkIds)

    local toRemove = #chunkIds - maxChunks
    local removedRecords = 0
    for i = 1, toRemove do
        local chunk = db.chunks[chunkIds[i]]
        if chunk then
            removedRecords = removedRecords + (chunk.count or 0)
        end
        db.chunks[chunkIds[i]] = nil
    end

    db.stats.total_chunks = math.max(0, (db.stats.total_chunks or 0) - toRemove)
    Log.Info("Flush", format("Pruned %d old chunks (%d records) — %d chunks retained", toRemove, removedRecords, maxChunks))
end

-- Called every frame to check timer and threshold
function FM.OnUpdate(elapsed)
    if not NS.SessionManager.IsActive() then return end

    flushTimer = flushTimer + elapsed
    local cfg = NS.Config.Get()

    -- Time-based flush
    if flushTimer >= (cfg.flushInterval or C.FLUSH_INTERVAL) then
        flushTimer = 0
        local pending = FM.GetPendingCount()
        if pending > 0 then
            FM.FlushAll("timer")
        end
        return
    end

    -- Threshold-based flush
    local pending = FM.GetPendingCount()
    if pending >= (cfg.flushThreshold or C.FLUSH_THRESHOLD) then
        flushTimer = 0
        FM.FlushAll("threshold")
    end
end

function FM.GetStats()
    local bufferStats = {}
    for name, buf in pairs(moduleBuffers) do
        bufferStats[name] = buf:GetStats()
    end
    return {
        totalFlushed = totalFlushed,
        pendingCount = FM.GetPendingCount(),
        buffers = bufferStats,
    }
end

-- Drain all module buffers without writing anywhere (discard)
function FM.DrainAll()
    for _, buf in pairs(moduleBuffers) do
        buf:Drain()
    end
end

function FM.Reset()
    FM.DrainAll()
    flushTimer = 0
    totalFlushed = 0
end
