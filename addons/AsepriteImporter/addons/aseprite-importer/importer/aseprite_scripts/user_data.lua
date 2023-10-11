print "Extracting user data"

local fs = app.fs
local file_path = app.params["file_path"]
local output_path = app.params["output_path"]

local filename = fs.fileTitle(file_path)
local sprite = app.open(file_path)

if not sprite then return print "No active sprite" end

local function export_user_data(cels)
    local user_data = {}
    for i,cel in ipairs(cels) do
        if not user_data[cel.frameNumber] then
            user_data[cel.frameNumber] = {}
        end 
        if cel.data ~= "" then
            table.insert(user_data[cel.frameNumber], cel.data)
        end
    end
    return user_data
end

local function write_json(filename, data)
    local json = dofile('./json.lua')
    local file = io.open(filename, "w")
    file:write(json.encode(data))
    file:close()
end

local data = {
    filename = sprite.filename,
    user_data = export_user_data(sprite.cels)
}

write_json(output_path, data)