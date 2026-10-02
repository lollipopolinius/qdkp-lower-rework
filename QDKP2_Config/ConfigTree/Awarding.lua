

local L=QDKP2_Config.Localize



----------------------Helper functions---------------------------

-- Award by boss

local function GetName(info)
	local i=tonumber(info[#info]) or tonumber(info[#info-1]) --so it can work both for the group and the input types
	local v=QDKP2_Config.Profile.Boss_Names[i]
	if v then return v.name or ''
	else return '!!VOID!!'
	end
end

local function SetName(info,value)
	local i=tonumber(info[#info-1])
	QDKP2_Config.Profile.Boss_Names[i].name=value
end

local function GetBossVoice(info)
	local i=info[#info-1]
	local field
	if string.find(info[#info],'10') then field='DKP_10'
	else field = 'DKP_25'
	end
	local voice=QDKP2_Config.Profile.Boss_Names[tonumber(i)]
	return voice, field
end

local function SetCustom(info, value)
	local voice, field=GetBossVoice(info)
	voice[field]=tonumber(value)
end

local function GetCustom(info)
	local voice, field=GetBossVoice(info)
	local a=voice[field]
	if not a or a==0 then return ''
	else return tostring(a)
	end
end

local function SetSelect(info,value)
	if value==3 then SetCustom(info,"0")
	elseif value==1 then SetCustom(info, nil)
	else SetCustom(info,"1")
	end
end

local function GetSelect(info)
	local voice, field=GetBossVoice(info)
	local a=voice[field]
	if not a then return 1
	elseif a==0 then return 3
	else return 2
	end
end

local function IsDisabledCA(info)
	local a=GetCustom(info)
	if a=='' then return true; end
end

local function AddBoss(info)  
	table.insert(QDKP2_Config.Profile.Boss_Names,{name='NewEntry'})
	QDKP2_Config.AceConfigDialog:SelectGroup("QDKP_V2", Awarding,BA,ByName,tostring(#QDKP2_Config.Profile.Boss_Names))
end

local function RemoveBoss(info)
local i=info[#info-1]
	table.remove(QDKP2_Config.Profile.Boss_Names,i)
end


-- Award by instance

local function SetInstance(info,value)
	local size,i=string.match(info[#info],"Inst([%dH]+)_(%d+)")
	local field='DKP_'..size
	local voice=QDKP2_Config.Profile.Boss_Instance[tonumber(i)]
	voice[field]=tonumber(value)
end

local function GetInstance(info)
	local size,i=string.match(info[#info],"Inst([%dH]+)_(%d+)")
	local field='DKP_'..size
	local voice=QDKP2_Config.Profile.Boss_Instance[tonumber(i)]
	return tostring(voice[field] or 0)
end

local function GetInstName(info)
	local i=tonumber(string.match(info[#info],'(%d+)$'))
	local voice = QDKP2_Config.Profile.Boss_Instance[i]
	if not voice then return ''
	else return voice.name
	end
end

local function GetOrder(info)
	local i=tonumber(string.match(info[#info],'(%d+)$'))
	local o=tonumber(string.match(info[#info],'^(%d+)'))
	return i*10+o-1
end

local function GetAmountName(info)
	local t=(string.match(info[#info],'^%d([^_]+)'))
	if      t=='Inst10' then return L["Instance10"]
	elseif t=='Inst10H' then return L["Instance10H"]
	elseif t=='Inst25' then return L["Instance25"]
	elseif t=='Inst25H' then return L["Instance25H"]
	end
end

local function GetHidden(info)
	if GetInstName(info)=='' then return true; end
end


-- Award exceptions

local function GetAwPerc(info)
	local var=QDKP2_Config:GetVar(info)
	if var==true then return 1
	elseif not var then return 0
	end
	var=string.gsub(var,'%%','')
	return tonumber(var)/100 or 0
end

local function SetAwPerc(info, value)
	if value==0 then value=false
	elseif value==1 then value=true
	else value=tostring(value*100)..'%' 
	end
	QDKP2_Config:SetVar(info,value)
end

local function GetColName(info)
	local n=info[#info]
	local sys=string.match(n,'AW_%a+_(%a+)')
	local v=GetAwPerc(info)
	local col
	if v==0 then col=QDKP2_Config.Colors.Disabled
	elseif v==1 then col=QDKP2_Config.Colors.Enabled
	else col=''
	end
	return col..L['AW_'..sys]
end



-------------------- TREES ----------------------------

--main

QDKP2_Config.Tree.args.Awarding={
	type = 'group',
	--childGroups = 'tab',
	order = 1,
	args={

		--Raid award (and boss)
		BA={
			type='group',
			--childGroups = 'select',
			args={
			
			--Award by Instance
				ByInstance={
					type='group',
					order=1,
					set=SetInstance,
					get=GetInstance,
					args={
					InstHelpText={
						type = 'description',
						--fontSize='medium',
						order=1,
						},
					Spacer1=QDKP2_Config:GetBreak(2),
					},
				},
				
				--Award by Name
				ByName={
					type='group',
					order=2,
					args={
						AddNewBoss={
							type='execute',
							func=AddBoss,
							order=1,
						},
					},
				},
			},
		},
		
		--Hourly bonus
		TIM={
			type='group',
			order=2,
			args={
				AW_TIM_Period={
					type='range',
					min=6,step=6,softMax=60,max=600,
					order=1
				},
				AW_TIM_ShowAward={
					type='toggle',
					order=2,
				},
				AW_TIM_RaidLogTicks={
					type='toggle',
					order=3,
				},
			},
		},
		
		--IronMan
		IM={
			type='group',
			order=3,
			args={
				AW_IM_PercReq={
					type='range',
					min=0,bigStep=5,max=100,
					order=1,
				},
				AW_IM_InWhenStarts={
					type='toggle',
					order=2,
				},
				AW_IM_InWhenEnds={
					type='toggle',
					order=3,
				},
			},
		},
		
		--ZeroSum
		ZS={
			type='group',
			order=4,
			args={
				AW_ZS_UseAsCharge={
					type='toggle',
					order=1,
				},
				AW_ZS_GiveZS2Payer={
					type='toggle',
					order=2,
				},
			},
		},
	}
}



-- Award exceptions

local CtlHeader={
	type='header',
	order=100,
}
local order={OfflineCtl=101,ZoneCtl=102,RankCtl=103,AltCtl=104,StandbyCtl=105,ExternalCtl=106}
local CtlSlider={
	type='range',
	min=0, step=0.01, bigStep=0.05, softMax=1, max=2.55,
	isPercent=true,
	name=GetColName,
	desc=function(info) local n=info[#info]; local sys=string.match(n,'AW_%a+_(%a+)'); return L['AW_'..sys..'_d']; end,
	order=function(info) local n=info[#info]; local sys=string.match(n,'AW_%a+_(%a+)'); return order[sys]; end,
	get=GetAwPerc,
	set=SetAwPerc,
}

for i,aw in pairs(QDKP2_Config.Tree.args.Awarding.args) do
	aw.args.AW_CtlHeader=CtlHeader
	for j,sys in pairs({"Offline","Zone","Rank","Alt","Standby","External"}) do
		local name="AW_"..i.."_"..sys.."Ctl"
--		aw.args[name..'Break']=QDKP2_Config:GetBreak(i*5+99)
		aw.args[name]=CtlSlider
	end
end
	
	

	
--Award by boss

local BossVoice={
	type = 'group',
	name = GetName,
	hidden = function(info) if GetName(info)=='!!VOID!!' then return true; end; end,
	order = function(info) return tonumber(info[#info]); end,
	args = {
		BossName={
			type='input',
			set=SetName,
			get=GetName,
			pattern='.+', --no null strings.
			name=L.AW_Boss_Name,
			desc=L.AW_Boss_Name_d,
			order=10,
		},
		AW_Boss_UseTarget={
			type='execute',
			name=L.BossUseTarget,
			disabled=function(info) if not UnitName("target") then return true; end; end,
			func=function(info) SetName(info, UnitName("target")); end,
			order=12,
		},
		Break1=QDKP2_Config:GetBreak(15),
		
		Select10={
			type = 'select',
			values ={"Default instance awards","Custom amounts","No awards"},
			name = L.AW_Boss_SelectBoss10,
			desc = L.AW_Boss_SelectBoss_d,
			set=SetSelect,
			get=GetSelect,
			order=20,
		},
		CustomAmount10={
			type = 'input',
			disabled=IsDisabledCA,
			name = L.AW_Boss_CustomAmount,
			set=SetCustom,
			get=GetCustom,
			order=30,
			pattern = '^-?%d+$',
		},
		Break2=QDKP2_Config:GetBreak(35),
		
		Select25={
			type = 'select',
			values ={"Default instance awards","Custom amounts","No awards"},
			name = L.AW_Boss_SelectBoss25,
			desc = L.AW_Boss_SelectBoss_d,
			set=SetSelect,
			get=GetSelect,
			order=40,
		},
		CustomAmount25={
			type = 'input',
			disabled=IsDisabledCA,
			name = L.AW_Boss_CustomAmount,
			set=SetCustom,
			get=GetCustom,
			pattern = '^-?%d+$',
			order=50,
		},
		Break3=QDKP2_Config:GetBreak(55),
		
		RemoveBoss={
		  name=L.AW_Boss_RemoveBoss,
			type = 'execute',
			func=RemoveBoss,
			confirm=true,
			confirmText=L.Confirm,
		},
	},
}

for i=1,99 do --maximum of 99 boss names entries. Seems resonable to me.
	QDKP2_Config.Tree.args.Awarding.args.BA.args.ByName.args[tostring(i)]=BossVoice
end




--Award by instance

local InstName={
	type = 'description',
	fontSize  = 'medium',
	name = GetInstName,
	hidden = GetHidden,
	order = GetOrder,
}
local InstAmount={
	type = 'input',
	name = GetAmountName,
	width='half',
	pattern = '^-?%d+$',
	hidden = GetHidden,
	order=GetOrder,
}

for i=1,20 do --maximum of 20 instances entries.
	local tab=QDKP2_Config.Tree.args.Awarding.args.BA.args.ByInstance.args
	tab["1InstName"..tostring(i)]=InstName
	tab["2Inst10_"..tostring(i)]=InstAmount
	tab["3Inst10H_"..tostring(i)]=InstAmount
	tab["4Inst25_"..tostring(i)]=InstAmount
	tab["5Inst25H_"..tostring(i)]=InstAmount
end

