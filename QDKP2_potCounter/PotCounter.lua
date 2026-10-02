-----------------------------------------------------------------------
-- QDKP2_potCounter: Potion Counter module
-- Tracks raiders drinking potions by counting aura applications
-- of the potion auras (IDs 53908 and 53909) from the combat log.
-- Every application (SPELL_AURA_APPLIED / SPELL_AURA_REFRESH)
-- increases that player's counter by 1.
-- This module is fully self-contained inside QDKP2_potCounter/.
-----------------------------------------------------------------------

local MODNAME = "QDKP2_potCounter"

-----------------------------------------------------------------------
-- Bootstrap: wait for ADDON_LOADED of this addon, then try to build on
-- AceAddon-3.0 (bundled in QDKP2_Config) or fall back to a plain frame.
-----------------------------------------------------------------------
local PotCounter -- set by bootstrap
local PotCounterAPI = {} -- public API, attached to the engine in StartModule

local function StartModule(engine)
  PotCounter = engine
  for k, v in pairs(PotCounterAPI) do
    if engine[k] == nil then engine[k] = v end
  end
  _G[MODNAME] = PotCounter
end

-----------------------
--   Constants
-----------------------
local TRACKED_AURAS = {
  [53908] = "Haste Potion", -- e.g. Potion of Speed line
  [53909] = "Crit Potion",  -- e.g. Destruction/Draenic line
}

local DB_VERSION = 1

-----------------------
--   Saved variables
-----------------------
local db

local function DefaultDB()
  return {
    version = DB_VERSION,
    -- players[NameRealm] = { haste = N, crit = N, last = timestamp }
    players = {},
  }
end

-----------------------
--   Helpers
-----------------------
local function NormalizeName(unitName)
  if not unitName or unitName == "" then return nil end
  local name, realm = strsplit("-", unitName, 2)
  if realm and realm ~= "" then
    return (name or "") .. "-" .. (realm or "")
  end
  -- Append current realm so keys are consistent ("Player" -> "Player-Realm")
  local ro = GetRealmName and GetRealmName() or ""
  if ro ~= "" then
    return (unitName) .. "-" .. ro
  end
  return unitName
end

local function UnitNameByKey(unit)
  local n = UnitName(unit)
  if not n then return nil end
  return NormalizeName(n)
end

local function ResolvePlayer(destGUID, destName)
  -- Prefer resolving through the raid roster by GUID (robust against
  -- server-side name formatting), fall back to normalized combat log name.
  if destGUID then
    local num = (GetNumGroupMembers and GetNumGroupMembers()) or (GetNumRaidMembers and GetNumRaidMembers()) or 0
    for i = 1, num do
      local unit = "raid" .. i
      if UnitExists(unit) and UnitGUID(unit) == destGUID then
        local key = UnitNameByKey(unit)
        if key then return key end
      end
    end
  end
  return NormalizeName(destName)
end

local function GetPlayerEntry(key, createIfMissing)
  if not key then return nil end
  local p = db.players[key]
  if not p and createIfMissing then
    db.players[key] = { haste = 0, crit = 0, last = 0 }
    p = db.players[key]
  end
  return p
end

-----------------------
--   Public API
--   (attached to the module table inside StartModule)
-----------------------

PotCounterAPI.GetPlayers = function(self)
  return db.players
end

PotCounterAPI.GetPlayerCount = function(self, key)
  local p = GetPlayerEntry(key, false)
  if not p then return 0 end
  return (p.haste or 0) + (p.crit or 0)
end

PotCounterAPI.GetTotals = function(self)
  local haste, crit, players = 0, 0, 0
  for _, p in pairs(db.players) do
    haste = haste + (p.haste or 0)
    crit = crit + (p.crit or 0)
    if (p.haste or 0) > 0 or (p.crit or 0) > 0 then players = players + 1 end
  end
  return haste, crit, players
end

PotCounterAPI.ResetAll = function(self)
  db.players = {}
  if PotCounter.frame then PotCounter.frame:Refresh() end
  print("|cff33ff99[PotCounter]|r counters reset.")
end

