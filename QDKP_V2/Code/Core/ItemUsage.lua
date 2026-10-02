-- Copyright 2010 Riccardo Belloli (belloli@email.it)
-- This file is a part of QDKP_V2 (see about.txt in the Addon's root folder)

--             ## CORE MODULE ##
--              Tracked Aura Usage Counter (QDKP2_ItemUsage)
--
--      Separate module that counts how many times guild characters which are
--      present in the raid have APPLIED one of the tracked auras.
--      Default tracked aura IDs: 53908 and 53909 (auras created by items
--      40211 / 40212). Every fresh application of a tracked aura on a raid
--      member increments that player's counter.
--
--      Detection method: the addon listens to COMBAT_LOG_EVENT_UNFILTERED and
--      watches SPELL_AURA_APPLIED / SPELL_AURA_REFRESH events whose spellID is
--      one of the tracked aura IDs. The target must be a friendly unit that is
--      currently in the raid/party roster.
--      The counters are stored in the persistent database (per guild), so they
--      survive between raids, sessions and /reloads.
--
-- API Documentation:
-- QDKP2IU_TrackAura(auraID)            -- starts tracking the given aura (spell) ID
-- QDKP2IU_UntrackAura(auraID)          -- stops tracking the given aura ID
-- QDKP2IU_SetTrackedAuras(list)        -- replaces the tracked auras list ("53908, 53909" style string or table)
-- QDKP2IU_GetTrackedAuras()            -- returns the sorted list of tracked aura IDs
-- QDKP2IU_IsTracked(auraID)            -- true if the given aura ID is tracked
-- QDKP2IU_RegisterApplication(name, auraID) -- registers one aura application on player <name>. Returns true if counted.
-- QDKP2IU_GetCount(name, [auraID])     -- applications count for <name> (total, or for a specific auraID)
-- QDKP2IU_GetTotalUses([auraID])       -- total number of tracked auras applied in the raid (all players)
-- QDKP2IU_GetRaidCounts()              -- returns a dictionary {name = {count=, dkpAwarded=}} of everyone with recorded applications
-- QDKP2IU_AwardAll(dkpPerUse)          -- awards dkpPerUse DKP for every non-awarded application of every tracked aura
-- QDKP2IU_AwardPlayer(name, dkpPerUse) -- awards dkpPerUse DKP for every non-awarded application of <name>
-- QDKP2IU_Reset([name])                -- resets counters (of <name> only, or all of them)


------------------------------- CONSTANTS & DEFAULTS -------------------------------

-- Auras we track by default (53908 / 53909, applied by items 40211 / 40212)
QDKP2IU_DEFAULT_AURAS = { 53908, 53909 }

-- How many times each tracked aura can be applied per raid encounter (for the "remaining uses" hint in the GUI)
QDKP2IU_USES_PER_BOSS = 1

-- Localized strings (fallbacks; overwritten by Local/enGB|ruRU|frFR.lua if loaded later)
QDKP2IU_LOC = QDKP2IU_LOC or {
  Header      = "Tracked auras usage",
  AuraIDs     = "Aura IDs",
  NoData      = "No tracked aura has been applied yet.",
  Player      = "Player",
  Uses        = "Applied",
  Awarded     = "DKP awarded",
  Total       = "Total applications",
  PerUse      = "DKP per application",
  AwardAll    = "Award all pending",
  AwardPlayer = "Award",
  Reset       = "Reset counters",
  NotOfficer  = "You need officer rights to award DKP.",
  NothingPay  = "There are no pending DKP awards for tracked auras.",
  AwardedMsg  = "$NAME received $DKP DKP for $N applications of tracked auras.",
  Registered  = "$NAME was affected by tracked aura $ITEM",
}


--------------------------------- LOCAL HELPERS ---------------------------------

local function IsTrackedID(auraID)
  local list = QDKP2_Data.TrackedItems
  if not list then return false; end
  for i = 1, #list do
    if list[i] == auraID then return true; end
  end
  return false
end

local function AuraDisplayName(auraID)
  -- GetSpellName exists only on <=4.x clients (undefined on modern ones), so the
  -- call is guarded: an unprotected nil-call here used to abort the whole
  -- registration routine right after the counter had been stored.
  local name
  if GetSpellName then name = GetSpellName(auraID) end
  if name and name ~= "" then return name; end
  if GetItemInfo then name = GetItemInfo(auraID) end
  if name then return name; end
  return ("Aura " .. tostring(auraID))
end

local function Round(amount)
  return math.floor(amount * 100 + 0.5) / 100
end

-- Cleans a combat-log name: strips surrounding quotes and the "-Realm" suffix.
local function StripCombatName(txt)
  if type(txt) ~= "string" then return nil; end
  txt = txt:gsub("\"", "")      -- strip quotes from combat log names
  txt = txt:gsub("%-.+", "")    -- strip server part ("Name-Realm" -> "Name")
  txt = txt:gsub("^%s+", "")
  txt = txt:gsub("%s+$", "")
  if txt == "" then return nil; end
  return txt
end

-- Resolves a combat log destination (name and/or GUID) into a plain player name.
-- Strategy:
--   1) resolve the destGUID against raid/party/self unit tokens (most reliable:
--      combat log names carry realm suffixes and different capitalization);
--   2) fall back to the raw destName cleaned from quotes/realm.
-- Returns nil when the target can't be resolved to a player.
local function UnitNameFromCombatLog(destName, destGUID)
  -- 1) GUID based resolution through unit tokens
  if type(destGUID) == "string" and UnitGUID then
    local numRaid = (GetNumRaidMembers and GetNumRaidMembers()) or 0
    if numRaid > 0 then
      for i = 1, numRaid do
        if UnitGUID("raid" .. i) == destGUID then
          local n = GetUnitName and GetUnitName("raid" .. i, true)
          return StripCombatName(n) or n
        end
      end
    else
      local numParty = (GetNumPartyMembers and GetNumPartyMembers()) or 0
      for i = 1, numParty do
        if UnitGUID("party" .. i) == destGUID then
          local n = GetUnitName and GetUnitName("party" .. i, true)
          return StripCombatName(n) or n
        end
      end
      if UnitGUID("player") == destGUID then
        local n = GetUnitName and GetUnitName("player")
        return StripCombatName(n) or n
      end
    end
  end

  -- 2) plain name fallback
  local candidate = StripCombatName(destName)
  if candidate then return candidate; end

  return nil
