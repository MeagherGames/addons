local Animation = {
    name = "",
    from = 0, -- frames
    to = 0, -- frames
    duration = 0,
    autoplay = false,
    repeats = 0, -- number of times the animation should repeat, 0 means infinite
    loop_mode = 0,
    reverse = false, -- if true, the animation plays in reverse
    data = {}
}

Animation.LOOP_NONE = 0
Animation.LOOP_LINEAR = 1
Animation.LOOP_PINGPONG = 2

function Animation:empty()
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.name = "RESET"
    o.from = 0
    o.to = #app.sprite.cels - 1
    o.duration = 0
    o.autoplay = false
    o.repeats = 0
    o.loop_mode = Animation.LOOP_LINEAR
    o.reverse = false
    o.data = {}
    return o
end

function Animation:from_tag(tag)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o.name = tag.name
    o.from = tag.fromFrame.frameNumber - 1
    o.to = tag.toFrame.frameNumber - 1

    o.repeats = tag.repeats
    o.data = {}

    local check_loop_mode = true
    for d in tag.data:split(", ") do
        d = d:trim()
        if d == "no_loop" then
            o.loop_mode = Animation.LOOP_NONE
            o.reverse = false
            check_loop_mode = false
        end
        if d == "autoplay" then
            o.autoplay = true
        end
        table.insert(o.data, d)
    end

    if check_loop_mode then
        if tag.aniDir == AniDir.FORWARD then
            o.loop_mode = Animation.LOOP_LINEAR
            o.reverse = false
        elseif tag.aniDir == AniDir.REVERSE then
            o.loop_mode = Animation.LOOP_LINEAR
            o.reverse = true
        elseif tag.aniDir == AniDir.PING_PONG then
            o.loop_mode = Animation.LOOP_PINGPONG
            o.reverse = false
        elseif tag.aniDir == AniDir.PINGPONG_REVERSE then
            o.loop_mode = Animation.LOOP_PINGPONG
            o.reverse = true
        end
    end

    o.duration = 0
    for i = tag.fromFrame.frameNumber, tag.toFrame.frameNumber do
        o.duration = o.duration + tag.sprite.frames[i].duration
    end
    return o
end

function Animation:to_json()
    local data = {
        name = self.name,
        from = self.from,
        to = self.to,
        duration = self.duration,
        autoplay = self.autoplay,
        repeats = self.repeats,
        loop_mode = self.loop_mode,
        reverse = self.reverse,
        data = self.data
    }
    return data
end

return Animation
