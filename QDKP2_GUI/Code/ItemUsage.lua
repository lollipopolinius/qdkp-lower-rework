-- This file is a part of QDKP_V2 (see about.txt in the core addon's root folder)

--             ## GUI MODULE ##
--        ItemUsage page (tracked items usage counters & DKP awarding)
--
-- A separate window that shows how many times each character present in the raid
-- has used the tracked items (default itemIDs: 40211 and 40212), and lets officers
-- award DKP for those uses.
-- Open it with /qdkp2 items, or from the QDKP main menu button "Item Usage".

local QDKP2IU_FRAME_NAME = "QDKP2IU_Frame"
local ROW_HEIGHT = 20
local MAX_ROWS = 30

local frame = nil
local scrollFrame = nil
local rows = {}
local perUseEditBox = nil
local statusText = nil
local headerText = nil
local totalText = nil
local sortedNames = {}


----------------------------- LOCAL HELPERS -----------------------------

local Loc = function(key)
  if QDKP2IU_LOC and QDKP2IU_LOC[key] then return QDKP2IU_LOC[key]; end
  return key
end

local function GetPerUse()
  return tonumber(perUseEditBox and perUseEditBox:GetText()) or 0
end

local function OnAwardAllClicked()
  local amount = GetPerUse()
  if amount <= 0 then
    DEFAULT_CHAT_FRAME:AddMessage(QDKP2_COLOR_YELLOW .. "QDKP2: " .. Loc("PerUse") .. "?")
    return
  end
  QDKP2IU_AwardAll(amount)
  QDKP2IU_RefreshPage()
end

local function OnResetClicked()
  StaticPopupDialogs["QDKP2IU_RESET"] = {
    text = Loc("Reset") .. "?",
    button1 = ACCEPT,
    button2 = CANCEL,
    hasEditBox = 0,
    timeout = 0,
    whileDead = 1,
    data = frame,
    OnShow = function(self) self.button1:SetText(YES); self.button2:SetText(NO); end,
    OnAccept = function()
      QDKP2IU_Reset()
      QDKP2IU_RefreshPage()
    end,
  }
  ShowPopup("QDKP2IU_RESET")
end


------------------------------ ROW RENDERING ------------------------------

local function MakeRow(index)
  local row
  if rows[index] then
    row = rows[index].frame
  else
    row = CreateFrame("Frame", QDKP2IU_FRAME_NAME .. "Row" .. index, scrollFrame)
    row:SetHeight(ROW_HEIGHT)

    row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    row.name:SetPoint("LEFT", 6, 0)
    row.name:SetWidth(150)
    row.name:SetJustifyH("LEFT")

    row.count = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    row.count:SetPoint("LEFT", row.name, "RIGHT", 10, 0)
    row.count:SetWidth(70)
    row.count:SetJustifyH("CENTER")

    row.awarded = row:CreateFontString(nil, "ARTWORK", "GameFontDisable")
    row.awarded:SetPoint("LEFT", row.count, "RIGHT", 10, 0)
    row.awarded:SetWidth(80)
    row.awarded:SetJustifyH("CENTER")

    row.pending = row:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    row.pending:SetPoint("LEFT", row.awarded, "RIGHT", 10, 0)
    row.pending:SetWidth(80)
    row.pending:SetJustifyH("CENTER")

    local btn = CreateFrame("Button", row:GetName() .. "AwardBtn", row, "UIPanelButtonTemplate")
    btn:SetWidth(60)
    btn:SetHeight(18)
    btn:SetPoint("LEFT", row.pending, "RIGHT", 8, 0)
    btn:SetText(Loc("AwardPlayer"))
    btn.index = index
    btn:SetScript("OnClick", function()
      local name = sortedNames[btn.index]
      local amount = GetPerUse()
      if not name or amount <= 0 then return; end
      QDKP2IU_AwardPlayer(name, amount)
      QDKP2IU_RefreshPage()
    end)

    local highlight = row:CreateTexture(nil, "BACKGROUND")
    highlight:SetPoint("TOPLEFT", 0, 0)
    highlight:SetPoint("BOTTOMRIGHT", 0, 0)
    if highlight.SetColorTexture then
      highlight:SetColorTexture(1, 1, 0.3, 0.15)
    else
      highlight:SetGradientAlpha("VERTICAL", 0.2, 0.2, 0.4, 0.6, 0.2, 0.2, 0.4, 0.6)
    end
    row.highlight = highlight

    rows[index] = { frame = row, button = btn }
  end
  return rows[index]
end

local function UpdateRows()
  local counts = QDKP2IU_GetRaidCounts and QDKP2IU_GetRaidCounts() or {}

  -- Build the sorted name list
  sortedNames = {}
  for name, data in pairs(counts) do
    table.insert(sortedNames, name)
  end
  table.sort(sortedNames)

  local perUse = GetPerUse()
  local shown = 0
  for i = 1, math.min(#sortedNames, MAX_ROWS) do
    local name = sortedNames[i]
    local data = counts[name]
    local row = MakeRow(i)
    row.frame:Show()
    row.frame.name:SetText(name)
    row.frame.count:SetText(tostring(data.count))
    row.frame.awarded:SetText(string.format("%.2f", data.dkpAwarded))
    local pending = math.floor((data.count * perUse - data.dkpAwarded) * 100 + 0.5) / 100
    if pending > 0 then
      row.frame.pending:SetText("|cffffd100+" .. string.format("%.2f", pending) .. "|r")
      row.button:Enable()
    else
      row.frame.pending:SetText("|cff00ff00OK|r")
      row.button:Disable()
    end
    row.frame:SetHeight(ROW_HEIGHT)
    row.frame:ClearAllPoints()
    row.frame:SetPoint("TOPLEFT", scrollFrame, "TOPLEFT", 0, -(i - 1) * ROW_HEIGHT)
    row.frame:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", 0, -(i - 1) * ROW_HEIGHT)
    if i % 2 == 0 then row.highlight:Show(); else row.highlight:Hide(); end
    shown = shown + 1
  end

  for i = shown + 1, #rows do
    rows[i].frame:Hide()
  end

  if statusText then
    if shown == 0 then
      statusText:SetText(Loc("NoData"))
    else
      statusText:SetText("")
    end
  end

  if totalText then
    local total = QDKP2IU_GetTotalUses and QDKP2IU_GetTotalUses() or 0
    totalText:SetText(Loc("Total") .. ": " .. tostring(total))
  end
end

-- Public refresh entry point (also called by the core through the ITEM_USAGE_UPDATED event)
function QDKP2IU_RefreshPage()
  if frame and frame:IsVisible() then
    UpdateRows()
  end
end


-------------------------------- THE WINDOW --------------------------------

local function CreateFrameWindow()
  if frame then return frame; end

  frame = CreateFrame("Frame", QDKP2IU_FRAME_NAME, UIParent, "DialogBoxFrame")
  frame:SetWidth(440)
  frame:SetHeight(460)
  frame:SetPoint("CENTER")
  frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
  })
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame:SetScript("OnShow", function() QDKP2IU_RefreshPage(); end)
  frame:Hide()

  -- Title
  local title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOP", 0, -22)
  title:SetText(Loc("Header"))
  headerText = title

  -- Tracked items hint line
  local itemsLine = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
  itemsLine:SetPoint("TOP", title, "BOTTOM", 0, -4)
  local ids = QDKP2IU_GetTrackedItems and QDKP2IU_GetTrackedItems() or {}
  local idstr = ""
  for i = 1, #ids do
    if i > 1 then idstr = idstr .. ", "; end
    idstr = idstr .. tostring(ids[i])
  end
  itemsLine:SetText("ItemIDs: " .. idstr)

  -- Columns header
  local colY = itemsLine
  local hName = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  hName:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -70)
  hName:SetText(Loc("Player"))
  local hCount = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  hCount:SetPoint("LEFT", hName, "RIGHT", 90, 0)
  hCount:SetText(Loc("Uses"))
  local hAwarded = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  hAwarded:SetPoint("LEFT", hCount, "RIGHT", 40, 0)
  hAwarded:SetText(Loc("Awarded"))

  -- Scroll area for rows
  scrollFrame = CreateFrame("Frame", nil, frame)
  scrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -92)
  scrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 96)

  -- Empty status
  statusText = frame:CreateFontString(nil, "ARTWORK", "GameFontDisable")
  statusText:SetPoint("TOP", scrollFrame, "TOP", 0, -20)

  -- Total line
  totalText = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  totalText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 70)

  -- DKP per use editbox
  local editLabel = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  editLabel:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 44)
  editLabel:SetText(Loc("PerUse"))

  perUseEditBox = CreateFrame("EditBox", QDKP2IU_FRAME_NAME .. "PerUse", frame, "InputBoxTemplate")
  perUseEditBox:SetWidth(50)
  perUseEditBox:SetHeight(20)
  perUseEditBox:SetPoint("LEFT", editLabel, "RIGHT", 8, 0)
  perUseEditBox:SetAutoFocus(false)
  perUseEditBox:SetNumeric(true)
  perUseEditBox:SetText(QDKP2IU_DefaultPerUse and tostring(QDKP2IU_DefaultPerUse) or "5")
  perUseEditBox:SetScript("OnEnterPressed", function(self) self:ClearFocus(); QDKP2IU_RefreshPage(); end)
  perUseEditBox:SetScript("OnTextChanged", function() QDKP2IU_RefreshPage(); end)

  -- Award all button
  local awardBtn = CreateFrame("Button", QDKP2IU_FRAME_NAME .. "AwardAllBtn", frame, "UIPanelButtonTemplate")
  awardBtn:SetWidth(130)
  awardBtn:SetHeight(22)
  awardBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -120, 40)
  awardBtn:SetText(Loc("AwardAll"))
  awardBtn:SetScript("OnClick", OnAwardAllClicked)

  -- Reset button
  local resetBtn = CreateFrame("Button", QDKP2IU_FRAME_NAME .. "ResetBtn", frame, "UIPanelButtonTemplate")
  resetBtn:SetWidth(90)
  resetBtn:SetHeight(22)
  resetBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 40)
  resetBtn:SetText(Loc("Reset"))
  resetBtn:SetScript("OnClick", OnResetClicked)

  return frame
end


----------------------------- OPEN / CLOSE API -----------------------------

function QDKP2IU_Toggle()
  local f = CreateFrameWindow()
  if f:IsVisible() then
    f:Hide()
  else
    UpdateRows()
    f:Show()
  end
end

function QDKP2IU_Open()
  local f = CreateFrameWindow()
  UpdateRows()
  f:Show()
end