end

-- Normalizes a player name to the exact capitalization stored in the guild roster
-- (the DKP tables are keyed by that exact string). Falls back to the input name.
local function NormalizePlayerName(name)
  if not name then return nil; end
  if QDKP2rankIndex and QDKP2rankIndex[name] then return name; end
  local upper = string.upper(name)
  for k, _ in pairs(QDKP2name or {}) do
    if string.upper(k) == upper then return k; end
  end
  return name
end


----------------------------- DATABASE INITIALIZATION -----------------------------

-- Called on CHAT_MSG_SYSTEM (Guild Roster request) from Events.lua, when the
-- persistent database is already loaded. Guarantees our fields exist.
function QDKP2IU_Init(force)
  if not QDKP2_Data then return; end

  if not QDKP2_Data.TrackedItems or force then
    QDKP2_Data.TrackedItems = {}
    for i = 1, #QDKP2IU_DEFAULT_AURAS do
      table.insert(QDKP2_Data.TrackedItems, QDKP2IU_DEFAULT_AURAS[i])
    end
  end

  if not QDKP2_Data.ItemUses then
    QDKP2_Data.ItemUses = {}   -- [Name] = { ["id"] = applications, ["dkp"] = dkp already awarded }
  end
end


-------------------------------- TRACKED AURAS LIST --------------------------------

function QDKP2IU_IsTracked(auraID)
  return IsTrackedID(tonumber(auraID))
end

function QDKP2IU_GetTrackedAuras()
  local list = {}
  if QDKP2_Data and QDKP2_Data.TrackedItems then
    for i = 1, #QDKP2_Data.TrackedItems do
      table.insert(list, QDKP2_Data.TrackedItems[i])
    end
  end
  table.sort(list)
  return list
end

-- Backwards compatible alias (older builds called this with item IDs)
QDKP2IU_GetTrackedItems = QDKP2IU_GetTrackedAuras

function QDKP2IU_TrackAura(auraID)
  auraID = tonumber(auraID)
  if not auraID then return; end
  QDKP2IU_Init()
  if IsTrackedID(auraID) then return; end
  table.insert(QDKP2_Data.TrackedItems, auraID)
  QDKP2_Msg(QDKP2_COLOR_BLUE .. "QDKP2: Now tracking aura ID " .. auraID)
end

