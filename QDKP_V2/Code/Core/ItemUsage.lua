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
  local name = GetSpellName(auraID)   -- works with spellIDs on 3.x/4.x clients
  if name and name ~= "" then return name; end
  name = GetItemInfo(auraID)
  if name then return name; end
  return ("Aura " .. tostring(auraID))
end

local function Round(amount)
  return math.floor(amount * 100 + 0.5) / 100
end

-- Resolves a unitId (or GUID) from the combat log into a plain player name.
-- Returns nil when the unit is not a known friendly raid/party member.
local function UnitNameFromCombatLog(destName, destGUID)
  local candidate = destName
  if type(candidate) == "string" then
    candidate = candidate:gsub("\"", "")   -- strip quotes from combat log names
  else
    candidate = nil
  end
  if (not candidate or candidate == "") and type(destGUID) == "string" then
    -- destName may be empty for some units; try resolving the GUID through the roster
    for i = 1, QDKP2_GetNumRaidMembers() do
      local unit = "raid" .. i
      if UnitGUID and GetUnitGUID and UnitGUID(unit) == destGUID then
        local n = GetUnitName and GetUnitName(unit)
        if n then candidate = n; break; end
      end
    end
    if not candidate and GetNumPartyMembers and GetNumPartyMembers() > 0 then
      for i = 1, GetNumPartyMembers() do
        local unit = "party" .. i
        if UnitGUID and GetUnitGUID and UnitGUID(unit) == destGUID then
          local n = GetUnitName and GetUnitName(unit)
          if n then candidate = n; break; end
        end
      end
    end
  end
  if not candidate or candidate == "" then return nil; end
  return candidate
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


----------------------------------- MAIN HANDLER -----------------------------------

-- Registers ONE application of a tracked aura on player <name>.
-- Counts the application ONLY IF:
--   * the aura ID is one of the tracked ones (default 53908 / 53909)
--   * the affected character is a guild member
--   * the character is currently present in the raid/party
function QDKP2IU_RegisterApplication(name, auraID)
  if not name or type(name) ~= "string" then return; end
  auraID = tonumber(auraID)
  if not auraID or not IsTrackedID(auraID) then return; end

  if not QDKP2_IsInGuild(name) then return; end
  if not QDKP2_IsInRaid(name) then
    QDKP2_Debug(3, "Core", "ItemUsage: " .. name .. " received a tracked aura but is not in the raid. Not counted.")
    return
  end

  QDKP2IU_Init()

  local rec = QDKP2_Data.ItemUses[name]
  if not rec then
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

--[[ Called from Core/Events.lua on every COMBAT_LOG_EVENT_UNFILTERED.
     Watches for SPELL_AURA_APPLIED / SPELL_AURA_REFRESH of the tracked auras
     landing on a friendly raid/party member, and counts each application.
     SPELL_AURA_REFRESH is handled too because consumable buff items often get
     re-applied while the previous buff is still active: the game delivers it
     as a refresh event, but it is still a NEW use of the item. ]]
function QDKP2IU_OnCombatLog(subevent, ...)
  if subevent ~= "SPELL_AURA_APPLIED" and subevent ~= "SPELL_AURA_REFRESH" then return; end
  -- after subevent: srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellID, ...
  local srcGUID, srcName, srcFlags, dstGUID, dstName, dstFlags, spellID = ...
  if not spellID then return; end
  if not IsTrackedID(spellID) then return; end

  local name = UnitNameFromCombatLog(dstName, dstGUID)
  if not name then return; end

  QDKP2IU_RegisterApplication(name, spellID)
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
