function string:trim()
    return self:match("^%s*(.-)%s*$")
end

function string:split(del)
    return string.gmatch(self, "([^" .. del .. "]+)")
end

function hash(str)
    h = 5381;
    for c in str:gmatch "." do
        h = ((h << 5) + h) + string.byte(c)
    end
    return h
end

function table:contains(item)
    for _, value in ipairs(self) do
        if value == item then
            return true
        end
    end
    return false
end

function table:indexOf(item)
    for i, value in ipairs(self) do
        if value == item then
            return i
        end
    end
    return nil
end
