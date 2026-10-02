
local L = QDKP2_Config.Localize


QDKP2_Config.Tree={
	type = 'group',
	name = L.QDKP2,
	childGroups = 'tab',
	get='GetVar', --Default getter, reads self.Profile using the voice name as index
	set='SetVar', --Default setter, sets passed value to self.Profile[] using the voice name as index
	handler=QDKP2_Config,
	icon = "Interface\\Addons\\QDKP2_GUI\\Arts\\Logo.tga",
	args = {},
}

QDKP2_Config.BlizTree={
	type = 'group',
	name = L.QDKP2,
	handler=QDKP2_Config,
	icon = "Interface\\Addons\\QDKP2_GUI\\Arts\\Logo.tga",
	args = {
		Button={
			type = 'execute',
			name="Open config window",
			func='OpenDialog',
			handler=QDKP2_Config,
		},
	},
}

local function ApplyNamesDesc_(key, voice)
	if type(voice)=='table' and voice.type then
		if not voice.name then voice.name=L[key]; end
		local desc=L[key..'_d']
		if not voice.desc and desc~=key..'_d' then voice.desc=desc; end
		if voice.args then foreach(voice.args, ApplyNamesDesc_); end
	end
end

function QDKP2_Config:ApplyNameDesc()
--this applies the proprietes "name" and "desc" to every editing voice with localization in the options tree
	ApplyNamesDesc_('', QDKP2_Config.Tree)
end
