--[[
    KoReader user patch: READ RECEIPT  (English version)

    Credits
      Original design and patch by w8. (Xiaohongshu) / wongyx04-create (GitHub):
      https://github.com/wongyx04-create/readreceipt
      English translation and layout changes by Selena, shared with the
      original creator's permission.
      Changes: English text, Courier Prime font, the page you were reading as
      the background, ticket aligned to the left.
    1:1 port of the Illustrator design (canvas 1264x1680, receipt 851.38x1506.06 centred).

    Install
      1. copy this file to  koreader/patches/2-read-receipt.lua
         (on Kobo: .kobo/../.adds/koreader/patches/)
      2. copy the font to koreader/fonts/ :
           CourierPrime-Regular.ttf   (free, from Google Fonts)
         No Chinese font is needed, because every label is now English.
      3. restart KoReader. Open a book -> menu (top bar) -> Tools -> READ RECEIPT.

    All coordinates below are design pixels, identical to the HTML mock-up.
--]]

local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Font = require("ui/font")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local RenderImage = require("ui/renderimage")
local RenderText = require("ui/rendertext")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local logger = require("logger")
local Screen = Device.screen

-- ---------------------------------------------------------------- geometry --
local W, H = 851.38, 1506.06          -- receipt size
local R = 35                          -- scallop / notch radius
local NOTCH_Y = 967.85                -- side notch centre
local NOTCH_DX = 3                    -- notch circle centre sits 3px outside the edge
local SCALLOPS = 8                    -- 8 bites per edge, centres every W/8 (corners included)

-- design px -> screen px. 1 when the receipt fits (portrait 1264x1680), smaller
-- when it does not (landscape, e.g. Kobo Libra Colour 1680x1264): the whole
-- ticket shrinks uniformly so the layout never changes, only its size.
local MARGIN = 24                     -- screen px kept free around the ticket

-- look settings
-- BACKGROUND: what shows behind the ticket
--   "page"  : the page you were reading (a snapshot of the screen taken when
--             the receipt opens, so it works as a sleep screen too)
--   "cover" : the faded book cover (original look)
--   "white" : plain white
local BACKGROUND = "page"
-- how far the background is lightened, 0 (none) to 1 (white). Raise it if you
-- want the ticket to stand out more against the page or cover.
local BACKGROUND_FADE = 0.35
-- true = solid white ticket paper, false = see-through paper (shows the
-- background through the ticket; e-ink has no real transparency)
local PAPER_WHITE = true
-- where the ticket sits horizontally: "left", "center" or "right"
local TICKET_ALIGN = "left"
-- gap (screen px) between the ticket and the screen edge when it is left/right
local TICKET_EDGE_GAP = 24
local S = 1
local function fitScale(sw, sh)
    S = math.min(1, (sw - 2 * MARGIN) / W, (sh - 2 * MARGIN) / H)
    return S
end

-- fonts (file names as installed in koreader/fonts)
local FONT_CN = "FZHengFSJF-SB.ttf"
local FONT_LA = "CourierPrime-Regular.ttf"
-- baseline factor: (1 - (asc+desc))/2 + asc   from each font's hhea table
local K_CN, K_LA = 0.792, 0.7625

local COL = {
    K  = Blitbuffer.COLOR_BLACK,
    G1 = Blitbuffer.Color8(0x82),      -- #818285  small labels
    G2 = Blitbuffer.Color8(0x95),      -- #939598  NOW / TODAY
    DASH = Blitbuffer.Color8(0x88),    -- #88898c  hair dashes
    DIV1 = Blitbuffer.Color8(0xAD),    -- #adafb2  date dividers
    DIV2 = Blitbuffer.Color8(0xA7),    -- #a7a9ac  summary dividers
    LINE = Blitbuffer.Color8(0x93),    -- #939598  group rules
    COVER = Blitbuffer.Color8(0x91),   -- #919396  cover placeholder
    TRACK = Blitbuffer.Color8(0xC7),   -- #c7c8ca  progress track
    FILL = Blitbuffer.Color8(0x4C),    -- #4c4d4f  progress fill
}

local BARS = {{38.3,2.15},{47.9,5.75},{55.6,3.8},{61.35,1.9},{69,1.95},{74.8,7.65},{86.3,1.9},{90.15,7.65},{101.65,1.95},{107.4,1.95},{111.25,1.95},{120.85,3.85},{126.6,1.95},{132.15,3.85},{143.65,1.95},{147.5,1.9},{153.25,3.85},{159,3.85},{166.7,3.85},{174.4,5.75},{182.05,1.95},{189.75,3.85},{195.5,1.9},{203.2,7.65},{212.8,1.9},{216.6,3.85},{227.9,1.9},{231.75,1.9},{237.5,1.9},{243.25,3.85},{249,1.95},{258.6,3.85},{264.4,3.8},{272.05,3.85},{279.75,7.65},{289.35,5.75},{297,1.95},{300.85,1.95},{306.6,1.95},{310.45,3.6},{321.75,1.9},{331.35,1.9},{337.1,3.85},{342.85,1.95},{346.7,3.85},{354.4,1.9},{364,3.8},{369.75,3.85},{377.4,3.85},{385.1,1.9},{394.7,3.85},{400.2,1.95},{406,1.9},{411.75,7.65},{421.35,1.9},{427.1,3.85},{432.85,3.85},{440.55,3.85},{448.2,1.95},{455.9,7.7},{465.5,1.9},{469.35,3.85},{480.85,1.95},{484.7,1.9},{490.2,3.85},{496,3.8},{503.65,3.85},{511.35,1.9},{515.2,1.9},{522.85,3.85},{532.45,1.95},{538.2,7.7},{549.75,1.9},{553.6,1.9},{559.35,3.85},{565.1,1.9},{574.7,3.6},{580.2,3.85},{587.9,3.85},{595.6,3.8},{603.25,5.75},{612.85,1.95},{616.7,5.75},{624.4,1.9},{630.15,3.85},{637.8,3.85},{643.6,3.8},{651.25,3.85},{658.95,1.9},{662.8,5.5},{670.2,7.7},{679.8,3.85},{687.5,1.9},{693.25,5.75},{700.95,5.75},{710.55,1.9},{716.3,3.85},{722.05,5.75},{729.75,1.9},{733.6,7.65},{743.2,1.9},{752.8,3.8},{760.2,1.95},{764.05,1.95},{769.8,1.95},{773.65,7.7},{785.2,3.8},{794.8,5.75},{802.45,1.95},{806.3,3.85}}
local BARCODE_Y, BARCODE_H = 1307.3, 47.8