function QDKP2IU_UntrackAura(auraID)
  auraID = tonumber(auraID)
  if not auraID or not QDKP2_Data or not QDKP2_Data.TrackedItems then return; end
  for i = 1, #QDKP2_Data.TrackedItems do
    if QDKP2_Data.TrackedItems[i] == auraID then
      table.remove(QDKP2_Data.TrackedItems, i)
      QDKP2_Msg(QDKP2_COLOR_BLUE .. "QDKP2: Stopped tracking aura ID " .. auraID)
      return
    end
  end
end

-- Accepts a comma separated list of aura ids ("53908, 53909") or a table of numbers
function QDKP2IU_SetTrackedAuras(list)
  local new = {}
  if type(list) == "string" then
    for id in string.gmatch(list, "%d+") do
      table.insert(new, tonumber(id))
    end
  elseif type(list) == "table" then
    for i = 1, #list do
      local id = tonumber(list[i])
      if id then table.insert(new, id); end
    end
  end
  QDKP2IU_Init()
  QDKP2_Data.TrackedItems = new
end


--------------------------------- COUNTER SERVICES ---------------------------------

function QDKP2IU_GetCount(name, auraID)
  if not name or not QDKP2_Data or not QDKP2_Data.ItemUses then return 0; end
  local rec = QDKP2_Data.ItemUses[name]
  if not rec then return 0; end
  if auraID then
    return rec["i" .. tonumber(auraID)] or 0
  end
  return rec["id"] or 0
end

function QDKP2IU_GetAwardedDKP(name)
  if not name or not QDKP2_Data or not QDKP2_Data.ItemUses then return 0; end
  local rec = QDKP2_Data.ItemUses[name]
  return (rec and rec["dkp"]) or 0
end

function QDKP2IU_GetTotalUses(auraID)
  local total = 0
  if QDKP2_Data and QDKP2_Data.ItemUses then
    for name, rec in pairs(QDKP2_Data.ItemUses) do
      if auraID then
        total = total + (rec["i" .. tonumber(auraID)] or 0)
      else
        total = total + (rec["id"] or 0)
      end
    end
  end
  return total
end

-- Returns { [Name] = { count = n, dkpAwarded = x } } for all players with recorded applications
function QDKP2IU_GetRaidCounts()
  local out = {}
  if QDKP2_Data and QDKP2_Data.ItemUses then
    for name, rec in pairs(QDKP2_Data.ItemUses) do
      if (rec["id"] or 0) > 0 then
        out[name] = { count = rec["id"], dkpAwarded = rec["dkp"] or 0 }
      end
    end
  end
  return out
end


------------------------------------ MAIN HANDLER ------------------------------------

local lastRawEntry = nil   -- anti-duplication guard (see QDKP2IU_ProcessEntry)

--[[ Registers ONE application of a tracked aura on player <name>.
     Counts the application ONLY IF:
       * the aura ID is one of the tracked ones (default 53908 / 53909)
       * the affected character belongs to the guild roster, OR is currently
         present in the raid/party (this also covers external/standby members) ]]
function QDKP2IU_RegisterApplication(name, auraID)
  if not name or type(name) ~= "string" then return; end
  auraID = tonumber(auraID)
  if not auraID or not IsTrackedID(auraID) then return; end

  name = NormalizePlayerName(name)

  local inGuild = QDKP2_IsInGuild and QDKP2_IsInGuild(name)
  local inRaid = QDKP2_IsInRaid and QDKP2_IsInRaid(name)
  if not inGuild and not inRaid then
    QDKP2_Debug(3, "Core", "ItemUsage: " .. name .. " received a tracked aura but is neither in the guild nor in the raid. Not counted.")
    return
  end

  QDKP2IU_Init()

  local rec = QDKP2_Data.ItemUses[name]
  if not rec then
    -- Re-assert the DB reference: on some client flavors the saved-variable table
    -- gets swapped after the addon opened (e.g. /reload, multi-guild profiles),
    -- and a stale local reference would silently drop the counter.
    if not QDKP2_Data or not QDKP2_Data.ItemUses then
      QDKP2_Data = QDKP2_Data  -- refresh global binding
      QDKP2IU_Init(true)
    end
    QDKP2_Data.ItemUses[name] = {}
    rec = QDKP2_Data.ItemUses[name]
  end

  rec["id"] = (rec["id"] or 0) + 1
  rec["i" .. auraID] = (rec["i" .. auraID] or 0) + 1

  QDKP2_Debug(2, "Core", "ItemUsage: counted aura application #" .. rec["id"] .. " of aura " .. auraID .. " on " .. name)

  local msg = QDKP2IU_LOC.Registered
  msg = string.gsub(msg, "$NAME", name)
  msg = string.gsub(msg, "$ITEM", AuraDisplayName(auraID))
  QDKP2_Msg(QDKP2_COLOR_YELLOW .. msg)

  QDKP2_Events:Fire("ITEM_USAGE_UPDATED", name, auraID)
  -- Auto-refresh the ItemUsage GUI page (if loaded and visible)
  if QDKP2IU_RefreshPage then QDKP2IU_RefreshPage(); end
  return true