-----------------------
--   Combat log handling
-----------------------
-- WoW Classic (3.3.5) COMBAT_LOG_EVENT_UNFILTERED argument layout for
-- SPELL_AURA_APPLIED / SPELL_AURA_REFRESH (as reported by the server core):
--   1  subevent
--   2  srcGUID
--   3  srcName
--   4  srcFlag
--   5  dstGUID
--   6  dstName
--   7  dstFlag
--   8  spellID
--   9  spellName
--   10 spellSchool
--   11 type ("BUFF" or "DEBUFF")
-- Some other builds/clients expose the same data via
-- CombatLogGetCurrentEventInfo() with the retail layout:
--   1 subevent, 2 hideCaster, 3 srcGUID, 4 srcName, 5 srcFlags,
--   6 dstGUID, 7 dstName, 8 dstFlags, 9 spellID, 10 spellName, 11 spellSchool, [12 auraType]
-- Both layouts are auto-detected (by checking which index holds the numeric
-- spellID) and normalized into one table so the counter works on either client.
local function IsSubevent(s)
  return type(s) == "string" and s:find("^SPELL_") ~= nil
end

local IsPlayerGUID = function(guid)
  if type(guid) ~= "string" then return false end
  -- Accept any GUID that contains a hex player low/high part; different
  -- cores use slightly different prefixes (Player-..., 0x0000000...).
  return guid:find("Player") ~= nil or guid:find("^0x") ~= nil
end

-- Returns normalized event table or nil. Layouts are distinguished by the
-- type pattern of the arguments around the spellID slot (the only reliably
-- numeric field in every variant).
local function MatchCompactClassic(args, subevent)
  -- 1 subevent, 2 srcGUID, 3 srcName, 4 srcFlag,
  -- 5 dstGUID, 6 dstName, 7 dstFlag, 8 spellID(number),
  -- 9 spellName(string), 10 spellSchool, 11 type ("BUFF"/"DEBUFF")
  if IsPlayerGUID(args[2]) and IsPlayerGUID(args[5])
     and type(args[8]) == "number" then
    return { subevent = subevent, destGUID = args[5], destName = args[6], spellID = args[8] }
  end
end

local function MatchFullVarargs(args, subevent)
  -- 1 subevent, 2 hideCaster(boolean), 3 srcUnitID, 4 srcGUID, 5 srcName,
  -- 6 srcFlags, 7 srcRaidFlags, 8 dstUnitID, 9 dstGUID, 10 dstName,
  -- 11 dstFlags, 12 dstRaidFlags, 13 spellID(number), 14 spellName(string), ...
  -- Some cores omit the raid-flag columns, so spellID sits at 11 instead.
  if type(args[2]) ~= "string" and IsPlayerGUID(args[4])
     and IsPlayerGUID(args[9]) then
    if type(args[13]) == "number" then
      return { subevent = subevent, destGUID = args[9], destName = args[10], spellID = args[13] }
    elseif type(args[11]) == "number" then
      return { subevent = subevent, destGUID = args[9], destName = args[10], spellID = args[11] }
    end
  end
end

local function MatchRetail(args, subevent)
  -- CombatLogGetCurrentEventInfo retail: 1 subevent, 2 hideCaster,
  -- 3 srcGUID, 4 srcName, 5 srcFlags, 6 dstGUID, 7 dstName, 8 dstFlags,
  -- 9 spellID(number), 10 spellName(string), 11 school, [12 auraType]
  if IsPlayerGUID(args[3]) and IsPlayerGUID(args[6])
     and type(args[9]) == "number" then
    return { subevent = subevent, destGUID = args[6], destName = args[7], spellID = args[9] }
  end
end

local function PickLayout(args)
  if not args or #args < 8 then return nil end
  local subevent = args[1]
  if type(subevent) ~= "string" or not IsSubevent(subevent) then return nil end

  return MatchFullVarargs(args, subevent)
      or MatchCompactClassic(args, subevent)
      or MatchRetail(args, subevent)
end

local function ParseCLEU(...)
  local args = { ... }

  -- Prefer the modern API when it actually returns combat log data.
  if CombatLogGetCurrentEventInfo then
    local ok, first = pcall(CombatLogGetCurrentEventInfo)
    if ok and type(first) == "string" and first ~= "" and (first:match("^SWING") or first:match("^[A-Z]+_[A-Z_]+$")) then
      local c = { CombatLogGetCurrentEventInfo() }
      local e = PickLayout(c)
      if e then return e end
    end
  end

  local e = PickLayout(args)
  if e then return e end

  -- Some client builds/core wrappers deliver CLEU with a leading extra
  -- argument before the subevent string. Try shifting by one so we still
  -- parse correctly instead of silently dropping the event.
  for shift = 1, 2 do
    local shifted = {}
    for i = 1 + shift, #args do shifted[i - shift] = args[i] end
    e = PickLayout(shifted)
    if e then return e end
  end

  return nil
end

-- Deduplicate identical events that some client/addon wrappers deliver twice.
local lastEventSig = nil

