-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 bliatun-code and VoltDeck contributors.
-- VoltDeck: theme-aware full-screen telemetry for FrSky Ethos / X20RS.
-- Configure one full-screen zone in Ethos. Scalar settings are saved per model.
-- Artwork is drawn natively. Model images and optional alert audio are user-selected.

local VERSION = "2026.10-v6"
local MAX_IMAGE_PIXELS = 160000
local BITMAP_RESERVE = 65536
local FLIGHT_SESSION
local HISTORY_POINTS = 180
local GRAPH_BINS = 48
local GRAPH_SOURCE_STEPS = 32
local GRAPH_BIN_STEPS = 24
local BITMAP_CACHE = setmetatable({}, {__mode = "v"})
-- Ethos 1.6 uses STD names for the medium fonts.
local VALUE_FONTS = {FONT_XXL, FONT_XL, FONT_L_BOLD, FONT_L, FONT_M_BOLD or FONT_STD_BOLD, FONT_M or FONT_STD, FONT_S, FONT_XS}
local SMALL_FONTS = {FONT_S, FONT_XS}
local SURFACE_HEIGHT = 480
local LOW_BATTERY_PERCENT = 30
local PACK_CHECK_MAX_CURRENT = 0.5
local PACK_CHECK_SECONDS = 10
local PACK_CHECK_RELAX_SECONDS = 60
local PACK_CHECK_STABILITY_MV = 10
local PACK_CHECK_AUTO_BP = 1000
local PACK_CHECK_MANUAL_BP = 2000
-- STC3115 default 4.20/4.35 V reference points, not a universal state of charge.
-- Published data: github.com/st-sw/STC3115GenericDriver/Docs/Config/.
local PACK_OCV_SOC = {0, 3, 6, 10, 15, 20, 25, 30, 40, 50, 60, 65, 70, 80, 90, 100}
local PACK_OCV_420 = {3300, 3541, 3618, 3658, 3695, 3721, 3747, 3761, 3778, 3802, 3863, 3899, 3929, 3991, 4076, 4176}
local PACK_OCV_435 = {3300, 3571, 3651, 3675, 3710, 3743, 3761, 3770, 3790, 3825, 3914, 3953, 3990, 4088, 4197, 4313}
local COLORS = {
    black = lcd.RGB(0, 0, 0),
    white = lcd.RGB(244, 247, 251),
    muted = lcd.RGB(145, 160, 175),
    accent = lcd.RGB(78, 218, 191),
    green = lcd.RGB(53, 220, 139),
    yellow = lcd.RGB(255, 211, 63),
    orange = lcd.RGB(255, 151, 48),
    red = lcd.RGB(255, 73, 91),
    border = lcd.RGB(106, 122, 139),
    track = lcd.RGB(112, 127, 144, 0.14),
}
local TYPES = {
    {name = "Lipo", full = 4.20, empty = 3.30, cellMinimum = 3.27, checkCurve = PACK_OCV_420},
    {name = "LiHV", full = 4.35, empty = 3.40, cellMinimum = 3.37, checkCurve = PACK_OCV_435},
    {name = "Li-ion", full = 4.20, empty = 3.00, cellMinimum = 2.97, checkCurve = PACK_OCV_420},
    {name = "LiFe", full = 3.65, empty = 2.80, cellMinimum = 2.77},
}
local SOURCE_FIELDS = {
    {key = "voltageSource", label = "Pack voltage", legacy = "voltageRef"},
    {key = "currentSource", label = "Current", legacy = "currentRef"},
    {key = "consumptionSource", label = "Consumed mAh", legacy = "consumedRef"},
    {key = "rssi1Source", label = "RF1 source", legacy = "rssiRef"},
    {key = "rssi2Source", label = "RF2 source"},
    {key = "rx1Source", label = "Rx1 voltage"},
    {key = "rx2Source", label = "Rx2 voltage"},
    {key = "txSource", label = "Tx voltage"},
    {key = "timerSource", label = "Flight timer"},
    {key = "percentSource", label = "Battery % source", legacy = "percentRef"},
}
local SETTINGS = {
    "chemistry", "cellCount", "capacityMah", "alarmEnabled", "alarmSound", "audioFolder",
    "alertInterval", "mahDisplay", "preview", "imageName", "backgroundMode",
    "backgroundColor", "accentColor", "bottomDisplay", "bottomMinimum",
    "bottomMaximum", "bottomDecimals", "bottomLabel", "redZone",
    "signalMinimum", "signalMaximum", "fontPath", "imageMode", "alarmEstimate", "batteryMethod",
    "deckMode", "rpmMode", "motorKV", "loadFactor", "rpmScale", "rpmMaximum",
    "wattMaximum", "cellMaximum", "logEnabled", "flightMinimum", "throttleThreshold",
    "highThrottleSeconds", "endDelay", "throttleMinimum", "throttleMaximum",
    "rfWarnDB", "rfCriticalDB", "rfWarnPercent", "rfCriticalPercent",
    "rf1Profile", "rf2Profile", "rf2WarnDB", "rf2CriticalDB", "rf2WarnPercent", "rf2CriticalPercent",
    "autoLogEnabled", "autoLogDelay", "customPosition",
}
local SETTING_DEFS = {
    {"chemistry", 1, 1, #TYPES},
    {"cellCount", 6, 1, 16},
    {"capacityMah", 2500, 100, 100000},
    {"alarmEnabled", true},
    {"alarmSound", ""},
    {"audioFolder", "/audio"},
    {"alertInterval", 10, 1, 600},
    {"mahDisplay", 1, 1, 2},
    {"preview", false},
    {"imageName", ""},
    {"backgroundMode", 1, 1, 3},
    {"backgroundColor", COLORS.black},
    {"accentColor", COLORS.accent},
    {"bottomDisplay", 2, 1, 2},
    {"bottomMinimum", 0, -100000, 999999},
    {"bottomMaximum", 100, -99999, 1000000},
    {"bottomDecimals", -1, -1, 3},
    {"bottomLabel", ""},
    {"redZone", 85, 10, 100},
    {"signalMinimum", 0, -150, 199},
    {"signalMaximum", 100, -149, 200},
    {"fontPath", ""},
    {"imageMode", 1, 1, 3},
    {"alarmEstimate", false},
    {"batteryMethod", 1, 1, 3},
    {"deckMode", 6, 1, 8},
    {"rpmMode", 1, 1, 2},
    {"motorKV", 0, 0, 10000},
    {"loadFactor", 100, 10, 100},
    {"rpmScale", 1, 1, 2},
    {"rpmMaximum", 12000, 1000, 200000},
    {"wattMaximum", 2000, 10, 100000},
    {"cellMaximum", 440, 200, 500},
    {"logEnabled", false},
    {"flightMinimum", 60, 60, 3600},
    {"throttleThreshold", 50, 10, 100},
    {"highThrottleSeconds", 5, 1, 120},
    {"endDelay", 10, 3, 120},
    {"throttleMinimum", -1024, -2048, 2047},
    {"throttleMaximum", 1024, -2047, 2048},
    {"rfWarnDB", 35, -149, 200},
    {"rfCriticalDB", 32, -150, 199},
    {"rfWarnPercent", 95, 1, 100},
    {"rfCriticalPercent", 50, 0, 99},
    {"rf1Profile", 1, 1, 3},
    {"rf2Profile", 1, 1, 3},
    {"rf2WarnDB", 35, -149, 200},
    {"rf2CriticalDB", 32, -150, 199},
    {"rf2WarnPercent", 95, 1, 100},
    {"rf2CriticalPercent", 50, 0, 99},
    {"autoLogEnabled", false},
    {"autoLogDelay", 5, 0, 120},
}
-- Keep the complete previous scalar layout for a lossless VD5 import.
local PREVIOUS_SETTING_DEFS = {}
for index, definition in ipairs(SETTING_DEFS) do PREVIOUS_SETTING_DEFS[index] = definition end
SETTING_DEFS[#SETTING_DEFS + 1] = {"customPosition", 3, 1, 3}
local SETTING_MAP = {}
for _, definition in ipairs(SETTING_DEFS) do SETTING_MAP[definition[1]] = definition end

-- SPDX-License-Identifier: MIT
-- Shared build-time code. Bundled into each widget; no runtime dependency.
local DeckCore = (function()
    local function clamp(value, minimum, maximum)
        return math.max(minimum, math.min(maximum, value))
    end
    local function round(value) return math.floor(value + 0.5) end
    local function finite(value)
        return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
    end
    local function selectedSource(source)
        if source == nil or source == false or source == "" then return nil end
        local ok, category = pcall(function() return source:category() end)
        if ok and CATEGORY_NONE ~= nil and category == CATEGORY_NONE then return nil, category end
        return source, ok and category or nil
    end
    local function getSource(parameters)
        local ok, source = pcall(system.getSource, parameters)
        if ok then return selectedSource(source) end
    end
    local function restoreSource(value)
        if type(value) == "string" and value ~= "" then return getSource(value)
        elseif type(value) == "number" then return getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = value})
        elseif type(value) == "userdata" or type(value) == "table" then return selectedSource(value) end
    end
    local function validWidget(widget)
        return type(widget) == "table" and not widget.destroyed and type(widget.data) == "table"
            and type(widget.scratch) == "table" and finite(widget.nextPoll)
    end
    local function sample(source, quantity)
        source = selectedSource(source)
        if not source then return nil end
        local ok, active, value, unit = pcall(function() return source:state(), source:value(), source:unit() end)
        if not ok or not finite(value) then return nil end
        if active == false then
            local categoryOK, category = pcall(function() return source:category() end)
            if not categoryOK then return nil end
            if not (quantity == "timer" and category == CATEGORY_TIMER)
                and not (quantity == "control" and category ~= CATEGORY_TELEMETRY_SENSOR) then return nil end
        end
        if quantity == "signal" and unit ~= UNIT_DB and unit ~= UNIT_PERCENT then return nil end
        if quantity == "rpm" and unit ~= UNIT_RPM and unit ~= UNIT_NONE then return nil end
        if quantity == "voltage" and unit ~= UNIT_VOLT and unit ~= UNIT_MILLIVOLT and unit ~= UNIT_NONE then return nil end
        if quantity == "current" and unit ~= UNIT_AMPERE and unit ~= UNIT_MILLIAMPERE and unit ~= UNIT_NONE then return nil end
        if quantity == "capacity" and unit ~= UNIT_MILLIAMPERE_HOUR and unit ~= UNIT_AMPERE_HOUR and unit ~= UNIT_NONE then return nil end
        if quantity == "percent" then
            -- Accept explicitly labelled raw percent sources, never arbitrary voltage/current.
            if unit ~= UNIT_PERCENT then
                local labelOK, label = pcall(function() return source:stringUnit() end)
                if unit ~= UNIT_NONE or not labelOK or type(label) ~= "string" or label:gsub("%s", "") ~= "%" then return nil end
            end
            if value < 0 or value > 100 then return nil end
        end
        if quantity == "voltage" and unit == UNIT_MILLIVOLT then value = value / 1000
        elseif quantity == "current" and unit == UNIT_MILLIAMPERE then value = value / 1000
        elseif quantity == "capacity" and unit == UNIT_AMPERE_HOUR then value = value * 1000 end
        return value
    end
    local function details(source, name, label)
        source = selectedSource(source)
        local result = {name = name, label = label, decimals = 0, unit = nil}
        if source then
            local ok, n, l, d, u = pcall(function()
                return source:name(), source:stringUnit(), source:decimals(), source:unit()
            end)
            if ok then
                if type(n) == "string" and n ~= "" then result.name = n end
                if type(l) == "string" then result.label = l end
                if finite(d) then result.decimals = clamp(d, 0, 3) end
                result.unit = u
            end
        end
        return result
    end
    local function sourceDetails(source, name, label)
        local value = details(source, name, label)
        return value.name, value.label, value.decimals
    end
    local function rfDetails(source, name)
        source = selectedSource(source)
        if not source then return name, "dB" end
        local value = details(source, name, "")
        return value.name, value.unit == UNIT_PERCENT and "%" or value.unit == UNIT_DB and "dB" or "?"
    end
    local function metadata(widget, slot, source, clock, name, label, rf)
        if not validWidget(widget) then return name, rf and (not source and "dB" or "?") or label, 0 end
        local cache = widget.metadata or {}
        widget.metadata = cache
        local previous = cache[slot]
        local cached = previous
        if not cached or cached.source ~= source or clock < cached.clock or clock >= cached.clock + 5 then
            cached = details(source, name, label)
            cached.source, cached.clock = source, clock
        end
        local canonicalUnit = cached.unit
        if validWidget(widget) and source ~= nil and source ~= false and source ~= "" then
            local ok, unit = pcall(function() return source:unit() end)
            canonicalUnit = ok and unit or nil -- canonical units must stay live
        end
        -- Native source calls can reenter changed/destroy or refresh this slot.
        -- Publish only into the same live cache; never revive invalidated state.
        if validWidget(widget) and widget.metadata == cache and cache[slot] == previous then
            cached.unit = canonicalUnit
            cache[slot] = cached
        end
        local unit = cached.label
        if rf then unit = not source and "dB"
            or canonicalUnit == UNIT_PERCENT and "%" or canonicalUnit == UNIT_DB and "dB" or "?" end
        return cached.name, unit, cached.decimals
    end
    -- Monotonic consumed-mAh high-water mark, separate from flight qualification.
    -- A sustained loss of a configured pack voltage is the same boundary as the log.
    local function batteryUsed(widget, slot, source, voltageSource, voltage, used, capacity, clock, key)
        widget.batteryStates = widget.batteryStates or {}
        local state = widget.batteryStates[slot]
        if not state or state.source ~= source or state.voltageSource ~= voltageSource
            or state.capacity ~= capacity or state.key ~= key then
            state = {source = source, voltageSource = voltageSource, capacity = capacity, key = key}
            widget.batteryStates[slot] = state
        end
        if selectedSource(voltageSource) then
            if voltage == nil then
                if not state.lossSince or clock < state.lossSince then state.lossSince = clock end
                if clock - state.lossSince >= widget.endDelay then state.newPack = true end
            else
                if state.newPack then state.high, state.uncertain, state.newPack = nil, nil, nil end
                state.lossSince = nil
            end
        end
        if used ~= nil then
            local tolerance = math.max(1, capacity * 0.001)
            if state.high and used + tolerance < state.high then state.uncertain = true end
            state.high = math.max(state.high or used, used)
        end
        return not state.uncertain and used or nil, state.uncertain == true
    end
    -- Cooldowns survive brief missing data, recovery and appearance edits.
    local function alarmReady(widget, slot, value, threshold, enabled, clock)
        widget.alertStates = widget.alertStates or {}
        local state = widget.alertStates[slot]
        if not state then state = {}; widget.alertStates[slot] = state end
        if value ~= nil then
            if value <= threshold then state.active = true
            elseif value >= threshold + 2 then state.active = false end
        end
        if not enabled or widget.preview or value == nil or value > threshold then return nil end
        if clock < (widget.audioUntil or 0) or clock < (state.nextDue or 0) then return nil end
        return state
    end
    local function alarmPlayed(widget, state, clock, interval, duration)
        duration = (duration or 0) + 0.5
        state.last, state.nextDue = clock, clock + math.max(interval, duration)
        widget.audioUntil = clock + duration
    end
    -- Strict, checksummed and versioned scalar records; unknown future schemas are read-only.
    local function decodeSettings(key, bytes, limit, digest, identityHex, decode, tag, definitions)
        if type(bytes) ~= "string" or #bytes > limit then return nil end
        local body, check = bytes:match("^(.*\n)CHECK=(%d+)\n$")
        if not body or tonumber(check) ~= digest(body) then return nil end
        local format, identity, sequence, payload = body:match("^(%u+%d+)|(%x+)|(%d+)\n(.*)$")
        sequence = tonumber(sequence)
        if identity ~= identityHex(key) or not sequence or sequence > 1000000000 then return nil end
        if format ~= tag then return nil, "Unsupported settings format; do not downgrade" end
        local values, count, position = {}, 0, 1
        while position <= #payload do
            local ending = payload:find("\n", position, true)
            if not ending then return nil end
            local name, kind, value = payload:sub(position, ending - 1):match("^([%a][%w]*)=([nbs]):(.*)$")
            if not name or values[name] ~= nil then return nil end
            if kind == "n" then value = tonumber(value); if not finite(value) then return nil end
            elseif kind == "b" then
                if value ~= "0" and value ~= "1" then return nil end
                value = value == "1"
            else
                if #value > 512 or #value % 2 ~= 0 or value:find("[^%x]") then return nil end
                value = value:lower():gsub("%x%x", decode)
            end
            values[name], count, position = value, count + 1, ending + 1
        end
        if values.schema ~= 1 then return nil, "Unsupported settings schema; do not downgrade" end
        values.schema, count = nil, count - 1
        if count ~= #definitions then return nil end
        for _, definition in ipairs(definitions) do
            if type(values[definition[1]]) ~= type(definition[2]) then return nil end
        end
        return {values = values, sequence = sequence, payload = payload, format = format}
    end
    -- Fixed-size native-font FIFO. Constant-time eviction; no retained custom fonts.
    local fitCache, fitKeys, fitCount, fitCursor = {}, {}, 0, 0
    local nativeFontHeights = {} -- fixed native font constants only
    local function fitText(value, width, height, customFont, small)
        value = tostring(value)
        local key = not customFont and table.concat({width, height, small and 1 or 0, value}, "|") or nil
        local cached = key and fitCache[key]
        if cached then return cached.font, cached.value, cached.w, cached.h end
        local fonts = small and SMALL_FONTS or VALUE_FONTS
        local chosen, tw, th
        if customFont and not small then
            lcd.font(customFont); tw, th = lcd.getTextSize(value)
            if tw <= width and th <= height then return customFont, value, tw, th end
        end
        for index, font in ipairs(fonts) do
            -- Native font heights do not depend on label width. Do not repeatedly
            -- measure fonts that are already known to be too tall for this field.
            local knownHeight = nativeFontHeights[font]
            if not knownHeight or knownHeight <= height or index == #fonts then
                chosen = font; lcd.font(font); tw, th = lcd.getTextSize(value)
                if not knownHeight then
                    nativeFontHeights[font] = th
                end
                if tw <= width and th <= height then break end
            end
        end
        if tw > width then
            local suffix = "..."
            local ew = lcd.getTextSize(suffix)
            if ew > width then value = ""
            else
                local low, high, best = 0, #value, 0
                while low < high do
                    local middle = math.ceil((low + high) / 2)
                    local boundary = middle
                    local byte = value:byte(boundary + 1)
                    while boundary > 0 and byte and byte >= 128 and byte < 192 do
                        boundary = boundary - 1; byte = value:byte(boundary + 1)
                    end
                    local candidate = value:sub(1, boundary) .. suffix
                    local candidateWidth = lcd.getTextSize(candidate)
                    if candidateWidth <= width then low, best = middle, boundary
                    else high = middle - 1 end
                end
                value = value:sub(1, best) .. suffix
            end
            tw, th = lcd.getTextSize(value)
        end
        if key then
            fitCursor = fitCursor % 64 + 1
            local previous = fitKeys[fitCursor]
            if previous then fitCache[previous] = nil else fitCount = fitCount + 1 end
            fitKeys[fitCursor] = key
            fitCache[key] = {font = chosen, value = value, w = tw, h = th}
        end
        return chosen, value, tw, th
    end
    return {clamp = clamp, round = round, finite = finite, selectedSource = selectedSource,
        getSource = getSource, restoreSource = restoreSource, validWidget = validWidget,
        sample = sample, sourceDetails = sourceDetails, rfDetails = rfDetails, metadata = metadata,
        batteryUsed = batteryUsed, alarmReady = alarmReady, alarmPlayed = alarmPlayed,
        decodeSettings = decodeSettings, fitText = fitText,
        cacheSize = function() return fitCount end}
end)()
local clamp, round, finite = DeckCore.clamp, DeckCore.round, DeckCore.finite
local selectedSource, getSource, restoreSource = DeckCore.selectedSource, DeckCore.getSource, DeckCore.restoreSource
local validWidget, sample = DeckCore.validWidget, DeckCore.sample
local sourceDetails, rfDetails = DeckCore.sourceDetails, DeckCore.rfDetails


