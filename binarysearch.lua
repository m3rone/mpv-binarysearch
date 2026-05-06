local lo, hi
local hist = {}

local function fmt(t) -- formats time
    if not t then return "?" end
    local h = math.floor(t / 3600)
    local m = math.floor((t % 3600) / 60)
    local s = t - h * 3600 - m * 60
    if h > 0 then return string.format("%d:%02d:%06.3f", h, m, s) end
    return string.format("%d:%06.3f", m, s)
end

local function osd(tag)
    local mid = (lo + hi) / 2
    mp.osd_message(string.format("%s  [%s, %s]  Δ%s  → %s",
        tag, fmt(lo), fmt(hi), fmt(hi - lo), fmt(mid)), 2)
end

local function seek_to(t)
    mp.commandv("seek", tostring(t), "absolute", "exact")
    mp.set_property_bool("pause", true)
end

local function push()
    hist[#hist + 1] = {
        lo = lo, hi = hi,
        pos = mp.get_property_number("time-pos"),
        pause = mp.get_property_bool("pause"),
    }
end

local function bisect(dir)
    local d = mp.get_property_number("duration")
    local p = mp.get_property_number("time-pos")
    if not d or not p then
        mp.osd_message("bisect: no duration/position", 2)
        return
    end
    push()
    lo = lo or 0
    hi = hi or d
    if dir < 0 then
        hi = p
        if lo > hi then lo = 0 end
    else
        lo = p
        if lo > hi then hi = d end
    end
    seek_to((lo + hi) / 2)
    osd(dir < 0 and "←" or "→")
end

local function undo()
    local s = table.remove(hist)
    if not s then
        mp.osd_message("bisect: nothing to undo", 2)
        return
    end
    lo, hi = s.lo, s.hi
    if s.pos then
        mp.commandv("seek", tostring(s.pos), "absolute", "exact")
    end
    if s.pause ~= nil then
        mp.set_property_bool("pause", s.pause)
    end
    mp.osd_message(string.format("undo  [%s, %s]  → %s",
        fmt(lo or 0), fmt(hi or 0), fmt(s.pos or 0)), 2)
end

mp.add_key_binding("b", "bisect-earlier", function() bisect(-1) end)
mp.add_key_binding("n", "bisect-later", function() bisect(1) end)
mp.add_key_binding("Ctrl+z", "bisect-undo", undo)

mp.register_event("file-loaded", function()
    lo, hi, hist = nil, nil, {}
end)
