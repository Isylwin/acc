local label = "Willems Kantine Editor"
local version = "0.2.3"
local itemsFile = "items.wka"

local common = require("common")
local completion = require("cc.completion")

local function writeItems(fileName, items)
    local content = textutils.serialize(items)

    local file = fs.open(fileName, "w")
    file.write(content)
    file.close()
end

local function paginateLines(lines)
    local _, h = term.getSize()
    local toClear = math.min(#lines, h)
    local text = table.concat(lines, "\n")
    textutils.pagedPrint(text, toClear)
end

local addItemCommand = {
    help = "Adds or updates a new craftable item (e.g. 'add minecraft:glass 200')",
    name = "add",
    complete = function(editorData)
        local choices = table.map(editorData.rs.listCraftableItems(), function(x) return x.name end)
        return { [2] = choices }
    end,
    execute = function(editorData, name, count)
        local isCraftable = editorData.rs.isItemCraftable({ name = name })
        if not isCraftable then
            printError(name, "is not craftable!")
            return false
        end

        count = tonumber(count)
        if count == nil then
            printError(count, "is not a number")
            return false
        end

        local _, item = table.find(editorData.items, function(_, item) return item.name == name end)

        local action = nil
        if item ~= nil then
            item.count = count
            action = "Updated"
        else
            item = { name = name, count = count }
            table.insert(editorData.items, item)
            action = "Added"
        end

        print(("%s item: {name=%s,count=%d}"):format(action, item.name, item.count))
        return true
    end,
}

local deleteItemCommand = {
    help = "Removes an item from autocrafting (e.g. 'delete minecraft:glass')",
    name = "delete",
    complete = function(editorData)
        local choices = table.map(editorData.items, function(x) return x.name end)
        return { [2] = choices }
    end,
    execute = function(editorData, name)
        local index, item = table.find(editorData.items, function(_, item) return item.name == name end)
        if item == nil then
            printError(name, "is not a valid entry!")
            return false
        end

        table.remove(editorData.items, index)
        print(("Deleting item: {name=%s,count=%d}"):format(item.name, item.count))
        return true
    end,
}

local listCommand = {
    help = "Lists all items registered for autocrafting (e.g. 'list')",
    name = "list",
    complete = function(editorData)
        return {}
    end,
    execute = function(editorData)
        local format = "%-6s | %s"
        local lines = table.map(editorData.items, function(x) return format:format(tostring(x.count), x.name) end)
        table.insert(lines, 1, format:format("Count", "Name"))

        paginateLines(lines)
        return false
    end,
}

local helpCommand = {
    help = "Help (e.g. 'help')",
    name = "help",
    complete = function(editorData)
        return {}
    end,
    execute = function(editorData)
        for _, command in ipairs(editorData.commands) do
            local lines = {}
            if command.name ~= "help" then
                table.insert(lines, ("'%s': %s"):format(command.name, command.help))
            end
            paginateLines(lines)
        end
        return false
    end,
}

local function getCommand(commands, name)
    local _, ret = table.find(commands, function(_, x) return x.name == name end)
    return ret
end

local function registerCommands()
    return { addItemCommand, deleteItemCommand, listCommand, helpCommand }
end

local function completionHelper(editorData)
    local compiledChoices = {}

    compiledChoices[1] = { "exit" }

    for _, command in ipairs(editorData.commands) do
        local name = command.name
        table.insert(compiledChoices[1], name)

        local x = command.complete(editorData)
        for index, choices in pairs(x) do
            if index == 1 then
                error("Bad complete function for: " .. name)
            end
            local current = compiledChoices[index] or {}
            current[name] = choices
            compiledChoices[index] = current
        end
    end

    return function(partial)
        local args = string.split(partial)

        local lastCharIsSpace = partial:sub(-1) == " "
        local index = #args + (lastCharIsSpace and 1 or 0)
        local commandName = args[1]

        if #args <= 1 and not lastCharIsSpace then
            return completion.choice(partial, compiledChoices[1])
        elseif #args > 0 then
            local text = lastCharIsSpace and "" or args[index]

            local choicesIndex = compiledChoices[index] or {}
            local choices = choicesIndex[commandName] or {}
            return completion.choice(text, choices)
        end

        return {}
    end
end

local function main(args)
    print(label, version)
    print("type 'exit' to quit or 'help' for help")

    local editorData = {
        rs = common.initializeRs(),
        items = common.readItems(itemsFile),
        commands = registerCommands()
    }

    while true do
        write("> ")

        local userArgs = string.split(read(nil, nil, completionHelper(editorData)))
        local commandString = userArgs[1]

        local result = nil

        if commandString == nil then
        elseif commandString == "exit" then
            print("Exiting...")
            break
        else
            local command = getCommand(editorData.commands, commandString)
            if command == nil then
                printError(commandString, "is not a valid command")
            else
                result = command.execute(editorData, table.unpack(userArgs, 2, #userArgs))
            end
        end

        if result then
            print("Saving changes...")
            writeItems(itemsFile, editorData.items)
            print("Saved changes")
        end
    end

end

main({ ... })
