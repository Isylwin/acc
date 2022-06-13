local label = "Isylwins Automated Craft & Control"
local version = "1.9.0"
local itemsFile = "items.wka"
local textSize = 0.5
local updateInterval = 1

local runOnce = false
local enableRender = true
local enableUpdate = true

local common = require("common")
local profiling = require("profiling")
local backendInitFn = require("backends.refined_storage")

local readItemRequests = common.readItems

local function fuzzy(percentage)
    return function(requested, current)
        local difference = requested - current
        local threshold = math.ceil(requested * percentage)
        local insufficient = difference >= threshold

        return insufficient, difference + threshold
    end
end

local function exact(requested, current)
    local difference = requested - current
    local insufficient = difference > 0
    return insufficient, difference
end

local fuzzy_10 = fuzzy(0.1)

local function update(backend, backendItems)
    for _, item in ipairs(backendItems) do
        local algo = item.requestedAmount >= 1000 and fuzzy_10 or exact
        local shouldCraft, craftAmount = algo(item.requestedAmount, item.currentAmount)

        if shouldCraft and not backend.isCrafting(item) then
            backend.craft(item, craftAmount)
            print("Crafting:", craftAmount, ":", item.displayName)
        end
    end
end

local function redirect(view, fn)
    return function(...)
        local old = term.redirect(view)
        local ret = fn(...)
        term.redirect(old)
        return ret
    end
end

local function renderItemData(data)
    local maxWidth = table.reduce(data, function(val, acc) return math.max(#val.displayName, acc) end, 0)

    local rowFormat = "%-" .. maxWidth .. "s | %s"
    local statusFormat = "%d/%d"

    print("Items:")
    print(rowFormat:format("Name", "Status"))

    table.sort(data, function(a, b) return a.name < b.name end)

    for _, item in ipairs(data) do
        local difference = item.requestedAmount - item.currentAmount
        local colour = difference > 0 and colours.red or colours.green
        term.setTextColour(colour)

        local statusString = statusFormat:format(item.currentAmount, item.requestedAmount)
        local rowString = rowFormat:format(item.displayName, statusString)
        print(rowString)
    end

end

local function render(monitor, itemData)
    local currentTime = textutils.formatTime(os.time())

    monitor.clear()
    monitor.setCursorPos(1, 1)
    monitor.setTextColour(colours.white)
    monitor.setBackgroundColour(colours.black)

    redirect(monitor, print)(label, version, currentTime)

    local x, y = monitor.getCursorPos()
    local width, height = monitor.getSize()
    y = x == 1 and y or y + 1
    x = 1
    height = height - y

    local listView = window.create(monitor, x, y, width / 2, height)
    local profilingView = window.create(monitor, width / 2, y, width / 2, height)

    redirect(listView, renderItemData)(itemData)
    redirect(profilingView, profiling.print)(profiling)
end

local function loop(backend, monitor)
    local itemRequests = readItemRequests(itemsFile)
    local backendItems = backend.read(itemRequests)

    update(backend, backendItems)
    render(monitor, backendItems)
end

local function waitAtleast(s, fn)
    local profiledSleep = profiling:wrap(sleep, "loop:idle")

    return function(...)
        ---@diagnostic disable-next-line: undefined-field
        local before = os.epoch("local")
        local ret = fn(...)
        ---@diagnostic disable-next-line: undefined-field
        local after = os.epoch("local")

        local sFn = (after - before) / 1000
        local sRemain = s - sFn

        if sRemain > 0 then
            profiledSleep(sRemain)
        end

        return ret
    end
end

local function main(args)
    print("Starting program:", label, version)

    local backend = backendInitFn()
    local monitor = common.initializeMonitor(textSize)

    print("Finished initialization, running main loop")

    readItemRequests = profiling:wrap(readItemRequests, "loop:readRequests")
    backend.read = profiling:wrap(backend.read, "loop:readBackend")
    update = enableUpdate and profiling:wrap(update, "loop:update") or common.fn.empty
    render = enableRender and profiling:wrap(render, "loop:render") or common.fn.empty
    loop = profiling:wrap(waitAtleast(updateInterval, loop), "loop")

    repeat
        profiling:reset()
        loop(backend, monitor)
    until runOnce
end

main({ ... })
