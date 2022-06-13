local functions = {
    empty = function(...) end,
    identity = function(...) return ... end
}

local table_ext = {
    find = function(_table, fn)
        for key, value in pairs(_table) do
            if fn(key, value) then
                return key, value
            end
        end

        return nil
    end,
    map = function(_table, fn)
        local ret = {}
        for key, value in pairs(_table) do
            ret[key] = fn(value)
        end
        return ret
    end,
    toKeys = function(_table)
        local ret = {}
        for key, _ in pairs(_table) do
            table.insert(ret, key)
        end
        return ret
    end,
    extend = function(_table, other)
        for _, value in ipairs(other) do
            table.insert(_table, value)
        end
    end,
    reduce = function(_table, fn, acc)
        for _, value in pairs(_table) do
            acc = fn(value, acc)
        end
        return acc
    end,
    set = function(_table, fn_set)
        fn_set = fn_set or functions.identity
        local ret = {}

        for _, value in pairs(_table) do
            ret[fn_set(value)] = value
        end

        return ret
    end
}

local string_ext = {
    split = function(str, sep)
        sep = sep or "%s"
        local pattern = "([^" .. sep .. "]+)"

        local ret = {}
        for val in string.gmatch(str, pattern) do
            table.insert(ret, val)
        end

        return ret
    end
}

table.find = table_ext.find
table.map = table_ext.map
table.toKeys = table_ext.toKeys
table.extend = table_ext.extend
table.reduce = table_ext.reduce
table.set = table_ext.set

string.split = string_ext.split

local module = {
    version = "0.0.5",
    fn = functions,
    initializeRs = function()
        local rs = peripheral.find("rsBridge")

        if rs == nil then
            error("rsBridge not found")
        end

        return rs
    end,
    initializeMonitor = function(textSize)
        local monitor = peripheral.find("monitor")

        if monitor == nil then
            error("No monitor connected")
        else
            monitor.setTextScale(textSize)
        end

        return monitor
    end,
    readItems = function(fileName)
        local file = fs.open(fileName, "r")
        local contents = file.readAll()
        file.close()

        local items = textutils.unserialize(contents)
        return items
    end,
}

return module