-- changed() invalidates the active poll as well as scheduling the next one.
local function validPoll(widget)
    return validWidget(widget) and widget.nextPoll ~= 0
end

local function changed(widget, resetAlarm)
    if not validWidget(widget) then return end
    widget.refresh = true
    widget.nextPoll = 0
    widget.metadata = nil
    if resetAlarm then widget.checkedSound = nil end
    pcall(model.dirty)
end

local function themeColor(index, fallback)
    if index ~= nil then
        local ok, color = pcall(lcd.themeColor, index)
        if ok and finite(color) then return color end
    end
    return fallback
end

local function palette(widget)
    local background = COLORS.black
    local foreground = COLORS.white
    local secondary = COLORS.muted
    local accent = widget.accentColor
    if widget.backgroundMode == 1 then
        background = themeColor(THEME_PAGE_BGCOLOR or THEME_DEFAULT_BGCOLOR, COLORS.black)
        foreground = themeColor(THEME_PRIMARY_COLOR or THEME_DEFAULT_COLOR, COLORS.white)
        secondary = themeColor(THEME_SECONDARY_COLOR, foreground)
        accent = themeColor(THEME_HIGHLIGHT_COLOR or THEME_FOCUS_COLOR, accent)
    elseif widget.backgroundMode == 3 then
        background = widget.backgroundColor
        local ok, contrast = pcall(lcd.getContrastingColor, background)
        if ok and finite(contrast) then foreground = contrast end
        secondary = foreground
    end
    local colors = widget.colors or {}
    colors.background, colors.foreground, colors.secondary = background, foreground, secondary
    colors.accent, colors.border, colors.track = accent, COLORS.border, COLORS.track
    widget.colors = colors
    return colors
end

local function create()
    local widget = {imageDirty = true, fontDirty = true, data = {}, scratch = {}, nextPoll = 0, refresh = true}
    for _, definition in ipairs(SETTING_DEFS) do widget[definition[1]] = definition[2] end
    widget.timerSource = getSource({category = CATEGORY_TIMER, member = 0})
    widget.builtinTx = getSource({category = CATEGORY_SYSTEM, member = SYSTEM_MAIN_VOLTAGE or MAIN_VOLTAGE})
    return widget
end

local function header(path, count)
    local ok, file = pcall(io.open, path, "rb")
    if not ok or not file then return nil end
    local readOK, bytes = pcall(io.read, file, count)
    pcall(io.close, file)
    if readOK and type(bytes) == "string" then return bytes end
end

local function modelKey()
    local ok, path = pcall(model.path)
    if ok and type(path) == "string" and path ~= "" and #path <= 256 then return path end
end

local function digest(value)
    local result, length = 5381, #value
    -- Four DJB2 steps at once, exactly representable below 2^52.
    -- This preserves existing filenames/checksums with far fewer VM instructions.
    local bulk = length - length % 4
    for index = 1, bulk, 4 do
        local a, b, c, d = value:byte(index, index + 3)
        result = (result * 1185921.0 + a * 35937.0 + b * 1089.0 + c * 33.0 + d) % 2147483647
    end
    for index = bulk + 1, length do result = (result * 33.0 + value:byte(index)) % 2147483647 end
    return math.floor(result)
end

local HEX_ENCODE, HEX_DECODE = {}, {}
for byte = 0, 255 do
    local character, encoded = string.char(byte), string.format("%02x", byte)
    HEX_ENCODE[character], HEX_DECODE[encoded] = encoded, character
end

local function identityHex(value)
    -- Table replacement runs inside Lua's string library, not a callback per byte.
    return (value:gsub(".", HEX_ENCODE))
end


