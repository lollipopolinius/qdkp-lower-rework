
local L=QDKP2_Config.Localize

local function SetVar(info,value)
	QDKP2_Config:SetVar(info,value)
	QDKP2_Config:RefreshGUI()
end

local GetVar_Col=function(info)
	local varname = info[#info] 
	local c=QDKP2_Config.Profile[varname]
	return c.r, c.g, c.b, c.a
end

local SetVar_Col=function(info,v1,v2,v3,v4,...)
	local v={r=v1,g=v2,b=v3,a=v4}
	local varname = info[#info] 
	QDKP2_Config.Profile[varname]=v
	QDKP2_Config:ApplyVarToGlobal(varname) --this line can be removed when	QDKP will use the profile-based configure system
	QDKP2_Config:RefreshGUI()
end
	

local function TrueIfClassBased()
	return QDKP2_Config.Profile.GUI_ClassBased
end

QDKP2_Config.Tree.args.GUI={
	type = 'group',
	order = 10,
	set = SetVar_Col,
	get = GetVar_Col,
	args = {
		Roster={
			type = 'header',
			order = 10,
		},
		GUI_ClassBased={
			type = 'toggle',
			get='GetVar',
			set=SetVar,
			order = 20,
		},
		GUI_DefaultColor={
			type = 'color',
			disabled = TrueIfClassBased,
			order = 30,
		},
		GUI_ModifiedColor={
			type = 'color',
			disabled = TrueIfClassBased,
			order = 40,
		},
		GUI_StandbyColor={
			type = 'color',
			disabled = TrueIfClassBased,
			order = 50,
		},
		GUI_AltColor={
			type = 'color',
			disabled = TrueIfClassBased,
			order = 60,
		},
		GUI_ExtColor={
			type = 'color',
			disabled = TrueIfClassBased,
			order = 70,
		},
		GUI_NoGuildColor={
			type = 'color',
			disabled = TrueIfClassBased,
			order = 80,
		},
		GUI_NoClassColor={
			type = 'color',
			disabled = function() if not TrueIfClassBased() then return true; end; end,
			order = 80,
		},
		----------------------------
		Log={
			type = 'header',
			order = 100,
		},
	},
}