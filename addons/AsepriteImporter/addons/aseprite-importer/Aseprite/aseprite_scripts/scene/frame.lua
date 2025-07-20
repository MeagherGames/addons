local Frame = {
    duration = 0,
    z_index = 0,
    opacity = 1,
    is_tilemap = false,
    tile_set = -1,
    tiles = {},
    position = {
        x = 0,
        y = 0
    },
    region = {
        x = 0,
        y = 0,
        w = 0,
        h = 0
    },
    data = {}
}

function Frame:new()
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.duration = 0
    o.z_index = 0
    o.opacity = 0
    o.is_tilemap = false
    o.tile_set = -1
    o.tiles = {}
    o.position = {
        x = 0,
        y = 0
    }
    o.region = atlas:use_empty_region()
    o.data = {}
    return o
end

local function parse_tile_data(tile_data)
    -- https://github.com/aseprite/aseprite/blob/b4555fc09876753fc4e74ac6957cce3c9b71b19b/src/doc/tile.h#L30

    local tile_index = (tile_data & index_mask)

    local flip_h = (tile_data & flip_h_mask) ~= 0
    local flip_v = (tile_data & flip_v_mask) ~= 0
    local transpose = (tile_data & transpose_mask) ~= 0

    return {
        index = tile_index,
        flip_h = flip_h,
        flip_v = flip_v,
        transpose = transpose
    }
end

function Frame:from_cel(cel)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.duration = cel.frame.duration
    o.z_index = cel.zIndex
    o.opacity = cel.opacity / 255.0 -- Aseprite uses 0-255 for opacity, we use 0-1
    o.position = {
        x = cel.position.x,
        y = cel.position.y
    }
    o.data = {}
    for d in cel.data:split(", ") do
        table.insert(o.data, d:trim())
    end

    if app.params["tiles"] == "true" and cel.layer.isTilemap then
        o.is_tilemap = true
        o.tile_set = get_tileset_id(cel.layer.tileset)
        o.tiles = {}
        local size = cel.image.width * cel.image.height
        o.region = {
            x = cel.position.x / cel.layer.tileset.grid.tileSize.width,
            y = cel.position.y / cel.layer.tileset.grid.tileSize.height,
            w = cel.bounds.width / cel.layer.tileset.grid.tileSize.width,
            h = cel.bounds.height / cel.layer.tileset.grid.tileSize.height
        }
        for i = 0, size - 1 do
            local tile_x = i % cel.image.width
            local tile_y = math.floor(i / cel.image.width)
            local tile_data = cel.image:getPixel(tile_x, tile_y)
            table.insert(o.tiles, tile_data)
        end
    else
        o.region = {
            x = 0,
            y = 0,
            w = 0,
            h = 0
        }
        atlas:add_image(cel.image, o.region, cel.position.x, cel.position.y)
    end
    return o
end

function Frame:to_json()
    local data = {
        duration = self.duration,
        z_index = self.z_index,
        opacity = self.opacity,
        region = {
            x = self.region.x,
            y = self.region.y,
            w = self.region.w,
            h = self.region.h
        },
        data = self.data
    }
    if self.is_tilemap then
        data.tile_set = self.tile_set
        data.tiles = self.tiles
    else
        data.position = {
            x = self.position.x,
            y = self.position.y
        }
    end
    return data
end

return Frame
