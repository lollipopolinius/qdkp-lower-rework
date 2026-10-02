
local L = QDKP2_Config.Localize

local Qualities={}
Qualities[0]=ITEM_QUALITY_COLORS[0].hex..ITEM_QUALITY0_DESC --poor
Qualities[1]=ITEM_QUALITY_COLORS[1].hex..ITEM_QUALITY1_DESC --common
Qualities[2]=ITEM_QUALITY_COLORS[2].hex..ITEM_QUALITY2_DESC --uncommon
Qualities[3]=ITEM_QUALITY_COLORS[3].hex..ITEM_QUALITY3_DESC --rare
Qualities[4]=ITEM_QUALITY_COLORS[4].hex..ITEM_QUALITY4_DESC --epic
Qualities[5]=ITEM_QUALITY_COLORS[5].hex..ITEM_QUALITY5_DESC --legendary

local function AddItem(info)
	table.insert(QDKP2_Config.Profile.LOOT_Items,{name='NewItem'})
	QDKP2_Config.AceConfigDialog:SelectGroup("QDKP_V2", 'Looting','LOOTPriceItem',tostring(#(QDKP2_Config.Profile.LOOT_Items)))
end


QDKP2_Config.Tree.args.Looting={
	type = 'group',
	order=70,
	args ={
		LOOTOptions={
			type='group',
			order=1,
			args={
				LOOTQualTresh={
					type='header',
					order=1,
				},
				LOOT_Qual_RaidLog={
					type='select',
					values=Qualities,
					order=2,
				},
				LOOT_Qual_PlayerLog={
					type='select',
					values=Qualities,
					order=3,
				},
				LOOT_Qual_ChargeKey={
					type='select',
					values=Qualities,
					order=4,
				},
				LOOT_Qual_ChargeChat={
					type='select',
					values=Qualities,
					order=5,
				},
				LOOT_Qual_ReasonHist={
					type='select',
					values=Qualities,
					order=6,
				},
				LOOT_Qual_PopupTB={
					type='select',
					values=Qualities,
					order=7,
				},
				LOOTSettingsHeader={
					type='header',
					order=10,
				},
				LOOT_OpenToolbox={
					type='toggle',
					order=11,
				},
				LOOT_LogBadge={
					type='toggle',
					order=12,
				},
				LOOT_LogDisench={
					type='toggle',
					order=13,
				},
			},
		},
		LOOTPriceInst={
			type='group',
			order=2,
			args={
				--AddInst={
				--},
			},
		},
		LOOTPriceItem={
			type='group',
			order=3,
			args={
				LOOT_Item_Add={
					type='execute',
					func=AddItem,
					order=10,
				},
			},
		},
	},
}
local function GetItemVoice(info)
	local i=tonumber(info[#info-1])
	return QDKP2_Config.Profile.LOOT_Items[i]
end

local function GetItemName(info)
	local i=tonumber(info[#info]) or tonumber(info[#info-1])
	local v=QDKP2_Config.Profile.LOOT_Items[i]
	if v then return v.name
	else return ''
	end
end

local function SetItemName(info,value)
	local v=GetItemVoice(info)
	v.name=value
	QDKP2_Config:UpdateItemTables()
end

local function GetItemOrder(info)
	local i=tonumber(info[#info])
	return i*10+100
end

local function GetItemSelectP(info)
	local v=GetItemVoice(info)
	if not v.price then return 1
	elseif v.price==0 then return 3
	else return 2
	end
end

local function SetItemSelectP(info,value)
	local v=GetItemVoice(info)
	if value==3 then v.price=0
	elseif value==1 then v.price=nil
	else v.price=1
	end
	QDKP2_Config:UpdateItemTables()
end

local function GetItemCustomP(info)
	local v=GetItemVoice(info)
	if not v.price or v.price==0 then return ''
	else return v.price
	end
end

local function SetItemCustomP(info,value)
	local v=GetItemVoice(info)
	v.price=value
	QDKP2_Config:UpdateItemTables()
end
	
local function GetNotifyLoot(info)
	local v=GetItemVoice(info)
	if not v.log then return 2
	else return v.log
	end
end

local function SetNotifyLoot(info,value)
	local v=GetItemVoice(info)
	if value==2 then value=nil;end
	v.log=value
	QDKP2_Config:UpdateItemTables()
end

local function CancItem(info)
	local i=tonumber(info[#info-1])
	table.remove(QDKP2_Config.Profile.LOOT_Items,i)
end
	
local ItemVoice={
	type='group',
	name=GetItemName,
	hidden=function(info) if GetItemName(info)=='' then return true; end; end,
	order=GetItemOrder,
	args={
		LOOT_Item_Name={
			type='input',
			pattern='.+', --no null strings.
			get=GetItemName,
			set=SetItemName,
			order=10,
		},
		Break1=QDKP2_Config:GetBreak(20),
		
		LOOT_Item_SelectP={
			type='select',
			get=GetItemSelectP,
			set=SetItemSelectP,
			values={"Default by instance","Custom value","No fixed price"},
			order=30,
		},
		LOOT_Item_CustomP={
			type='input',
			disabled=function(info) if GetItemSelectP(info)~=2 then return true; end; end,
			pattern = '^-?%d+$',
			get=GetItemCustomP,
			set=SetItemCustomP,
			order=40,
		},
		Break2=QDKP2_Config:GetBreak(50),
		
		LOOT_Item_NotifyLoot={
			type='select',
			get=GetNotifyLoot,
			set=SetNotifyLoot,
			order=50,
			values={"Prevent logging","Default","Force logging","Logging+Message","Logging+Warning"},
		},
		Break2=QDKP2_Config:GetBreak(70),
		
		LOOT_Item_Cancel={
			type='execute',
			func=CancItem,
			order=80,
		},
	},
}

for i=1,99 do
	QDKP2_Config.Tree.args.Looting.args.LOOTPriceItem.args[tostring(i)]=ItemVoice
end



	