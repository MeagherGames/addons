local Frame = dofile("./frame.lua")
local Layer = {
    name = "",
    group = "",
    visible = true,
    is_tilemap = false,
    opacity = 1, -- Aseprite uses 0-255 for opacity, we use 0-1
    offset = {
        x = 0,
        y = 0
    },
    blend_mode = "normal", -- Aseprite blend modes are mapped to standard blend modes
    frames = {},
    data = {}
}

function Layer:from_layer(layer, group)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o:_init(layer, group)
    o:_parse_frames(layer)
    return o
end

function Layer:from_tilemap(tilemap, group, atlas)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o:_init(tilemap, group)
    o.is_tilemap = true
    o.tile_set = get_tileset_id(tilemap.tileset)
    o:_parse_frames(tilemap)
    return o
end

function Layer:_init(layer, group)
    self.name = layer.name
    self.group = group
    self.opacity = layer.opacity / 255.0 -- Aseprite uses 0-255 for opacity, we use 0-1
    self.visible = layer.isVisible
    self.blend_mode = layer.blendMode -- Aseprite blend modes are mapped to standard blend modes
    self.data = {}
    for d in layer.data:split(", ") do
        table.insert(self.data, d:trim())
    end
end

function Layer:_parse_frames(layer)
    self.frames = {}
    for i, frame in ipairs(app.sprite.frames) do
        local cel = layer:cel(i)
        local frame_data = false
        if cel then
            frame_data = Frame:from_cel(cel)
        else
            frame_data = Frame:new()
            frame_data.duration = frame.duration
            frame_data.is_tilemap = self.is_tilemap
        end
        table.insert(self.frames, frame_data)
    end
end

function Layer:to_json()
    local data = {
        name = self.name,
        group = self.group,
        opacity = self.opacity,
        visible = self.visible,
        blend_mode = self.blend_mode,
        is_tilemap = self.is_tilemap,
        offset = self.offset,
        frames = {},
        data = self.data
    }
    if self.is_tilemap then
        data.tile_set = self.tile_set
    end

    if self.is_tilemap then
        table.insert(data.frames, self.frames[1]:to_json())
    else
        for _, frame in ipairs(self.frames) do
            table.insert(data.frames, frame:to_json())
        end
    end
    return data
end

return Layer
