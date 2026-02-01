local Atlas = dofile("./atlas.lua")

function get_tileset_id(tileset)
    -- Find the index of this tileset in sprite.tilesets
    for i = 1, #app.sprite.tilesets do
        if app.sprite.tilesets[i] == tileset then
            return i - 1 -- Convert to 0-based index
        end
    end
    return nil
end

local TileSet = {
    name = "",
    padding = 0, -- Padding between tiles
    grid = {
        x = 0,
        y = 0,
        w = 0,
        h = 0
    },
    region = {
        x = 0,
        y = 0,
        w = 0,
        h = 0
    },
    tiles = {}
}

function TileSet:generate_image(tileset)
    local tile_count = #tileset - 1
    if tile_count < 0 then
        return
    end
    -- Square-ish width
    local chunk_width = math.floor(math.sqrt(tile_count) + 0.5)

    local hframes = chunk_width
    local vframes = math.ceil(tile_count / chunk_width)
    local w = self.grid.w * hframes
    local h = self.grid.h * vframes

    local spec = ImageSpec {
        width = w + self.padding * (hframes - 1),
        height = h + self.padding * (vframes - 1),
        colorMode = app.sprite.colorMode,
        transparentColor = app.sprite.transparentColor
    }
    local image = Image(spec)

    for i = 0, tile_count - 1 do
        local tile_image = tileset:tile(i + 1).image

        if tile_image:isEmpty() then
            goto continue
        end

        local h = (i % chunk_width)
        local v = math.floor(i / chunk_width)
        local x = h * self.grid.w + h * self.padding
        local y = v * self.grid.h + v * self.padding

        table.insert(self.tiles, {
            x = h,
            y = v
        })
        image:drawImage(tile_image, Point(x, y))

        ::continue::
    end

    self.region = atlas:add_image(image) -- Add the image to the atlas
end

function TileSet:from_tile_set(tileset)
    local o = {}
    setmetatable(o, self)
    self.__index = self

    o.name = tileset.name
    o.grid = {
        x = tileset.grid.origin.x,
        y = tileset.grid.origin.y,
        w = tileset.grid.tileSize.width,
        h = tileset.grid.tileSize.height
    }
    o.tiles = {}
    o:generate_image(tileset)
    return o
end

function TileSet:to_json()
    local data = {
        name = self.name,
        padding = self.padding,
        grid = {
            x = self.grid.x,
            y = self.grid.y,
            w = self.grid.w,
            h = self.grid.h
        },
        region = {
            x = self.region.x,
            y = self.region.y,
            w = self.region.w,
            h = self.region.h
        },
        tiles = {}
    }

    for _, tile in ipairs(self.tiles) do
        table.insert(data.tiles, {
            x = tile.x,
            y = tile.y
        })
    end

    return data
end

return TileSet
