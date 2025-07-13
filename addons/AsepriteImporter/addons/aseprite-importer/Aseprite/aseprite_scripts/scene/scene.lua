dofile("./data.lua")
local TileSet = dofile("./tile_set.lua")
local Layer = dofile("./layer.lua")
local Animation = dofile("./animation.lua")

local Scene = {
    width = 0,
    height = 0,
    tile_sets = {},
    layers = {},
    animations = {}
}

function Scene:add_from_layer(layer, group, atlas)
    if layer.isGroup then
        -- If the layer is a group, we need to add its children
        if #group == 0 then
            group = {layer.name}
        else
            group = {table.unpack(group)}
            table.insert(group, layer.name)
        end
        for _, child_layer in ipairs(layer.layers) do
            self:add_from_layer(child_layer, group)
        end
        return
    end
    local layer_data
    if app.params["tiles"] == "true" and layer.isTilemap then
        -- The atlas is passed here so the tilemap layer can add it's tilset image
        layer_data = Layer:from_tilemap(layer, group, atlas)
    else
        -- The atlas for regular layers is handled by frames
        layer_data = Layer:from_layer(layer, group)
    end
    table.insert(self.layers, layer_data)
end

function Scene:from_sprite()
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.width = app.sprite.width
    o.height = app.sprite.height

    -- Add tile_sets
    o.tile_sets = {}
    if app.params["tiles"] == "true" then
        local tilemap_count = 0
        for _, layer in ipairs(app.sprite.layers) do
            if layer.isTilemap then
                tilemap_count = tilemap_count + 1
            end
        end
        if tilemap_count > 0 then
            for i, tile_set in ipairs(app.sprite.tilesets) do
                local tile_set_data = TileSet:from_tile_set(tile_set)
                table.insert(o.tile_sets, tile_set_data)
            end
        end
    end

    -- Add layers
    o.layers = {}
    for _, layer in ipairs(app.sprite.layers) do
        o:add_from_layer(layer, {})
    end

    -- Add animations
    o.animations = {}
    if #app.sprite.tags == 0 then
        local animation_data = Animation:from_tag({
            name = "RESET",
            fromFrame = {
                frameNumber = 1
            },
            toFrame = {
                frameNumber = #app.sprite.cels
            },
            sprite = app.sprite,
            repeats = 0,
            loop = AniDir.FORWARD,
            data = ""
        })
        table.insert(o.animations, animation_data)
    else
        for i, tag in ipairs(app.sprite.tags) do
            local animation_data = Animation:from_tag(tag)
            table.insert(o.animations, animation_data)
        end
    end

    return o
end

function Scene:to_json()
    local data = {
        width = self.width,
        height = self.height,
        tile_sets = {},
        layers = {},
        animations = {},
        meta = self.meta
    }

    for _, tile_set in ipairs(self.tile_sets) do
        table.insert(data.tile_sets, tile_set:to_json())
    end
    for _, layer in ipairs(self.layers) do
        table.insert(data.layers, layer:to_json())
    end
    for _, animation in ipairs(self.animations) do
        table.insert(data.animations, animation:to_json())
    end
    return data
end

return Scene
