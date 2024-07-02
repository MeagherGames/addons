print "Running tile set export script"

local fs = app.fs
local file_path = app.params["file_path"]
local tile_set_data_path = app.params["tile_set_data_path"]
local images_output_path = fs.filePath(tile_set_data_path)
local file_name = fs.fileTitle(file_path)

local sprite = app.open(file_path)
if not sprite then return print "No active sprite" end

local tile_set_number = 0

local function write_json(filename, data)
    local json = dofile('./json.lua')
    local file = io.open(filename, "w")
    file:write(json.encode(data))
    file:close()
end

local function export_tile_set(tile_set)
    local tile_set_data = {}
    local tile_count = #tile_set
    local chunk_width = math.floor(math.sqrt(tile_count) + 0.5)
    local tile_size = tile_set.grid.tileSize
    tile_set_data.grid = {
        tileSize = {width = tile_size.width, height = tile_size.height},
    }
    tile_set_data.tiles = {}

    if tile_count > 0 then
        local hframes = chunk_width
        local vframes = math.ceil(tile_count / chunk_width)

        tile_set_data.grid.hframes = hframes
        tile_set_data.grid.vframes = vframes

        local image_spec = sprite.spec
        image_spec.width = tile_size.width * hframes
        image_spec.height = tile_size.height * vframes
        local image = Image(image_spec)
        image:clear()
        for i = 0, tile_count - 1 do
            local tile = tile_set:getTile(i)
            local h = (i % chunk_width)
            local v = math.floor(i / chunk_width)
            local x = h * tile_size.width
            local y = v * tile_size.height

            tile_set_data.tiles[i+1] = {
                h = h,
                v = v,
                x = x,
                y = y,
            }

            image:drawImage(tile, x, y)
        end

        tile_set_number = tile_set_number + 1
        local tile_set_name = string.format("%s_%s_%d.png", file_name, tile_set.name, tile_set_number)
        local output_path = fs.joinPath(images_output_path, tile_set_name)
        print("Exporting tile set " .. output_path)
        image:saveAs(output_path)
        tile_set_data.id = tile_set_number
        tile_set_data.name = tile_set.name
        tile_set_data.width = image_spec.width
        tile_set_data.height = image_spec.height
        tile_set_data.image = tile_set_name
        tile_set_data.image_path = output_path
    end
    return tile_set_data
end

local function export_tile_sets(layers)
    local tile_sets_data = {}
    for _,layer in ipairs(layers) do
        -- aseprite calles it tileset (one word) godot does tile_set (two words)
        -- we'll use godot naming convention
        local tile_set = layer.tileset
        table.insert(tile_sets_data, export_tile_set(tile_set))
    end
    return tile_sets_data
end

local data = {
    filename = sprite.filename,
    width = sprite.width,
    height = sprite.height
}

if #sprite.layers then
    -- We only actually care about tile sets used in layers
    data.tile_sets = export_tile_sets(sprite.layers)
else
    print "No tile sets found"
end

write_json(tile_set_data_path, data)