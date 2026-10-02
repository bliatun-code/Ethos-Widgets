-- SPDX-License-Identifier: MIT
-- Copyright (c) 2026 bliatun-code and VoltDeck contributors.
-- VoltDeck: theme-aware full-screen telemetry for FrSky Ethos / X20RS.
-- Configure one full-screen zone in Ethos. Scalar settings are saved per model.
-- Artwork is drawn natively. Model images and optional alert audio are user-selected.

local VERSION = "2026.5-v2"
local MAX_IMAGE_PIXELS = 160000
local BITMAP_RESERVE = 65536
local FLIGHT_SESSION
local HISTORY_POINTS = 180
local GRAPH_BINS = 48
local GRAPH_SOURCE_STEPS = 32
local GRAPH_BIN_STEPS = 24
local BITMAP_CACHE = setmetatable({}, {__mode = "v"})
local VALUE_FONTS = {FONT_XXL, FONT_XL, FONT_L_BOLD, FONT_L, FONT_M_BOLD, FONT_M, FONT_S, FONT_XS}
local SMALL_FONTS = {FONT_S, FONT_XS}
local LOW_BATTERY_PERCENT = 30
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
    {name = "Lipo", full = 4.20, empty = 3.30},
    {name = "HV Lipo", full = 4.35, empty = 3.40},
    {name = "Li-ion", full = 4.20, empty = 3.00},
    {name = "LiFe", full = 3.65, empty = 2.80},
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
}

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function round(value)
    return math.floor(value + 0.5)
end

