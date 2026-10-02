
local L = QDKP2_Config.Localize

local function isVinT(tab,value)
	for i,v in pairs(tab) do
		if v==value then return i; end
	end
end

local function RankList(info)
	local l={}
	local t=QDKP2_Config.Profile[info[#info]]
	for i=1,99 do
		local r=GuildControlGetRankName(i)
		local rr=r
		if not r or r=='' then break; end
		if isVinT(t,r) then rr=QDKP2_Config.Colors.Enabled..r; end
		l[r]=rr
	end
	return l
end

local function SetRankList(info,value)
	local Table=QDKP2_Config.Profile[info[#info]]
	local i=isVinT(Table,value)
	if i then table.remove(Table,i)
	else table.insert(Table,value)
	end
	QDKP2_Config:RefreshGUI()
end

function GetRankList(info) end

function GetWinTrig(info)
	local s=''
	for i,v in pairs(QDKP2_Config.Profile.MISC_DetectWinTrig) do
		if #s>1 then s=s..', '; end
		s=s..v
	end
	return s
end

function SetWinTrig(info,value)
	RunScript("QDKP2_Config_Temp."..i.."={"..value..'}')
	QDKP2_Config.Profile.MISC_DetectWinTrig=QDKP2_Config_Temp
	QDKP2_Config:ApplyVarToGlobal('MISC_DetectWinTrig')
end

QDKP2_Config.Tree.args.Misc={
	type = 'group',
	name = L.Misc,
	order = 80,
	args ={
		MISC_MaxNetDKP={
			type='input',
			pattern = '^-?%d+$',
			order=10,
		},
		MISC_MinNetDKP={
			type='input',
			pattern = '^-?%d+$',
			order=20,
		},
		MISCBreak1=QDKP2_Config:GetBreak(25),
		
		AW_SpecialRanks={
			type='select',
			set=SetRankList,
			values=RankList,
			order=30,
		},
		MISC_HidRanks={
			type='select',
			set=SetRankList,
			values=RankList,
			order=40,
		},
		MISC_MinLevel={
			type='range',
			min=1,step=1,max=85,
			set=function(info,value) QDKP2_Config:SetVar(info,value); QDKP2_Config:RefreshGUI(); end,
			order=50,
		},
		MISCBreak2=QDKP2_Config:GetBreak(55),
		
		MISC_PromptWinDetect={
			type='toggle',
			order=60,
		},
		MISC_DetectWinTrig={
			type='input',
			get=GetWinTrig,
			set=SetWinTrig,
			width='double',
			order=70,
		},
		MISCUploadHeader={
			type='header',
			order=80,
		},
		MISC_UploadOn_Raid={
			type='toggle',
			order=90,
		},
		MISC_UploadOn_Tick={
			type='toggle',
			order=100,
		},
		MISC_UploadOn_Hourly={
			type='toggle',
			order=110,
		},
		MISC_UploadOn_IronMan={
			type='toggle',
			order=120,
		},
		MISC_UploadOn_Payment={
			type='toggle',
			order=130,
		},
		MISC_UploadOn_Modif={
			type='toggle',
			order=140,
		},
		MISC_UploadOn_ZS={
			type='toggle',
			order=150,
		},
		MISCLogHeader={
			type='header',
			order=160,
		},
		LOG_MaxRaid={
			type='range',
			min=1,step=1,softMax=200,max=1000,
			order=170,
		},
		LOG_MaxPlayer={
			type='range',
			min=1,step=1,softMax=200,max=1000,
			order=180,
		},
		LOG_MaxSession={
			type='range',
			min=1,step=1,softMax=100,max=1000,
			order=190,
		},
		MISCInfHeader={
			type='header',
			order=200,
		},
		MISC_Inf_WentNeg={
			type='toggle',
			order=210,
		},
		MISC_Inf_IsNeg={
			type='toggle',
			order=220,
		},
		MISC_Inf_NewMember={
			type='toggle',
			order=230,
		},
		MISC_Inf_NoInGuild={
			type='toggle',
			order=240,
		},
		MISCTextHeader={
			type='toggle',
			order=250,
		},
		MISC_Report_Header={
			type='input',
			width='full',
			order=260,
		},
		MISC_Report_Tail={
			type='input',
			width='full',
			order=270,
		},
		MISC_Export_Header={
			type='input',
			width='full',
			order=280,
		},
		MISC_NotifyText={
			type='input',
			width='full',
			order=290,
		},
		MISC_NotifyText3rd={
			type='input',
			width='full',
			order=300,
		},
		MISC_TimeInHours={
			type='range',
			min=1,step=1,max=24,
			order=310,
		},
		MISC_TimeInDOW={
			type='range',
			min=1,step=1,max=7,
			order=320,
		},
		MISC_TimeZoneCtl={
			type='input',
			order=330,
			set=function(info,value) value=tonumber(value); QDKP2_Config:SetVal(info,value); end,
			get=function(info) value=QDKP2_Config:GetVar(info); value=tostring(value or ''); return value; end,
		},
	},
}