-- All labels are English and use the Latin font ("L").
-- Optional fields: key = live data, maxw = truncate width, follow = start right
-- after the previous item, center = centre the text on this design x.
local ITEMS = {
  {x=599.56,top=132.58,f="L",size=20,ls=1.2,c="G1",t="STATUS"},
  {x=599.56,top=195,f="L",size=36,ls=1,c="G2",t="READING",key="status"},
  {x=661.48,top=66.64,f="L",size=25,ls=-0.1,c="K",t="NO. D08282026",key="no"},
  {x=35.04,top=92,f="L",size=22,ls=0.5,c="K",t="DAILY READING TICKET"},
  {x=34.12,top=136,f="L",size=72,ls=0.03,c="K",t="READ RECEIPT"},
  {x=34.36,top=232.2,f="L",size=25,ls=0,c="K",t="TODAY'S READING TRAIL"},
  {x=68.16,top=343,f="L",size=18,ls=0.5,c="G1",t="DATE"},
  {x=319.24,top=343,f="L",size=18,ls=0.5,c="G1",t="WEEK"},
  {x=583,top=343,f="L",size=18,ls=0.5,c="G1",t="START DATE"},
  {x=70.08,top=371.53,f="L",size=36,ls=-0.61,c="K",t="08.28.2026",key="date"},
  {x=317.76,top=371.69,f="L",size=36,ls=-0.97,c="K",t="FRI",key="weekday_en"},
  {x=582.24,top=371.53,f="L",size=36,ls=-0.61,c="K",t="08.27.2026",key="start_date"},
  {x=36.92,top=458,f="L",size=26,ls=0.5,c="K",t="CURRENTLY READING"},
  {x=39.66,top=489.58,f="L",size=32,ls=-0.07,c="K",t="Heart the Lover",key="title",maxw=460},
  {x=36.76,top=570,f="L",size=22,ls=0.5,c="K",t="AUTHOR"},
  {x=39.66,top=604,f="L",size=30,ls=0.67,c="K",t="Lily King",key="author",maxw=400},
  {x=33.84,top=775.75,f="L",size=28,ls=0.5,c="K",t="TIME LEFT"},
  {x=250,top=772.86,f="L",size=32,ls=0.27,c="K",t="4 hr 16 m",key="left_time"},
  {x=33.36,top=820.9,f="L",size=28,ls=0.5,c="K",t="TOTAL TIME"},
  {x=250,top=818.9,f="L",size=32,ls=0.36,c="K",t="33 m",key="total_time"},
  {x=34.56,top=894.3,f="L",size=32,ls=-0.11,c="K",t="88 / 568",key="pages"},
  {x=0,top=897.4,f="L",size=26,ls=0,c="K",t="pages",follow=10.8},
  {x=402.2,top=895.22,f="L",size=32,ls=-0.21,c="K",t="15%",key="pct"},
  {x=39.12,top=1003.27,f="L",size=36,ls=-0.2,c="K",t="TODAY'S SUMMARY"},
  {center=218,top=1072,f="L",size=20,ls=1,c="G2",t="NOW"},
  {center=629.3,top=1072,f="L",size=20,ls=1,c="G2",t="TODAY"},
  {x=35.08,top=1110.83,f="L",size=26,ls=-0.08,c="K",t="PAGES READ"},
  {x=221.08,top=1110.83,f="L",size=26,ls=-0.02,c="K",t="READING TIME"},
  {x=444.52,top=1111.31,f="L",size=26,ls=-0.11,c="K",t="PAGES READ"},
  {x=634.36,top=1111.31,f="L",size=26,ls=-0.04,c="K",t="READING TIME"},
  {x=36.08,top=1197.29,f="L",size=52,ls=-0.35,c="K",t="28",key="s_pages"},
  {x=0,top=1211.5,f="L",size=30,ls=0,c="K",t="pg",follow=8},
  {x=222.16,top=1196.65,f="L",size=52,ls=0.32,c="K",t="1h 40m",key="s_time"},
  {x=445.52,top=1198.01,f="L",size=52,ls=-0.35,c="K",t="28",key="d_pages"},
  {x=0,top=1212.3,f="L",size=30,ls=0,c="K",t="pg",follow=8},
  {x=635.44,top=1197.37,f="L",size=52,ls=0.32,c="K",t="1h 40m",key="d_time"},
  {x=290,top=1390.24,f="L",size=22,ls=0.03,c="K",t="• READING LOG •"},
  {x=526.6,top=1390.52,f="L",size=22,ls=-0.7,c="K",t="D08282026",key="id"},
}

-- ------------------------------------------------------------- primitives --
local floor, ceil, sqrt, abs = math.floor, math.ceil, math.sqrt, math.abs

local function px(v) return floor(v + 0.5) end

-- x, y, w, h in design px; scaled by S here
local function rect(bb, ox, oy, x, y, w, h, c)
    w, h = px(w * S), px(h * S)
    if w < 1 then w = 1 end
    if h < 1 then h = 1 end
    bb:paintRect(ox + px(x * S), oy + px(y * S), w, h, c)
end

local function dashedH(bb, ox, oy, x1, x2, y, weight, dash, gap, offset, c)
    local period = dash + gap
    local t = x1 - (offset or 0)
    while t < x2 do
        local a = t < x1 and x1 or t
        local b = t + dash
        if b > x2 then b = x2 end
        if b > a then rect(bb, ox, oy, a, y - weight / 2, b - a, weight, c) end
        t = t + period
    end
end