PotCounterAPI.OnCombatLog = function(selfOrFirst, ...)
  -- Tolerate both plain and colon invocation: if called as
  -- PotCounter:OnCombatLog(...) the first argument is the engine table,
  -- which would shift every combat-log index by one. Detect a non-string
  -- leading argument (subevent is always a string) and drop it.
  local args = { ... }
  if type(selfOrFirst) ~= "string" then
    -- selfOrFirst is 'self'; varargs already hold the log payload.
  else
    table.insert(args, 1, selfOrFirst)
  end
  local ok, err = pcall(function(parsed)
    if not parsed then return end
    local subevent, destGUID, destName, spellID = parsed.subevent, parsed.destGUID, parsed.destName, parsed.spellID
    if type(subevent) ~= "string" then return end
    if subevent ~= "SPELL_AURA_APPLIED" and subevent ~= "SPELL_AURA_REFRESH" then return end
    if type(spellID) ~= "number" then return end
    if not TRACKED_AURAS[spellID] then return end

    local now = GetTime and GetTime() or 0
    local sig = table.concat({ subevent, tostring(spellID), tostring(destGUID), string.format("%.3f", now) }, "|")
    if sig == lastEventSig then return end
    lastEventSig = sig

    local key = ResolvePlayer(destGUID, destName)
    if not key then return end

    local entry = GetPlayerEntry(key, true)
    if not entry then return end

    if spellID == 53908 then
      entry.haste = (entry.haste or 0) + 1
    else
      entry.crit = (entry.crit or 0) + 1
    end
    entry.last = now

    -- Update GUI only after the counter is safely incremented.
    if PotCounter.frame and PotCounter.frame:IsVisible() then
      PotCounter.frame:Refresh()
    end
  end, ParseCLEU(unpack(args)))
  if not ok then
    DEFAULT_CHAT_FRAME = DEFAULT_CHAT_FRAME or { AddMessage = function() end }
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
      DEFAULT_CHAT_FRAME:AddMessage("|cffff5555[PotCounter]|r event error: " .. tostring(err))
    end
  end
end

-----------------------
--   GUI window
-----------------------
local FRAME_W, FRAME_H = 420, 460

local function CreateMainWindow()
  if PotCounter.frame then return PotCounter.frame end

  local f = CreateFrame("Frame", "PotCounterWindow", UIParent)
  f:SetSize(FRAME_W, FRAME_H)
  f:SetPoint("CENTER")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:Hide()

  f:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 },
  })

  local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, -16)
  title:SetText("Potion Counter (53908 / 53909)")

  local totals = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  totals:SetPoint("TOP", title, "BOTTOM", 0, -8)
  totals:SetText("")

  -- Header row
  local colNames = { {"Player", 220}, {"Haste (53908)", 90}, {"Crit (53909)", 90} }
  local headerY = -70
  local xoff = 0
  for i, col in ipairs(colNames) do
    local hs = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hs:SetPoint("LEFT", 20 + xoff, headerY)
    hs:SetText(col[1])
    xoff = xoff + col[2]
  end

  -- Scrollable list
  local scroll = CreateFrame("ScrollFrame", "PotCounterScroll", f, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 16, headerY - 18)
  scroll:SetPoint("BOTTOMRIGHT", -36, 60)

  local content = CreateFrame("Frame", nil, scroll)
  content:SetWidth(FRAME_W - 80)
  scroll:SetScrollChild(content)

  f.rows = {}
  local ROW_H = 20
  function f:Refresh()
    local list = {}
    for k, p in pairs(db.players) do
      if (p.haste or 0) > 0 or (p.crit or 0) > 0 then
        table.insert(list, { key = k, haste = p.haste or 0, crit = p.crit or 0 })
      end
    end
    table.sort(list, function(a, b)
      return (a.haste + a.crit) > (b.haste + b.crit) or
             (a.haste + a.crit) == (b.haste + b.crit) and a.key < b.key
    end)

    local needed = #list * ROW_H
    if needed < 1 then needed = 1 end
    content:SetHeight(math.max(needed, scroll:GetHeight()))

    for i = 1, #list do
      local row = f.rows[i]
      if not row then
        row = CreateFrame("Frame", nil, content)
        row:SetHeight(ROW_H)
        row:SetWidth(FRAME_W - 80)
        row.cells = {}
        local xo = 0
        for ci, col in ipairs(colNames) do
          local c = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
          c:SetPoint("LEFT", 4 + xo, 0)
          c:SetWidth(col[2] - 8)
          c:SetJustifyH(ci == 1 and "LEFT" or "CENTER")
          row.cells[ci] = c
          xo = xo + col[2]
        end
        f.rows[i] = row
      end
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(i - 1) * ROW_H)
      row.cells[1]:SetText(list[i].key)
      row.cells[2]:SetText(list[i].haste)
      row.cells[3]:SetText(list[i].crit)
      row:Show()
    end
    for i = #list + 1, #f.rows do
      f.rows[i]:Hide()
    end

    local h, c, pl = PotCounter:GetTotals()
    totals:SetText(format("Total: %d haste | %d crit | players with potions: %d", h, c, pl))
  end

  -- Buttons
  local btnReset = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  btnReset:SetSize(100, 22)
  btnReset:SetPoint("BOTTOMLEFT", 20, 20)
  btnReset:SetText("Reset")
  btnReset:SetScript("OnClick", function()
    StaticPopup_Show("POTCOUNTER_RESET_CONFIRM")
  end)

  local btnClose = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  btnClose:SetSize(100, 22)
  btnClose:SetPoint("BOTTOMRIGHT", -20, 20)
  btnClose:SetText("Close")
  btnClose:SetScript("OnClick", function() f:Hide() end)

  function f:Toggle()
    if self:IsVisible() then self:Hide() else self:Show(); self:Refresh() end
  end

  f:SetScript("OnShow", function(self) self:Refresh() end)

  StaticPopupDialogs["POTCOUNTER_RESET_CONFIRM"] = {
    text = "Reset all potion counters?",
    button1 = YES,
    button2 = CANCEL,
    OnAccept = function() PotCounter:ResetAll() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
  }

  PotCounter.frame = f
  return f
