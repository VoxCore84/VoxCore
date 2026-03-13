-- VoxSniffer Scheduler
-- Manages OnUpdate tick callbacks with configurable cadences per module
-- Modules register a tick function and cadence; Scheduler calls them on time

local _, NS = ...
NS.Scheduler = {}
local Sched = NS.Scheduler

local callbacks = {}  -- [name] = { fn, interval, elapsed, enabled }
local frame = nil

-- Register a polling callback
-- name: unique identifier (usually module name)
-- fn: function to call on tick
-- interval: seconds between calls
function Sched.Register(name, fn, interval)
    callbacks[name] = {
        fn = fn,
        interval = interval or 1.0,
        elapsed = 0,
        enabled = true,
    }
end

function Sched.Unregister(name)
    callbacks[name] = nil
end

function Sched.SetEnabled(name, enabled)
    if callbacks[name] then
        callbacks[name].enabled = enabled
    end
end

function Sched.SetInterval(name, interval)
    if callbacks[name] then
        callbacks[name].interval = interval
    end
end

-- Called every frame from the main addon frame
function Sched.OnUpdate(elapsed)
    for name, cb in pairs(callbacks) do
        if cb.enabled then
            cb.elapsed = cb.elapsed + elapsed
            if cb.elapsed >= cb.interval then
                cb.elapsed = 0
                local ok, err = pcall(cb.fn)
                if not ok and NS.Log then
                    NS.Log.Error("Scheduler", format("Tick error in '%s': %s", name, tostring(err)))
                end
            end
        end
    end
end

function Sched.GetRegistered()
    local list = {}
    for name, cb in pairs(callbacks) do
        list[name] = {
            interval = cb.interval,
            enabled = cb.enabled,
        }
    end
    return list
end

function Sched.Reset()
    wipe(callbacks)
end
