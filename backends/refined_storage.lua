-- http://lua-users.org/wiki/CurriedLua

local function flatten(t)
    local ret = {}
    for _, v in ipairs(t) do
        if type(v) == 'table' then
            for _, fv in ipairs(flatten(v)) do
                ret[#ret + 1] = fv
            end
        else
            ret[#ret + 1] = v
        end
    end
    return ret
end

local function curry(func, num_args)
    num_args = num_args or debug.getinfo(func, "u").nparams
    if num_args < 2 then return func end
    local function helper(argtrace, n)
        if n < 1 then
            return func(table.unpack(flatten(argtrace)))
        else
            return function(...)
                return helper({ argtrace, ... }, n - select("#", ...))
            end
        end
    end

    return helper({}, num_args)
end

local function createBackendItemFromRs(requestItem, rsItem)
    local name = rsItem.name
    local requestedAmount = requestItem.count
    local currentAmount = rsItem.amount
    local _, _, displayName = rsItem.displayName:find("%[(.+)%]")

    return {
        name = name,
        displayName = displayName,
        requestedAmount = requestedAmount,
        currentAmount = currentAmount
    }
end

local function readRs(rs, itemRequests)
    local errors = nil
    local items = {}

    local requestsLookup = table.set(itemRequests, function(v) return v.name end)
    local craftablesLookup = table.set(rs.listCraftableItems(), function(v) return v.name end)

    for _, rsItem in ipairs(rs.listItems()) do
        local requestMatch = requestsLookup[rsItem.name]

        if requestMatch ~= nil then
            local craftableMatch = craftablesLookup[rsItem.name]

            if craftableMatch == nil then
                errors = errors or {}
                table.insert(errors, rsItem.name .. " is not craftable")
            elseif craftableMatch.amount ~= rsItem.amount then
                local item = createBackendItemFromRs(requestMatch, rsItem)
                table.insert(items, item)
            end
        end
    end

    if #itemRequests ~= #items then
        for name, itemRequest in pairs(requestsLookup) do
            local _, item = table.find(items, function(_, v) return v.name == name end)
            if item == nil then
                local craftableMatch = craftablesLookup[name]
                if item == nil and craftableMatch then
                    local newItem = createBackendItemFromRs(itemRequest, craftableMatch)
                    table.insert(items, newItem)
                    newItem.currentAmount = 0
                    print("INFO -", newItem.displayName, ":", newItem.currentAmount)
                else
                    errors = errors or {}
                    table.insert(errors, name .. " does not have a match")
                end
            end
        end
    end

    return items, errors
end

local function craftRsItem(rs, item, count)
    return rs.craftItem({ name = item.name, count = count })
end

local function isCraftingRs(rs, item)
    return rs.isItemCrafting(item.name)
end

local function initializeRs()
    local rs = peripheral.find("rsBridge")

    if rs == nil then
        error("rsBridge not found")
    end

    local interface = {}
    interface.craft = curry(craftRsItem)(rs)
    interface.isCrafting = curry(isCraftingRs)(rs)
    interface.read = curry(readRs)(rs)

    return interface
end

return initializeRs