end

-- Legacy alias kept so old integrations (loot based counting) don't break
QDKP2IU_RegisterUse = QDKP2IU_RegisterApplication


------------------------------ COMBAT LOG EVENT HANDLER ------------------------------

--[[ Extracts (subevent, srcGUID, srcName, dstGUID, dstName, spellID) from ONE
     combat log entry, in a client-version-safe way:
       - WoW 10.x+ Retail/Classic : CombatLogGetCurrentEventInfo() returns the current entry
       - WoW 4.x-9.x              : UnitEvents("COMBAT_LOG_EVENT_UNFILTERED", idx) ring buffer
       - WoW <=3.3 (legacy)       : fields forwarded as event args (arg2..arg9) ]]
local function ReadCombatLogEntry(idx)
  local timestamp, subevent, srcGUID, srcName, srcFlags, srcRobust,
        dstGUID, dstName, dstFlags, dstRobust, spellID
  if CombatLogGetCurrentEventInfo then
    timestamp, subevent, srcGUID, srcName, srcFlags, srcRobust,
            dstGUID, dstName, dstFlags, dstRobust, spellID = CombatLogGetCurrentEventInfo()
  elseif UnitEvents then
    timestamp, subevent, srcGUID, srcName, srcFlags, srcRobust,
            dstGUID, dstName, dstFlags, dstRobust, spellID =
      select(2, UnitEvents("COMBAT_LOG_EVENT_UNFILTERED", idx or 1))
  else
    local f = QDKP2IU_EventFrame
    if not f then return end
    subevent = f.arg2; srcGUID = f.arg3; srcName = f.arg4
    dstGUID  = f.arg5; dstName  = f.arg6; spellID = f.arg9
  end
  return subevent, srcGUID, srcName, dstGUID, dstName, spellID
end

function QDKP2IU_ProcessEntry(subevent, dstGUID, dstName, spellID)
  if not subevent then return; end
  if subevent ~= "SPELL_AURA_APPLIED" and subevent ~= "SPELL_AURA_REFRESH" then return; end
  if not spellID or not IsTrackedID(spellID) then return; end
  -- Anti-duplication: the same log entry can reach us through more than one
  -- listener (core Events frame + module hidden frame). Identify the raw entry
  -- and skip it if we have already processed this exact one.
  local entryKey = tostring(dstGUID) .. "|" .. tostring(dstName) .. "|" .. tostring(spellID)
  if entryKey == lastRawEntry then return; end
  lastRawEntry = entryKey
  -- dest must resolve to a player name
  local name = UnitNameFromCombatLog(dstName, dstGUID)
  if not name then return; end
  QDKP2IU_RegisterApplication(name, spellID)
end