local function disc(bb, ox, oy, cx, cy, r, c)
    cx, cy, r = cx * S, cy * S, r * S
    for dy = -ceil(r), ceil(r) do
        local hw = r * r - dy * dy
        if hw > 0 then
            hw = sqrt(hw)
            local w = px(hw * 2)
            if w < 1 then w = 1 end
            bb:paintRect(ox + px(cx - hw), oy + px(cy + dy), w, 1, c)
        end
    end
end

-- the ticket outline: scalloped top/bottom + one round notch per side.
-- painted by scanning rows (fill) and rows+columns (1px border) so the maths,
-- not a bitmap, defines every curve.
local function scallopCentres()
    local t = {}
    for k = 0, SCALLOPS do t[#t + 1] = k * (W / SCALLOPS) end
    return t
end

local function subtract(spans, a, b)
    local out = {}
    for _, s in ipairs(spans) do
        if b <= s[1] or a >= s[2] then
            out[#out + 1] = s
        else
            if a > s[1] then out[#out + 1] = { s[1], a } end
            if b < s[2] then out[#out + 1] = { b, s[2] } end
        end
    end
    return out
end

local CX = scallopCentres()

local function rowSpans(y)
    local spans = { { 0, W } }
    if y < R then
        local hw = sqrt(R * R - y * y)
        for _, cx in ipairs(CX) do spans = subtract(spans, cx - hw, cx + hw) end
    end
    local dyb = H - y
    if dyb < R then
        local hw = sqrt(R * R - dyb * dyb)
        for _, cx in ipairs(CX) do spans = subtract(spans, cx - hw, cx + hw) end
    end
    local dn = abs(y - NOTCH_Y)
    if dn < R then
        local hw = sqrt(R * R - dn * dn)
        spans = subtract(spans, -1e6, -NOTCH_DX + hw)
        spans = subtract(spans, W + NOTCH_DX - hw, 1e6)
    end
    return spans
end

local function colSpans(x)
    local spans = { { 0, H } }
    for _, cx in ipairs(CX) do
        local dx = abs(x - cx)
        if dx < R then
            local hh = sqrt(R * R - dx * dx)
            spans = subtract(spans, -1e6, hh)
            spans = subtract(spans, H - hh, 1e6)
        end
    end
    if x < R - NOTCH_DX then
        local hh = sqrt(R * R - (x + NOTCH_DX) * (x + NOTCH_DX))
        spans = subtract(spans, NOTCH_Y - hh, NOTCH_Y + hh)
    end
    if x > W - R + NOTCH_DX then
        local d = W + NOTCH_DX - x
        local hh = sqrt(R * R - d * d)
        spans = subtract(spans, NOTCH_Y - hh, NOTCH_Y + hh)
    end
    return spans
end

-- scans screen rows / columns and asks the design-space outline for each
local function paintPaper(bb, ox, oy)
    local rows = {}
    for y = 0, px(H * S) do
        local r = {}
        for _, s in ipairs(rowSpans(y / S)) do
            local a, b = px(s[1] * S), px(s[2] * S)
            if b - a >= 1 then r[#r + 1] = { a, b } end
        end
        rows[y] = r
    end
    if PAPER_WHITE then
        for y = 0, px(H * S) do
            for _, s in ipairs(rows[y]) do
                bb:paintRect(ox + s[1], oy + y, s[2] - s[1], 1, Blitbuffer.COLOR_WHITE)
            end
        end
    end
    for y = 0, px(H * S) do
        for _, s in ipairs(rows[y]) do
            bb:paintRect(ox + s[1], oy + y, 1, 1, Blitbuffer.COLOR_BLACK)
            bb:paintRect(ox + s[2] - 1, oy + y, 1, 1, Blitbuffer.COLOR_BLACK)
        end
    end
    for x = 0, px(W * S) do
        for _, s in ipairs(colSpans(x / S)) do
            local a, b = px(s[1] * S), px(s[2] * S)
            if b - a >= 1 then
                bb:paintRect(ox + x, oy + a, 1, 1, Blitbuffer.COLOR_BLACK)
                bb:paintRect(ox + x, oy + b - 1, 1, 1, Blitbuffer.COLOR_BLACK)
            end
        end
    end
end

-- ------------------------------------------------------------------- text --
local face_cache = {}
local function paths(basenames)
    local dirs = { "", "fonts/",
        "/mnt/us/koreader/fonts/", "/mnt/us/fonts/",                       -- Kindle
        "/mnt/onboard/.adds/koreader/fonts/", "/mnt/onboard/fonts/" }      -- Kobo
    local ok_ds, DataStorage = pcall(require, "datastorage")
    if ok_ds then table.insert(dirs, 2, DataStorage:getDataDir() .. "/fonts/") end
    local out = {}
    for _, base in ipairs(basenames) do
        for _, ext in ipairs({ ".ttf", ".TTF" }) do
            for _, dir in ipairs(dirs) do out[#out + 1] = dir .. base .. ext end
        end
    end
    return out
end
-- The original receipt used the JP-form slots of the Chinese font for some
-- characters. All text is English now, so the Chinese font is only a fallback.
local font_candidates = {
    C = paths({ "FZHengFSJF-SB", "FZHengFSJF-M", "FZHengFSJF-EB", "FZHengFSJF-R" }),
    L = paths({ "CourierPrime-Regular", "CourierPrime-Bold", "CourierPrime" }),
}
local resolved_font = {}

-- KoReader scales every size handed to Font:getFace by the screen DPI factor,
-- so a raw design px value comes out far too big. Instead of guessing the
-- factor we calibrate it once against a string whose design width we know.
local FONT_SCALE = nil

local function rawFace(which, size)
    size = px(size)
    if size < 6 then size = 6 end
    local key = which .. "/" .. size
    if face_cache[key] then return face_cache[key] end
    local f
    local names = resolved_font[which] and { resolved_font[which] } or font_candidates[which]
    for _, name in ipairs(names) do
        local ok, face = pcall(Font.getFace, Font, name, size)
        if ok and face then
            if not resolved_font[which] then
                resolved_font[which] = name
                logger.info("read-receipt: using font", name)
            end
            f = face
            break
        end
    end
    if not f then
        logger.warn("read-receipt: font not found for", which, "- falling back to cfont")
        f = Font:getFace("cfont", size)
    end
    face_cache[key] = f
    return f
end

local function textWidth(face, s)
    local ok, w = pcall(function()
        return RenderText:sizeUtf8Text(0, 1e6, face, s, true, false).x
    end)
    return ok and w or 0
end

local function calibrate()
    -- "READ RECEIPT" is 479.0 design px wide at design size 72
    local probe, target, guess = "READ RECEIPT", 479.0, 72
    for _ = 1, 6 do
        local w = textWidth(rawFace("L", guess), probe)
        if w <= 0 then break end
        if math.abs(w - target) < 0.75 then break end
        guess = guess * target / w
    end
    FONT_SCALE = guess / 72
    logger.info("read-receipt: font scale calibrated to", FONT_SCALE)
end

local function getFace(which, size)
    if not FONT_SCALE then calibrate() end
    return rawFace(which, size * FONT_SCALE)
end

local function utf8chars(s)
    local t = {}
    for ch in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do t[#t + 1] = ch end
    return t
end

-- true when this face itself can draw the character (so we never let KoReader
-- silently substitute Noto for a glyph the receipt fonts do have)
local has_char_memo = {}
local function faceHasChar(face, ch)
    local memo_key = tostring(face) .. ch
    local memo = has_char_memo[memo_key]
    if memo ~= nil then return memo end
    local code
    local b1 = ch:byte(1)
    if not b1 then return true end
    if b1 < 0x80 then code = b1
    elseif b1 < 0xE0 then code = (b1 - 0xC0) * 0x40 + (ch:byte(2) or 0) - 0x80
    elseif b1 < 0xF0 then
        code = (b1 - 0xE0) * 0x1000 + ((ch:byte(2) or 0) - 0x80) * 0x40 + ((ch:byte(3) or 0) - 0x80)
    else return true end
    local has
    local ok = pcall(function() has = face.ftface:hasGlyph(code) end)
    if not ok or has == nil then has = true end
    has_char_memo[memo_key] = has
    return has
end

-- draws text and returns the pen position after the last glyph
local function drawText(bb, x, baseline, face, alt_face, text, ls, c)
    local per_char = (ls and abs(ls) >= 0.4)
    if not per_char then
        -- still go per char when a glyph is missing from the primary face
        for _, ch in ipairs(utf8chars(text)) do
            if not faceHasChar(face, ch) then
                per_char = true
                break
            end
        end
    end
    if not per_char then
        RenderText:renderUtf8Text(bb, px(x), px(baseline), face, text, true, false, c)
        return x + textWidth(face, text)
    end
    for _, ch in ipairs(utf8chars(text)) do
        local f = face
        if alt_face and not faceHasChar(face, ch) then f = alt_face end
        RenderText:renderUtf8Text(bb, px(x), px(baseline), f, ch, true, false, c)
        x = x + textWidth(f, ch) + (ls or 0)
    end
    return x - (ls or 0)
end

-- --------------------------------------------------------------- the data --
-- everything the receipt shows; keys match ITEMS[i].key
local function collectData(ui)
    local now = os.time()
    local wd_en = { "SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT" }
    local wd = tonumber(os.date("%w", now)) + 1
    local d = {
        date = os.date("%m.%d.%Y", now),
        weekday_en = wd_en[wd],
        no = "NO. D" .. os.date("%m%d%Y", now),
        id = "D" .. os.date("%m%d%Y", now),
    }
    if ui and ui.document then
        local props = ui.document:getProps() or {}
        if props.title and props.title ~= "" then d.title = props.title end
        if props.authors and props.authors ~= "" then d.author = props.authors end
        local cur = ui.view and ui.view.state and ui.view.state.page or 1
        local total = ui.document:getPageCount() or 1
        d.pages = string.format("%d / %d", cur, total)
        d.progress = cur / total
        d.pct = string.format("%d%%", math.floor(d.progress * 100 + 0.5))
    end

    -- status: READING / FINISHED
    d.status = "READING"
    if ui and ui.doc_settings then
        local ok, summary = pcall(function() return ui.doc_settings:readSetting("summary") end)
        if ok and summary and summary.status == "complete" then d.status = "FINISHED" end
    end
    if d.progress and d.progress >= 0.999 then d.status = "FINISHED" end

    -- figures we cannot read show as "--" so a mismatch is never hidden
    d.s_pages, d.s_time, d.d_pages, d.d_time = "--", "--", "--", "--"
    d.total_time, d.left_time = "--", "--"
    d.start_date = "--"

    local function hm(seconds)
        seconds = math.floor(tonumber(seconds) or 0)
        local h, m = math.floor(seconds / 3600), math.floor((seconds % 3600) / 60)
        if h > 0 then return string.format("%dh %02dm", h, m) end
        return string.format("%d m", m)
    end

    local stats = ui and ui.statistics
    local enabled = stats and stats.settings and stats.settings.is_enabled
    local dbg = {}

    -- flush the running session into the db first, exactly like KoReader's own
    -- book-status window does, so the numbers include the pages just read
    if stats and stats.insertDB then pcall(function() stats:insertDB() end) end

    if not stats then
        d.debug = "no ui.statistics"
    elseif not enabled then
        d.debug = "statistics plugin disabled"
    else
        local id_book = stats.id_curr_book
        dbg[#dbg + 1] = "id=" .. tostring(id_book)

        -- pages / time read today (plugin API returns time, pages)
        if stats.getTodayBookStats then
            local ok, t, p = pcall(stats.getTodayBookStats, stats)
            dbg[#dbg + 1] = "today=" .. tostring(ok) .. ":" .. tostring(p) .. "/" .. tostring(t)
            if ok then
                if p then d.d_pages = tostring(p) end
                if t then d.d_time = hm(t) end
            end
        end

        -- total reading time for this book: returns pages, time
        if stats.getPageTimeTotalStats and id_book then
            local ok, pages, secs = pcall(stats.getPageTimeTotalStats, stats, id_book)
            dbg[#dbg + 1] = "total=" .. tostring(ok) .. ":" .. tostring(pages) .. "/" .. tostring(secs)
            if ok and secs then d.total_time = hm(secs) end
        end

        -- estimated time left = avg seconds per page turn x pages left
        if stats.avg_time and stats.avg_time > 0 and ui.document then
            local total = ui.document:getPageCount() or 1
            local cur = (ui.view and ui.view.state and ui.view.state.page) or 1
            d.left_time = hm(stats.avg_time * math.max(total - cur + 1, 0))
            dbg[#dbg + 1] = "avg=" .. string.format("%.1f", stats.avg_time)
        end

        -- this session + start date come from the page_stat view
        if id_book then
            local ok_db, err = pcall(function()
                local SQ3 = require("lua-ljsqlite3/init")
                local DataStorage = require("datastorage")
                local conn = SQ3.open(DataStorage:getSettingsDir() .. "/statistics.sqlite3")
                local function one(sql)
                    local ok, v = pcall(function() return conn:rowexec(sql) end)
                    if not ok or v == nil then return nil end
                    return tonumber((tostring(v):gsub("[^%-%d%.]", "")))
                end
                local first = one(string.format("SELECT min(start_time) FROM page_stat WHERE id_book = %d", id_book))
                if first then d.start_date = os.date("%m.%d.%Y", first) end
                local since = tonumber((tostring(stats.start_current_period or ""):gsub("[^%d]", ""))) or os.time()
                local sp = one(string.format("SELECT count(DISTINCT page) FROM page_stat WHERE id_book = %d AND start_time >= %d", id_book, since))
                local st = one(string.format("SELECT sum(duration) FROM page_stat WHERE id_book = %d AND start_time >= %d", id_book, since))
                if sp then d.s_pages = tostring(sp) end
                if st then d.s_time = hm(st) end
                dbg[#dbg + 1] = "sess=" .. tostring(sp) .. "/" .. tostring(st)
                conn:close()
            end)
            if not ok_db then dbg[#dbg + 1] = "dberr:" .. tostring(err):sub(-48) end
        end

        -- session time always has the plugin clock as a floor
        if d.s_time == "--" and stats.start_current_period then
            d.s_time = hm(os.time() - tonumber((tostring(stats.start_current_period):gsub("[^%d]", ""))))
        end
        d.debug = table.concat(dbg, " ")
    end

    return d
end


-- cover: same sources the bookshelf (coverbrowser) uses, then the document itself
local function loadCover(doc)
    if not doc then return nil end
    local file = doc.file
    local tries = {
        -- 1) CoverBrowser's BookInfoManager cache - exactly what the shelf grid
        --    paints. The module is on the package path as "bookinfomanager".
        function()
            local BIM = require("bookinfomanager")
            local info = BIM:getBookInfo(file, true)
            return info and info.cover_bb
        end,
        function()
            local BIM = require("plugins/coverbrowser.koplugin/bookinfomanager")
            local info = BIM:getBookInfo(file, true)
            return info and info.cover_bb
        end,
        -- 2) a custom cover the user set for this book
        function()
            local DocSettings = require("docsettings")
            local path = DocSettings:findCustomCoverFile(file)
            if not path then return nil end
            return RenderImage:renderImageFile(path, false)
        end,
        -- 3) KoReader's own book-info cover extractor
        function()
            local BookInfo = require("apps/filemanager/filemanagerbookinfo")
            return BookInfo:getCoverImage(nil, file, true)
        end,
        function()
            local BookInfo = require("apps/filemanager/filemanagerbookinfo")
            return BookInfo:getCoverImage(doc)
        end,
        -- 4) straight from the open document
        function() return doc:getCoverPageImage() end,
    }
    for i, fn in ipairs(tries) do
        local ok, res = pcall(fn)
        if ok and res then
            logger.info("read-receipt: cover loaded via strategy", i)
            return res
        end
        logger.warn("read-receipt: cover strategy", i, "->", tostring(res))
    end
    return nil
end

-- scale to fill the box and centre-crop
local function blitCoverInto(bb, img, dx, dy, dw, dh)
    if not img then return false end
    dx, dy, dw, dh = math.floor(dx), math.floor(dy), math.floor(dw), math.floor(dh)
    local iw, ih = img:getWidth(), img:getHeight()
    if not iw or iw < 1 then return false end
    -- ImageWidget is what the bookshelf grid uses; it owns the scaling maths
    local ok, err = pcall(function()
        local ImageWidget = require("ui/widget/imagewidget")
        local w = ImageWidget:new{
            image = img,
            image_disposable = false,
            width = dw,
            height = dh,
            scale_factor = nil,   -- stretch to exactly width x height
        }
        w:paintTo(bb, dx, dy)
        w:free()
    end)
    if ok then return true end
    logger.warn("read-receipt: ImageWidget cover failed:", tostring(err))
    -- fallbacks: scaler, then an unscaled centre crop
    local s = math.max(dw / iw, dh / ih)
    local sw, sh = math.max(math.ceil(iw * s), dw), math.max(math.ceil(ih * s), dh)
    local attempts = {
        function()
            local scaled = RenderImage:scaleBlitBuffer(img, sw, sh, false)
            bb:blitFrom(scaled, dx, dy, math.floor((sw - dw) / 2), math.floor((sh - dh) / 2), dw, dh)
        end,
        function()
            local w, h = math.min(iw, dw), math.min(ih, dh)
            bb:blitFrom(img, dx, dy, math.floor((iw - w) / 2), math.floor((ih - h) / 2), w, h)
        end,
    }
    for i, fn in ipairs(attempts) do
        local ok2, err2 = pcall(fn)
        if ok2 then return true end
        logger.warn("read-receipt: cover blit attempt", i, "failed:", tostring(err2))
    end
    return false
end

-- ------------------------------------------------------------- the widget --
local Receipt = InputContainer:extend{
    name = "read_receipt_view",
    covers_fullscreen = true,
    data = nil,
    document = nil,
    ui = nil,
}

function Receipt:init()
    self.dimen = Geom:new{ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() }
    -- snapshot of what is on screen right now (the page being read), used as
    -- the background behind the ticket
    if BACKGROUND == "page" and not self.page_bb then
        pcall(function() self.page_bb = Screen.bb:copy() end)
    end
    if Device:isTouchDevice() and not self.is_screensaver then
        self.ges_events = {
            Tap = { GestureRange:new{ ges = "tap", range = self.dimen } },
            -- long-press saves the receipt as a PNG (the system screenshot
            -- gesture cannot reach a fullscreen widget)
            Hold = { GestureRange:new{ ges = "hold", range = self.dimen } },
        }
    end
    if Device:hasKeys() then
        local back = Device.input and Device.input.group and Device.input.group.Back or { "Back" }
        self.key_events = { Close = { back } }
    end
end

function Receipt:getData()
    if not self.data then self.data = collectData(self.ui) end
    return self.data
end

function Receipt:getCover()
    if self.cover_checked then return self.cover end
    self.cover_checked = true
    self.cover = loadCover(self.document)
    return self.cover
end

function Receipt:getSize() return self.dimen end

-- the device was rotated while the receipt is up: follow the new screen size
-- (dimen is updated in place so the gesture ranges follow too)
function Receipt:onSetDimensions(dimen)
    self.dimen.w, self.dimen.h = Screen:getWidth(), Screen:getHeight()
    UIManager:setDirty(self, "full")
end

function Receipt:onHold()
    local DataStorage = require("datastorage")
    local dir = G_reader_settings:readSetting("screenshot_dir")
        or (DataStorage:getDataDir() .. "/screenshots")
    pcall(function() require("libs/libkoreader-lfs").mkdir(dir) end)
    local path = dir .. "/read-receipt-" .. os.date("%Y%m%d-%H%M%S") .. ".png"
    local ok = pcall(function() Screen:shot(path) end)
    local InfoMessage = require("ui/widget/infomessage")
    UIManager:show(InfoMessage:new{
        text = ok and ("Screenshot saved\n" .. path) or "Screenshot failed",
        timeout = 3,
    })
    logger.info("read-receipt: screenshot ->", path, tostring(ok))
    return true
end
function Receipt:onCloseWidget()
    if self.page_bb then
        pcall(function() self.page_bb:free() end)
        self.page_bb = nil
    end
end
function Receipt:onTap() UIManager:close(self) return true end
function Receipt:onClose() UIManager:close(self) return true end

function Receipt:paintTo(bb, x, y)
    local sw, sh = Screen:getWidth(), Screen:getHeight()
    fitScale(sw, sh)
    local ox
    if TICKET_ALIGN == "left" then
        ox = x + TICKET_EDGE_GAP
    elseif TICKET_ALIGN == "right" then
        ox = x + px(sw - W * S) - TICKET_EDGE_GAP
    else
        ox = x + px((sw - W * S) / 2)
    end
    local oy = y + px((sh - H * S) / 2)
    bb:paintRect(x, y, sw, sh, Blitbuffer.COLOR_WHITE)
    self:getData()
    -- behind the ticket: the page being read (snapshot), the faded book cover,
    -- or plain white, depending on BACKGROUND
    local drew_bg = false
    if BACKGROUND == "page" and self.page_bb
            and self.page_bb:getWidth() == sw and self.page_bb:getHeight() == sh then
        local ok = pcall(function() bb:blitFrom(self.page_bb, x, y, 0, 0, sw, sh) end)
        drew_bg = ok
    elseif BACKGROUND == "cover" or (BACKGROUND == "page" and not self.page_bb) then
        drew_bg = blitCoverInto(bb, self:getCover(), x, y, sw, sh)
    end
    if drew_bg and BACKGROUND_FADE > 0 then
        pcall(function() bb:lightenRect(x, y, sw, sh, BACKGROUND_FADE) end)
    end

    paintPaper(bb, ox, oy)

    -- hair dashes above / below the date row
    dashedH(bb, ox, oy, 33.7, 815, 327.2, 1.1, 4.1, 5.9, 2, COL.DASH)
    dashedH(bb, ox, oy, 33.7, 815, 418.6, 1.1, 4.1, 5.9, 2, COL.DASH)
    -- status rule (right of the title block)
    rect(bb, ox, oy, 586.06, 53.52, 1, 259.9, COL.LINE)
    -- date column dividers
    rect(bb, ox, oy, 273.3, 339.9, 1, 66, COL.DIV1)
    rect(bb, ox, oy, 540.4, 339.9, 1, 66, COL.DIV1)
    -- cover: the real book cover, scaled to fill and centre-cropped
    local function paintCover()
        local cx, cy, cw, ch = px(512.9 * S), px(450.5 * S), px(302.9 * S), px(399.6 * S)
        if not blitCoverInto(bb, self:getCover(), ox + cx, oy + cy, cw, ch) then
            bb:paintRect(ox + cx, oy + cy, cw, ch, COL.COVER)   -- only when there is no cover
        end
    end
    paintCover()
    -- progress bar
    local progress = (self.data and self.data.progress) or 0.1705
    rect(bb, ox, oy, 33.6, 868.6, 423.6, 14.6, COL.TRACK)
    rect(bb, ox, oy, 33.6, 868.6, 423.6 * progress, 14.6, COL.FILL)
    -- tear line (through the side notches)
    dashedH(bb, ox, oy, 33.2, 814.5, 967.85, 3, 4.3, 5.7, 2, COL.K)
    -- summary rule
    rect(bb, ox, oy, 31.9, 1053.35, 785.8, 1, COL.K)
    -- NOW / TODAY rules
    rect(bb, ox, oy, 45.3, 1087.1, 137, 1, COL.LINE)
    rect(bb, ox, oy, 253.8, 1087.1, 137.5, 1, COL.LINE)
    rect(bb, ox, oy, 456.8, 1087.1, 137, 1, COL.LINE)
    rect(bb, ox, oy, 664.8, 1087.1, 137.5, 1, COL.LINE)
    -- stat column dividers
    rect(bb, ox, oy, 200.9, 1117.2, 1, 126.3, COL.DIV2)
    rect(bb, ox, oy, 422.4, 1117.2, 1, 126.3, COL.DIV2)
    rect(bb, ox, oy, 612.4, 1117.2, 1, 126.3, COL.DIV2)
    -- dotted line above the barcode
    dashedH(bb, ox, oy, 33.2, 814.5, 1272.35, 3, 4.3, 5.7, 2, COL.K)
    -- barcode
    for _, b in ipairs(BARS) do
        rect(bb, ox, oy, b[1], BARCODE_Y, b[2], BARCODE_H, COL.K)
    end
    -- five dots
    disc(bb, ox, oy, 383.28, 1441.84, 3.1, COL.K)
    for i, cx in ipairs({ 406.92, 427.8, 448.44, 469.32 }) do
        disc(bb, ox, oy, cx, 1441.84, 2.4, COL.K)
    end

    -- type
    local data = self.data or {}
    local pen = 0
    for _, it in ipairs(ITEMS) do
        local text = it.t
        if it.key and data[it.key] then text = data[it.key] end
        if text ~= "" then
            local face = getFace(it.f, it.size * S)
            local alt = getFace(it.f == "C" and "L" or "C", it.size * S)
            local k = it.f == "C" and K_CN or K_LA
            local maxw = it.maxw and it.maxw * S
            if maxw and textWidth(face, text) > maxw then
                local chars = utf8chars(text)
                while #chars > 1 and textWidth(face, table.concat(chars) .. "…") > maxw do
                    table.remove(chars)
                end
                text = table.concat(chars) .. "…"
            end
            local sx
            if it.center then
                sx = ox + it.center * S - textWidth(face, text) / 2
            elseif it.follow then
                sx = pen + it.follow * S
            else
                sx = ox + it.x * S
            end
            local ok, res = pcall(drawText, bb, sx, oy + (it.top + k * it.size) * S,
                                  face, alt, text, (it.ls or 0) * S, COL[it.c])
            if ok then pen = res else logger.warn("read-receipt: draw failed", text, res) end
        end
    end
end

-- ------------------------------------------------------------ integration --
local function showReceipt(ui)
    local data = collectData(ui)
    local function open()
        UIManager:show(Receipt:new{ ui = ui, data = data, document = ui and ui.document })
    end
    if BACKGROUND == "page" then
        -- let the menu that launched us finish closing and the page repaint,
        -- so the snapshot is the clean page and not the menu on top of it
        UIManager:nextTick(function()
            pcall(function() UIManager:forceRePaint() end)
            open()
        end)
    else
        open()
    end
end

local ReceiptModule = WidgetContainer:extend{ name = "read_receipt" }

function ReceiptModule:init()
    if self.ui and self.ui.menu then self.ui.menu:registerToMainMenu(self) end
end

function ReceiptModule:addToMainMenu(menu_items)
    menu_items.read_receipt = {
        text = "READ RECEIPT",
        sorting_hint = "tools",
        callback = function() showReceipt(self.ui) end,
    }
end

function ReceiptModule:onShowReadReceipt()
    showReceipt(self.ui)
    return true
end

-- register the module on every ReaderUI instance
local ReaderUI = require("apps/reader/readerui")
local orig_reader_init = ReaderUI.init
function ReaderUI:init()
    orig_reader_init(self)
    self:registerModule("read_receipt", ReceiptModule:new{
        ui = self, view = self.view, document = self.document,
    })
end

-- gesture / profile action
local ok_dispatcher, Dispatcher = pcall(require, "dispatcher")
if ok_dispatcher then
    Dispatcher:registerAction("show_read_receipt", {
        category = "none", event = "ShowReadReceipt",
        title = "Read Receipt", reader = true, general = true,
    })
end

-- ------------------------------------------- kindle native screensaver --
-- On Kindle the framework redraws its OWN screensaver when the device is
-- powered off (and on some firmwares when it suspends), painting right over
-- whatever KoReader left on the screen.  We cannot stop that, so instead we
-- make the native screensaver BE the receipt: dump the framebuffer to the
-- screensaver-hack folder while the receipt is on screen.
-- (Kindle only: these parts do nothing on a Kobo.)
local lfs = require("libs/libkoreader-lfs")

local KINDLE_SS_DIRS = {
    "/mnt/us/linkss/screensavers",
    "/mnt/us/linkjs/screensavers",
    "/mnt/us/screensavers",
}
local KINDLE_SS_FILE = "bg_ss00.png"

local function isDir(path)
    local a = lfs.attributes(path)
    return a and a.mode == "directory"
end

-- resolved target file, or nil when this device has no writable hack folder
local function kindleSSTarget()
    if not Device:isKindle() then return nil end
    local custom = G_reader_settings:readSetting("read_receipt_kindle_ss_path")
    if custom and custom ~= "" then
        return custom, isDir(custom:match("^(.*)/[^/]+$") or "")
    end
    for _, dir in ipairs(KINDLE_SS_DIRS) do
        if isDir(dir) then return dir .. "/" .. KINDLE_SS_FILE, true end
    end
    return KINDLE_SS_DIRS[1] .. "/" .. KINDLE_SS_FILE, false
end

-- When KoReader runs while the Kindle framework is still up (launched from the
-- Home screen rather than with the framework stopped), lab126's powerd owns the
-- screen at suspend: it paints its OWN screensaver over ours about a second
-- later and hands the foreground back to Home on wake - which is exactly the
-- "receipt flashes, then the Kindle screensaver" report.
--
-- powerd takes an instruction not to: preventScreenSaver. Setting it keeps our
-- receipt on screen for the whole sleep, and it must be cleared on resume or
-- the device would never dim again.
local function lipcSet(prop, value)
    if not Device:isKindle() then return end
    pcall(os.execute,
        ("lipc-set-prop com.lab126.powerd %s %s 2>/dev/null"):format(prop, tostring(value)))
end

local function holdNativeScreensaver()
    if G_reader_settings:isFalse("read_receipt_block_native_ss") then return end
    lipcSet("preventScreenSaver", 1)
end

local function releaseNativeScreensaver()
    lipcSet("preventScreenSaver", 0)
end

-- dump what is currently on screen into the Kindle screensaver folder
local function syncReceiptToKindleScreensaver()
    if G_reader_settings:isFalse("read_receipt_sync_kindle_ss") then return end
    local target, dir_ok = kindleSSTarget()
    if not target then return end
    if not dir_ok then
        logger.warn("read-receipt: no Kindle screensaver folder at " .. target)
        return
    end
    local ok, err = pcall(function() Screen:shot(target) end)
    if ok then
        logger.info("read-receipt: wrote Kindle screensaver " .. target)
        -- flush to flash so a hard power cut still keeps the new image
        pcall(os.execute, "sync")
    else
        logger.warn("read-receipt: screensaver dump failed: " .. tostring(err))
    end
end

-- ---------------------------------------------------------- sleep screen --
-- "Show read receipt on sleep screen": a screensaver_type of its own, shown
-- through KoReader's ScreenSaverWidget so power/tap behaviour stays native.
local ok_ss, Screensaver = pcall(require, "ui/screensaver")
if ok_ss then
    local ScreenSaverWidget = require("ui/widget/screensaverwidget")
    local orig_screensaver_show = Screensaver.show
    Screensaver.show = function(self)
        if self.screensaver_type ~= "read_receipt" then
            return orig_screensaver_show(self)
        end
        local ui = self.ui or ReaderUI.instance
        if not (ui and ui.document) then
            -- nothing open to print a receipt for: hand back to the default
            self.screensaver_type = "disable"
            return orig_screensaver_show(self)
        end
        if self.screensaver_widget then
            UIManager:close(self.screensaver_widget)
            self.screensaver_widget = nil
        end
        Device.screen_saver_mode = true
        -- the receipt fits either orientation now, so the sleep screen stays in
        -- whatever orientation the reader is held (landscape included)
        Device.orig_rotation_mode = nil
        local receipt = Receipt:new{
            ui = ui, document = ui.document, is_screensaver = true,
        }
        self.screensaver_widget = ScreenSaverWidget:new{
            widget = receipt,
            background = Blitbuffer.COLOR_WHITE,
            covers_fullscreen = true,
        }
        self.screensaver_widget.modal = true
        self.screensaver_widget.dithered = true
        UIManager:show(self.screensaver_widget, "full")
        -- once the full refresh has landed, mirror it into the Kindle
        -- screensaver folder so the native screensaver shows the same ticket
        -- paint synchronously: on poweroff/reboot KoReader may not run any
        -- further scheduled task before the device goes down
        pcall(function() UIManager:forceRePaint() end)
        -- tell lab126's powerd to keep its hands off the screen, and ALSO leave
        -- the receipt in the screensaver folder for the case where the framework
        -- wins anyway (a real power-off, or no preventScreenSaver support)
        holdNativeScreensaver()
        syncReceiptToKindleScreensaver()
    end

    -- keep the receipt as the sleep screen for suspend AND poweroff/reboot:
    -- KoReader otherwise falls back to its own message on those events
    local orig_setup = Screensaver.setup
    Screensaver.setup = function(self, event, event_message)
        orig_setup(self, event, event_message)
        if G_reader_settings:readSetting("screensaver_type") == "read_receipt" then
            local ui = self.ui or ReaderUI.instance
            if ui and ui.document then
                self.screensaver_type = "read_receipt"
                self.show_message = false
            end
        end
    end

    -- clear preventScreenSaver on the way back up, or the Kindle would never
    -- dim on its own again
    local orig_close = Screensaver.close
    Screensaver.close = function(self, ...)
        releaseNativeScreensaver()
        return orig_close(self, ...)
    end

    -- add the option to Settings > Screen > Sleep screen > Wallpaper
    local orig_dofile = dofile
    dofile = function(filepath)
        local result = orig_dofile(filepath)
        if filepath and filepath:match("screensaver_menu%.lua$")
                and result and result[1] and result[1].sub_item_table then
            table.insert(result[1].sub_item_table, 1, {
                text = "READ RECEIPT",
                radio = true,
                checked_func = function()
                    return G_reader_settings:readSetting("screensaver_type") == "read_receipt"
                end,
                callback = function()
                    G_reader_settings:saveSetting("screensaver_type", "read_receipt")
                end,
            })
            if Device:isKindle() then
                table.insert(result[1].sub_item_table, 2, {
                    text = "Block Kindle native screensaver overlay",
                    help_text = "When KoReader is launched from the Kindle Home screen, the system "
                        .. "framework is still running in the background. About a second after "
                        .. "sleep it paints its own screensaver over the receipt, and returns to "
                        .. "the Kindle Home screen on wake. When enabled, this tells powerd not to "
                        .. "draw its screensaver (preventScreenSaver), so the receipt stays "
                        .. "until wake-up; it is released automatically on wake.",
                    enabled_func = function()
                        return G_reader_settings:readSetting("screensaver_type") == "read_receipt"
                    end,
                    checked_func = function()
                        return not G_reader_settings:isFalse("read_receipt_block_native_ss")
                    end,
                    callback = function()
                        local on = not G_reader_settings:isFalse("read_receipt_block_native_ss")
                        G_reader_settings:saveSetting("read_receipt_block_native_ss", not on)
                        if on then releaseNativeScreensaver() end
                    end,
                })
                table.insert(result[1].sub_item_table, 3, {
                    text = "Write receipt to Kindle native screensaver on power-off",
                    help_text = "On power-off, the Kindle system paints its own screensaver over "
                        .. "the KoReader screen. When enabled, the receipt is also written to the "
                        .. "screensaver hack folder "
                        .. "(/mnt/us/linkss/screensavers/bg_ss00.png), so the system screensaver "
                        .. "shows the same receipt. Requires the Kindle screensaver hack to be "
                        .. "installed, and no other images in that folder.",
                    enabled_func = function()
                        return G_reader_settings:readSetting("screensaver_type") == "read_receipt"
                    end,
                    checked_func = function()
                        return not G_reader_settings:isFalse("read_receipt_sync_kindle_ss")
                    end,
                    callback = function()
                        local on = not G_reader_settings:isFalse("read_receipt_sync_kindle_ss")
                        G_reader_settings:saveSetting("read_receipt_sync_kindle_ss", not on)
                    end,
                    separator = true,
                })
            end
        end
        return result
    end
end

logger.info("read-receipt patch loaded")
