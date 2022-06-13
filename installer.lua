local expect = require("cc.expect")
local expect, field, range = expect.expect, expect.field, expect.range


local InstallWebRaw = {
    _buffer_size = 8192,
    type_match = nil,
    types = {"web_raw"},
    parse = function(self, entry)
        expect(1, entry, "table")
        field(entry, "dest", "string")
        field(entry, "origin", "string")

        self.dest = entry.dest
        self.origin = entry.origin
    end,
    execute = function (self)
        local dest = self.dest
        local origin = self.origin
        local buffer_size = self._buffer_size

        local response = http.get(origin)
        local code = response.getResponseCode()

        local validateOrigin = code >= 200 and code < 300

        local destHandle = io.open(dest, "w")
        local validateDest = destHandle ~= nil

        if validateDest and validateOrigin then
            while true do
                local chunk = response.read(buffer_size)
                if(chunk == nil) then break end
                destHandle:write(chunk)
            end
        end

        destHandle:close()
        response:close()
    end
}

local function createInstallLookup(installRecipes)
    local lookupTable = {}
    for _, recipe in pairs(installRecipes) do
        field(recipe, "types", "table")
        field(recipe, "parse", "function")
        field(recipe, "execute", "function")

        for _, typeName in ipairs(recipe.types) do
            lookupTable[typeName:upper()] = recipe
        end
    end
    return lookupTable
end

local InstallRecipes = createInstallLookup({InstallWebRaw})

-- local InstallData = {
--     files = {}
-- }

local function new(meta, o)
    o = o or {}
    setmetatable(o, meta)
    meta.__index = meta
    return o
end

local function readJsonFile(fileName)
    local file = fs.open(fileName, "r")
    local contents = file.readAll()
    file.close()

    return textutils.unserializeJSON(contents)
end

local function parseEntry(entry)
    field(entry, "type", "string")
    local typeString = entry.type:upper()
    local value = new(InstallRecipes[typeString])
    value.type_match = typeString
    value:parse(entry)
    return value
end

local function parseInstallData(installer)
    expect(1, installer, "table")
    field(installer, "version", "string")
    field(installer, "files", "table")

    for index, value in ipairs(installer.files) do
        installer.files[index] = parseEntry(value)
    end

    return installer
end

local function parseInstallerFile(fileName)
    local jsonObj = readJsonFile(fileName)
    return parseInstallData(jsonObj)
end

local function executeInstallData(installData)
    for _, entry in pairs(installData.files) do
        local result = entry:execute()
    end
end

local function main(args)
    local installerFile = args[1]
    local installData = parseInstallerFile(installerFile)
    executeInstallData(installData)
end

main({ ... })