-- Scalar settings belong to the model, not to a particular widget instance.
-- Native ETHOS storage retains only compact, strongly typed source references.
local SOURCE_KEYS = {}
for _, field in ipairs(SOURCE_FIELDS) do SOURCE_KEYS[#SOURCE_KEYS + 1] = field.key end
for _, key in ipairs({"bottomSource", "rpmSource", "armSource", "throttleSource",
    "airborneSource", "graph1Source", "graph2Source"}) do SOURCE_KEYS[#SOURCE_KEYS + 1] = key end
local CONFIG_LIMIT = 4096
local CONFIG_STATE

local function configRecord(key, bytes)
    local current = type(bytes) == "string" and bytes:match("^VD6|") ~= nil
    return DeckCore.decodeSettings(key, bytes, CONFIG_LIMIT, digest, identityHex, HEX_DECODE,
        current and "VD6" or "VD5", current and SETTING_DEFS or PREVIOUS_SETTING_DEFS)
end

local function configLoad(key)
    if not key then return nil, nil, "Model path unavailable" end
    local base = "/scripts/vc3" .. tostring(digest(key))
    local a, b = header(base .. "a.cfg", CONFIG_LIMIT + 1), header(base .. "b.cfg", CONFIG_LIMIT + 1)
    local function generation(bytes)
        if not bytes or #bytes > CONFIG_LIMIT then return -1 end
        local format, identity, sequence = bytes:match("^(VD%d+)|(%x+)|(%d+)\n")
        if identity ~= identityHex(key) then return -1 end
        sequence = tonumber(sequence)
        return sequence and sequence <= 1000000000 and sequence or -1
    end
    -- Fully validate newest first; inspect the older copy only for recovery.
    if generation(b) > generation(a) then a, b = b, a end
    local latest, formatProblem = configRecord(key, a)
    if formatProblem then CONFIG_STATE = nil; return nil, base, formatProblem end
    if not latest then latest, formatProblem = configRecord(key, b) end
    if formatProblem then CONFIG_STATE = nil; return nil, base, formatProblem end
    if not latest and (a or b) then
        CONFIG_STATE = nil
        return nil, base, "Settings files invalid; restore backup"
    end
    CONFIG_STATE = {key = key, base = base, record = latest}
    return latest, base
end

local function configPayload(widget)
    local lines = {}
    for _, key in ipairs(SETTINGS) do
        local value, kind = widget[key]
        if type(value) == "boolean" then kind, value = "b", value and "1" or "0"
        elseif finite(value) then kind, value = "n", string.format("%.0f", value)
        elseif type(value) == "string" and #value <= 256 then kind, value = "s", identityHex(value)
        else return nil end
        lines[#lines + 1] = key .. "=" .. kind .. ":" .. value .. "\n"
    end
    return "schema=n:1\n" .. table.concat(lines)
end

local function configSave(widget)
    local key = modelKey()
    if key ~= widget.configKey or not key then return false, "Model changed; reopen widget" end
    -- Refresh disk state in read(), never reparse both files on every save.
    -- External simulator-file changes are supported only while it is closed.
    if widget.configError and not CONFIG_STATE then return false, widget.configError end
    if not CONFIG_STATE or CONFIG_STATE.key ~= key then return false, "Reopen widget before saving" end
    local record, base = CONFIG_STATE.record, CONFIG_STATE.base
    local payload = configPayload(widget)
    if not payload then return false, "Invalid or oversized setting" end
    if record and record.payload == payload then widget.configPayload = payload; return true end
    if record and record.payload ~= widget.configPayload then return false, "Settings changed in another instance; reopen" end
    local sequence = (record and record.sequence or 0) + 1
    if sequence > 1000000000 then return false, "Settings generation limit reached" end
    local body = "VD6|" .. identityHex(key) .. "|" .. sequence .. "\n" .. payload
    local bytes = body .. "CHECK=" .. tostring(digest(body)) .. "\n"
    if #bytes > CONFIG_LIMIT then return false, "Settings file too large" end
    local path = base .. (sequence % 2 == 1 and "a.cfg" or "b.cfg")
    local ok, handle = pcall(io.open, path, "w")
    if not ok or not handle then return false, "Cannot open settings file" end
    local written = pcall(io.write, handle, bytes)
    local closed = pcall(io.close, handle)
    if not written or not closed or header(path, CONFIG_LIMIT + 1) ~= bytes then
        return false, "Settings write failed; previous copy retained"
    end
    CONFIG_STATE.record = {sequence = sequence, payload = payload}
    widget.configPayload, widget.configPath = payload, path
    print("VoltDeck settings saved: " .. path)
    return true
end

local settingValues
local function settingRead(key)
    if settingValues then return settingValues[key] end
    return storage.read(key)
end

local function numberSetting(key, default, minimum, maximum)
    local definition = SETTING_MAP[key]
    if definition and definition[3] then minimum, maximum = definition[3], definition[4] end
    local value = settingRead(key)
    if finite(value) then return round(clamp(value, minimum, maximum)) end
    return default
end

local function read(widget)
    if not validWidget(widget) then return end
    widget.configKey = modelKey()
    local record, base, problem = configLoad(widget.configKey)
    widget.configError, widget.configPath = problem, base
    widget.configPayload = record and record.payload or nil
    -- Current source schema only. Scalar settings use this major version's namespace.
    local first, native = storage.read("v"), {}
    if first == "VD4" then
        for index, key in ipairs(SOURCE_KEYS) do native[key] = storage.read(string.char(96 + index)) end
    elseif first ~= nil then
        widget.configError = "Unsupported source storage; reselect sources"
    end
    settingValues = record and record.values or {}
    widget.chemistry = numberSetting("chemistry", 1, 1, #TYPES)
    widget.cellCount = numberSetting("cellCount", 6, 1, 16)
    widget.capacityMah = numberSetting("capacityMah", 2500, 100, 100000)
    widget.alertInterval = numberSetting("alertInterval", 10, 1, 600)
    widget.mahDisplay = numberSetting("mahDisplay", 1, 1, 2)
    widget.alarmEnabled = settingRead("alarmEnabled") ~= false
    local sound = settingRead("alarmSound")
    widget.alarmSound = type(sound) == "string" and sound or ""
    local folder = settingRead("audioFolder")
    widget.audioFolder = type(folder) == "string" and folder ~= "" and folder or "/audio"
    widget.backgroundMode = numberSetting("backgroundMode", 1, 1, 3)
    for _, key in ipairs({"backgroundColor", "accentColor"}) do
        local value = settingRead(key)
        if finite(value) then widget[key] = value end
    end
    widget.bottomDisplay = numberSetting("bottomDisplay", 2, 1, 2)
    widget.bottomMinimum = numberSetting("bottomMinimum", 0, -100000, 999999)
    widget.bottomMaximum = numberSetting("bottomMaximum", 100, -99999, 1000000)
    widget.bottomMaximum = math.max(widget.bottomMinimum + 1, widget.bottomMaximum)
    widget.bottomDecimals = numberSetting("bottomDecimals", -1, -1, 3)
    widget.redZone = numberSetting("redZone", 85, 10, 100)
    widget.signalMinimum = numberSetting("signalMinimum", 0, -150, 199)
    widget.signalMaximum = numberSetting("signalMaximum", 100, -149, 200)
    widget.signalMaximum = math.max(widget.signalMinimum + 1, widget.signalMaximum)
    widget.preview = settingRead("preview") == true
    for _, key in ipairs({"imageName", "bottomLabel", "fontPath"}) do
        local value = settingRead(key)
        widget[key] = type(value) == "string" and value or ""
    end
    widget.imageMode = numberSetting("imageMode", 1, 1, 3)
    widget.alarmEstimate = settingRead("alarmEstimate") == true
    widget.batteryMethod = numberSetting("batteryMethod", 1, 1, 3)
    for _, key in ipairs(SOURCE_KEYS) do
        local value = native[key]
        if key ~= "timerSource" or value ~= nil then widget[key] = restoreSource(value) end
    end
    local options = {
        {"deckMode", 6, 1, 8}, {"customPosition", 3, 1, 3},
        {"rpmMode", 1, 1, 2}, {"motorKV", 0, 0, 10000},
        {"loadFactor", 100, 10, 100}, {"rpmScale", 1, 1, 2},
        {"rpmMaximum", 12000, 1000, 200000}, {"wattMaximum", 2000, 10, 100000},
        {"cellMaximum", 440, 200, 500}, {"flightMinimum", 60, 60, 3600},
        {"throttleThreshold", 50, 10, 100}, {"highThrottleSeconds", 5, 1, 120},
        {"endDelay", 10, 3, 120}, {"throttleMinimum", -1024, -2048, 2047},
        {"throttleMaximum", 1024, -2047, 2048}, {"rfWarnDB", 35, -149, 200},
        {"rfCriticalDB", 32, -150, 199}, {"rfWarnPercent", 95, 1, 100},
        {"rfCriticalPercent", 50, 0, 99},
    }
    for _, option in ipairs(options) do widget[option[1]] = numberSetting(option[1], option[2], option[3], option[4]) end
    local profileDefault = 1
    widget.rf1Profile = numberSetting("rf1Profile", profileDefault, 1, 3)
    widget.rf2Profile = numberSetting("rf2Profile", profileDefault, 1, 3)
    widget.rf2WarnDB = numberSetting("rf2WarnDB", widget.rfWarnDB, -149, 200)
    widget.rf2CriticalDB = numberSetting("rf2CriticalDB", widget.rfCriticalDB, -150, 199)
    widget.rf2WarnPercent = numberSetting("rf2WarnPercent", widget.rfWarnPercent, 1, 100)
    widget.rf2CriticalPercent = numberSetting("rf2CriticalPercent", widget.rfCriticalPercent, 0, 99)
    widget.logEnabled = settingRead("logEnabled") == true
    widget.autoLogEnabled = settingRead("autoLogEnabled") == true
    widget.autoLogDelay = numberSetting("autoLogDelay", 5, 0, 120)
    widget.autoLogSession, widget.autoLogSeen, widget.autoLogDue = nil, nil, nil
    if widget.throttleMaximum <= widget.throttleMinimum then widget.throttleMaximum = widget.throttleMinimum + 1 end
    if widget.rfCriticalDB > widget.rfWarnDB then widget.rfCriticalDB = widget.rfWarnDB end
    if widget.rfCriticalPercent > widget.rfWarnPercent then widget.rfCriticalPercent = widget.rfWarnPercent end
    widget.rf2CriticalDB = math.min(widget.rf2CriticalDB, widget.rf2WarnDB)
    widget.rf2CriticalPercent = math.min(widget.rf2CriticalPercent, widget.rf2WarnPercent)
    settingValues = nil
    widget.imageDirty, widget.fontDirty = true, true
    changed(widget)
end

local function write(widget)
    if not validWidget(widget) then return end
    local ok, problem = configSave(widget)
    widget.configError = not ok and problem or nil
    if not ok then print("VoltDeck settings NOT saved: " .. problem) end
    -- Header and sources must be read/written in this exact order.
    storage.write("v", "VD4")
    for index, key in ipairs(SOURCE_KEYS) do storage.write(string.char(96 + index), widget[key] or "") end
end





-- Source names and canonical units remain available without a live reading.


-- Visual profiles only; a frequency label cannot identify the radio protocol.
local function rfLimits(widget, unit, channel)
    local second = channel == 2
    local profile = second and widget.rf2Profile or widget.rf1Profile
    local warning, critical
    if unit == "%" then
        warning = second and widget.rf2WarnPercent or widget.rfWarnPercent
        critical = second and widget.rf2CriticalPercent or widget.rfCriticalPercent
        if profile ~= 3 then warning, critical = 95, 50 end
    else
        warning = second and widget.rf2WarnDB or widget.rfWarnDB
        critical = second and widget.rf2CriticalDB or widget.rfCriticalDB
        if profile == 1 then warning, critical = 35, 32
        elseif profile == 2 then warning, critical = 45, 42 end
    end
    return unit == "%" and 0 or widget.signalMinimum,
        unit == "%" and 100 or widget.signalMaximum, warning, critical,
        profile == 1 and "ACCESS/TD/TW" or profile == 2 and "ACCST" or "Custom"
end

-- ETHOS uses io.read(handle, byteCount), not the standard Lua file:read().
-- Only resource changes perform file I/O; no file is left open on an error.
local function integer(bytes, offset, count, little)
    if not bytes or offset + count - 1 > #bytes then return nil end
    local value = 0
    for index = 0, count - 1 do
        local position = little and offset + count - 1 - index or offset + index
        value = value * 256 + bytes:byte(position)
    end
    return value
end

local function imagePath(name)
    if type(name) ~= "string" then return "" end
    name = name:gsub("\\", "/")
    if name == "" or name:sub(-1) == "/" or name:find("..", 1, true) then return "" end
    name = name:gsub("^BITMAPS:/", "/bitmaps/")
    if not name:find("/", 1, true) and not name:find(":", 1, true) then
        name = "/bitmaps/models/" .. name
    end
    return name
end

local function imageSize(bytes)
    if not bytes then return nil, nil, "Image file unavailable" end
    if bytes:sub(1, 8) == "\137PNG\r\n\26\n" and bytes:sub(13, 16) == "IHDR" then
        local depth, kind = bytes:byte(25), bytes:byte(26)
        if depth ~= 8 or (kind ~= 2 and kind ~= 6) then
            return nil, nil, "Use 8-bit RGB/RGBA PNG"
        end
        return integer(bytes, 17, 4), integer(bytes, 21, 4)
    elseif bytes:sub(1, 2) == "BM" then
        local height = integer(bytes, 23, 4, true)
        -- Top-down BITMAPV4 files stalled this simulator's native decoder.
        if height and height >= 2147483648 then
            return nil, nil, "Top-down BMP not supported; use PNG"
        end
        return integer(bytes, 19, 4, true), height
    elseif bytes:sub(1, 2) == "\255\216" then
        -- Bounded JPEG SOF search. Refuse unusual headers instead of a blind allocation.
        local position = 3
        while position + 8 <= #bytes do
            if bytes:byte(position) ~= 255 then return nil, nil, "Invalid JPEG header" end
            local marker = bytes:byte(position + 1)
            if marker == 255 then position = position + 1
            elseif marker == 216 or marker == 1 or (marker >= 208 and marker <= 215) then
                position = position + 2
            else
                local length = integer(bytes, position + 2, 2)
                if not length or length < 2 then break end
                if marker >= 192 and marker <= 207 and marker ~= 196 and marker ~= 200 and marker ~= 204 then
                    return integer(bytes, position + 7, 2), integer(bytes, position + 5, 2)
                end
                if marker == 218 or marker == 217 then break end
                position = position + length + 2
            end
        end
        return nil, nil, "JPEG header too long; use PNG"
    end
    return nil, nil, "Unsupported image header"
end

local function collectResources()
    if type(collectgarbage) == "function" then pcall(collectgarbage, "collect") end
end

local function memory()
    local ok, result = pcall(system.getMemoryUsage)
    if ok and type(result) == "table" then return result end
    return {}
end

local function updateResources(widget)
    local requested = widget.imageName
    if widget.imageMode == 1 then
        local ok, name = pcall(model.bitmap)
        requested = ok and name or ""
    elseif widget.imageMode == 3 then requested = "" end
    local path = imagePath(requested)
    if widget.loadedImagePath ~= path then widget.imageDirty = true end
    if widget.imageDirty then
        widget.modelImage, widget.imageError, widget.imagePixels = nil, nil, 0
        widget.imageDirty, widget.loadedImagePath = false, path
        widget.refresh = true
        collectResources()
        if path ~= "" then
            local width, height, problem = imageSize(header(path, 4096))
            if not width or not height or width < 1 or height < 1 then
                widget.imageError = problem or "Invalid image dimensions"
            elseif width > 800 or height > 480 or width * height > MAX_IMAGE_PIXELS then
                widget.imageError = "Max 160k pixels; try 290x191"
            else
                widget.imagePixels, widget.imageWidth, widget.imageHeight = width * height, width, height
                widget.modelImage = BITMAP_CACHE[path]
                if not widget.modelImage then
                    local available = memory().luaBitmapsRamAvailable
                    -- Allow for transparency/decoder overhead and leave a reserve.
                    if finite(available) and available < width * height * 4 + BITMAP_RESERVE then
                        widget.imageError = "Not enough bitmap memory"
                    else
                        local ok, bitmap = pcall(lcd.loadBitmap, path, false)
                        if ok and bitmap then
                            widget.modelImage, BITMAP_CACHE[path] = bitmap, bitmap
                        else widget.imageError = "Image could not be decoded" end
                    end
                end
            end
            if widget.imageError then print("VoltDeck: " .. widget.imageError .. " [" .. path .. "]") end
        end
    end
    if widget.fontDirty then
        widget.valueFont, widget.fontDirty = nil, false
        collectResources()
        if widget.fontPath ~= "" then
            local available = memory().luaRamAvailable
            if not finite(available) or available > 131072 then
                local ok, font = pcall(lcd.loadFont, widget.fontPath)
                if ok and finite(font) then widget.valueFont = font end
            end
        end
    end
end

local function voltagePercent(widget, voltage)
    if not voltage or voltage <= 0 then return nil end
    local chemistry = TYPES[widget.chemistry]
    return clamp((voltage / widget.cellCount - chemistry.empty)
        * 100 / (chemistry.full - chemistry.empty), 0, 100)
end

local function normalizeAudioFolder(folder)
    folder = type(folder) == "string" and folder or ""
    folder = folder:gsub("\\", "/"):gsub("/+$", "")
    if folder == "" then return "/audio" end
    if folder:sub(1, 1) ~= "/" and not folder:match("^%a+:") then folder = "/" .. folder end
    return folder
end

local function audioPath(folder, filename)
    if type(filename) ~= "string" or filename == "" then return "" end
    filename = filename:gsub("\\", "/")
    local path = filename
    if filename:sub(1, 1) ~= "/" and not filename:match("^%a+:") then
        path = normalizeAudioFolder(folder) .. "/" .. filename
    end
    if not path:lower():match("%.wav$") then path = path .. ".wav" end
    return path
end

local function audioInfo(path)
    local bytes = header(path, 4096)
    if not bytes or bytes:sub(1, 4) ~= "RIFF" or bytes:sub(9, 12) ~= "WAVE" then return nil end
    local position, rate, valid = 13, nil, false
    while position + 7 <= #bytes do
        local kind = bytes:sub(position, position + 3)
        local length = integer(bytes, position + 4, 4, true)
        if not length then return nil end
        if kind == "fmt " and length >= 16 then
            valid = integer(bytes, position + 8, 2, true) == 1
                and integer(bytes, position + 10, 2, true) == 1
                and integer(bytes, position + 12, 4, true) == 32000
                and integer(bytes, position + 22, 2, true) == 16
            rate = integer(bytes, position + 16, 4, true)
        elseif kind == "data" then
            if valid and rate == 64000 and length > 0 then return length / rate end
            return nil
        end
        position = position + 8 + length + length % 2
    end
end


-- Computed values are read-only: never create or change the user's sensors/mixes.
local function switchOn(source)
    local category
    source, category = selectedSource(source)
    if not source then return false end
    -- Always on is unconditional, not a positive analog value.
    if CATEGORY_ALWAYS_ON ~= nil and category == CATEGORY_ALWAYS_ON then return true, true end
    local ok, value = pcall(function() return source:value() end)
    if not ok then return false, nil end
    -- Generic state() is validity for some sources: valid does not imply ON.
    return value == true or (finite(value) and value > 0), value
end

local function armIsOff(source)
    local selected, category = selectedSource(source)
    if not selected or (CATEGORY_ALWAYS_ON ~= nil and category == CATEGORY_ALWAYS_ON) then return false end
    local ok, active, raw = pcall(function() return selected:state(), selected:value() end)
    if not ok or (active == false and category == CATEGORY_TELEMETRY_SENSOR) then return false end
    return raw == false or (finite(raw) and raw <= 0)
end

local function clearPackCheckWindow(state)
    state.idleSince, state.minimum, state.maximum = nil, nil, nil
    state.ready, state.sample = false, nil
end

local function samePackSetup(widget, state, key)
    return state and state.key == key and state.source == widget.consumptionSource
        and state.voltageSource == widget.voltageSource and state.currentSource == widget.currentSource
        and state.armSource == widget.armSource and state.capacity == widget.capacityMah
        and state.cells == widget.cellCount and state.chemistry == widget.chemistry
        and state.method == widget.batteryMethod and state.endDelay == widget.endDelay
end
local function samePackCheck(widget, state, generation)
    return validPoll(widget) and widget.packCheckState == state and not widget.preview
        and samePackSetup(widget, state, state.key) and widget.configGeneration == generation
        and widget.batteryMethod == 1
        and (widget.batteryStates and widget.batteryStates.Pack) == state.pack
end

local function packCheckCurrent(widget)
    return math.min(PACK_CHECK_MAX_CURRENT, widget.capacityMah / 20000)
end

local function packReferenceBP(chemistry, cellMv)
    local curve = chemistry.checkCurve
    if not curve then return nil end
    if cellMv <= curve[1] then return 0 end
    for index = 2, #curve do
        if cellMv <= curve[index] then
            return round((PACK_OCV_SOC[index - 1] + (cellMv - curve[index - 1])
                * (PACK_OCV_SOC[index] - PACK_OCV_SOC[index - 1])
                / (curve[index] - curve[index - 1])) * 100)
        end
    end
    return 10000
end

local function packDecision(widget, voltage, used)
    local chemistry = TYPES[widget.chemistry]
    local cellMv = round(voltage * 1000 / widget.cellCount)
    local counterBP = round(clamp((widget.capacityMah - used) / widget.capacityMah, 0, 1) * 10000)
    local referenceBP = packReferenceBP(chemistry, cellMv)
    local deltaBP = referenceBP and counterBP - referenceBP or nil
    local band = "manual"
    if cellMv > round(chemistry.full * 1000) + 150 then band = "cells"
    elseif deltaBP and math.abs(deltaBP) > PACK_CHECK_MANUAL_BP then band = "blocked"
    elseif deltaBP and math.abs(deltaBP) <= PACK_CHECK_AUTO_BP then band = "auto" end
    return {cellMv = cellMv, counterBP = counterBP, referenceBP = referenceBP,
        deltaBP = deltaBP, band = band}
end

local function packDifference(decision)
    return decision.deltaBP and math.ceil(math.abs(decision.deltaBP) / 10) / 10 or nil
end

local function samePackDecision(a, b)
    return a and b and a.band == b.band and packDifference(a) == packDifference(b)
        and round(a.counterBP / 10) == round(b.counterBP / 10)
        and (a.referenceBP and round(a.referenceBP / 10))
            == (b.referenceBP and round(b.referenceBP / 10))
end

local function packUnitsValid(state)
    local ok, vu, cu = pcall(function()
        return state.voltageSource:unit(), state.currentSource:unit()
    end)
    return ok and (vu == UNIT_VOLT or vu == UNIT_MILLIVOLT)
        and (cu == UNIT_AMPERE or cu == UNIT_MILLIAMPERE)
end

local function packArmIdle(source)
    local selected, category = selectedSource(source)
    -- Always ON qualifies the flight log, but is not a physical ARM indication.
    return not selected or (CATEGORY_ALWAYS_ON ~= nil and category == CATEGORY_ALWAYS_ON)
        or armIsOff(selected)
end

-- Qualify one battery episode, then use its monotonic counter during flight.
-- No voltage/percentage comparison is made after qualification. A reset, long
-- telemetry gap or battery setup change starts a fresh low-load check.
local function checkBatteryCounter(widget, data, used, clock, key, newPack)
    local pack = widget.batteryStates and widget.batteryStates.Pack
    local state, generation = widget.packCheckState, widget.configGeneration
    local sameSetup = samePackSetup(widget, state, key)
    local expired = state and state.lossSince and data.voltage ~= nil
        and clock - state.lossSince >= widget.endDelay
    local clockChanged = state and state.lastClock and (clock < state.lastClock
        or clock - state.lastClock >= widget.endDelay)
    if not sameSetup or newPack or state.pack ~= pack or state.recheck or expired or clockChanged then
        local holdUntil = sameSetup and state.holdUntil or nil
        if state and state.lastClock and clock < state.lastClock and holdUntil then
            holdUntil = clock + PACK_CHECK_RELAX_SECONDS
        end
        state = {pack = pack, key = key, source = widget.consumptionSource,
            voltageSource = widget.voltageSource, currentSource = widget.currentSource,
            armSource = widget.armSource, capacity = widget.capacityMah,
            cells = widget.cellCount, chemistry = widget.chemistry, holdUntil = holdUntil,
            method = widget.batteryMethod, endDelay = widget.endDelay}
        widget.packCheckState = state
    end
    if state.lastClock and clock - state.lastClock > 1 then clearPackCheckWindow(state) end
    state.lastClock = clock
    if widget.batteryMethod ~= 1 then clearPackCheckWindow(state); return used end
    if data.current ~= nil and data.current > packCheckCurrent(widget) then
        state.holdUntil = clock + PACK_CHECK_RELAX_SECONDS
    end
    if data.voltage == nil then
        state.lossSince = state.lossSince or clock
        if clock - state.lossSince >= widget.endDelay then state.qualified = nil end
        clearPackCheckWindow(state)
        data.packCheckPending = true
        return nil
    end
    state.lossSince = nil
    if pack and pack.uncertain and not state.requiresCounterAcceptance then
        state.qualified, state.requiresCounterAcceptance, state.problem = nil, true, nil
        clearPackCheckWindow(state)
    end
    local unitsOK = packUnitsValid(state)
    if not samePackCheck(widget, state, generation) then
        if validWidget(widget) then widget.nextPoll = 0 end
        return nil
    end
    if not unitsOK or not key or data.used == nil then
        clearPackCheckWindow(state); data.packCheckPending = true; return nil
    end
    if state.qualified then return used end
    data.packCheckPending = true
    if data.current == nil or data.current < 0 or data.current > packCheckCurrent(widget) then
        clearPackCheckWindow(state); return nil
    end
    local idleArm = packArmIdle(state.armSource)
    if not samePackCheck(widget, state, generation) then
        if validWidget(widget) then widget.nextPoll = 0 end
        return nil
    end
    if not idleArm then
        state.holdUntil = clock + PACK_CHECK_RELAX_SECONDS
        clearPackCheckWindow(state); return nil
    end
    if state.holdUntil and clock < state.holdUntil then clearPackCheckWindow(state); return nil end
    local decision = packDecision(widget, data.voltage, data.used)
    if not state.idleSince or state.candidate ~= decision.band
        or math.max(state.maximum or decision.cellMv, decision.cellMv)
            - math.min(state.minimum or decision.cellMv, decision.cellMv) > PACK_CHECK_STABILITY_MV then
        state.idleSince, state.minimum, state.maximum, state.candidate = clock,
            decision.cellMv, decision.cellMv, decision.band
        state.ready, state.sample, state.problem = false, nil, nil
    else
        state.minimum, state.maximum = math.min(state.minimum, decision.cellMv),
            math.max(state.maximum, decision.cellMv)
    end
    if clock - state.idleSince >= PACK_CHECK_SECONDS then
        state.ready, state.sample = true, decision
        if decision.band == "auto" and not state.requiresCounterAcceptance then
            state.qualified, state.problem, data.packCheckPending = true, nil, nil
            return used
        end
        state.problem = decision.band == "cells" and "cells"
            or (decision.referenceBP == nil and "profile" or "counter")
        data.packCheck, data.packCheckPending = state.problem, nil
    end
    return nil
end

local function throttlePercent(widget)
    local value = sample(widget.throttleSource, "control")
    if value == nil then return nil end
    return clamp((value - widget.throttleMinimum) * 100
        / math.max(1, widget.throttleMaximum - widget.throttleMinimum), 0, 100), value
end

local function counterRecord(session, bytes)
    if not bytes then return nil end
    local identity, sequence, count, check = bytes:match("^VD2|(%x+)|(%d+)|(%d+)|(%d+)\n$")
    if not identity then return nil end
    local body = "VD2|" .. identity .. "|" .. sequence .. "|" .. count .. "|"
    if tonumber(check) ~= digest(body) then return nil end
    if identity ~= session.identity then session.storeBlocked = true; return nil end
    sequence, count = tonumber(sequence), tonumber(count)
    if not sequence or sequence > 1000000000 or not count or count > 999999 then return nil end
    return {sequence = sequence, count = count}
end

local function newSession(key)
    local session = {key = key, identity = identityHex(key), count = 0, sequence = 0,
        revision = 0, retryAt = 0, attempts = 0}
    session.basePath = "/scripts/vd" .. string.format("%08x", digest(key))
    local aBytes, bBytes = header(session.basePath .. "a.dat", 1024), header(session.basePath .. "b.dat", 1024)
    local a, b = counterRecord(session, aBytes), counterRecord(session, bBytes)
    local latest = a
    if b and (not a or b.sequence > a.sequence) then latest = b end
    if latest then session.count, session.sequence = latest.count, latest.sequence
    elseif aBytes or bBytes then session.storeBlocked = true end
    if session.storeBlocked then session.error = "Counter file invalid" end
    return session
end

-- Two alternating, checked slots retain the last valid count across an interrupted
-- write/reset. Only the tiny counter is persisted; all graphs and stats stay in RAM.
local function saveCounter(session)
    if session.storeBlocked then return false end
    local sequence = session.sequence + 1
    local body = "VD2|" .. session.identity .. "|" .. sequence .. "|" .. session.count .. "|"
    local bytes = body .. digest(body) .. "\n"
    local path = session.basePath .. (sequence % 2 == 1 and "a.dat" or "b.dat")
    local ok, handle = pcall(io.open, path, "w")
    if not ok or not handle then session.error = "Counter save failed"; return false end
    local wrote = pcall(io.write, handle, bytes)
    local closed = pcall(io.close, handle)
    if wrote and closed and header(path, 1024) == bytes then
        session.sequence, session.error, session.pending = sequence, nil, false
        return true
    end
    session.error = "Counter save failed"
    return false
end

local function minimum(a, b)
    if a == nil then return b end
    if b == nil then return a end
    return math.min(a, b)
end

local function graphSample(flight, clock, rf1, rf2)
    local history = flight.history
    history.low1, history.low2 = minimum(history.low1, rf1), minimum(history.low2, rf2)
    history.gap1, history.gap2 = history.gap1 or rf1 == nil, history.gap2 or rf2 == nil
    if clock < history.next then return false end
    if history.count == HISTORY_POINTS then
        -- Pairwise minimum compression keeps brief low-signal events, never averages
        -- them away. Gap flags prevent a line claiming reception across missing data.
        for index = 1, HISTORY_POINTS / 2 do
            local a, b = index * 2 - 1, index * 2
            history.rf1[index] = minimum(history.rf1[a], history.rf1[b])
            history.rf2[index] = minimum(history.rf2[a], history.rf2[b])
            history.missing1[index] = history.missing1[a] or history.missing1[b]
            history.missing2[index] = history.missing2[a] or history.missing2[b]
            history.times[index] = history.times[b]
        end
        for index = HISTORY_POINTS / 2 + 1, HISTORY_POINTS do
            history.rf1[index], history.rf2[index], history.times[index] = nil, nil, nil
            history.missing1[index], history.missing2[index] = nil, nil
        end
        history.count, history.interval = HISTORY_POINTS / 2, history.interval * 2
        history.compaction = (history.compaction or 0) + 1
    end
    local index = history.count + 1
    history.count = index
    history.rf1[index], history.rf2[index] = history.low1, history.low2
    history.missing1[index], history.missing2[index] = history.gap1, history.gap2
    history.times[index] = clock - flight.started
    history.low1, history.low2, history.gap1, history.gap2 = nil, nil, false, false
    history.next = clock + history.interval
    history.revision = (history.revision or 0) + 1
    return true
end

local function updateFlightDiagnostics(widget, data, key)
    local session = widget.flightSession
    local flight = session and session.current
    data.logDuration = flight and math.floor(flight.duration * 10) / 10 or 0
    data.logHighTime = flight and math.floor(flight.highTime * 10) / 10 or 0
    data.logCounted = flight and flight.counted or false
    data.logStoreError = session and session.error or nil
    if not widget.logEnabled then data.logReason = "LOG DISABLED"
    elseif widget.preview then data.logReason = "PREVIEW ENABLED"
    elseif not key then data.logReason = "MODEL ID UNAVAILABLE"
    elseif session and session.owner ~= widget then data.logReason = "ANOTHER WIDGET OWNS LOG"
    elseif data.logLossTime ~= nil then
        data.logReason = "PACK LOSS " .. string.format("%.1f / %d s", data.logLossTime, widget.endDelay)
    elseif session and not flight and session.last and data.voltage == nil then
        data.logReason = "PACK COMPLETE - LAST LOG KEPT"
    elseif not selectedSource(widget.armSource) then data.logReason = "SELECT ARM SOURCE"
    elseif not selectedSource(widget.throttleSource) then data.logReason = "SELECT THROTTLE SOURCE"
    elseif data.throttlePercent == nil then data.logReason = "INVALID THROTTLE"
    elseif flight and not data.armed then data.logReason = "SESSION PAUSED - ARM OFF"
    elseif flight and not data.airborne then data.logReason = "SESSION PAUSED - GATE OFF"
    elseif not data.armed then data.logReason = "ARM CONDITION OFF"
    elseif not data.airborne then data.logReason = "AIRBORNE GATE OFF"
    elseif data.voltage == nil then data.logReason = "NO VALID PACK VOLTAGE"
    elseif data.logCounted then data.logReason = "FLIGHT COUNTED"
    elseif data.logDuration < widget.flightMinimum then data.logReason = "WAITING FOR FLIGHT TIME"
    elseif data.logHighTime < widget.highThrottleSeconds then data.logReason = "WAITING FOR HIGH THROTTLE"
    else data.logReason = "READY" end
    if widget.diagnosticsVisible then
        data.throttleName = sourceDetails(widget.throttleSource, "Not selected", "")
        data.armName = sourceDetails(widget.armSource, "Not selected", "")
        data.gateName = sourceDetails(selectedSource(widget.airborneSource), "Not selected (passes)", "")
    end
end

local function updateFlight(widget, data, clock, key)
    if widget.logEnabled or widget.diagnosticsVisible then
        data.throttlePercent, data.throttleRaw = throttlePercent(widget)
        data.armed, data.armRaw = switchOn(widget.armSource)
        local gateSource = selectedSource(widget.airborneSource)
        data.gateOptional = gateSource == nil
        if gateSource then data.airborne, data.gateRaw = switchOn(gateSource)
        else data.airborne, data.gateRaw = true, nil end
    end
    if not validPoll(widget) then return end
    if not widget.logEnabled or widget.preview or not key then
        if FLIGHT_SESSION and FLIGHT_SESSION.owner == widget then
            -- Disabling logging pauses the pack session; it must not rearm its count.
            FLIGHT_SESSION.owner, FLIGHT_SESSION.lastClock = nil, nil
            if FLIGHT_SESSION.current then FLIGHT_SESSION.current.running = false end
        end
        widget.flightSession = nil
        return
    end
    if not FLIGHT_SESSION or FLIGHT_SESSION.key ~= key then
        local session = newSession(key)
        if not validPoll(widget) then return end
        FLIGHT_SESSION = session
    end
    if not validPoll(widget) then return end
    local session = FLIGHT_SESSION
    widget.flightSession = session
    if session.owner and session.owner ~= widget then
        data.logCount, data.logState, data.logRevision = session.count, "Shared log", session.revision
        return
    end
    local dt = session.lastClock and clamp(clock - session.lastClock, 0, 1) or 0
    local armed, throttle, gate = data.armed, data.throttlePercent, data.airborne
    local ready = selectedSource(widget.armSource) ~= nil and throttle ~= nil and data.voltage ~= nil
    if not validPoll(widget) then return end
    if ready and armed and gate and not session.current then
        local source1 = selectedSource(widget.graph1Source) or selectedSource(widget.rssi1Source)
        local source2 = selectedSource(widget.graph2Source) or selectedSource(widget.rssi2Source)
        local name1, unit1 = rfDetails(source1, "RF1")
        local name2, unit2 = rfDetails(source2, "RF2")
        if not validPoll(widget) then return end
        session.current = {started = clock, duration = 0, highTime = 0, modelName = data.modelName,
            source1 = source1, source2 = source2, graphSourcesPinned = true,
            name1 = name1, name2 = name2, unit1 = unit1, unit2 = unit2, counted = false,
            history = {count = 0, interval = 1, next = clock + 1,
                rf1 = {}, rf2 = {}, times = {}, missing1 = {}, missing2 = {}}}
        -- Keep the last qualified record until this candidate actually qualifies.
        dt = 0
    end
    session.owner, session.lastClock = widget, clock
    local flight = session.current
    if flight then
        if data.voltage == nil then
            flight.lossSince = flight.lossSince or clock
        else flight.lossSince = nil end
        local running = armed and ready and gate
        if running then
            -- A resumed motor must not add the preceding paused polling interval.
            local progress = flight.running and dt or 0
            flight.duration = flight.duration + progress
            if throttle >= widget.throttleThreshold then flight.highTime = flight.highTime + progress end
            if data.voltage ~= nil then
                flight.minVoltage = minimum(flight.minVoltage, data.voltage)
                flight.maxVoltage = math.max(flight.maxVoltage or data.voltage, data.voltage)
            end
            if data.current ~= nil then flight.maxCurrent = math.max(flight.maxCurrent or 0, data.current) end
            if data.rpm ~= nil then flight.maxRPM = math.max(flight.maxRPM or 0, data.rpm) end
            if data.rpmPotential ~= nil then flight.maxPotential = math.max(flight.maxPotential or 0, data.rpmPotential) end
            if data.watts ~= nil then flight.maxWatts = math.max(flight.maxWatts or 0, data.watts) end
            if not flight.counted and flight.duration >= widget.flightMinimum
                and flight.highTime >= widget.highThrottleSeconds then
                flight.counted = true
                session.last = nil
                session.count = math.min(999999, session.count + 1)
                session.pending, session.attempts, session.retryAt = true, 0, clock
            end
        end
        flight.running = running
        -- RF history spans the whole pack session, including motor inspection pauses.
        flight.minRF1, flight.minRF2 = minimum(flight.minRF1, data.graph1), minimum(flight.minRF2, data.graph2)
        if graphSample(flight, clock, data.graph1, data.graph2) then session.revision = session.revision + 1 end
        -- ARM and the optional gate only pause progress. Sustained pack-voltage
        -- absence is the session boundary; short telemetry losses resume this record.
        if flight.lossSince and clock - flight.lossSince >= widget.endDelay then
            flight.elapsed = clock - flight.started
            flight.running = false
            if flight.counted then
                session.last = flight
                session.completedSerial = (session.completedSerial or 0) + 1
                session.completedAt = clock
            end
            session.current = nil
            session.revision = session.revision + 1
        end
    end
    if session.pending and clock >= session.retryAt and session.attempts < 3 then
        session.attempts = session.attempts + 1
        saveCounter(session)
        session.retryAt = clock + 5
    end
    flight = session.current
    data.logCount = session.count
    data.logPaused = flight ~= nil and not flight.running
    data.logShowingLast = session.last ~= nil and (not flight or not flight.counted)
    data.logLossTime = flight and flight.lossSince
        and math.floor((clock - flight.lossSince) * 10) / 10 or nil
    data.logState = session.error or (not selectedSource(widget.armSource) and "Choose arm source")
        or (not selectedSource(widget.throttleSource) and "Choose throttle")
        or (flight and (flight.lossSince and "Pack loss wait"
            or (flight.counted and (flight.running and "FLIGHT" or "FLIGHT paused"))
            or (flight.running and "Qualifying" or "Qualify paused")))
        or (session.last and "Pack complete") or "Ready"
    data.logRevision = session.revision
end

-- Only a newly completed qualified pack session may schedule this one-shot view.
-- Keep no extra flight/history copy, and do not revisit old logs when enabling it.
local function cancelAutoLog(widget)
    widget.autoLogDue = nil
end

local function updateAutoLog(widget, data, clock, key)
    local session = widget.flightSession
    if session ~= widget.autoLogSession then
        widget.autoLogSession = session
        widget.autoLogSeen = session and (session.completedSerial or 0) or 0
        cancelAutoLog(widget)
    end
    if not session or session.key ~= key or not widget.logEnabled or widget.preview then
        cancelAutoLog(widget)
        return
    end
    local serial = session.completedSerial or 0
    if serial ~= widget.autoLogSeen then
        widget.autoLogSeen = serial
        if widget.autoLogEnabled and session.completedAt and session.last
            and data.voltage == nil then
            widget.autoLogDue = session.completedAt + widget.autoLogDelay
        end
    end
    if not widget.autoLogEnabled or data.voltage ~= nil or session.current or not session.last then
        cancelAutoLog(widget)
        return
    end
    if widget.autoLogDue and clock >= widget.autoLogDue then
        cancelAutoLog(widget)
        widget.logVisible, widget.diagnosticsVisible, widget.refresh = true, false, true
    end
end

local function alarm(widget, data, clock)
    local allowed = widget.alarmEnabled and (not data.estimated or widget.alarmEstimate)
    local state = DeckCore.alarmReady(widget, "Battery", data.percent, LOW_BATTERY_PERCENT, allowed, clock)
    if not state then return end
    local path = audioPath(widget.audioFolder, widget.alarmSound)
    if widget.checkedSound ~= path then
        local lookup = {}
        widget.checkedSound, widget.soundDuration = lookup, nil
        local duration = path ~= "" and audioInfo(path) or nil
        -- Preserve resets during file I/O, including a second lookup of this path.
        if not validWidget(widget) or widget.checkedSound ~= lookup then return end
        widget.checkedSound, widget.soundDuration = path, duration
        if path ~= "" and not widget.soundDuration then print("VoltDeck: invalid WAV; using tone [" .. path .. "]") end
    end
    local played = false
    if widget.soundDuration then played = pcall(system.playFile, path) end
    if not validWidget(widget) or widget.checkedSound ~= path then return end
    if not played then pcall(system.playTone, 1200, 250, 50) end
    if not validWidget(widget) or widget.checkedSound ~= path then return end
    DeckCore.alarmPlayed(widget, state, clock, widget.alertInterval, played and widget.soundDuration or 0)
    widget.lastAlert = clock
end

-- Keep the 180-point history; build a 48-bin trace outside paint, in small slices.
local function prepareFlightGraphs(widget, clock)
    local session = widget.flightSession
    local flight = session and ((session.current and session.current.counted and session.current)
        or session.last or session.current)
    local width, height = widget.graphWidth, widget.graphHeight
    if not widget.logVisible or not flight or not width or not height then
        widget.rfGraphs, widget.rfGraphWork = nil, nil
        return false
    end
    local history = flight.history
    local unit1 = flight.unit1 ~= "" and flight.unit1 or "dB"
    local unit2 = flight.unit2 ~= "" and flight.unit2 or "dB"
    unit1, unit2 = unit1 or "dB", unit2 or "dB"
    local signature = table.concat({width, height, widget.signalMinimum,
        widget.signalMaximum, widget.rfWarnDB, widget.rfCriticalDB,
        widget.rfWarnPercent, widget.rfCriticalPercent, widget.rf1Profile, widget.rf2Profile,
        widget.rf2WarnDB, widget.rf2CriticalDB, widget.rf2WarnPercent, widget.rf2CriticalPercent,
        unit1, unit2}, ":")
    local ready, work = widget.rfGraphs, widget.rfGraphWork
    if ready and (ready.flight ~= flight or ready.signature ~= signature) then
        widget.rfGraphs, ready = nil, nil
    end
    local compaction = history.compaction or 0
    if work and (work.flight ~= flight or work.signature ~= signature
        or work.compaction ~= compaction) then
        widget.rfGraphWork, work = nil, nil
    end
    local revision = history.revision or history.count
    local total = math.max(1, math.floor(flight.elapsed or (clock - flight.started)))
    if not work then
        if ready and ready.revision == revision and ready.total == total then return false end
        local sx, sy = width / 800, height / 480
        work = {flight = flight, signature = signature, compaction = compaction,
            revision = revision, total = total, width = width, height = height,
            count = math.min(history.count, HISTORY_POINTS), sampleIndex = 1,
            binIndex = 1, binScale = GRAPH_BINS / total, channels = {}}
        for channel = 1, 2 do
            local unit = channel == 1 and unit1 or unit2
            local low, high, warning, critical = rfLimits(widget, unit, channel)
            work.channels[channel] = {
                readings = channel == 1 and history.rf1 or history.rf2,
                missing = channel == 1 and history.missing1 or history.missing2,
                bins = {}, segments = {},
                minimum = low, maximum = high, warning = warning, critical = critical,
                x = (channel == 1 and 24 or 425) * sx, y = 220 * sy,
                w = 350 * sx, h = 165 * sy,
                dotX = math.min(sx, 1), dotY = math.min(sy, 1),
            }
        end
        widget.rfGraphWork = work
    end
    if work.sampleIndex <= work.count then
        local last = math.min(work.count, work.sampleIndex + GRAPH_SOURCE_STEPS - 1)
        for index = work.sampleIndex, last do
            local time = history.times[index] or 0
            local bin = math.max(1, math.min(GRAPH_BINS,
                math.floor(time * work.binScale) + 1))
            for channel = 1, 2 do
                local graph = work.channels[channel]
                local value, missing = graph.readings[index], graph.missing[index]
                local entry = graph.bins[bin]
                if not entry then entry = {}; graph.bins[bin] = entry end
                if value ~= nil and (entry.value == nil or value < entry.value) then
                    entry.value, entry.time = value, time
                end
                entry.gap = entry.gap or value == nil or missing
            end
        end
        work.sampleIndex = last + 1
        return false
    end
    local last = math.min(GRAPH_BINS, work.binIndex + GRAPH_BIN_STEPS - 1)
    for index = work.binIndex, last do
        for channel = 1, 2 do
            local graph = work.channels[channel]
            local entry = graph.bins[index]
            if entry then
                if entry.value ~= nil then
                    local px = round(graph.x + clamp(entry.time / work.total, 0, 1) * graph.w)
                    local py = round(graph.y + graph.h - clamp((entry.value - graph.minimum)
                        / math.max(1, graph.maximum - graph.minimum), 0, 1) * graph.h)
                    local tone = entry.value <= graph.critical and 3
                        or (entry.value <= graph.warning and 2 or 1)
                    local segments, offset = graph.segments, #graph.segments
                    if graph.previousX and not graph.previousGap and not entry.gap then
                        segments[offset + 1], segments[offset + 2] = graph.previousX, graph.previousY
                        segments[offset + 3], segments[offset + 4] = px, py
                        segments[offset + 6] = 1
                    else
                        segments[offset + 1], segments[offset + 2] =
                            round(px - graph.dotX), round(py - graph.dotY)
                        segments[offset + 3], segments[offset + 4] =
                            round(2 * graph.dotX), round(2 * graph.dotY)
                        segments[offset + 6] = 0
                    end
                    segments[offset + 5] = tone
                    graph.previousX, graph.previousY, graph.previousGap = px, py, entry.gap
                else
                    graph.previousX, graph.previousY, graph.previousGap = nil, nil, true
                end
            end
        end
    end
    work.binIndex = last + 1
    if work.binIndex <= GRAPH_BINS then return false end
    for channel = 1, 2 do
        local graph = work.channels[channel]
        graph.bins, graph.readings, graph.missing = nil, nil, nil
    end
    widget.rfGraphs, widget.rfGraphWork = work, nil
    return true
end

local function wakeup(widget)
    if not validWidget(widget) then return end
    local clock = os.clock()
    if widget.focusRepaintAt and clock >= widget.focusRepaintAt then
        widget.focusRepaintAt = nil
        lcd.invalidate()
        if not validWidget(widget) then return end
    end
    if clock < widget.nextPoll then return end
    widget.nextPoll = clock + 0.25
    updateResources(widget)
    if not validPoll(widget) then return end
    -- Read the active model on every poll, including after switching models.
    local nameOK, modelName = pcall(model.name)
    if not validPoll(widget) then return end
    local colors = palette(widget)
    if not validPoll(widget) then return end
    local data = widget.scratch
    for key in pairs(data) do data[key] = nil end
    data.modelName = nameOK and modelName or "VoltDeck"
    local key = modelKey()
    if not validPoll(widget) then return end
    if widget.peakModelKey ~= key then
        widget.peakModelKey, widget.peakRPM, widget.peakWatts = key, nil, nil
        widget.alertStates, widget.audioUntil, widget.metadata, widget.batteryStates = nil, nil, nil, nil
        widget.packCheckState = nil
    end
    local readings = {
        voltage = sample(widget.voltageSource, "voltage"),
        current = sample(widget.currentSource, "current"),
        used = sample(widget.consumptionSource, "capacity"),
        rssi1 = sample(widget.rssi1Source, "signal"), rssi2 = sample(widget.rssi2Source, "signal"),
        rx1 = sample(widget.rx1Source, "voltage"), rx2 = sample(widget.rx2Source, "voltage"),
        tx = sample(widget.txSource or widget.builtinTx, "voltage"),
        timer = sample(widget.timerSource, "timer"), percent = sample(widget.percentSource, "percent"),
    }
    if not validPoll(widget) then return end
    for key, value in pairs(readings) do data[key] = value end
    data.themeBackground, data.themeForeground = colors.background, colors.foreground
    data.themeSecondary, data.themeAccent = colors.secondary, colors.accent
    data.rssi1Name, data.rssi1Unit = DeckCore.metadata(widget, "RF1", widget.rssi1Source, clock, "RF1", "", true)
    if not validPoll(widget) then return end
    data.rssi2Name, data.rssi2Unit = DeckCore.metadata(widget, "RF2", widget.rssi2Source, clock, "RF2", "", true)
    if not validPoll(widget) then return end
    local liveVoltage, liveCurrent = data.voltage, data.current
    if widget.preview then
        data.voltage, data.current, data.used = 22.8, 18.2, 650
        data.rssi1, data.rssi2, data.rx1, data.tx = 86, 83, 7.4, 8.0
        data.timer, data.percent = 253, nil
    end
    if data.used ~= nil and data.used < 0 then data.used = nil end
    if data.voltage ~= nil and data.voltage <= 0 then data.voltage = nil end
    if data.rx1 ~= nil and data.rx1 <= 0 then data.rx1 = nil end
    if data.rx2 ~= nil and data.rx2 <= 0 then data.rx2 = nil end
    local trustedUsed = data.used
    if not widget.preview then
        local previousPack = widget.batteryStates and widget.batteryStates.Pack
        if previousPack and previousPack.lossSince and data.voltage ~= nil
            and clock - previousPack.lossSince >= widget.endDelay then previousPack.newPack = true end
        local newPack = previousPack and previousPack.newPack and data.voltage ~= nil
        trustedUsed, data.counterReset = DeckCore.batteryUsed(widget, "Pack", widget.consumptionSource,
            widget.voltageSource, data.voltage, data.used, widget.capacityMah, clock, key)
        if not validPoll(widget) then return end
        trustedUsed = checkBatteryCounter(widget, data, trustedUsed, clock, key, newPack)
        if not validPoll(widget) then return end
    elseif widget.packCheckState then
        local state, pack = widget.packCheckState, widget.batteryStates and widget.batteryStates.Pack
        clearPackCheckWindow(state)
        if state.lastClock and (clock < state.lastClock or clock - state.lastClock >= widget.endDelay) then
            state.qualified, state.recheck = nil, true
            if clock < state.lastClock and state.holdUntil then
                state.holdUntil = clock + PACK_CHECK_RELAX_SECONDS
            end
        end
        state.lastClock = clock
        -- Demo values never qualify a pack; an observed live disconnect still
        -- marks a possible battery change, including reconnection during demo.
        if liveVoltage == nil or liveVoltage <= 0 then
            state.lossSince = state.lossSince or clock
        end
        if state.lossSince and clock - state.lossSince >= widget.endDelay then
            state.qualified = nil
            if pack then pack.newPack = true end
        end
        if liveVoltage ~= nil and liveVoltage > 0 then state.lossSince = nil end
        if liveCurrent ~= nil and liveCurrent > packCheckCurrent(widget) then
            state.holdUntil = clock + PACK_CHECK_RELAX_SECONDS
        end
    end
    if trustedUsed ~= nil then data.remaining = math.max(0, widget.capacityMah - trustedUsed) end
    data.voltagePercent = voltagePercent(widget, data.voltage)
    if widget.preview or widget.batteryMethod == 1 then
        data.percent = data.remaining and clamp(data.remaining / widget.capacityMah * 100, 0, 100) or nil
    elseif widget.batteryMethod == 2 then
        if data.percent ~= nil and (data.percent < 0 or data.percent > 100) then data.percent = nil end
    else
        data.percent, data.estimated = data.voltagePercent, true
    end
    if data.percent ~= nil then data.percent = round(data.percent) end
    data.low = data.percent ~= nil and data.percent <= LOW_BATTERY_PERCENT
    data.rpm = sample(widget.rpmSource, "rpm")
    if not validPoll(widget) then return end
    if data.rpm ~= nil and data.rpm < 0 then data.rpm = nil end
    data.watts = data.voltage and data.current and data.current >= 0 and data.voltage * data.current or nil
    data.cellVoltage = data.voltage and data.voltage / widget.cellCount or nil
    data.rpmPotential = data.voltage and widget.motorKV > 0 and data.voltage * widget.motorKV or nil
    data.rpmEstimate = data.rpmPotential and data.rpmPotential * widget.loadFactor / 100 or nil
    data.rpmDisplay = widget.rpmMode == 2 and data.rpmEstimate or data.rpm
    local ceiling = widget.motorKV * widget.cellCount * TYPES[widget.chemistry].full
    data.rpmCeiling = widget.rpmScale == 2 and ceiling > 0 and math.ceil(ceiling / 1000) * 1000 or widget.rpmMaximum
    if not widget.preview and data.rpmDisplay ~= nil then widget.peakRPM = math.max(widget.peakRPM or 0, data.rpmDisplay) end
    if not widget.preview and data.watts ~= nil then widget.peakWatts = math.max(widget.peakWatts or 0, data.watts) end
    data.peakRPM, data.peakWatts = widget.peakRPM, widget.peakWatts
    local currentFlight = widget.flightSession and widget.flightSession.current
    local graphSource1, graphSource2
    if currentFlight and currentFlight.graphSourcesPinned then
        graphSource1, graphSource2 = currentFlight.source1, currentFlight.source2
    else
        graphSource1 = selectedSource(widget.graph1Source) or selectedSource(widget.rssi1Source)
        graphSource2 = selectedSource(widget.graph2Source) or selectedSource(widget.rssi2Source)
    end
    data.graph1 = sample(graphSource1, "signal")
    data.graph2 = sample(graphSource2, "signal")
    if not validPoll(widget) then return end
    if widget.preview then
        data.rpm, data.rpmDisplay, data.watts = 8300, 8300, 414.96
        data.peakRPM, data.peakWatts = 8300, 414.96
    end
    updateFlight(widget, data, clock, key)
    if not validPoll(widget) then return end
    updateAutoLog(widget, data, clock, key)
    updateFlightDiagnostics(widget, data, key)
    if not validPoll(widget) then return end
    local graphDirty = prepareFlightGraphs(widget, clock)
    if widget.bottomSource then
        data.bottomValue = sample(widget.bottomSource)
        if not validPoll(widget) then return end
        data.bottomName, data.bottomUnit, data.bottomDecimals =
            DeckCore.metadata(widget, "Bottom", widget.bottomSource, clock, "TELEMETRY", "")
        if not validPoll(widget) then return end
    else
        data.bottomValue, data.bottomName, data.bottomUnit = nil, "SELECT A DECK SOURCE", ""
        data.bottomDecimals = 0
    end
    if widget.bottomLabel ~= "" then data.bottomName = widget.bottomLabel end
    if widget.bottomDecimals >= 0 then data.bottomDecimals = widget.bottomDecimals end
    local dirty = widget.refresh or graphDirty
    for key, value in pairs(data) do
        if widget.data[key] ~= value then dirty = true end
    end
    for key in pairs(widget.data) do
        if data[key] == nil then dirty = true end
    end
    widget.scratch, widget.data, widget.refresh = widget.data, data, false
    alarm(widget, data, clock)
    if dirty then lcd.invalidate() end
    local pending = widget.pendingBatteryMessage
    if pending then
        widget.pendingBatteryMessage = nil
        local currentKey = modelKey()
        if validPoll(widget) and not widget.preview and currentKey == pending.key
            and widget.configGeneration == pending.generation
            and widget.packCheckState == pending.check then
            form.openDialog({title = "Battery not accepted", message = pending.message,
                buttons = {{label = "Close", action = function() return true end}}})
        end
    end
end

-- Percentage thresholds are shared by the battery colors and the 30% audio alert.
-- Exactly 30 / 35 / 40 percent belongs to red / orange / yellow respectively.
local function batteryColor(percent)
    if percent == nil then return COLORS.muted end
    if percent <= 30 then return COLORS.red end
    if percent <= 35 then return COLORS.orange end
    if percent <= 40 then return COLORS.yellow end
    return COLORS.green
end

local function voltageMetricColor(widget, kind, fallback)
    if kind ~= 4 and kind ~= 5 then return fallback end
    local cell = widget.data.cellVoltage
    if cell == nil then return COLORS.muted end
    local chemistry = TYPES[widget.chemistry]
    -- Ignore only arithmetic noise from Pack / Cells at an exact boundary.
    local cellMv, fullMv, emptyMv = cell * 1000, chemistry.full * 1000, chemistry.empty * 1000
    -- Ignore arithmetic noise near a boundary; 0.01 mV is far below display resolution.
    local toleranceMv = 0.01
    if cellMv > fullMv + toleranceMv then return COLORS.red end
    if kind == 5 then return batteryColor(widget.data.voltagePercent and round(widget.data.voltagePercent)) end
    return batteryColor((cellMv - emptyMv - toleranceMv) * 100 / (fullMv - emptyMv))
end

local function rect(x, y, w, h, color)
    if w <= 0 or h <= 0 then return end
    lcd.color(color)
    lcd.drawFilledRectangle(round(x), round(y), round(w), round(h))
end

local function rounded(x, y, w, h, radius, color)
    radius = math.max(0, math.floor(math.min(radius, w / 2, h / 2)))
    if radius < 1 then rect(x, y, w, h, color); return end
    lcd.color(color)
    lcd.drawFilledRectangle(round(x + radius), round(y), math.max(0, round(w - 2 * radius)), round(h))
    lcd.drawFilledRectangle(round(x), round(y + radius), round(radius), math.max(0, round(h - 2 * radius)))
    lcd.drawFilledRectangle(round(x + w - radius), round(y + radius), round(radius), math.max(0, round(h - 2 * radius)))
    lcd.drawFilledCircle(round(x + radius), round(y + radius), radius)
    lcd.drawFilledCircle(round(x + w - radius - 1), round(y + radius), radius)
    lcd.drawFilledCircle(round(x + radius), round(y + h - radius - 1), radius)
    lcd.drawFilledCircle(round(x + w - radius - 1), round(y + h - radius - 1), radius)
end

local function text(x, y, value, width, height, color, align, customFont, small)
    local font, fitted, tw, th = DeckCore.fitText(value, width, height, customFont, small)
    lcd.font(font); lcd.color(color)
    lcd.drawText(round(x), round(math.max(0, math.min(y, SURFACE_HEIGHT - th))), fitted, align or LEFT)
    return tw, th
end

local function valueText(value, decimals, missing)
    if value == nil then return missing or "--" end
    return string.format("%." .. tostring(decimals or 0) .. "f", value)
end

local function timerText(value)
    if value == nil then return "--:--" end
    local seconds = math.floor(math.abs(value))
    local minutes = math.floor(seconds / 60)
    local result
    if minutes <= 99 then
        result = string.format("%02d:%02d", minutes, seconds % 60)
    else
        result = string.format("%dh%02d", math.floor(minutes / 60), minutes % 60)
    end
    return value < 0 and "-" .. result or result
end

local function drawSignal(widget, colors, x, y, value, unit, label, channel, sx, sy)
    text(x, y, label, 148 * sx, 14 * sy, colors.secondary, LEFT, nil, true)
    local low, high, warning, critical = rfLimits(widget, unit, channel)
    local ratio = value and clamp((value - low) / math.max(1, high - low), 0, 1) or 0
    local active = value and math.ceil(ratio * 5) or 0
    local tone = value == nil and colors.secondary or value <= critical and COLORS.red
        or value <= warning and COLORS.yellow or colors.accent
    for bar = 1, 5 do
        local height = (5 + bar * 3) * sy
        rounded(x + (104 + (bar - 1) * 7) * sx, y + 35 * sy - height,
            4 * sx, height, 1 * sx, bar <= active and tone or colors.track)
    end
    text(x, y + 14 * sy, valueText(value, 0) .. (unit or ""), 99 * sx, 23 * sy, tone)
end

local function drawBattery(widget, colors, sx, sy)
    local data = widget.data
    local x, y, w, h = 630 * sx, 150 * sy, 136 * sx, 222 * sy
    local color = batteryColor(data.percent)
    local scale = math.min(sx, sy)
    rounded(x + 44 * sx, y - 14 * sy, 48 * sx, 12 * sy, 4 * scale, colors.border)
    rounded(x, y, w, h, 17 * scale, colors.border)
    rounded(x + 2 * sx, y + 2 * sy, w - 4 * sx, h - 4 * sy, 15 * scale, colors.background)
    local gap = 4 * sy
    local segmentH = (h - 26 * sy - 9 * gap) / 10
    for segment = 1, 10 do
        local segmentY = y + h - 13 * sy - segment * segmentH - (segment - 1) * gap
        rounded(x + 11 * sx, segmentY, w - 22 * sx, segmentH, 3 * scale, colors.track)
        if data.percent ~= nil then
            local fill = clamp(data.percent / 10 - (segment - 1), 0, 1)
            if fill > 0 then
                local fillHeight = segmentH * fill
                rounded(x + 11 * sx, segmentY + segmentH - fillHeight,
                    w - 22 * sx, fillHeight, 3 * scale, color)
            end
        end
    end
    text(x + w / 2, 390 * sy, valueText(data.percent, 0) .. "%",
        152 * sx, 57 * sy, color, CENTERED, widget.valueFont)
    text(x + w / 2, 450 * sy, data.estimated and "VOLTAGE ESTIMATE" or "REMAINING", 152 * sx, 16 * sy,
        colors.secondary, CENTERED, nil, true)
end


local function metricValues(widget, kind)
    local data = widget.data
    if kind == 1 then return data.bottomValue, data.bottomName or "CUSTOM TELEMETRY",
        data.bottomUnit or "", widget.bottomMinimum, widget.bottomMaximum, data.bottomDecimals or 0 end
    if kind == 2 then return data.rpmDisplay,
        widget.rpmMode == 2 and "RPM ESTIMATE" or "MOTOR RPM", "rpm",
        0, data.rpmCeiling or widget.rpmMaximum, 0, data.peakRPM end
    if kind == 3 then return data.watts, "PACK POWER", "W", 0, widget.wattMaximum, 0, data.peakWatts end
    if kind == 4 then
        local chemistry = TYPES[widget.chemistry]
        return data.cellVoltage, "CELL VOLTAGE (AVG)", "V", chemistry.cellMinimum, chemistry.full, 2
    end
    return data.voltagePercent, "VOLTAGE ESTIMATE", "%", 0, 100, 0
end
local DECK_METRICS = {{1}, {2}, {3}, {4}, {5}, {2, 3}, {2, 3, 4}, {}}
local function resolvedDeckKinds(widget)
    if not validWidget(widget) then return {} end
    local mode = widget.deckMode
    if mode == 8 then return {} end
    if mode == 1 then return {1} end
    local kinds = {}
    for index, kind in ipairs(DECK_METRICS[mode] or DECK_METRICS[6]) do kinds[index] = kind end
    local custom = selectedSource(widget.bottomSource)
    if not validWidget(widget) then return {} end
    if custom then
        if #kinds == 3 then table.remove(kinds) end
        table.insert(kinds, clamp(widget.customPosition or 3, 1, #kinds + 1), 1)
    end
    return kinds
end

local function drawMeter(widget, colors, sx, sy, kind)
    local reading, label, unit, minimumValue, maximumValue, decimals = metricValues(widget, kind)
    local valueColor = voltageMetricColor(widget, kind, colors.foreground)
    local x, y, w = 24 * sx, 347 * sy, 290 * sx
    text(x, y, string.upper(label or "TELEMETRY"), w, 18 * sy,
        colors.secondary, LEFT, nil, true)
    local value = valueText(reading, decimals or 0)
    local unit = unit or ""
    if widget.bottomDisplay == 1 then
        local tw, th = text(x, y + 28 * sy, value, w - 60 * sx, 56 * sy,
            valueColor, LEFT, widget.valueFont)
        text(x + tw + 8 * sx, y + 28 * sy + math.max(0, th - 22 * sy),
            unit, math.max(30 * sx, w - tw - 8 * sx), 24 * sy, colors.secondary, LEFT, nil, true)
        return
    end
    text(x + w, y + 20 * sy, value .. (unit ~= "" and " " .. unit or ""),
        w, 39 * sy, valueColor, RIGHT, widget.valueFont)
    local ratio = reading and clamp((reading - minimumValue)
        / math.max(0.01, maximumValue - minimumValue), 0, 1) or 0
    local count, gap = 28, 3 * sx
    local width = (w - (count - 1) * gap) / count
    for index = 1, count do
        local position = (index - 1) / (count - 1)
        local segmentX = x + (index - 1) * (width + gap)
        local segmentY = 440 * sy - 30 * sy * position ^ 0.8
        local color = colors.track
        if reading ~= nil and index <= math.ceil(ratio * count) then
            local zone = index / count * 100
            if kind == 4 or kind == 5 then color = valueColor
            elseif zone >= widget.redZone then color = COLORS.red
            elseif zone >= widget.redZone - 10 then color = COLORS.orange
            elseif zone >= widget.redZone - 20 then color = COLORS.yellow
            else color = colors.accent end
        end
        lcd.color(color)
        local slant, height = 2 * sx, 16 * sy
        lcd.drawFilledTriangle(round(segmentX + slant), round(segmentY),
            round(segmentX + width), round(segmentY),
            round(segmentX), round(segmentY + height))
        lcd.drawFilledTriangle(round(segmentX + width), round(segmentY),
            round(segmentX + width - slant), round(segmentY + height),
            round(segmentX), round(segmentY + height))
    end
    for index = 0, 4 do
        local amount = minimumValue + (maximumValue - minimumValue) * index / 4
        local label = math.abs(amount) >= 1000 and string.format("%.1fk", amount / 1000)
            or string.format(kind == 4 and "%.2f" or (maximumValue - minimumValue < 10 and "%.1f" or "%.0f"), amount)
        local align = index == 0 and LEFT or (index == 4 and RIGHT or CENTERED)
        text(x + w * index / 4, 462 * sy, label, 65 * sx, 14 * sy,
            colors.secondary, align, nil, true)
    end
end


local function drawBottom(widget, colors, sx, sy)
    local kinds = resolvedDeckKinds(widget)
    local count = #kinds
    if count == 0 then return end
    if count == 1 then
        drawMeter(widget, colors, sx, sy, kinds[1])
        local _, _, _, _, _, _, peak = metricValues(widget, kinds[1])
        if peak then text(24 * sx, (widget.bottomDisplay == 2 and 398 or 444) * sy,
            "MAX " .. valueText(peak, 0), 140 * sx, 13 * sy, colors.accent, LEFT, nil, true) end
        return
    end
    local height = 126 / count
    for index, kind in ipairs(kinds) do
        local value, label, unit, minimumValue, maximumValue, decimals, peak = metricValues(widget, kind)
        local valueColor = voltageMetricColor(widget, kind, colors.foreground)
        local x, y, width = 24 * sx, (347 + (index - 1) * height) * sy, 290 * sx
        text(x, y, label, 182 * sx, 14 * sy, colors.secondary, LEFT, nil, true)
        if peak then text(x + width, y, "MAX " .. valueText(peak, 0), 104 * sx,
            14 * sy, colors.accent, RIGHT, nil, true) end
        text(x + width, y + 15 * sy, valueText(value, decimals) .. " " .. unit,
            width, (count == 3 and 22 or 28) * sy, valueColor, RIGHT, widget.valueFont)
        if widget.bottomDisplay == 2 then
            local ratio = value and clamp((value - minimumValue) / math.max(0.01, maximumValue - minimumValue), 0, 1) or 0
            local gap, segments = 2 * sx, 24
            local segmentWidth = (width - gap * (segments - 1)) / segments
            for segment = 1, segments do
                local tone = colors.track
                if value ~= nil and segment <= math.ceil(ratio * segments) then
                    if kind == 4 or kind == 5 then tone = valueColor
                    else tone = segment / segments * 100 >= widget.redZone and COLORS.red or colors.accent end
                end
                rect(x + (segment - 1) * (segmentWidth + gap), y + (height - 7) * sy,
                    segmentWidth, 4 * sy, tone)
            end
            if peak then
                local marker = clamp((peak - minimumValue) / math.max(0.01, maximumValue - minimumValue), 0, 1)
                rect(x + marker * (width - 2 * sx), y + (height - 8) * sy, 2 * sx, 6 * sy, colors.foreground)
            end
        end
    end
end

local function drawFlightGraph(widget, colors, flight, channel, x, y, width, height, sx, sy)
    local unit = channel == 1 and flight.unit1 or flight.unit2
    unit = unit ~= "" and unit or "dB"
    unit = unit or "dB"
    local minimumValue, maximumValue, warning, critical, profile = rfLimits(widget, unit, channel)
    local low = channel == 1 and flight.minRF1 or flight.minRF2
    local name = (channel == 1 and flight.name1 or flight.name2) or "RF" .. channel
    text(x, y - 24 * sy, name .. "  MIN " .. valueText(low, 0) .. unit,
        width, 19 * sy, colors.secondary, LEFT, nil, true)
    rect(x, y, width, height, colors.track)
    if unit ~= "dB" and unit ~= "%" then
        text(x + width / 2, y + height / 2, "Select RSSI (dB) or VFR (%)",
            width - 16 * sx, 18 * sy, colors.secondary, CENTERED, nil, true)
        return
    end
    local range = math.max(1, maximumValue - minimumValue)
    lcd.color(COLORS.yellow)
    local warningY = round(y + height - clamp((warning - minimumValue) / range, 0, 1) * height)
    lcd.drawLine(round(x), warningY, round(x + width), warningY)
    lcd.color(COLORS.red)
    local criticalY = round(y + height - clamp((critical - minimumValue) / range, 0, 1) * height)
    lcd.drawLine(round(x), criticalY, round(x + width), criticalY)
    local ready = widget.rfGraphs
    if ready and (ready.flight ~= flight or ready.width ~= widget.graphWidth
        or ready.height ~= widget.graphHeight) then ready = nil end
    if ready then
        local segments = ready.channels[channel].segments
        local tones = {colors.accent, COLORS.yellow, COLORS.red}
        local previousTone
        -- At most 48 primitives per channel: no history scan or per-point geometry.
        for index = 1, #segments, 6 do
            local tone = tones[segments[index + 4]]
            if tone ~= previousTone then lcd.color(tone); previousTone = tone end
            if segments[index + 5] == 1 then
                lcd.drawLine(segments[index], segments[index + 1],
                    segments[index + 2], segments[index + 3])
            else
                lcd.drawFilledRectangle(segments[index], segments[index + 1],
                    segments[index + 2], segments[index + 3])
            end
        end
    else
        text(x + width / 2, y + height / 2, "Preparing RF trace...",
            width - 16 * sx, 18 * sy, colors.secondary, CENTERED, nil, true)
    end
    local total = ready and ready.total
        or math.max(1, math.floor(flight.elapsed or (os.clock() - flight.started)))
    text(x, y + height + 6 * sy, "0s", 40 * sx, 14 * sy, colors.secondary, LEFT, nil, true)
    text(x + width, y + height + 6 * sy, timerText(total), 80 * sx, 14 * sy,
        colors.secondary, RIGHT, nil, true)
    local limits = unit == "%" and "VFR early " .. warning .. "% / low " .. critical .. "%"
        or profile .. " low " .. warning .. " / crit " .. critical .. " dB"
    text(x, y + height + 23 * sy, limits, width, 14 * sy, colors.secondary, LEFT, nil, true)
end

local function paintFlight(widget, colors, sx, sy)
    local session = widget.flightSession
    local flight = session and ((session.current and session.current.counted and session.current)
        or session.last or session.current)
    text(24 * sx, 16 * sy, widget.data.logShowingLast and "LAST FLIGHT LOG" or "FLIGHT LOG",
        320 * sx, 28 * sy, colors.foreground)
    text(24 * sx, 49 * sy, widget.data.modelName or "VoltDeck", 550 * sx, 23 * sy,
        colors.secondary, LEFT, nil, true)
    text(776 * sx, 14 * sy, "FLIGHTS " .. tostring(session and session.count or 0),
        280 * sx, 35 * sy, colors.accent, RIGHT)
    text(776 * sx, 54 * sy, widget.data.logState or "Enable log in settings", 270 * sx,
        17 * sy, colors.secondary, RIGHT, nil, true)
    if not flight then
        text(400 * sx, 190 * sy, "No qualifying flight yet", 710 * sx, 33 * sy,
            colors.foreground, CENTERED)
        text(400 * sx, 239 * sy, "Arm + valid telemetry + time/throttle gates", 710 * sx,
            20 * sy, colors.secondary, CENTERED, nil, true)
        text(400 * sx, 282 * sy, "Bench filtering is not proof of airborne flight.", 710 * sx,
            20 * sy, colors.secondary, CENTERED, nil, true)
    else
        local labels = {"RPM MAX (MEASURED)", "CURRENT MAX", "PACK LOW / HIGH"}
        local values = {valueText(flight.maxRPM, 0), valueText(flight.maxCurrent, 1) .. " A",
            valueText(flight.minVoltage, 1) .. " / " .. valueText(flight.maxVoltage, 1) .. " V"}
        for index = 1, 3 do
            local x = (24 + (index - 1) * 254) * sx
            text(x, 95 * sy, labels[index], 235 * sx, 17 * sy, colors.secondary, LEFT, nil, true)
            text(x, 119 * sy, values[index], 235 * sx, 32 * sy, colors.foreground)
        end
        text(24 * sx, 161 * sy, (widget.data.logShowingLast and "LAST FLIGHT " or "FLIGHT ")
        .. timerText(flight.duration)
            .. "   POWER MAX " .. valueText(flight.maxWatts, 0) .. " W",
            752 * sx, 19 * sy, colors.foreground, LEFT, nil, true)
        drawFlightGraph(widget, colors, flight, 1, 24 * sx, 220 * sy, 350 * sx, 165 * sy, sx, sy)
        drawFlightGraph(widget, colors, flight, 2, 425 * sx, 220 * sy, 350 * sx, 165 * sy, sx, sy)
        text(24 * sx, 430 * sy, "KV POTENTIAL MAX " .. valueText(flight.maxPotential, 0)
            .. " rpm (not measured)", 752 * sx, 17 * sy, colors.secondary, LEFT, nil, true)
        text(24 * sx, 449 * sy, "RF: 48 minimum bins/channel; gaps = missing data. Visual limits only.",
            752 * sx, 17 * sy, colors.secondary, LEFT, nil, true)
    end
    text(24 * sx, 463 * sy, "Widget menu: Dashboard / Flight log", 750 * sx, 14 * sy,
        colors.accent, LEFT, nil, true)
end

local function paintDiagnostics(widget, colors, sx, sy)
    local data = widget.data
    text(24 * sx, 16 * sy, "FLIGHT DIAGNOSTICS", 550 * sx, 28 * sy, colors.foreground)
    text(24 * sx, 51 * sy, data.modelName or "VoltDeck", 520 * sx, 20 * sy, colors.secondary, LEFT, nil, true)
    text(776 * sx, 19 * sy, VERSION, 200 * sx, 19 * sy, colors.secondary, RIGHT, nil, true)
    local tone = data.logCounted and COLORS.green or COLORS.yellow
    if data.logPaused then tone = COLORS.yellow end
    if data.throttlePercent == nil or data.voltage == nil or not widget.logEnabled or widget.preview
        or ((not data.armed or not data.airborne) and not data.logPaused) then tone = COLORS.red end
    rect(24 * sx, 83 * sy, 752 * sx, 47 * sy, colors.track)
    text(40 * sx, 94 * sy, data.logReason or "Waiting for sources", 720 * sx, 25 * sy, tone, LEFT, nil, true)
    local labels = {"THROTTLE API RAW", "THROTTLE 0-100%", "CALIBRATION RAW"}
    local values = {valueText(data.throttleRaw, 1), valueText(data.throttlePercent, 1) .. "%",
        tostring(widget.throttleMinimum) .. " / " .. tostring(widget.throttleMaximum)}
    local notes = {data.throttleName or "Not selected",
        "High gate >= " .. tostring(widget.throttleThreshold) .. "%", "Low / high endpoints"}
    for index = 1, 3 do
        local x = (24 + (index - 1) * 254) * sx
        text(x, 150 * sy, labels[index], 235 * sx, 17 * sy, colors.secondary, LEFT, nil, true)
        text(x, 177 * sy, values[index], 235 * sx, 36 * sy, colors.foreground)
        text(x, 220 * sy, notes[index], 235 * sx, 16 * sy, colors.secondary, LEFT, nil, true)
    end
    rect(24 * sx, 249 * sy, 752 * sx, math.max(1, sy), colors.track)
    local gates = {
        {"ARM", data.armed, data.armName or "Not selected",
            type(data.armRaw) == "boolean" and tostring(data.armRaw) or valueText(data.armRaw, 0)},
        {"AIRBORNE GATE", data.airborne, data.gateName or "Not selected",
            data.gateOptional and "Optional" or (type(data.gateRaw) == "boolean" and tostring(data.gateRaw)
                or valueText(data.gateRaw, 0))},
        {"PACK VOLTAGE", data.voltage ~= nil, "Positive voltage required", valueText(data.voltage, 1) .. " V"},
    }
    for index, gate in ipairs(gates) do
        local x = (24 + (index - 1) * 254) * sx
        text(x, 267 * sy, gate[1], 235 * sx, 17 * sy, colors.secondary, LEFT, nil, true)
        text(x, 294 * sy, (gate[2] and "PASS  " or "BLOCK  ") .. gate[4], 235 * sx, 27 * sy,
            gate[2] and COLORS.green or COLORS.red, LEFT, nil, true)
        text(x, 329 * sy, gate[3], 235 * sx, 15 * sy, colors.secondary, LEFT, nil, true)
    end
    text(24 * sx, 369 * sy, "QUALIFYING TIME", 350 * sx, 17 * sy, colors.secondary, LEFT, nil, true)
    text(425 * sx, 369 * sy, "HIGH THROTTLE TIME", 350 * sx, 17 * sy, colors.secondary, LEFT, nil, true)
    text(24 * sx, 393 * sy, valueText(data.logDuration, 1) .. " / " .. widget.flightMinimum .. " s",
        350 * sx, 28 * sy, colors.foreground)
    text(425 * sx, 393 * sy, valueText(data.logHighTime, 1) .. " / " .. widget.highThrottleSeconds .. " s",
        350 * sx, 28 * sy, colors.foreground)
    text(24 * sx, 436 * sy, data.logStoreError or ("COUNTER " .. tostring(data.logCount or 0)
        .. "   " .. (widget.preview and "Preview: no logging" or "Live diagnostic, not an airborne detector")),
        752 * sx, 16 * sy, data.logStoreError and COLORS.red or colors.secondary, LEFT, nil, true)
    text(24 * sx, 463 * sy, "Widget menu: Dashboard / Flight log / Flight diagnostics",
        752 * sx, 14 * sy, colors.accent, LEFT, nil, true)
end

local function keepFocus(widget)
    -- Home focus expires in ETHOS. Refresh only the visible widget's existing
    -- focus; leave native short/long presses and other pages to ETHOS.
    widget.focusRepaintAt = nil
    if type(lcd.hasFocus) == "function" and type(lcd.resetFocusTimeout) == "function" then
        local ok, focused = pcall(lcd.hasFocus)
        if ok and focused == true then
            local renewed = pcall(lcd.resetFocusTimeout)
            if renewed and validWidget(widget) then widget.focusRepaintAt = os.clock() + 4 end
        end
    end
end

local function paint(widget)
    if not validWidget(widget) then return end
    keepFocus(widget)
    if not validWidget(widget) then return end
    local w, h = lcd.getWindowSize()
    if not finite(w) or not finite(h) or w <= 0 or h <= 0 then return end
    SURFACE_HEIGHT = h
    widget.graphWidth, widget.graphHeight = w, h
    local sx, sy = w / 800, h / 480
    local colors, data = palette(widget), widget.data
    rect(0, 0, w, h, colors.background)
    if widget.diagnosticsVisible then paintDiagnostics(widget, colors, sx, sy); return end
    if widget.logVisible then paintFlight(widget, colors, sx, sy); return end
    text(24 * sx, 9 * sy, "MODEL", 286 * sx, 17 * sy, colors.secondary, LEFT, nil, true)
    text(24 * sx, 30 * sy, data.modelName or "VoltDeck", 292 * sx, 39 * sy,
        colors.foreground, LEFT, widget.valueFont)
    local pack = TYPES[widget.chemistry].name .. "  /  " .. widget.cellCount .. "S  /  "
        .. widget.capacityMah .. " mAh"
    text(24 * sx, 78 * sy, pack, 294 * sx, 17 * sy, colors.secondary, LEFT, nil, true)
    drawSignal(widget, colors, 343 * sx, 12 * sy, data.rssi1, data.rssi1Unit,
        data.rssi1Name or "RF1", 1, sx, sy)
    drawSignal(widget, colors, 343 * sx, 56 * sy, data.rssi2, data.rssi2Unit,
        data.rssi2Name or "RF2", 2, sx, sy)
    text(503 * sx, 18 * sy, "RX", 29 * sx, 18 * sy, colors.secondary, LEFT, nil, true)
    text(535 * sx, 17 * sy, valueText(data.rx1, 1) .. "V", 73 * sx, 26 * sy, colors.foreground)
    text(503 * sx, 61 * sy, "TX", 29 * sx, 18 * sy, colors.secondary, LEFT, nil, true)
    text(535 * sx, 60 * sy, valueText(data.tx, 1) .. "V", 73 * sx, 26 * sy, colors.foreground)
    text(776 * sx, 23 * sy, timerText(data.timer), 151 * sx, 46 * sy,
        colors.foreground, RIGHT, widget.valueFont)
    text(776 * sx, 78 * sy, "FLIGHT TIME", 151 * sx, 16 * sy, colors.secondary, RIGHT, nil, true)
    rect(24 * sx, 108 * sy, 752 * sx, math.max(1, sy), colors.track)

    if widget.modelImage then
        local iw, ih = widget.imageWidth or 290, widget.imageHeight or 191
        local fit = math.min(290 * sx / iw, 191 * sy / ih)
        lcd.drawBitmap(round(24 * sx + (290 * sx - iw * fit) / 2),
            round(131 * sy + (191 * sy - ih * fit) / 2), widget.modelImage,
            round(iw * fit), round(ih * fit))
    else
        text(169 * sx, 203 * sy, "MODEL IMAGE", 264 * sx, 22 * sy,
            colors.secondary, CENTERED, nil, true)
        text(169 * sx, 237 * sy, widget.imageError or "Choose model image in Ethos", 264 * sx, 19 * sy,
            colors.secondary, CENTERED, nil, true)
        rect(135 * sx, 178 * sy, 68 * sx, 2 * sy, colors.accent)
    end
    if widget.preview then
        text(24 * sx, 315 * sy, "PREVIEW", 285 * sx, 17 * sy, colors.accent, LEFT, nil, true)
    elseif data.voltage == nil and data.used == nil then
        text(24 * sx, 315 * sy, "Select telemetry sensors", 285 * sx, 17 * sy,
            colors.secondary, LEFT, nil, true)
    end

    text(349 * sx, 131 * sy, "PACK VOLTAGE", 238 * sx, 19 * sy,
        colors.secondary, LEFT, nil, true)
    local tw, th = text(345 * sx, 158 * sy, valueText(data.voltage, 1), 195 * sx, 66 * sy,
        colors.foreground, LEFT, widget.valueFont)
    text(345 * sx + tw + 8 * sx, 158 * sy + math.max(0, th - 26 * sy),
        "V", 38 * sx, 29 * sy, colors.secondary)
    text(349 * sx, 241 * sy, "CURRENT", 235 * sx, 18 * sy,
        colors.secondary, LEFT, nil, true)
    text(349 * sx, 264 * sy, valueText(data.current, 1) .. " A", 234 * sx, 43 * sy,
        colors.foreground, LEFT, widget.valueFont)
    local mah = widget.mahDisplay == 2 and data.remaining or data.used
    local label = widget.mahDisplay == 2 and "REMAINING CAPACITY" or "CONSUMED"
    text(349 * sx, 327 * sy, label, 238 * sx, 18 * sy, colors.secondary, LEFT, nil, true)
    text(349 * sx, 351 * sy, valueText(mah, 0) .. " mAh", 238 * sx, 37 * sy,
        colors.foreground, LEFT, widget.valueFont)
    if data.counterReset and widget.batteryMethod == 1 and not widget.preview then
        text(349 * sx, 409 * sy, "COUNTER RESET: CHECK PACK", 238 * sx, 18 * sy, COLORS.red, LEFT, nil, true)
    elseif data.packCheck and not widget.preview then
        text(349 * sx, 409 * sy, data.packCheck == "cells" and "CHECK CELLS/TYPE" or "CHECK PACK/COUNTER",
            238 * sx, 18 * sy, COLORS.red, LEFT, nil, true)
    elseif data.packCheckPending and not widget.preview then
        text(349 * sx, 409 * sy, "CHECKING PACK", 238 * sx, 18 * sy, colors.secondary, LEFT, nil, true)
    elseif data.low and not widget.preview then
        rounded(349 * sx, 414 * sy, 5 * sx, 5 * sy, 2 * math.min(sx, sy), COLORS.orange)
        text(361 * sx, 409 * sy, "LOW BATTERY", 231 * sx, 18 * sy, COLORS.orange, LEFT, nil, true)
    elseif widget.rx2Source then
        text(349 * sx, 409 * sy, "RX2  " .. valueText(data.rx2, 1) .. " V",
            235 * sx, 19 * sy, colors.secondary, LEFT, nil, true)
    end
    if widget.logEnabled then
        text(349 * sx, 447 * sy, "FLIGHTS " .. tostring(data.logCount or 0) .. " | " .. (data.logState or "Ready"),
            238 * sx, 18 * sy, colors.accent, LEFT, nil, true)
    end
    drawBattery(widget, colors, sx, sy)
    drawBottom(widget, colors, sx, sy)
end

local function numberField(widget, label, key, minimum, maximum, suffix, step, onChanged, active)
    local generation = widget.configGeneration
    if not validWidget(widget) then return end
    local definition = SETTING_MAP[key]
    if definition and definition[3] then minimum, maximum = definition[3], definition[4] end
    local line = form.addLine(label, widget.configPanel)
    if not validWidget(widget) or widget.configGeneration ~= generation then return end
    local field = form.addNumberField(line, nil, minimum, maximum,
        function() return widget[key] end,
        function(value) if not validWidget(widget) or widget.configGeneration ~= generation
                or (active and not active()) then return end; widget[key] = value
            if key == "bottomMinimum" then widget.bottomMaximum = math.max(value + 1, widget.bottomMaximum) end
            if key == "bottomMaximum" then widget.bottomMinimum = math.min(value - 1, widget.bottomMinimum) end
            if key == "signalMinimum" then widget.signalMaximum = math.max(value + 1, widget.signalMaximum) end
            if key == "signalMaximum" then widget.signalMinimum = math.min(value - 1, widget.signalMinimum) end
            if key == "throttleMinimum" then widget.throttleMaximum = math.max(value + 1, widget.throttleMaximum) end
            if key == "throttleMaximum" then widget.throttleMinimum = math.min(value - 1, widget.throttleMinimum) end
            if key == "rfWarnDB" then widget.rfCriticalDB = math.min(widget.rfCriticalDB, value) end
            if key == "rfCriticalDB" then widget.rfWarnDB = math.max(widget.rfWarnDB, value) end
            if key == "rfWarnPercent" then widget.rfCriticalPercent = math.min(widget.rfCriticalPercent, value) end
            if key == "rfCriticalPercent" then widget.rfWarnPercent = math.max(widget.rfWarnPercent, value) end
            if key == "rf2WarnDB" then widget.rf2CriticalDB = math.min(widget.rf2CriticalDB, value) end
            if key == "rf2CriticalDB" then widget.rf2WarnDB = math.max(widget.rf2WarnDB, value) end
            if key == "rf2WarnPercent" then widget.rf2CriticalPercent = math.min(widget.rf2CriticalPercent, value) end
            if key == "rf2CriticalPercent" then widget.rf2WarnPercent = math.max(widget.rf2WarnPercent, value) end
            if key == "rfWarnDB" or key == "rfCriticalDB" or key == "rfWarnPercent"
                or key == "rfCriticalPercent" then widget.rf1Profile = 3 end
            if key == "rf2WarnDB" or key == "rf2CriticalDB" or key == "rf2WarnPercent"
                or key == "rf2CriticalPercent" then widget.rf2Profile = 3 end
            changed(widget)
            if onChanged and validWidget(widget) and widget.configGeneration == generation then onChanged() end
        end)
    if not validWidget(widget) or widget.configGeneration ~= generation then return end
    if suffix then field:suffix(suffix) end
    if step then field:step(step) end
    return field
end

local function choiceField(widget, label, key, choices, onChanged, active)
    local generation = widget.configGeneration
    if not validWidget(widget) then return end
    local line = form.addLine(label, widget.configPanel)
    if not validWidget(widget) or widget.configGeneration ~= generation then return end
    return form.addChoiceField(line, nil, choices,
        function() return widget[key] end,
        function(value) if not validWidget(widget) or widget.configGeneration ~= generation
                or (active and not active()) then return end; widget[key] = value
            if key == "rpmMode" then widget.peakRPM = nil end
            changed(widget)
            if onChanged and validWidget(widget) and widget.configGeneration == generation then onChanged() end
        end)
end

local function colorField(widget, label, key, active)
    local generation = widget.configGeneration
    if not validWidget(widget) then return end
    local line = form.addLine(label, widget.configPanel)
    if not validWidget(widget) or widget.configGeneration ~= generation then return end
    return form.addColorField(line, nil,
        function() return widget[key] end,
        function(value) if not validWidget(widget) or widget.configGeneration ~= generation
                or (active and not active()) then return end; widget[key] = value; changed(widget) end)
end

local function batterySetup(widget)
    return {generation = widget.configGeneration, states = widget.batteryStates,
        pack = widget.batteryStates and widget.batteryStates.Pack, check = widget.packCheckState,
        lossSince = widget.batteryStates and widget.batteryStates.Pack and widget.batteryStates.Pack.lossSince,
        newPack = widget.batteryStates and widget.batteryStates.Pack and widget.batteryStates.Pack.newPack,
        source = widget.consumptionSource, voltageSource = widget.voltageSource,
        currentSource = widget.currentSource, armSource = widget.armSource,
        capacity = widget.capacityMah, cells = widget.cellCount, chemistry = widget.chemistry,
        method = widget.batteryMethod, endDelay = widget.endDelay,
        decision = widget.packCheckState and widget.packCheckState.sample}
end
local function sameBatterySetup(widget, setup)
    return validWidget(widget) and not widget.preview and widget.configGeneration == setup.generation
        and widget.batteryStates == setup.states and widget.packCheckState == setup.check
        and (widget.batteryStates and widget.batteryStates.Pack) == setup.pack
        and (not setup.pack or (setup.pack.lossSince == setup.lossSince and setup.pack.newPack == setup.newPack))
        and widget.consumptionSource == setup.source and widget.voltageSource == setup.voltageSource
        and widget.currentSource == setup.currentSource and widget.armSource == setup.armSource
        and widget.capacityMah == setup.capacity and widget.cellCount == setup.cells
        and widget.chemistry == setup.chemistry and widget.batteryMethod == setup.method
        and widget.endDelay == setup.endDelay
end
local function acceptOtherCounter(widget, setup, key)
    local off = armIsOff(setup.armSource)
    local voltage = sample(setup.voltageSource, "voltage")
    local used = sample(setup.source, "capacity")
    local voltageSelected = selectedSource(setup.voltageSource)
    local unitOK, voltageUnit = pcall(function() return voltageSelected and voltageSelected:unit() end)
    local currentKey = modelKey()
    if not sameBatterySetup(widget, setup) or currentKey ~= key then
        return false, "Setup changed; reopen the menu.", true
    end
    if not setup.pack or not setup.pack.uncertain then return false, "No consumption-counter reset to accept." end
    if not off then return false, "Select a valid ARM source and disarm before confirming." end
    if used == nil or used < 0 or (voltageSelected and (voltage == nil or voltage <= 0)) then
        return false, "Wait for valid pack voltage and consumed mAh."
    end
    if unitOK and (voltageUnit == UNIT_VOLT or voltageUnit == UNIT_MILLIVOLT)
        and voltage ~= nil and round(voltage * 1000 / setup.cells) > round(TYPES[setup.chemistry].full * 1000) + 150 then
        return false, "Check Cells and Battery type first."
    end
    -- Other methods retain their optional remaining-mAh counter reset guard;
    -- their main percentage still comes from the selected method.
    setup.pack.high, setup.pack.uncertain, setup.pack.lossSince, setup.pack.newPack = used, nil, nil, nil
    widget.nextPoll, widget.refresh = 0, true
    return true
end
local function acceptBatteryCounter(widget, setup, expectedKey)
    if not validWidget(widget) or widget.preview then return false, "Exit preview first." end
    setup = setup or batterySetup(widget)
    local key = modelKey()
    if not sameBatterySetup(widget, setup) or (expectedKey and key ~= expectedKey) then
        return false, "Setup changed; reopen the menu.", true
    end
    if setup.method ~= 1 then return acceptOtherCounter(widget, setup, key) end
    local voltage = sample(setup.voltageSource, "voltage")
    local current = sample(setup.currentSource, "current")
    local used = sample(setup.source, "capacity")
    local unitsOK = setup.check and packUnitsValid(setup.check)
    local idleArm = packArmIdle(setup.armSource)
    local currentKey = modelKey()
    if not sameBatterySetup(widget, setup) or currentKey ~= key then
        return false, "Setup changed; reopen the menu.", true
    end
    local state, clock = setup.check, os.clock()
    if setup.method ~= 1 or not setup.pack or not state then
        return false, "Wait for a consumed-mAh battery check and reopen the menu."
    end
    if not unitsOK or used == nil or used < 0 or voltage == nil or voltage <= 0 or current == nil or current < 0 then
        clearPackCheckWindow(state)
        return false, "Wait for valid pack voltage, current and consumed mAh."
    end
    if current > packCheckCurrent(widget) or not idleArm then
        state.holdUntil = clock + PACK_CHECK_RELAX_SECONDS
        clearPackCheckWindow(state)
        return false, "Disarm and let the battery settle at low current; then reopen the menu."
    end
    local decision = packDecision(widget, voltage, used)
    if decision.band == "cells" then return false, "Check Cells and Battery type first." end
    if decision.band == "blocked" then
        return false, string.format("Difference %.1f pp exceeds 20 pp. Check battery charge, Cells / Battery type and consumed mAh.", packDifference(decision))
    end
    if state.qualified then return false, "Battery already checked." end
    if not state.ready or not state.lastClock or clock < state.lastClock or clock - state.lastClock > 1
        or (state.holdUntil and clock < state.holdUntil)
        or math.max(state.maximum or decision.cellMv, decision.cellMv)
            - math.min(state.minimum or decision.cellMv, decision.cellMv) > PACK_CHECK_STABILITY_MV then
        clearPackCheckWindow(state)
        return false, "Wait for a stable low-current check and reopen the menu."
    end
    if not samePackDecision(setup.decision, decision) then
        clearPackCheckWindow(state)
        return false, "Readings changed; wait for a new check and reopen the menu."
    end
    -- Explicit acceptance applies to this verified battery episode only.
    setup.pack.high, setup.pack.uncertain, setup.pack.lossSince, setup.pack.newPack = used, nil, nil, nil
    state.qualified, state.problem, state.requiresCounterAcceptance = true, nil, nil
    widget.nextPoll, widget.refresh = 0, true
    return true
end
local function confirmBatteryCounter(widget)
    if not validWidget(widget) then return end
    local setup = batterySetup(widget)
    local key = modelKey()
    if not sameBatterySetup(widget, setup) then return end
    local state, decision, title, message = setup.check, setup.decision
    if setup.method ~= 1 and setup.pack and setup.pack.uncertain then
        message = "Check actual charge and consumed mAh before accepting this counter reset. ARM must be OFF. Acceptance affects the optional remaining-mAh reading; battery percentage still follows Remaining from."
    elseif setup.method ~= 1 then
        title, message = "Consumption counter", "No consumption-counter reset to accept. Battery percentage follows the selected Remaining from method."
    elseif state and state.qualified then
        title, message = "Battery already checked", "The current battery counter is accepted. A new battery episode will be checked again."
    elseif decision and decision.band == "cells" then
        title, message = "Check battery settings", "Pack voltage exceeds the selected Cells / Battery type. Correct the setup first."
    elseif decision and decision.band == "blocked" then
        title, message = "Check pack/counter", string.format("Counter %.1f%%; voltage reference %.1f%%. Difference %.1f pp exceeds 20 pp. Check charge, Cells / Battery type and consumed mAh.",
            decision.counterBP / 100, decision.referenceBP / 100, packDifference(decision))
    elseif not state or not state.ready or not decision then
        title, message = "Checking battery", string.format("Wait for valid readings and 10 s of stable voltage at current at most %.3f A. Disarm first; after load, allow at least 60 s to settle.", packCheckCurrent(widget))
    elseif not decision.referenceBP then
        message = string.format("LiFe voltage cannot reliably check charge. Counter %.1f%%. Confirm only after checking actual battery charge, capacity and consumed mAh. Acceptance does not restore missing consumption.", decision.counterBP / 100)
    else
        message = string.format("Counter %.1f%%; voltage reference %.1f%%. Difference %.1f pp. Confirm only after checking actual battery charge, Cells / Battery type and consumed mAh. Acceptance does not restore missing consumption.",
            decision.counterBP / 100, decision.referenceBP / 100, packDifference(decision))
    end
    if title then
        form.openDialog({title = title, message = message,
            buttons = {{label = "Close", action = function() return true end}}})
        return
    end
    form.openDialog({title = "Accept battery counter?", message = message,
        buttons = {{label = "Cancel", action = function() return true end},
            {label = "Confirm", action = function()
                if not sameBatterySetup(widget, setup) then return true end
                local ok, problem, stale = acceptBatteryCounter(widget, setup, key)
                if not ok and not stale then
                    widget.pendingBatteryMessage = {message = problem, key = key,
                        generation = setup.generation, check = setup.check}
                    widget.nextPoll, widget.refresh = 0, true
                end
                lcd.invalidate(); return true
            end}}})
end



local function configure(widget)
    if not validWidget(widget) then return end
    widget.configGeneration = (widget.configGeneration or 0) + 1
    widget.nextPoll = 0
    local generation, bindings = widget.configGeneration, {}
    local function currentForm()
        return validWidget(widget) and widget.configGeneration == generation
    end
    local function bind(field, active)
        if currentForm() and field and active then bindings[#bindings + 1] = {field = field, active = active} end
        return field
    end
    local function refreshFields()
        for _, binding in ipairs(bindings) do
            if not currentForm() then return end
            if type(binding.field.enable) == "function" then
                local enabled = binding.active()
                if not currentForm() then return end
                binding.field:enable(enabled)
            end
        end
    end
    local function number(label, key, minimum, maximum, suffix, step, active)
        if not currentForm() then return end
        return bind(numberField(widget, label, key, minimum, maximum, suffix, step, refreshFields, active), active)
    end
    local function choice(label, key, choices, active)
        if not currentForm() then return end
        return bind(choiceField(widget, label, key, choices, refreshFields, active), active)
    end
    local function color(label, key, active)
        if not currentForm() then return end
        return bind(colorField(widget, label, key, active), active)
    end
    local function hasKind(wanted)
        if not currentForm() then return false end
        local kinds = resolvedDeckKinds(widget)
        if not currentForm() then return false end
        for _, kind in ipairs(kinds) do if kind == wanted then return true end end
        return false
    end
    local function hasRPM() return hasKind(2) end
    local function hasWatts() return hasKind(3) end
    local function custom() return hasKind(1) end
    local function customSource() return widget.deckMode ~= 8 end
    local function customPosition() return widget.deckMode ~= 1 and widget.deckMode ~= 8 and custom() end
    local function meter() return widget.deckMode ~= 8 and widget.bottomDisplay == 2 end
    local function redZone() return meter() and (custom() or hasRPM() or hasWatts()) end
    local function logging() return widget.logEnabled end
    local function alerting() return widget.alarmEnabled end
    cancelAutoLog(widget)
    widget.configPanel = nil
    form.addLine("VoltDeck " .. VERSION)
    if not currentForm() then return end
    local function group(label)
        if not currentForm() then return end
        local panel = form.addExpansionPanel(label)
        if not currentForm() then return end
        widget.configPanel = panel
        panel:open(false)
    end
    local function note(message)
        if not currentForm() then return end
        local line = form.addLine("", widget.configPanel)
        local ok, width = pcall(form.width)
        if not currentForm() then return end
        form.addStaticText(line, {x = 10, y = 0, w = ok and width - 20 or 720, h = 30}, message)
    end
    local function boolean(label, key, alarmReset, active)
        if not currentForm() then return end
        local line = form.addLine(label, widget.configPanel)
        if not currentForm() then return end
        local field = form.addBooleanField(line, nil, function() return widget[key] end,
            function(value) if not currentForm() or (active and not active()) then return end; widget[key] = value
                if key == "autoLogEnabled" or key == "logEnabled" or key == "preview" then cancelAutoLog(widget) end
                changed(widget, alarmReset)
                if currentForm() then refreshFields() end
            end)
        return bind(field, active)
    end
    local function sourceField(label, key, alarmReset, active)
        if not currentForm() then return end
        local line = form.addLine(label, widget.configPanel)
        if not currentForm() then return end
        local field = form.addSourceField(line, nil, function() return widget[key] end,
            function(value)
                if not currentForm() or (active and not active()) then return end
                local source = selectedSource(value)
                if not currentForm() or (active and not active()) then return end
                widget[key] = source; changed(widget, alarmReset)
                if currentForm() then refreshFields() end
            end)
        return bind(field, active)
    end
    local function stringField(label, key, dirty, alarmReset, active)
        if not currentForm() then return end
        local line = form.addLine(label, widget.configPanel)
        if not currentForm() then return end
        local field = form.addTextField(line, nil, function() return widget[key] end,
            function(value)
                if not currentForm() or (active and not active()) then return end
                widget[key] = key == "audioFolder" and normalizeAudioFolder(value) or value or ""
                if dirty then widget[dirty] = true end
                changed(widget, alarmReset)
            end)
        return bind(field, active)
    end
    local function fileField(label, folder, filter, getter, setter, active)
        if not currentForm() then return end
        local line = form.addLine(label, widget.configPanel)
        if not currentForm() then return end
        local field = form.addFileField(line, nil, folder, filter, getter, function(value)
            if not currentForm() or (active and not active()) then return end
            setter(value)
        end)
        return bind(field, active)
    end

    if widget.configError then note(widget.configError) end

    group("Battery")
    choice("Remaining from", "batteryMethod",
        {{"Consumed mAh", 1}, {"% sensor", 2}, {"Voltage estimate", 3}})
    choice("Battery type", "chemistry", {{"Lipo", 1}, {"LiHV", 2}, {"Li-ion", 3}, {"LiFe", 4}})
    number("Capacity", "capacityMah", 100, 100000, "mAh", 50)
    number("Cells", "cellCount", 1, 16, nil, 1)
    choice("mAh display", "mahDisplay", {{"Consumed", 1}, {"Remaining", 2}})

    group("Appearance")
    choice("Background", "backgroundMode", {{"Radio theme", 1}, {"Black", 2}, {"Custom", 3}})
    color("Background color", "backgroundColor", function() return widget.backgroundMode == 3 end)
    color("Accent color", "accentColor", function() return widget.backgroundMode ~= 1 end)
    stringField("Font file", "fontPath", "fontDirty")
    local line
    choice("Image source", "imageMode", {{"Selected model", 1}, {"Image file", 2}, {"Hidden", 3}})
    fileField("Image file", "/bitmaps/models", "image+ext",
        function() return widget.imageName:gsub("^/bitmaps/models/", "") end,
        function(value) widget.imageName = value or ""; widget.imageDirty = true; changed(widget) end,
        function() return widget.imageMode == 2 end)

    group("Battery alert")
    boolean("Battery alert", "alarmEnabled", true)
    boolean("Alert on estimate", "alarmEstimate", true, function() return alerting() and widget.batteryMethod == 3 end)
    number("Repeat", "alertInterval", 1, 600, "s", 1, alerting)
    stringField("Audio folder", "audioFolder", nil, true, alerting)
    local pickerFolder = normalizeAudioFolder(widget.audioFolder)
    fileField("Alert WAV", pickerFolder, "audio+ext", function()
        local prefix = pickerFolder .. "/"
        return widget.alarmSound:sub(1, #prefix) == prefix and widget.alarmSound:sub(#prefix + 1) or widget.alarmSound
    end, function(value) widget.alarmSound = audioPath(pickerFolder, value)
        widget.checkedSound = nil
        changed(widget, true)
    end, alerting)

    group("Telemetry")
    for _, definition in ipairs(SOURCE_FIELDS) do
        sourceField(definition.label, definition.key, true, definition.key == "percentSource"
            and function() return widget.batteryMethod == 2 end or nil)
    end
    group("RF signals")
    local rfProfiles = {{"ACCESS / TD / TW", 1}, {"ACCST", 2}, {"Custom", 3}}
    choice("RF1 profile", "rf1Profile", rfProfiles)
    choice("RF2 profile", "rf2Profile", rfProfiles)
    number("RSSI scale min", "signalMinimum", -150, 199, "dB", 1)
    number("RSSI scale max", "signalMaximum", -149, 200, "dB", 1)
    number("RF1 low RSSI", "rfWarnDB", -149, 200, "dB", 1, function() return widget.rf1Profile == 3 end)
    number("RF1 critical RSSI", "rfCriticalDB", -150, 199, "dB", 1, function() return widget.rf1Profile == 3 end)
    number("RF1 early VFR", "rfWarnPercent", 1, 100, "%", 1, function() return widget.rf1Profile == 3 end)
    number("RF1 low VFR", "rfCriticalPercent", 0, 99, "%", 1, function() return widget.rf1Profile == 3 end)
    number("RF2 low RSSI", "rf2WarnDB", -149, 200, "dB", 1, function() return widget.rf2Profile == 3 end)
    number("RF2 critical RSSI", "rf2CriticalDB", -150, 199, "dB", 1, function() return widget.rf2Profile == 3 end)
    number("RF2 early VFR", "rf2WarnPercent", 1, 100, "%", 1, function() return widget.rf2Profile == 3 end)
    number("RF2 low VFR", "rf2CriticalPercent", 0, 99, "%", 1, function() return widget.rf2Profile == 3 end)

    group("Lower deck")
    choice("Show", "deckMode", {{"Only Custom", 1}, {"RPM", 2}, {"Watts", 3},
        {"Cell volts", 4}, {"Voltage estimate", 5}, {"RPM + Watts", 6}, {"RPM + W + cell", 7}, {"Hidden", 8}})
    choice("Meter style", "bottomDisplay", {{"Numeric", 1}, {"Retro LCD", 2}}, function() return widget.deckMode ~= 8 end)
    sourceField("Custom source", "bottomSource", nil, customSource)
    number("Custom position", "customPosition", 1, 3, nil, 1, customPosition)
    stringField("Custom label", "bottomLabel", nil, nil, custom)
    number("Custom min", "bottomMinimum", -100000, 999999, nil, 1, function() return custom() and meter() end)
    number("Custom max", "bottomMaximum", -99999, 1000000, nil, 100, function() return custom() and meter() end)
    number("Decimals (-1 auto)", "bottomDecimals", -1, 3, nil, 1, custom)
    number("Red zone", "redZone", 10, 100, "%", 1, redZone)
    number("Watt max", "wattMaximum", 10, 100000, "W", 100, function() return hasWatts() and meter() end)

    group("Motor / RPM")
    sourceField("RPM source", "rpmSource", nil, function() return logging() or (hasRPM() and widget.rpmMode == 1) end)
    choice("RPM value", "rpmMode", {{"Measured RPM", 1}, {"KV x volts (est.)", 2}}, hasRPM)
    number("Motor KV", "motorKV", 0, 10000, "rpm/V", 10, function() return logging() or (hasRPM() and (widget.rpmMode == 2 or (meter() and widget.rpmScale == 2))) end)
    number("Estimate factor", "loadFactor", 10, 100, "%", 1, function() return hasRPM() and widget.rpmMode == 2 end)
    choice("RPM scale", "rpmScale", {{"Manual", 1}, {"Full-pack KV", 2}}, function() return hasRPM() and meter() end)
    number("RPM max", "rpmMaximum", 1000, 200000, "rpm", 1000, function() return hasRPM() and meter() and (widget.rpmScale == 1 or widget.motorKV <= 0) end)

    group("Flight log")
    boolean("Enable log", "logEnabled")
    sourceField("Arm switch", "armSource")
    sourceField("Throttle source", "throttleSource")
    sourceField("Airborne gate", "airborneSource")
    number("Throttle low (raw)", "throttleMinimum", -2048, 2047, nil, 1)
    number("Throttle high (raw)", "throttleMaximum", -2047, 2048, nil, 1)
    number("Flight minimum", "flightMinimum", 60, 3600, "s", 10, logging)
    number("Throttle gate", "throttleThreshold", 10, 100, "%", 5, logging)
    number("High throttle", "highThrottleSeconds", 1, 120, "s", 1, logging)
    -- Keep the checked settings key/order compatible with earlier builds.
    number("Pack loss delay", "endDelay", 3, 120, "s", 1)
    boolean("Auto-open log", "autoLogEnabled", nil, logging)
    number("Extra log delay", "autoLogDelay", 0, 120, "s", 1, function() return logging() and widget.autoLogEnabled end)
    sourceField("RF graph 1", "graph1Source", nil, logging)
    sourceField("RF graph 2", "graph2Source", nil, logging)
    if not currentForm() then return end
    line = form.addLine("Reset counter", widget.configPanel)
    if not currentForm() then return end
    bind(form.addButton(line, nil, {text = "Reset...", press = function()
        if not currentForm() or not logging() then return end
        local session, armSource = widget.flightSession, widget.armSource
        local armed = switchOn(armSource)
        if not currentForm() or not logging() or widget.flightSession ~= session or widget.armSource ~= armSource then return end
        if not session or session.current or armed then
            form.openDialog({title = "Flight counter", message = "Enable log, disarm and disconnect pack before reset.",
                buttons = {{label = "OK", action = function() return true end}}})
            return
        end
        local key = session.key
        form.openDialog({title = "Reset flight count?", message = widget.data.modelName or "Current model",
            buttons = {{label = "Cancel", action = function() return true end},
                {label = "Reset", action = function()
                    if not currentForm() or not logging() or widget.flightSession ~= session then return true end
                    local armSource = widget.armSource
                    local armed, currentKey = switchOn(armSource), modelKey()
                    if not currentForm() or not logging() or widget.flightSession ~= session or widget.armSource ~= armSource
                        or currentKey ~= key or armed or session.current then return true end
                    session.count, session.last = 0, nil
                    session.pending, session.attempts, session.retryAt = true, 0, 0
                    session.revision = session.revision + 1
                    widget.refresh = true
                    return true
                end}}})
    end}), logging)

    group("Preview")
    boolean("Preview", "preview")
    if currentForm() then refreshFields(); widget.configPanel = nil end
end

local function destroy(widget)
    if not validWidget(widget) then return end
    widget.destroyed = true
    widget.autoLogSession, widget.autoLogSeen, widget.autoLogDue = nil, nil, nil
    widget.modelImage, widget.valueFont, widget.flightSession = nil, nil, nil
    widget.checkedSound, widget.soundDuration = nil, nil
    widget.rfGraphs, widget.rfGraphWork = nil, nil
    widget.metadata, widget.batteryStates, widget.alertStates = nil, nil, nil
    widget.packCheckState = nil
    widget.pendingBatteryMessage = nil
    widget.focusRepaintAt = nil
    if FLIGHT_SESSION and FLIGHT_SESSION.owner == widget then
        FLIGHT_SESSION.owner, FLIGHT_SESSION.lastClock = nil, nil
        if FLIGHT_SESSION.current then FLIGHT_SESSION.current.running = false end
    end
    collectResources()
end

local function menu(widget)
    if not validWidget(widget) then return {} end
    return {
        {(widget.logVisible or widget.diagnosticsVisible) and "Dashboard" or "Flight log", function()
            if not validWidget(widget) then return end
            cancelAutoLog(widget)
            if widget.diagnosticsVisible then widget.logVisible = false
            else widget.logVisible = not widget.logVisible end
            widget.diagnosticsVisible, widget.refresh = false, true
            lcd.invalidate()
        end},
        {"Flight diagnostics", function()
            if not validWidget(widget) then return end
            cancelAutoLog(widget)
            widget.diagnosticsVisible, widget.logVisible, widget.refresh = true, false, true
            lcd.invalidate()
        end},
        {"Reset live peaks", function()
            if not validWidget(widget) then return end
            widget.peakRPM, widget.peakWatts = nil, nil; changed(widget) end},
        {"Accept battery counter...", function()
            confirmBatteryCounter(widget) end},
    }
end

local function init()
    system.registerWidget({
        key = "vdeck", name = "VoltDeck", create = create, paint = paint,
        wakeup = wakeup, configure = configure, read = read, write = write,
        menu = menu, destroy = destroy,
        persistent = true, title = false,
    })
end

return {init = init}
