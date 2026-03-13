-- VoxSniffer RingBuffer
-- Fixed-size FIFO queue with overflow eviction
-- Each module gets its own ring buffer to cap memory usage

local _, NS = ...
NS.RingBuffer = {}

local RingBuffer = {}
RingBuffer.__index = RingBuffer

function NS.RingBuffer.New(capacity)
    local self = setmetatable({}, RingBuffer)
    self.capacity = capacity or NS.Constants.RING_BUFFER_CAP
    self.buffer = {}
    self.head = 1       -- next write position
    self.count = 0      -- current item count
    self.totalAdded = 0 -- lifetime counter (for stats)
    self.totalEvicted = 0
    return self
end

function RingBuffer:Push(item)
    if item == nil then return end  -- session gate: MakeEnvelope returns nil when inactive
    if self.count >= self.capacity then
        -- Overwrite oldest entry
        self.totalEvicted = self.totalEvicted + 1
    else
        self.count = self.count + 1
    end

    self.buffer[self.head] = item
    self.head = (self.head % self.capacity) + 1
    self.totalAdded = self.totalAdded + 1
end

-- Drain all items from the buffer, returning them as an array
-- Resets the buffer after drain
function RingBuffer:Drain()
    if self.count == 0 then return {} end

    local items = {}
    local readPos
    if self.count < self.capacity then
        readPos = 1
    else
        readPos = self.head  -- oldest item is at current head (about to be overwritten)
    end

    for i = 1, self.count do
        items[i] = self.buffer[readPos]
        self.buffer[readPos] = nil
        readPos = (readPos % self.capacity) + 1
    end

    self.head = 1
    self.count = 0
    return items
end

-- Peek at count without draining
function RingBuffer:Count()
    return self.count
end

function RingBuffer:IsFull()
    return self.count >= self.capacity
end

function RingBuffer:GetStats()
    return {
        count = self.count,
        capacity = self.capacity,
        totalAdded = self.totalAdded,
        totalEvicted = self.totalEvicted,
    }
end

function RingBuffer:Clear()
    wipe(self.buffer)
    self.head = 1
    self.count = 0
end
