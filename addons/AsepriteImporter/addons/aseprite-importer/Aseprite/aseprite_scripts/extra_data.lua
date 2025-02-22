print "Extracting user data"

local fs = app.fs
local file_path = app.params["file_path"]
local output_path = app.params["output_path"]

local filename = fs.fileTitle(file_path)
local sprite = app.open(file_path)

if not sprite then
    return error("No active sprite")
end

local function export_user_data(cels)
    local user_data = {}
    for i, cel in ipairs(cels) do
        if not user_data[cel.frameNumber] then
            user_data[cel.frameNumber] = {}
        end
        if cel.data ~= "" then
            table.insert(user_data[cel.frameNumber], cel.data)
        end
    end
    return user_data
end

local function add_layer_data(layer_table, layer)
    local data = {
        name = layer.name,
        visible = layer.isVisible
    }
    table.insert(layer_table, data)
    if layer.isGroup then
        for i, child in ipairs(layer.layers) do
            local child_data = add_layer_data(layer_table, child)
        end
    end
    return data
end

local function export_layer_data(layers)
    local layer_data = {}
    for i, layer in ipairs(layers) do
        add_layer_data(layer_data, layer)
    end
    return layer_data
end

local function write_json(filename, data)
    local json = dofile('./json.lua')
    local file = io.open(filename, "w")
    file:write(json.encode(data))
    file:close()
end

local data = {
    filename = sprite.filename,
    user_data = export_user_data(sprite.cels),
    layer_data = export_layer_data(sprite.layers)
}

write_json(output_path, data)