--[[ Processes the currently available combat log entries.
     On WoW 4.x-9.x clients it drains the WHOLE ring buffer (NUM_COMBAT_LOGS), so no
     aura application can be missed even if another addon consumed the event first.
     On modern and legacy clients there is only one entry per event: use the args
     passed with the event when present, otherwise re-read them from the API.
     NOTE: on modern clients the forwarded arg2 IS the subevent string; on legacy
     (<=3.3) dispatchers arg2 may instead be the source GUID, in which case we
     re-read the entry fields from the frame's forwarded args. ]]
function QDKP2IU_OnCombatLog(subevent, srcGUID, srcName, dstGUID, dstName, spellID)
  if not QDKP2_Data or not QDKP2_Data.TrackedItems then return; end

  local num = NUM_COMBAT_LOGS   -- defined only on WoW 4.x-9.x ring-buffer clients
  if num and num > 0 and UnitEvents and not CombatLogGetCurrentEventInfo then
    for i = 1, num do
      local s, sg, sn, dg, dn, sp = ReadCombatLogEntry(i)
      QDKP2IU_ProcessEntry(s, dg, dn, sp)
    end
  else
    if type(subevent) ~= "string" or not string.find(subevent, "^SPELL_") and not string.find(subevent, "^UNIT_") then
      -- not a recognizable subevent (legacy arg layout): re-read from the API/args
      subevent, srcGUID, srcName, dstGUID, dstName, spellID = ReadCombatLogEntry(1)
    elseif CombatLogGetCurrentEventInfo and not UnitEvents and not NUM_COMBAT_LOGS then
      -- Modern client: the authoritative data is CombatLogGetCurrentEventInfo();
      -- always take the full field set from there (spellID sits at position 10).
      local s2, sg2, sn2, dg2, dn2, sp2 = ReadCombatLogEntry(1)
      if s2 then subevent, srcGUID, srcName, dstGUID, dstName, spellID = s2, sg2, sn2, dg2, dn2, sp2 end
    end
    QDKP2IU_ProcessEntry(subevent, dstGUID, dstName, spellID)
  end
end

-- Dedicated hidden frame listening to COMBAT_LOG_EVENT_UNFILTERED.
-- It is created as soon as this file loads, so it works even before the guild
-- database finished initializing (the handler itself checks for readiness).
if not QDKP2IU_EventFrame then
  QDKP2IU_EventFrame = CreateFrame("Frame", "QDKP2IU_EventFrame")
  QDKP2IU_EventFrame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  QDKP2IU_EventFrame:SetScript("OnEvent", function(self, event, ...)
    if event ~= "COMBAT_LOG_EVENT_UNFILTERED" then return; end
    -- Pass the varargs straight through: legacy (<=3.3) clients forward the log
    -- fields as event args, modern clients pass nothing and the handler re-reads
    -- the entry via CombatLogGetCurrentEventInfo instead.
    local ok, err = pcall(QDKP2IU_OnCombatLog, ...)
    if not ok and QDKP2_Debug then QDKP2_Debug(1, "Core", "ItemUsage combatlog error: " .. tostring(err)) end
  end)
end


------------------------------------ AWARDS ------------------------------------

--[[ Awards DKP for all the pending (not yet awarded) tracked-aura applications.
     dkpPerUse: DKP amount given for each single application.
     If name is provided, only that player is paid.
     Uses the low level DKP API (QDKP2_PlayerGains), so it works both inside and
     outside an ongoing session and it logs the operation automatically. ]]
function QDKP2IU_Award(dkpPerUse, name)
  dkpPerUse = tonumber(dkpPerUse)
  if not dkpPerUse or dkpPerUse <= 0 then
    QDKP2_Debug(1, "Core", "ItemUsage: invalid DKP per use amount: " .. tostring(dkpPerUse))
    return
  end
  if not QDKP2_OfficerMode() then
    QDKP2_Msg(QDKP2IU_LOC.NotOfficer, "ERROR")
    return
  end
  QDKP2IU_Init()

  local any = false
  local counts = QDKP2IU_GetRaidCounts()

  for playerName, data in pairs(counts) do
    if not name or playerName == name then
      local pending = Round(data.count * dkpPerUse - data.dkpAwarded)
      if pending > 0 and QDKP2_IsInGuild(playerName) then
        local reason = string.format("Tracked auras applied: %d x %.2f DKP", data.count, dkpPerUse)
        QDKP2_PlayerGains(playerName, pending, reason)
        QDKP2_Data.ItemUses[playerName]["dkp"] = Round(data.count * dkpPerUse)
        any = true
        local msg = string.gsub(QDKP2IU_LOC.AwardedMsg, "$NAME", playerName)
        msg = string.gsub(msg, "$DKP", tostring(pending))
        msg = string.gsub(msg, "$N", tostring(data.count))
        QDKP2_Msg(QDKP2_COLOR_BLUE .. msg)
      end
    end
  end

  if not any then
    QDKP2_Msg(QDKP2IU_LOC.NothingPay)
  end
  return any
end

function QDKP2IU_AwardAll(dkpPerUse)
  return QDKP2IU_Award(dkpPerUse)
end

function QDKP2IU_AwardPlayer(name, dkpPerUse)
  return QDKP2IU_Award(dkpPerUse, name)
end


------------------------------------- RESET -------------------------------------

function QDKP2IU_Reset(name)
  if not QDKP2_Data or not QDKP2_Data.ItemUses then return; end
  if name then
    QDKP2_Data.ItemUses[name] = nil
  else
    table.wipe(QDKP2_Data.ItemUses)
  end
  QDKP2_Events:Fire("ITEM_USAGE_UPDATED", name)
end
