-- Copyright 2010 Riccardo Belloli (belloli@email.it)
-- This file is a part of QDKP_V2 (see about.txt in the Addon's root folder)

--             ## CORE MODULE ##
--              Tracked Items Usage Counter (QDKP2_ItemUsage)
--
--      Separate module that counts how many times guild characters which are
--      present in the raid have used (looted and consumed) items with certain
--      item IDs. Default tracked IDs: 40211 and 40212.
--      The counters are stored in the persistent database (per guild), so they
--      survive between raids, sessions and /reloads.
--
-- API Documentation:
-- QDKP2IU_TrackItem(itemID)            -- starts tracking the given item ID
-- QDKP2IU_UntrackItem(itemID)          -- stops tracking the given item ID
-- QDKP2IU_SetTrackedItems(list)        -- replaces the tracked items list ("40211, 40212" style string or table)
-- QDKP2IU_GetTrackedItems()            -- returns the sorted list of tracked item IDs
-- QDKP2IU_IsTracked(itemID)            -- true if the given item ID is tracked
-- QDKP2IU_RegisterUse(name, itemLink)  -- registers one use of the item <itemLink> by player <name>. Returns true if counted.
-- QDKP2IU_GetCount(name, [itemID])     -- uses count for <name> (total, or for a specific itemID)
-- QDKP2IU_GetTotalUses([itemID])       -- total number of tracked items used in the raid (all players)
-- QDKP2IU_GetRaidCounts()              -- returns a dictionary {name = {count=, dkpAwarded=}} of everyone with recorded uses
-- QDKP2IU_AwardAll(dkpPerUse)          -- awards dkpPerUse DKP for every non-awarded use of every tracked item
-- QDKP2IU_AwardPlayer(name, dkpPerUse) -- awards dkpPerUse DKP for every non-awarded use of <name>
-- QDKP2IU_Reset([name])                -- resets counters (of <name> only, or all of them)


------------------------------- CONSTANTS & DEFAULTS -------------------------------

-- Items we track by default (40211 / 40212)
QDKP2IU_DEFAULT_ITEMS = { 40211, 40212 }

-- How many times each tracked item can be used per raid encounter (for the "remaining uses" hint in the GUI)
QDKP2IU_USES_PER_BOSS = 1

-- Localized strings (fallbacks; overwritten by Local/enGB|ruRU|frFR.lua if loaded later)
QDKP2IU_LOC = QDKP2IU_LOC or {
  Header      = "Tracked items usage",
  NoData      = "No tracked item has been used yet.",
  Player      = "Player",
  Uses        = "Uses",
  Awarded     = "DKP awarded",
  Total       = "Total uses",
  PerUse      = "DKP per use",
  AwardAll    = "Award all pending",
  AwardPlayer = "Award",
  Reset       = "Reset counters",
  NotOfficer  = "You need officer rights to award DKP.",
  NothingPay  = "There are no pending DKP awards for tracked items.",
  AwardedMsg  = "$NAME received $DKP DKP for $N uses of tracked items.",
  Registered  = "Tracked item used by $NAME ($ITEM)",
}


--------------------------------- LOCAL HELPERS ---------------------------------

local function IsTrackedID(itemID)
  local list = QDKP2_Data.TrackedItems
  if not list then return false; end
  for i = 1, #list do
    if list[i] == itemID then return true; end
  end
  return false
end

local function GetItemIDFromLink(link)
  if type(link) ~= "string" then return nil; end
  local _, _, itemID = string.find(link, "Hitem:(%d+)")
  return tonumber(itemID)
end

local function ItemDisplayName(itemID)
  local name = GetItemInfo(itemID)
  return name or ("Item " .. tostring(itemID))
end

local function Round(amount)
  return math.floor(amount * 100 + 0.5) / 100
end


----------------------------- DATABASE INITIALIZATION -----------------------------

-- Called on CHAT_MSG_SYSTEM (Guild Roster request) from Events.lua, when the
-- persistent database is already loaded. Guarantees our fields exist.
function QDKP2IU_Init(force)
  if not QDKP2_Data then return; end

  if not QDKP2_Data.TrackedItems or force then
    QDKP2_Data.TrackedItems = {}
    for i = 1, #QDKP2IU_DEFAULT_ITEMS do
      table.insert(QDKP2_Data.TrackedItems, QDKP2IU_DEFAULT_ITEMS[i])
    end
  end

  if not QDKP2_Data.ItemUses then
    QDKP2_Data.ItemUses = {}   -- [Name] = { ["id"] = uses, ["dkp"] = dkp already awarded }
  end
end


-------------------------------- TRACKED ITEMS LIST --------------------------------

function QDKP2IU_IsTracked(itemID)
  return IsTrackedID(tonumber(itemID))
end

function QDKP2IU_GetTrackedItems()
  local list = {}
  if QDKP2_Data and QDKP2_Data.TrackedItems then
    for i = 1, #QDKP2_Data.TrackedItems do
      table.insert(list, QDKP2_Data.TrackedItems[i])
    end
  end
  table.sort(list)
  return list
end

function QDKP2IU_TrackItem(itemID)
  itemID = tonumber(itemID)
  if not itemID then return; end
  QDKP2IU_Init()
  if IsTrackedID(itemID) then return; end
  table.insert(QDKP2_Data.TrackedItems, itemID)
  QDKP2_Msg(QDKP2_COLOR_BLUE .. "QDKP2: Now tracking item ID " .. itemID)
end

function QDKP2IU_UntrackItem(itemID)
  itemID = tonumber(itemID)
  if not itemID or not QDKP2_Data or not QDKP2_Data.TrackedItems then return; end
  for i = 1, #QDKP2_Data.TrackedItems do
    if QDKP2_Data.TrackedItems[i] == itemID then
      table.remove(QDKP2_Data.TrackedItems, i)
      QDKP2_Msg(QDKP2_COLOR_BLUE .. "QDKP2: Stopped tracking item ID " .. itemID)
      return
    end
  end
end

-- Accepts a comma separated list of item ids ("40211, 40212") or a table of numbers
function QDKP2IU_SetTrackedItems(list)
  local new = {}
  if type(list) == "string" then
    for id in string.gfind(list, "%d+") do
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

function QDKP2IU_GetCount(name, itemID)
  if not name or not QDKP2_Data or not QDKP2_Data.ItemUses then return 0; end
  local rec = QDKP2_Data.ItemUses[name]
  if not rec then return 0; end
  if itemID then
    return rec["i" .. tonumber(itemID)] or 0
  end
  return rec["id"] or 0
end

function QDKP2IU_GetAwardedDKP(name)
  if not name or not QDKP2_Data or not QDKP2_Data.ItemUses then return 0; end
  local rec = QDKP2_Data.ItemUses[name]
  return (rec and rec["dkp"]) or 0
end

function QDKP2IU_GetTotalUses(itemID)
  local total = 0
  if QDKP2_Data and QDKP2_Data.ItemUses then
    for name, rec in pairs(QDKP2_Data.ItemUses) do
      if itemID then
        total = total + (rec["i" .. tonumber(itemID)] or 0)
      else
        total = total + (rec["id"] or 0)
      end
    end
  end
  return total
end

-- Returns { [Name] = { count = n, dkpAwarded = x } } for all players with recorded uses
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

-- Called from Core/Loot.lua (QDKP2_OnLoot) whenever a loot is detected.
-- Counts the use ONLY IF:
--   * the item ID is one of the tracked ones (default 40211 / 40212)
--   * the looting character is a guild member
--   * the character is currently present in the raid/party
function QDKP2IU_RegisterUse(name, item)
  if not name or type(name) ~= "string" then return; end
  local itemID = GetItemIDFromLink(item)
  if not itemID or not IsTrackedID(itemID) then return; end

  if not QDKP2_IsInGuild(name) then return; end
  if not QDKP2_IsInRaid(name) then
    QDKP2_Debug(3, "Core", "ItemUsage: " .. name .. " used a tracked item but is not in the raid. Not counted.")
    return
  end

  QDKP2IU_Init()

  local rec = QDKP2_Data.ItemUses[name]
  if not rec then
    QDKP2_Data.ItemUses[name] = {}
    rec = QDKP2_Data.ItemUses[name]
  end

  rec["id"] = (rec["id"] or 0) + 1
  rec["i" .. itemID] = (rec["i" .. itemID] or 0) + 1

  QDKP2_Debug(2, "Core", "ItemUsage: counted use #" .. rec["id"] .. " of item " .. itemID .. " by " .. name)

  local msg = QDKP2IU_LOC.Registered
  msg = string.gsub(msg, "$NAME", name)
  msg = string.gsub(msg, "$ITEM", ItemDisplayName(itemID))
  QDKP2_Msg(QDKP2_COLOR_YELLOW .. msg)

  QDKP2_Events:Fire("ITEM_USAGE_UPDATED", name, itemID)
  -- Auto-refresh the ItemUsage GUI page (if loaded and visible)
  if QDKP2IU_RefreshPage then QDKP2IU_RefreshPage(); end
  return true
end


------------------------------------ AWARDS ------------------------------------

--[[ Awards DKP for all the pending (not yet awarded) tracked-item uses.
     dkpPerUse: DKP amount given for each single use.
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
        local reason = string.format("Tracked items used: %d x %.2f DKP", data.count, dkpPerUse)
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