end

-----------------------
--   Addon lifecycle
-----------------------
local function InitDB()
  local saved = _G[MODNAME .. "_DB"]
  if type(saved) ~= "table" or saved.version ~= DB_VERSION then
    saved = DefaultDB()
  end
  setmetatable(saved, { __index = DefaultDB() })
  db = saved
  _G[MODNAME .. "_DB"] = saved
end

local function EnableModule()
  CreateMainWindow()
  -- Hidden frame listener: independent from QDKP core event routing and
  -- from AceEvent, so CLEU is always seen.
  if not PotCounter.listener then
    local lf = CreateFrame("Frame", MODNAME .. "Listener", UIParent)
    lf:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
    lf:SetScript("OnEvent", function(self, event, ...)
      if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        -- NOTE: call as plain function; passing self would shift all
        -- vararg indices by one and break combat log parsing.
        PotCounterAPI.OnCombatLog(...)
      end
    end)
    PotCounter.listener = lf
  end
end

if LibStub and LibStub("AceAddon-3.0", true) then
  -- Preferred path: run as an AceAddon object (libs bundled in QDKP2_Config).
  local PotCounterAce = LibStub("AceAddon-3.0"):NewAddon(MODNAME)
  PotCounterAce.Name = MODNAME
  function PotCounterAce:OnInitialize()
    StartModule(PotCounterAce)
    InitDB()
  end
  function PotCounterAce:OnEnable()
    EnableModule()
  end
else
  -- Fallback path: plain frame-driven bootstrap (no external libs needed).
  local boot = CreateFrame("Frame", MODNAME .. "Boot", UIParent)
  boot:RegisterEvent("ADDON_LOADED")
  boot:SetScript("OnEvent", function(_, event, addonName)
    if event ~= "ADDON_LOADED" or addonName ~= MODNAME then return end
    local engine = {}
    function engine:OnInitialize() StartModule(engine); InitDB(); EnableModule() end
    boot:UnregisterEvent("ADDON_LOADED")
    engine:OnInitialize()
  end)
end

local function SlashHandler(msg)
  local cmd = strtrim(msg or ""):lower()
  if not PotCounter then return end
  if cmd == "reset" then
    PotCounter:ResetAll()
  elseif cmd == "totals" then
    local h, c, p = PotCounter:GetTotals()
    print(format("[PotCounter] haste=%d crit=%d players=%d", h, c, p))
  else
    PotCounter.frame:Toggle()
  end
end

SLASH_POTCOUNTER1 = "/potc"
SLASH_POTCOUNTER2 = "/potcounter"
if SlashCmdHandler then
  SlashCmdHandler[SLASH_POTCOUNTER1] = function(msg) SlashHandler(msg) end
  SlashCmdHandler[SLASH_POTCOUNTER2] = function(msg) SlashHandler(msg) end
end