local function finite(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge
end

local function getSource(parameters)
    local ok, source = pcall(system.getSource, parameters)
    if ok then return source end
end

local function restoreSource(value)
    if type(value) == "string" and value ~= "" then
        return getSource(value)
    elseif type(value) == "number" then
        return getSource({category = CATEGORY_TELEMETRY_SENSOR, appId = value})
    elseif type(value) == "userdata" or type(value) == "table" then
        return value
    end
end

local function changed(widget, resetAlarm)
    widget.refresh = true
    widget.nextPoll = 0
    if resetAlarm then widget.lastAlert = nil end
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
    return {
        chemistry = 1, cellCount = 6, capacityMah = 2500,
        alarmEnabled = true, alarmSound = "", audioFolder = "/audio", alertInterval = 10,
        mahDisplay = 1, preview = false, imageName = "", imageMode = 1, imageDirty = true,
        alarmEstimate = false, batteryMethod = 1,
        backgroundMode = 1, backgroundColor = COLORS.black, accentColor = COLORS.accent,
        bottomDisplay = 2, bottomMinimum = 0, bottomMaximum = 100,
        bottomDecimals = -1, bottomLabel = "", redZone = 85,
        signalMinimum = 0, signalMaximum = 100,
        fontPath = "", fontDirty = true,
        deckMode = 6, rpmMode = 1, motorKV = 0, loadFactor = 100, rpmScale = 1,
        rpmMaximum = 12000, wattMaximum = 2000, cellMaximum = 440,
        logEnabled = false, flightMinimum = 60, throttleThreshold = 50,
        highThrottleSeconds = 5, endDelay = 10,
        throttleMinimum = -1024, throttleMaximum = 1024,
        rfWarnDB = 45, rfCriticalDB = 42, rfWarnPercent = 95, rfCriticalPercent = 90,
        timerSource = getSource({category = CATEGORY_TIMER, member = 0}),
        builtinTx = getSource({category = CATEGORY_SYSTEM,
            member = SYSTEM_MAIN_VOLTAGE or MAIN_VOLTAGE}),
        data = {}, scratch = {}, nextPoll = 0, refresh = true,
    }
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
    if not bytes or #bytes > CONFIG_LIMIT then return nil end
    local body, check = bytes:match("^(.*\n)CHECK=(%d+)\n$")
    if not body or tonumber(check) ~= digest(body) then return nil end
    local identity, sequence, payload = body:match("^VD3|(%x+)|(%d+)\n(.*)$")
    sequence = tonumber(sequence)
    if identity ~= identityHex(key) or not sequence or sequence > 1000000000 then return nil end
    local values, count = {}, 0
    for name, kind, value in payload:gmatch("([%a]+)=([nbs]):([^\n]*)\n") do
        if values[name] ~= nil then return nil end
        if kind == "n" then
            value = tonumber(value)
            if not finite(value) then return nil end
        elseif kind == "b" then
            if value ~= "0" and value ~= "1" then return nil end
            value = value == "1"
        else
            if #value > 512 or #value % 2 ~= 0 or value:find("[^%x]") then return nil end
            value = value:lower():gsub("%x%x", HEX_DECODE)
        end
        values[name], count = value, count + 1
    end
    if count ~= #SETTINGS then return nil end
    for _, name in ipairs(SETTINGS) do if values[name] == nil then return nil end end
    return {values = values, sequence = sequence, payload = payload}
end

local function configLoad(key)
    if not key then return nil, nil, "Model path unavailable" end
    local base = "/scripts/vc" .. tostring(digest(key))
    local a, b = header(base .. "a.cfg", CONFIG_LIMIT + 1), header(base .. "b.cfg", CONFIG_LIMIT + 1)
    local function generation(bytes)
        if not bytes or #bytes > CONFIG_LIMIT then return -1 end
        local identity, sequence = bytes:match("^VD3|(%x+)|(%d+)\n")
        if identity ~= identityHex(key) then return -1 end
        sequence = tonumber(sequence)
        return sequence and sequence <= 1000000000 and sequence or -1
    end
    -- Fully validate newest first; inspect the older copy only for recovery.
    if generation(b) > generation(a) then a, b = b, a end
    local latest = configRecord(key, a)
    if not latest then latest = configRecord(key, b) end
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
    return table.concat(lines)
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
    local body = "VD3|" .. identityHex(key) .. "|" .. sequence .. "\n" .. payload
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
    local value = settingRead(key)
    if finite(value) then return round(clamp(value, minimum, maximum)) end
    return default
end

local function read(widget)
    widget.configKey = modelKey()
    local record, base, problem = configLoad(widget.configKey)
    widget.configError, widget.configPath = problem, base
    widget.configPayload = record and record.payload or nil
    -- ETHOS storage is an ordered stream; labels are diagnostic, not map keys.
    -- Read exactly the same sequence that write() emits, with its header first.
    local first = storage.read("v")
    local native, legacy, compact = {}, {}, false
    if first == "VD4" or first == "3" then
        compact = true
        for index, key in ipairs(SOURCE_KEYS) do native[key] = storage.read(string.char(96 + index)) end
    elseif type(first) == "userdata" or type(first) == "table" or first == "" then
        -- Recover the first compact prototype (sources, followed by its marker).
        compact, native[SOURCE_KEYS[1]] = true, first
        for index = 2, #SOURCE_KEYS do native[SOURCE_KEYS[index]] = storage.read(string.char(96 + index)) end
        storage.read("v")
    elseif finite(first) then
        -- Original scalar-first record. Preserve its original write order.
        legacy[SETTINGS[1]] = first
        for index = 2, #SETTINGS do legacy[SETTINGS[index]] = storage.read(SETTINGS[index]) end
        for _, key in ipairs(SOURCE_KEYS) do native[key] = storage.read(key) end
        storage.read("battVersion")
    elseif first == nil then
        -- Empty native storage (also supports the older keyed regression fixture).
        for _, key in ipairs(SETTINGS) do legacy[key] = storage.read(key) end
        for _, field in ipairs(SOURCE_FIELDS) do
            native[field.key] = storage.read(field.key)
            if native[field.key] == nil and field.legacy then native[field.key] = storage.read(field.legacy) end
        end
        for index = 11, #SOURCE_KEYS do native[SOURCE_KEYS[index]] = storage.read(SOURCE_KEYS[index]) end
    else
        widget.configError = "Unknown source storage format; reselect sources"
    end
    settingValues = record and record.values or (compact and {} or legacy)
    widget.chemistry = numberSetting("chemistry", 1, 1, #TYPES)
    widget.cellCount = numberSetting("cellCount", 6, 1, 16)
    widget.capacityMah = numberSetting("capacityMah", 2500, 100, 100000)
    widget.alertInterval = numberSetting("alertInterval", 10, 1, 600)
    widget.mahDisplay = numberSetting("mahDisplay", 1, 1, 2)
    local enabled = settingRead("alarmEnabled")
    if enabled == nil then enabled = settingRead("lowBeep") end
    widget.alarmEnabled = enabled ~= false
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
    widget.imageMode = numberSetting("imageMode", widget.imageName ~= "" and 2 or 1, 1, 3)
    widget.alarmEstimate = settingRead("alarmEstimate") == true
    widget.batteryMethod = numberSetting("batteryMethod", 1, 1, 3)
    for _, key in ipairs(SOURCE_KEYS) do
        local value = native[key]
        if key ~= "timerSource" or value ~= nil then widget[key] = restoreSource(value) end
    end
    local options = {
        {"deckMode", widget.bottomSource and 1 or 6, 1, 8},
        {"rpmMode", 1, 1, 2}, {"motorKV", 0, 0, 10000},
        {"loadFactor", 100, 10, 100}, {"rpmScale", 1, 1, 2},
        {"rpmMaximum", 12000, 1000, 200000}, {"wattMaximum", 2000, 10, 100000},
        {"cellMaximum", 440, 200, 500}, {"flightMinimum", 60, 60, 3600},
        {"throttleThreshold", 50, 10, 100}, {"highThrottleSeconds", 5, 1, 120},
        {"endDelay", 10, 3, 120}, {"throttleMinimum", -1024, -2048, 2047},
        {"throttleMaximum", 1024, -2047, 2048}, {"rfWarnDB", 45, -149, 200},
        {"rfCriticalDB", 42, -150, 199}, {"rfWarnPercent", 95, 1, 100},
        {"rfCriticalPercent", 90, 0, 99},
    }
    for _, option in ipairs(options) do widget[option[1]] = numberSetting(option[1], option[2], option[3], option[4]) end
    widget.logEnabled = settingRead("logEnabled") == true
    if widget.throttleMaximum <= widget.throttleMinimum then widget.throttleMaximum = widget.throttleMinimum + 1 end
    if widget.rfCriticalDB > widget.rfWarnDB then widget.rfCriticalDB = widget.rfWarnDB end
    if widget.rfCriticalPercent > widget.rfWarnPercent then widget.rfCriticalPercent = widget.rfWarnPercent end
    settingValues = nil
    widget.imageDirty, widget.fontDirty = true, true
    changed(widget)
end

local function write(widget)
    local ok, problem = configSave(widget)
    widget.configError = not ok and problem or nil
    if not ok then print("VoltDeck settings NOT saved: " .. problem) end
    -- Header and sources must be read/written in this exact order.
    storage.write("v", "VD4")
    for index, key in ipairs(SOURCE_KEYS) do storage.write(string.char(96 + index), widget[key] or "") end
end

local function sample(source, quantity)
    if not source then return nil end
    local ok, active, value, unit = pcall(function()
        return source:state(), source:value(), source:unit()
    end)
    if not ok or not finite(value) then return nil end
    if active == false then
        -- Timer state means running/stopped, not valid/missing telemetry.
        local categoryOK, category = pcall(function() return source:category() end)
        if not categoryOK then return nil end
        local timerValid = quantity == "timer" and category == CATEGORY_TIMER
        local controlValid = quantity == "control" and category ~= CATEGORY_TELEMETRY_SENSOR
        if not timerValid and not controlValid then return nil end
    end
    if quantity == "signal" and unit ~= UNIT_DB and unit ~= UNIT_PERCENT and unit ~= UNIT_NONE then return nil end
    if quantity == "rpm" and unit ~= UNIT_RPM and unit ~= UNIT_NONE then return nil end
    if quantity == "voltage" and unit ~= UNIT_VOLT and unit ~= UNIT_MILLIVOLT and unit ~= UNIT_NONE then return nil end
    if quantity == "current" and unit ~= UNIT_AMPERE and unit ~= UNIT_MILLIAMPERE and unit ~= UNIT_NONE then return nil end
    if quantity == "capacity" and unit ~= UNIT_MILLIAMPERE_HOUR and unit ~= UNIT_AMPERE_HOUR and unit ~= UNIT_NONE then return nil end
    if quantity == "voltage" and unit == UNIT_MILLIVOLT then
        value = value / 1000
    elseif quantity == "current" and unit == UNIT_MILLIAMPERE then
        value = value / 1000
    elseif quantity == "capacity" and unit == UNIT_AMPERE_HOUR then
        value = value * 1000
    end
    return value
end

local function sourceDetails(source, fallbackName, fallbackUnit)
    if source then
        local ok, name, unit, decimals = pcall(function()
            return source:name(), source:stringUnit(), source:decimals()
        end)
        if ok then
            return type(name) == "string" and name or fallbackName,
                type(unit) == "string" and unit or fallbackUnit,
                finite(decimals) and clamp(decimals, 0, 3) or 0
        end
    end
    return fallbackName, fallbackUnit, 0
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

local function memorySnapshot(widget)
    local m = memory()
    print(string.format("VoltDeck %s LuaFree=%s BitmapFree=%s Image=%s Pixels=%s",
        VERSION, tostring(m.luaRamAvailable), tostring(m.luaBitmapsRamAvailable),
        widget.loadedImagePath or "-", tostring(widget.imagePixels or 0)))
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
    if not source then return false end
    local ok, value = pcall(function() return source:value() end)
    return ok and (value == true or (finite(value) and value > 0))
end

local function throttlePercent(widget)
    local value = sample(widget.throttleSource, "control")
    if value == nil then return nil end
    return clamp((value - widget.throttleMinimum) * 100
        / math.max(1, widget.throttleMaximum - widget.throttleMinimum), 0, 100)
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

local function updateFlight(widget, data, clock, key)
    if not widget.logEnabled or widget.preview or not key then
        if FLIGHT_SESSION and FLIGHT_SESSION.owner == widget then
            FLIGHT_SESSION.current, FLIGHT_SESSION.owner = nil, nil
        end
        widget.flightSession = nil
        return
    end
    if not FLIGHT_SESSION or FLIGHT_SESSION.key ~= key then FLIGHT_SESSION = newSession(key) end
    local session = FLIGHT_SESSION
    widget.flightSession = session
    if session.owner and session.owner ~= widget then
        data.logCount, data.logState, data.logRevision = session.count, "Shared log", session.revision
        return
    end
    session.owner = widget
    local dt = session.lastClock and clamp(clock - session.lastClock, 0, 1) or 0
    session.lastClock = clock
    local armed = switchOn(widget.armSource)
    local throttle = throttlePercent(widget)
    local gate = not widget.airborneSource or switchOn(widget.airborneSource)
    local ready = widget.armSource and throttle ~= nil and data.voltage ~= nil
    if not armed then session.lockout = false end
    if ready and armed and gate and not session.current and not session.lockout then
        local _, unit1 = sourceDetails(widget.graph1Source or widget.rssi1Source, "RF1", "dB")
        local _, unit2 = sourceDetails(widget.graph2Source or widget.rssi2Source, "RF2", "dB")
        session.current = {started = clock, duration = 0, highTime = 0, modelName = data.modelName,
            unit1 = unit1, unit2 = unit2, counted = false,
            history = {count = 0, interval = 1, next = clock + 1,
                rf1 = {}, rf2 = {}, times = {}, missing1 = {}, missing2 = {}}}
        session.last = nil
        dt = 0
    end
    local flight = session.current
    if flight then
        if data.voltage == nil then
            flight.lossSince = flight.lossSince or clock
        else flight.lossSince = nil end
        if armed and ready and gate then
            flight.duration = flight.duration + dt
            if throttle >= widget.throttleThreshold then flight.highTime = flight.highTime + dt end
            if data.voltage ~= nil then
                flight.minVoltage = minimum(flight.minVoltage, data.voltage)
                flight.maxVoltage = math.max(flight.maxVoltage or data.voltage, data.voltage)
            end
            if data.current ~= nil then flight.maxCurrent = math.max(flight.maxCurrent or 0, data.current) end
            if data.rpm ~= nil then flight.maxRPM = math.max(flight.maxRPM or 0, data.rpm) end
            if data.rpmPotential ~= nil then flight.maxPotential = math.max(flight.maxPotential or 0, data.rpmPotential) end
            if data.watts ~= nil then flight.maxWatts = math.max(flight.maxWatts or 0, data.watts) end
            flight.minRF1, flight.minRF2 = minimum(flight.minRF1, data.graph1), minimum(flight.minRF2, data.graph2)
            if not flight.counted and flight.duration >= widget.flightMinimum
                and flight.highTime >= widget.highThrottleSeconds then
                flight.counted = true
                session.count = math.min(999999, session.count + 1)
                session.pending, session.attempts, session.retryAt = true, 0, clock
            end
            flight.endSince = nil
        elseif not armed or not gate then flight.endSince = flight.endSince or clock end
        if graphSample(flight, clock, data.graph1, data.graph2) then session.revision = session.revision + 1 end
        if (flight.endSince and clock - flight.endSince >= widget.endDelay)
            or (flight.lossSince and clock - flight.lossSince >= 30) then
            flight.elapsed = clock - flight.started
            if flight.counted then session.last = flight end
            session.current, session.lockout = nil, armed
            session.revision = session.revision + 1
        end
    end
    if session.pending and clock >= session.retryAt and session.attempts < 3 then
        session.attempts = session.attempts + 1
        saveCounter(session)
        session.retryAt = clock + 5
    end
    data.logCount = session.count
    data.logState = session.error or (not widget.armSource and "Choose arm source")
        or (not widget.throttleSource and "Choose throttle")
        or (session.current and (session.current.counted and "FLIGHT" or "Qualifying"))
        or (session.lockout and "Disarm to rearm") or "Ready"
    data.logRevision = session.revision
end

local function alarm(widget, data, clock)
    if widget.preview or not widget.alarmEnabled or data.percent == nil
        or data.percent > LOW_BATTERY_PERCENT
        or (data.estimated and not widget.alarmEstimate) then
        widget.lastAlert = nil
        return
    end
    local path = audioPath(widget.audioFolder, widget.alarmSound)
    if widget.checkedSound ~= path then
        widget.checkedSound, widget.soundDuration = path, path ~= "" and audioInfo(path) or nil
        if path ~= "" and not widget.soundDuration then
            print("VoltDeck: invalid/missing WAV; using tone [" .. path .. "]")
        end
    end
    local interval = math.max(widget.alertInterval, (widget.soundDuration or 0) + 0.5)
    if widget.lastAlert and clock >= widget.lastAlert and clock - widget.lastAlert < interval then return end
    widget.lastAlert = clock
    if path ~= "" and widget.soundDuration then
        local ok = pcall(system.playFile, path)
        if ok then return end
    end
    pcall(system.playTone, 1200, 250, 50)
end

-- Keep the 180-point history; build a 48-bin trace outside paint, in small slices.
local function prepareFlightGraphs(widget, clock)
    local session = widget.flightSession
    local flight = session and (session.current or session.last)
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
        widget.rfWarnPercent, widget.rfCriticalPercent, unit1, unit2}, ":")
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
            work.channels[channel] = {
                readings = channel == 1 and history.rf1 or history.rf2,
                missing = channel == 1 and history.missing1 or history.missing2,
                bins = {}, segments = {},
                minimum = unit == "%" and 0 or widget.signalMinimum,
                maximum = unit == "%" and 100 or widget.signalMaximum,
                warning = unit == "%" and widget.rfWarnPercent or widget.rfWarnDB,
                critical = unit == "%" and widget.rfCriticalPercent or widget.rfCriticalDB,
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
    local clock = os.clock()
    if clock < widget.nextPoll then return end
    widget.nextPoll = clock + 0.25
    updateResources(widget)
    -- Read the active model on every poll, including after switching models.
    local nameOK, modelName = pcall(model.name)
    local colors = palette(widget)
    local data = widget.scratch
    for key in pairs(data) do data[key] = nil end
    data.modelName = nameOK and modelName or "VoltDeck"
    local readings = {
        voltage = sample(widget.voltageSource, "voltage"),
        current = sample(widget.currentSource, "current"),
        used = sample(widget.consumptionSource, "capacity"),
        rssi1 = sample(widget.rssi1Source, "signal"), rssi2 = sample(widget.rssi2Source, "signal"),
        rx1 = sample(widget.rx1Source, "voltage"), rx2 = sample(widget.rx2Source, "voltage"),
        tx = sample(widget.txSource or widget.builtinTx, "voltage"),
        timer = sample(widget.timerSource, "timer"), percent = sample(widget.percentSource),
    }
    for key, value in pairs(readings) do data[key] = value end
    data.themeBackground, data.themeForeground = colors.background, colors.foreground
    data.themeSecondary, data.themeAccent = colors.secondary, colors.accent
    local _, unit1 = sourceDetails(widget.rssi1Source, "RF1", "dB")
    local _, unit2 = sourceDetails(widget.rssi2Source, "RF2", "dB")
    data.rssi1Unit = data.rssi1 ~= nil and unit1 ~= "" and unit1 or "dB"
    data.rssi2Unit = data.rssi2 ~= nil and unit2 ~= "" and unit2 or "dB"
    if widget.preview then
        data.voltage, data.current, data.used = 22.8, 18.2, 650
        data.rssi1, data.rssi2, data.rx1, data.tx = 86, 83, 7.4, 8.0
        data.timer, data.percent = 253, nil
    end
    if data.used ~= nil and data.used < 0 then data.used = nil end
    if data.voltage ~= nil and data.voltage <= 0 then data.voltage = nil end
    if data.rx1 ~= nil and data.rx1 <= 0 then data.rx1 = nil end
    if data.rx2 ~= nil and data.rx2 <= 0 then data.rx2 = nil end
    if data.used ~= nil then
        data.remaining = math.max(0, widget.capacityMah - data.used)
    end
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
    local key = modelKey()
    if widget.peakModelKey ~= key then
        widget.peakModelKey, widget.peakRPM, widget.peakWatts = key, nil, nil
    end
    data.rpm = sample(widget.rpmSource, "rpm")
    if data.rpm ~= nil and data.rpm < 0 then data.rpm = nil end
    data.watts = data.voltage and data.current and data.current >= 0 and data.voltage * data.current or nil
    data.cellVoltage = data.voltage and data.voltage / widget.cellCount or nil
    data.rpmPotential = data.voltage and widget.motorKV > 0 and data.voltage * widget.motorKV or nil
    data.rpmEstimate = data.rpmPotential and data.rpmPotential * widget.loadFactor / 100 or nil
    data.rpmDisplay = widget.rpmMode == 2 and data.rpmEstimate or data.rpm
    local ceiling = widget.motorKV * widget.cellCount * TYPES[widget.chemistry].full
    data.rpmCeiling = widget.rpmScale == 2 and ceiling > 0 and math.ceil(ceiling / 1000) * 1000 or widget.rpmMaximum
    if data.rpmDisplay ~= nil then widget.peakRPM = math.max(widget.peakRPM or 0, data.rpmDisplay) end
    if data.watts ~= nil then widget.peakWatts = math.max(widget.peakWatts or 0, data.watts) end
    data.peakRPM, data.peakWatts = widget.peakRPM, widget.peakWatts
    data.graph1 = sample(widget.graph1Source or widget.rssi1Source, "signal")
    data.graph2 = sample(widget.graph2Source or widget.rssi2Source, "signal")
    if widget.preview then data.rpm, data.rpmDisplay, data.watts, data.cellVoltage = 8300, 8300, 414.96, 3.8 end
    updateFlight(widget, data, clock, key)
    local graphDirty = prepareFlightGraphs(widget, clock)
    if widget.bottomSource then
        data.bottomValue = sample(widget.bottomSource)
        data.bottomName, data.bottomUnit, data.bottomDecimals =
            sourceDetails(widget.bottomSource, "TELEMETRY", "")
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
    local fonts = small and SMALL_FONTS or VALUE_FONTS
    local tw, th
    if customFont and not small then
        lcd.font(customFont)
        tw, th = lcd.getTextSize(value)
        if tw <= width and th <= height then
            lcd.color(color)
            lcd.drawText(round(x), round(y), value, align or LEFT)
            return tw, th
        end
    end
    for _, font in ipairs(fonts) do
        lcd.font(font)
        tw, th = lcd.getTextSize(value)
        if tw <= width and th <= height then break end
    end
    lcd.color(color)
    lcd.drawText(round(x), round(y), value, align or LEFT)
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

local function drawSignal(widget, colors, x, y, value, unit, label, sx, sy)
    text(x, y, label, 32 * sx, 18 * sy, colors.secondary, LEFT, nil, true)
    local ratio = value and clamp((value - widget.signalMinimum)
        / math.max(1, widget.signalMaximum - widget.signalMinimum), 0, 1) or 0
    local active = value and math.ceil(ratio * 5) or 0
    for bar = 1, 5 do
        local height = (5 + bar * 3) * sy
        rounded(x + (36 + (bar - 1) * 7) * sx, y + 22 * sy - height,
            4 * sx, height, 1 * sx, bar <= active and colors.accent or colors.track)
    end
    local reading = valueText(value, 0) .. (unit or "")
    text(x + 74 * sx, y, reading, 76 * sx, 23 * sy, colors.foreground)
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
    if kind == 4 then return data.cellVoltage, "CELL VOLTAGE (AVG)", "V", 0, widget.cellMaximum / 100, 2 end
    return data.voltagePercent, "VOLTAGE ESTIMATE", "%", 0, 100, 0
end
local DECK_METRICS = {{1}, {2}, {3}, {4}, {5}, {2, 3}, {2, 3, 4}, {}}
local function drawMeter(widget, colors, sx, sy, kind)
    local reading, label, unit, minimumValue, maximumValue, decimals = metricValues(widget, kind)
    local x, y, w = 24 * sx, 347 * sy, 290 * sx
    text(x, y, string.upper(label or "TELEMETRY"), w, 18 * sy,
        colors.secondary, LEFT, nil, true)
    local value = valueText(reading, decimals or 0)
    local unit = unit or ""
    if widget.bottomDisplay == 1 then
        local tw, th = text(x, y + 28 * sy, value, w - 60 * sx, 56 * sy,
            colors.foreground, LEFT, widget.valueFont)
        text(x + tw + 8 * sx, y + 28 * sy + math.max(0, th - 22 * sy),
            unit, math.max(30 * sx, w - tw - 8 * sx), 24 * sy, colors.secondary, LEFT, nil, true)
        return
    end
    text(x + w, y + 20 * sy, value .. (unit ~= "" and " " .. unit or ""),
        w, 39 * sy, colors.foreground, RIGHT, widget.valueFont)
    local ratio = reading and clamp((reading - minimumValue)
        / math.max(1, maximumValue - minimumValue), 0, 1) or 0
    local count, gap = 28, 3 * sx
    local width = (w - (count - 1) * gap) / count
    for index = 1, count do
        local position = (index - 1) / (count - 1)
        local segmentX = x + (index - 1) * (width + gap)
        local segmentY = 440 * sy - 30 * sy * position ^ 0.8
        local color = colors.track
        if reading ~= nil and index <= math.ceil(ratio * count) then
            local zone = index / count * 100
            if zone >= widget.redZone then color = COLORS.red
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
            or string.format(maximumValue - minimumValue < 10 and "%.1f" or "%.0f", amount)
        local align = index == 0 and LEFT or (index == 4 and RIGHT or CENTERED)
        text(x + w * index / 4, 462 * sy, label, 65 * sx, 14 * sy,
            colors.secondary, align, nil, true)
    end
end


local function drawBottom(widget, colors, sx, sy)
    local kinds = DECK_METRICS[widget.deckMode] or DECK_METRICS[6]
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
        local x, y, width = 24 * sx, (347 + (index - 1) * height) * sy, 290 * sx
        text(x, y, label, 182 * sx, 14 * sy, colors.secondary, LEFT, nil, true)
        if peak then text(x + width, y, "MAX " .. valueText(peak, 0), 104 * sx,
            14 * sy, colors.accent, RIGHT, nil, true) end
        text(x + width, y + 15 * sy, valueText(value, decimals) .. " " .. unit,
            width, (count == 3 and 22 or 28) * sy, colors.foreground, RIGHT, widget.valueFont)
        if widget.bottomDisplay == 2 then
            local ratio = value and clamp((value - minimumValue) / math.max(0.01, maximumValue - minimumValue), 0, 1) or 0
            local gap, segments = 2 * sx, 24
            local segmentWidth = (width - gap * (segments - 1)) / segments
            for segment = 1, segments do
                local tone = colors.track
                if value ~= nil and segment <= math.ceil(ratio * segments) then
                    tone = segment / segments * 100 >= widget.redZone and COLORS.red or colors.accent
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
    local minimumValue = unit == "%" and 0 or widget.signalMinimum
    local maximumValue = unit == "%" and 100 or widget.signalMaximum
    local warning = unit == "%" and widget.rfWarnPercent or widget.rfWarnDB
    local critical = unit == "%" and widget.rfCriticalPercent or widget.rfCriticalDB
    local low = channel == 1 and flight.minRF1 or flight.minRF2
    text(x, y - 24 * sy, "RF" .. channel .. "  MIN " .. valueText(low, 0) .. unit,
        width, 19 * sy, colors.secondary, LEFT, nil, true)
    rect(x, y, width, height, colors.track)
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
end

local function paintFlight(widget, colors, sx, sy)
    local session = widget.flightSession
    local flight = session and (session.current or session.last)
    text(24 * sx, 16 * sy, "FLIGHT LOG", 320 * sx, 28 * sy, colors.foreground)
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
        text(24 * sx, 161 * sy, "FLIGHT " .. timerText(flight.duration)
            .. "   POWER MAX " .. valueText(flight.maxWatts, 0) .. " W",
            752 * sx, 19 * sy, colors.foreground, LEFT, nil, true)
        drawFlightGraph(widget, colors, flight, 1, 24 * sx, 220 * sy, 350 * sx, 165 * sy, sx, sy)
        drawFlightGraph(widget, colors, flight, 2, 425 * sx, 220 * sy, 350 * sx, 165 * sy, sx, sy)
        text(24 * sx, 419 * sy, "KV POTENTIAL MAX " .. valueText(flight.maxPotential, 0)
            .. " rpm (not measured)", 752 * sx, 17 * sy, colors.secondary, LEFT, nil, true)
        text(24 * sx, 441 * sy, "RF: 48 minimum bins/channel; gaps = missing data. Visual limits only.",
            752 * sx, 17 * sy, colors.secondary, LEFT, nil, true)
    end
    text(24 * sx, 463 * sy, "Widget menu: Dashboard / Flight log", 750 * sx, 14 * sy,
        colors.accent, LEFT, nil, true)
end

local function paint(widget)
    local w, h = lcd.getWindowSize()
    widget.graphWidth, widget.graphHeight = w, h
    local sx, sy = w / 800, h / 480
    local colors, data = palette(widget), widget.data
    rect(0, 0, w, h, colors.background)
    if widget.logVisible then paintFlight(widget, colors, sx, sy); return end
    text(24 * sx, 9 * sy, "MODEL", 286 * sx, 17 * sy, colors.secondary, LEFT, nil, true)
    text(24 * sx, 30 * sy, data.modelName or "VoltDeck", 292 * sx, 39 * sy,
        colors.foreground, LEFT, widget.valueFont)
    local pack = TYPES[widget.chemistry].name .. "  /  " .. widget.cellCount .. "S  /  "
        .. widget.capacityMah .. " mAh"
    text(24 * sx, 78 * sy, pack, 294 * sx, 17 * sy, colors.secondary, LEFT, nil, true)
    drawSignal(widget, colors, 343 * sx, 19 * sy, data.rssi1, data.rssi1Unit, "RF1", sx, sy)
    drawSignal(widget, colors, 343 * sx, 62 * sy, data.rssi2, data.rssi2Unit, "RF2", sx, sy)
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
    if data.low and not widget.preview then
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

local function numberField(widget, label, key, minimum, maximum, suffix, step)
    local line = form.addLine(label, widget.configPanel)
    local field = form.addNumberField(line, nil, minimum, maximum,
        function() return widget[key] end,
        function(value)
            widget[key] = value
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
            changed(widget)
        end)
    if suffix then field:suffix(suffix) end
    if step then field:step(step) end
end

local function choiceField(widget, label, key, choices)
    local line = form.addLine(label, widget.configPanel)
    form.addChoiceField(line, nil, choices,
        function() return widget[key] end,
        function(value)
            widget[key] = value
            if key == "rpmMode" then widget.peakRPM = nil end
            changed(widget)
        end)
end

local function colorField(widget, label, key)
    local line = form.addLine(label, widget.configPanel)
    form.addColorField(line, nil,
        function() return widget[key] end,
        function(value) widget[key] = value; changed(widget) end)
end

local function configure(widget)
    widget.configPanel = nil
    form.addLine("VoltDeck " .. VERSION)
    local function group(label)
        widget.configPanel = form.addExpansionPanel(label)
        widget.configPanel:open(false)
    end
    local function note(message)
        local line = form.addLine("", widget.configPanel)
        local ok, width = pcall(form.width)
        form.addStaticText(line, {x = 10, y = 0, w = ok and width - 20 or 720, h = 30}, message)
    end
    local function boolean(label, key, alarmReset)
        local line = form.addLine(label, widget.configPanel)
        form.addBooleanField(line, nil, function() return widget[key] end,
            function(value) widget[key] = value; changed(widget, alarmReset) end)
    end
    local function sourceField(label, key, alarmReset)
        local line = form.addLine(label, widget.configPanel)
        form.addSourceField(line, nil, function() return widget[key] end,
            function(value) widget[key] = value; changed(widget, alarmReset) end)
    end
    if widget.configError then note(widget.configError) end
    note("Settings: per-model checked files in /scripts/vc*.cfg")

    group("Battery")
    choiceField(widget, "Remaining from", "batteryMethod",
        {{"Consumed mAh", 1}, {"% sensor", 2}, {"Voltage estimate", 3}})
    choiceField(widget, "Battery type", "chemistry", {{"Lipo", 1}, {"HV Lipo", 2}, {"Li-ion", 3}, {"LiFe", 4}})
    numberField(widget, "Capacity", "capacityMah", 100, 100000, "mAh", 50)
    numberField(widget, "Cells", "cellCount", 1, 16, nil, 1)
    choiceField(widget, "mAh display", "mahDisplay", {{"Consumed", 1}, {"Remaining", 2}})
    note("Default: remaining = capacity - consumed mAh.")
    note("Voltage estimate is approximate, not measured charge.")

    group("Appearance")
    choiceField(widget, "Background", "backgroundMode", {{"Radio theme", 1}, {"Black", 2}, {"Custom", 3}})
    colorField(widget, "Background color", "backgroundColor")
    colorField(widget, "Accent color", "accentColor")
    local line = form.addLine("Font file", widget.configPanel)
    form.addTextField(line, nil, function() return widget.fontPath end,
        function(value) widget.fontPath = value or ""; widget.fontDirty = true; changed(widget) end)
    note("Blank font uses native ETHOS fonts.")
    choiceField(widget, "Image source", "imageMode", {{"Selected model", 1}, {"Image file", 2}, {"Hidden", 3}})
    line = form.addLine("Image file", widget.configPanel)
    form.addFileField(line, nil, "/bitmaps/models", "image+ext",
        function() return widget.imageName:gsub("^/bitmaps/models/", "") end,
        function(value) widget.imageName = value or ""; widget.imageDirty = true; changed(widget) end)
    note("PNG: 290x191 recommended; 480x272 / 480x320 OK.")
    note("Aspect ratio is preserved; maximum 160k pixels.")

    group("Battery alert")
    boolean("Battery alert", "alarmEnabled", true)
    boolean("Alert on estimate", "alarmEstimate", true)
    numberField(widget, "Repeat", "alertInterval", 1, 600, "s", 1)
    line = form.addLine("Audio folder", widget.configPanel)
    form.addTextField(line, nil, function() return widget.audioFolder end,
        function(value) widget.audioFolder = normalizeAudioFolder(value); changed(widget, true) end)
    local pickerFolder = normalizeAudioFolder(widget.audioFolder)
    line = form.addLine("Alert WAV", widget.configPanel)
    form.addFileField(line, nil, pickerFolder, "audio+ext", function()
        local prefix = pickerFolder .. "/"
        return widget.alarmSound:sub(1, #prefix) == prefix and widget.alarmSound:sub(#prefix + 1) or widget.alarmSound
    end, function(value)
        widget.alarmSound = audioPath(pickerFolder, value)
        widget.checkedSound = nil
        changed(widget, true)
    end)
    note("Alarm at <=30%; invalid WAV uses a tone.")
    note("WAV: PCM 32kHz mono 16-bit; repeat waits for audio.")
    note("Reopen settings after changing the audio folder.")

    group("Telemetry")
    for _, definition in ipairs(SOURCE_FIELDS) do sourceField(definition.label, definition.key, true) end
    note("Blank Tx source uses radio battery; RF = dB or %.")
    numberField(widget, "RF scale min", "signalMinimum", -150, 199, nil, 1)
    numberField(widget, "RF scale max", "signalMaximum", -149, 200, nil, 1)

    group("Lower deck")
    choiceField(widget, "Show", "deckMode", {{"Custom", 1}, {"RPM", 2}, {"Watts", 3},
        {"Cell volts", 4}, {"Voltage estimate", 5}, {"RPM + Watts", 6}, {"RPM + W + cell", 7}, {"Hidden", 8}})
    choiceField(widget, "Meter style", "bottomDisplay", {{"Numeric", 1}, {"Retro LCD", 2}})
    sourceField("Custom source", "bottomSource")
    line = form.addLine("Custom label", widget.configPanel)
    form.addTextField(line, nil, function() return widget.bottomLabel end,
        function(value) widget.bottomLabel = value or ""; changed(widget) end)
    numberField(widget, "Custom min", "bottomMinimum", -100000, 999999, nil, 1)
    numberField(widget, "Custom max", "bottomMaximum", -99999, 1000000, nil, 100)
    numberField(widget, "Decimals (-1 auto)", "bottomDecimals", -1, 3, nil, 1)
    numberField(widget, "Red zone", "redZone", 10, 100, "%", 1)
    numberField(widget, "Watt max", "wattMaximum", 10, 100000, "W", 100)
    numberField(widget, "Cell max (cV)", "cellMaximum", 200, 500, "cV", 5)
    note("Watts = pack V x A, electrical input, not shaft power.")
    note("Cell volts = pack V / cells, not individual cells.")

    group("Motor / RPM")
    sourceField("RPM source", "rpmSource")
    choiceField(widget, "RPM value", "rpmMode", {{"Measured RPM", 1}, {"KV x volts (est.)", 2}})
    numberField(widget, "Motor KV", "motorKV", 0, 10000, "rpm/V", 10)
    numberField(widget, "Estimate factor", "loadFactor", 10, 100, "%", 1)
    choiceField(widget, "RPM scale", "rpmScale", {{"Manual", 1}, {"Full-pack KV", 2}})
    numberField(widget, "RPM max", "rpmMaximum", 1000, 200000, "rpm", 1000)
    note("KV x live volts is potential speed, NOT actual RPM.")
    note("Default 100% = no-load; choose factor from testing.")
    note("KV scale uses full-pack volts, so sag stays visible.")

    group("Flight log")
    boolean("Enable log", "logEnabled")
    sourceField("Arm switch", "armSource")
    sourceField("Throttle source", "throttleSource")
    sourceField("Airborne gate", "airborneSource")
    numberField(widget, "Throttle low", "throttleMinimum", -2048, 2047, nil, 1)
    numberField(widget, "Throttle high", "throttleMaximum", -2047, 2048, nil, 1)
    numberField(widget, "Flight minimum", "flightMinimum", 60, 3600, "s", 10)
    numberField(widget, "Throttle gate", "throttleThreshold", 10, 100, "%", 5)
    numberField(widget, "High throttle", "highThrottleSeconds", 1, 120, "s", 1)
    numberField(widget, "End delay", "endDelay", 3, 120, "s", 1)
    sourceField("RF graph 1", "graph1Source")
    sourceField("RF graph 2", "graph2Source")
    numberField(widget, "RF warning dB", "rfWarnDB", -149, 200, "dB", 1)
    numberField(widget, "RF critical dB", "rfCriticalDB", -150, 199, "dB", 1)
    numberField(widget, "VFR warning", "rfWarnPercent", 1, 100, "%", 1)
    numberField(widget, "VFR critical", "rfCriticalPercent", 0, 99, "%", 1)
    note("Arm + >=60s + >=50% throttle for >=5s by default.")
    note("Long armed bench runs can count: use airborne gate.")
    note("Channels: -1024..1024; percent sources: set 0..100.")
    note("Blank graph sources use RF1/RF2; VFR is % not RSSI.")
    note("Graph limits are visual, not radio alarm settings.")
    note("Only counter persists; last-flight graphs stay in RAM.")
    line = form.addLine("Reset counter", widget.configPanel)
    form.addButton(line, nil, {text = "Reset...", press = function()
        local session = widget.flightSession
        if not session or session.current or switchOn(widget.armSource) then
            form.openDialog({title = "Flight counter", message = "Enable log and disarm before reset.",
                buttons = {{label = "OK", action = function() return true end}}})
            return
        end
        local key = session.key
        form.openDialog({title = "Reset flight count?", message = widget.data.modelName or "Current model",
            buttons = {{label = "Cancel", action = function() return true end},
                {label = "Reset", action = function()
                    if modelKey() ~= key or switchOn(widget.armSource) or session.current then return true end
                    session.count, session.last = 0, nil
                    session.pending, session.attempts, session.retryAt = true, 0, 0
                    session.revision = session.revision + 1
                    widget.refresh = true
                    return true
                end}}})
    end})

    group("Preview")
    boolean("Preview", "preview")
    note("Preview never counts flights or plays alerts.")
    widget.configPanel = nil
end

local function destroy(widget)
    widget.modelImage, widget.valueFont, widget.flightSession = nil, nil, nil
    widget.rfGraphs, widget.rfGraphWork = nil, nil
    if FLIGHT_SESSION and FLIGHT_SESSION.owner == widget then FLIGHT_SESSION.owner = nil end
    collectResources()
end

local function menu(widget)
    return {
        {widget.logVisible and "Dashboard" or "Flight log", function()
            widget.logVisible = not widget.logVisible; widget.refresh = true; lcd.invalidate()
        end},
        {"Reset live peaks", function() widget.peakRPM, widget.peakWatts = nil, nil; changed(widget) end},
        {"Memory snapshot", function() memorySnapshot(widget) end},
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

