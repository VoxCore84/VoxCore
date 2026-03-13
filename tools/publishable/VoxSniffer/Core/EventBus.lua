-- VoxSniffer EventBus
-- Simple pub/sub for inter-module communication
-- Modules publish observations, others subscribe to process them

local _, NS = ...
NS.EventBus = {}
local EB = NS.EventBus

local subscribers = {}  -- [eventName] = { callback1, callback2, ... }
local stats = { published = 0, delivered = 0 }

-- Subscribe a callback to an event name
-- Returns a handle that can be used to unsubscribe
function EB.Subscribe(eventName, callback)
    if not subscribers[eventName] then
        subscribers[eventName] = {}
    end
    local subs = subscribers[eventName]
    subs[#subs + 1] = callback
    return { event = eventName, index = #subs }
end

-- Unsubscribe using the handle returned by Subscribe
function EB.Unsubscribe(handle)
    if not handle or not handle.event then return end
    local subs = subscribers[handle.event]
    if subs and handle.index and subs[handle.index] then
        subs[handle.index] = nil
    end
end

-- Publish an event to all subscribers
-- payload is passed directly to callbacks
function EB.Publish(eventName, payload)
    stats.published = stats.published + 1
    local subs = subscribers[eventName]
    if not subs then return end

    for _, callback in pairs(subs) do
        if callback then
            local ok, err = pcall(callback, payload)
            if ok then
                stats.delivered = stats.delivered + 1
            elseif NS.Log then
                NS.Log.Error("EventBus", format("Handler error for '%s': %s", eventName, tostring(err)))
            end
        end
    end
end

function EB.GetStats()
    return stats
end

function EB.Reset()
    wipe(subscribers)
    stats.published = 0
    stats.delivered = 0
end
