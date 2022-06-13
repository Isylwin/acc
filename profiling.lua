local profiling = {}

profiling.enable = true
profiling.current = {}
profiling.buffer = {}
profiling.labels = {}
profiling.wrap = function(self, fn, profileLabel)
    if self.enable then
        table.insert(self.labels, profileLabel)
        table.sort(self.labels)

        return function(...)
            ---@diagnostic disable-next-line: undefined-field
            local before = os.epoch("local")
            local ret = fn(...)
            ---@diagnostic disable-next-line: undefined-field
            local after = os.epoch("local")
            local ms = (after - before)
            self.current[profileLabel] = ms
            return ret
        end
    end

    return fn
end
--TODO self.enable wrapper
profiling.print = function(self)
    if not self.enable then
        return
    end

    local data = self.buffer
    local lbls = self.labels

    local width = table.reduce(lbls, function(val, acc) return math.max(#val, acc) end, 0)
    local format = "%-" .. width .. "s | %s"
    local header = string.format(format, "Label", "Time")

    print("Profiling:")
    print(header)

    for _, lbl in pairs(lbls) do
        local rowData = data[lbl] --Currently just ms
        local ms = rowData or 0

        local timeStr = string.format("%.3f s", ms / 1000)
        local rowStr = string.format(format, lbl, timeStr)
        print(rowStr)
    end
end

profiling.reset = function(self)
    if not self.enable then
        return
    end

    self.buffer = self.current
    self.current = {}
end

return profiling
