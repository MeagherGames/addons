local function write_json(filepath, data)
    assert(type(filepath) == "string", "Filename must be a string")
    local file = io.open(filepath, "w")
    assert(file, "Could not open file for writing: " .. filepath)
    file:write(json.encode(data, {
        indent = true
    }))
    file:close()
end
local function save_data(filepath, data)
    print("Saving data to " .. filepath)
    write_json(filepath, data)
    print("Scene data saved successfully.")
end

local file_path = app.params["file_path"]
local output_path = app.params["output_path"]
local atlas_path = app.fs.joinPath(app.fs.filePath(output_path), app.fs.fileName(file_path) .. ".png")

local sprite = app.open(file_path)

if not sprite then
    return print "Could not find sprite " .. file_path .. " to export"
end

-- remove layers that have -noimp in their name
for i = #sprite.layers, 1, -1 do
    local layer = sprite.layers[i]
    if layer.name:find("-noimp") then
        sprite:deleteLayer(layer)
    end
end

if app.params["layers"] ~= "true" then
    sprite:flatten()
end

local Atlas = dofile("./scene/atlas.lua")
local Scene = dofile("./scene/scene.lua")

atlas = Atlas:new() -- global so the scene can access it

local scene = Scene:from_sprite() -- Modifies the atlas
local atlas_image = atlas:pack(app.params["pack_mode"] == "grid" and #app.sprite.frames or 0)

atlas_image:saveAs(atlas_path)
local data = scene:to_json()
data.meta = {
    name = app.fs.fileTitle(file_path),
    aseprite_file = file_path,
    filepath = output_path,
    atlas_path = atlas_path,
    atlas_width = atlas_image.width,
    atlas_height = atlas_image.height
}

if app.params["tiles"] == "true" then
    data.meta.tile_index_mask = 0x1fffffff
    data.meta.tile_flip_h_mask = 0x80000000
    data.meta.tile_flip_v_mask = 0x40000000
    data.meta.tile_transpose_mask = 0x20000000
end

save_data(output_path, data)
