local Atlas = {
    width = 0,
    height = 0,
    padding = 1,
    empty_region = nil, -- This will be set to a default empty region
    images = {}, -- This will hold the images added to the atlas
    data = {} -- Key is an image, value is the region
}

function Atlas:use_empty_region()
    if not self.empty_region then
        self.empty_region = {
            x = 0,
            y = 0,
            w = 1,
            h = 1
        }
        table.insert(self.data, {
            image = nil,
            region = self.empty_region
        })
    end
    return self.empty_region
end

function Atlas:add_image(image, region, offset_x, offset_y)
    assert(image, "Image cannot be nil")
    assert(region, "Region cannot be nil")
    assert(image.width and image.height, "Image must have width and height")
    assert(image.width > 0 and image.height > 0, "Image must have a valid size")
    if self.images[image] ~= nil then
        return -- Image already added
    end
    -- offsets only used for grid packing
    region.offset_x = offset_x or 0
    region.offset_y = offset_y or 0
    region.x = 0
    region.y = 0
    region.w = image.width
    region.h = image.height
    self.images[image] = region
    table.insert(self.data, {
        image = image,
        region = region
    })
end

function Atlas:pack(grid_width)
    grid_width = grid_width or 0
    if grid_width > 0 then
        return self:pack_grid(grid_width)
    else
        return self:pack_scan()
    end
end

function Atlas:pack_grid(grid_width)
    assert(grid_width > 0, "Grid width must be greater than 0")

    -- Calculate grid dimensions
    local num_images = #self.data
    local grid_height = math.ceil(num_images / grid_width)

    -- Find the maximum width and height of any image to use as cell size
    local cell_width = app.sprite.width
    local cell_height = app.sprite.height

    -- Position each image in the grid
    for i, item in ipairs(self.data) do
        local region = item.region

        -- Calculate grid position (0-indexed)
        local grid_x = (i - 1) % grid_width
        local grid_y = math.floor((i - 1) / grid_width)

        -- Set actual pixel position
        region.x = grid_x * cell_width + region.offset_x
        region.y = grid_y * cell_height + region.offset_y
    end

    -- Update atlas dimensions
    self.width = grid_width * cell_width
    self.height = grid_height * cell_height

    -- Create the atlas image
    local spec = ImageSpec {
        width = self.width,
        height = self.height,
        colorMode = app.sprite.colorMode
    }
    local atlas_image = Image(spec)

    -- Draw all images to the atlas
    for image, region in pairs(self.images) do
        atlas_image:drawImage(image, Point(region.x, region.y))
    end

    return atlas_image
end

function Atlas:pack_scan()
    local placed_regions = {}
    local atlas_width = 0
    local atlas_height = 0

    -- Convert regions to a sortable array and sort by area (descending)
    local images_to_pack = {}
    for i, item in pairs(self.data) do
        table.insert(images_to_pack, item)
    end
    -- Sort by area, largest first
    table.sort(images_to_pack, function(a, b)
        return a.region.h * a.region.w > b.region.h * b.region.w
    end)

    for _, item in ipairs(images_to_pack) do
        local region = item.region

        local pos = self:find_region_position(region, placed_regions, atlas_width, atlas_height)
        region.x = pos.x
        region.y = pos.y

        -- Update atlas dimensions
        atlas_width = math.max(atlas_width, region.x + region.w)
        atlas_height = math.max(atlas_height, region.y + region.h)

        -- Add to placed regions
        table.insert(placed_regions, region)
    end

    self.width = atlas_width
    self.height = atlas_height

    -- Create the atlas image
    local spec = ImageSpec {
        width = atlas_width,
        height = atlas_height,
        colorMode = app.sprite.colorMode
    }
    local atlas_image = Image(spec)

    -- Draw all images to the atlas
    for image, region in pairs(self.images) do
        atlas_image:drawImage(image, Point(region.x, region.y))
    end

    return atlas_image
end

function Atlas:find_region_position(region, placed_regions, atlas_width, atlas_height)
    local max_x = atlas_width
    local max_y = atlas_height

    local max_a = max_x
    local max_b = max_y
    if atlas_width >= atlas_height then
        max_a = max_x
        max_b = max_y + region.h
    else
        max_a = max_y
        max_b = max_x + region.w

    end

    for a = 0, max_a do
        for b = 0, max_b do
            if not self:overlaps_with_placed(a, b, region.w, region.h, placed_regions) then
                return {
                    x = a,
                    y = b
                }
            end
        end
    end
    return {
        x = 0,
        y = 0
    }
end

function Atlas:overlaps_with_placed(x, y, width, height, placed_regions)
    for _, region in ipairs(placed_regions) do
        if not (x >= region.x + region.w + self.padding or x + width + self.padding <= region.x or y >= region.y +
            region.h + self.padding or y + height + self.padding <= region.y) then
            return true
        end
    end
    return false
end

function Atlas:new()
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.width = 0
    o.height = 0
    o.images = {}
    o.data = {}
    return o
end

return Atlas
