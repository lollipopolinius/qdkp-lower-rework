
local L = QDKP2_Config.Localize

local Channels={GUILD="Guild", RAID="Raid", PARTY="Party", GROUP="Group", RAID_WARNING="Raid Warning", OFFICER="Officer", BATTLEGROUND="Battleground", SAY="Say" , YELL="Yell"}
local ChannelsPers={GUILD="Guild", RAID="Raid", PARTY="Party", GROUP="Group", RAID_WARNING="Raid Warning", OFFICER="Officer", BATTLEGROUND="Battleground", SAY="Say" , YELL="Yell", WHISPER='Whisper to player', BID="Same channel"}

----------------------- Helper functions -------------------------------

local function AddKeyword(info)
	local n={keywords="New Keyword"}
	table.insert(QDKP2_Config.Profile.BM_Keywords,n)
	QDKP2_Config.AceConfigDialog:SelectGroup("QDKP_V2",'BidManager','BidKeywords',tostring(table.getn(QDKP2_Config.Profile.BM_Keywords)))
end

local function DelKeyword(info)
	local i=tonumber(info[#info-1])
	table.remove(QDKP2_Config.Profile.BM_Keywords,i)
end

local function SetPreset(info,value)
	QDKP2_Config.Profile.BM_Keywords={}
	for i,v in pairs(QDKP2_Config.KeywordPresets[value].keys) do
		local s={}
		for j,w in pairs(v) do s[j]=w; end
		QDKP2_Config.Profile.BM_Keywords[i]=s
	end
	QDKP2_Config:ApplyVarToGlobal('BM_Keywords') 
end

local function GetPreset(info)
  local kw=QDKP2_Config:Serialize(QDKP2_Config.Profile.BM_Keywords)
	for key,ps in pairs(QDKP2_Config.KeywordPresets) do
	  local pres=QDKP2_Config:Serialize(ps.keys)
	  if kw==pres then return key; end
	end
	return "CUSTOM" --return the "custom" voice if no other matched.
end

local function GetKWField(info)
	local i=tonumber(info[#info]) or tonumber(info[#info-1])  --so it can work both for the group and the input types
	local field=info[#info]
	if tonumber(field) then field='keywords'; end
	local v=QDKP2_Config.Profile.BM_Keywords[i]
	if v then return v[field] or ''
	else return '!!VOID!!'
	end
end

local function SetKWField(info,value)
	local i=tonumber(info[#info-1])
	local field=info[#info]
	local v=QDKP2_Config.Profile.BM_Keywords[i]
--	if string.gsub(value,'%s','')=='' then value=false; end --on void string or only whitespaces set to false. Not nil or AceDB will mess things up.
	if string.gsub(value,'%s','')=='' then value=nil; end
	if v then v[field]=value; end
end
	
local function TestKey(info)
	local i=tonumber(info[#info-1])
	local voice=QDKP2_Config.Profile.BM_Keywords[i]
	for i,v in pairs(voice) do
		if v and i~='keywords' and v~='' then 
			v=string.gsub(v,"$lowerbid1",'10')
			v=string.gsub(v,"$higherbid1",'100')
			v=string.gsub(v,"$ranknum1",'3')
			v=string.gsub(v,"$rank1",'Officer')
			v=string.gsub(v,"$name1",'Boboo')
			v=string.gsub(v,"$class1",'Hunter')--That's an hunter weapon. No matter what.
			v=string.gsub(v,"$lowerbid2",'15')
			v=string.gsub(v,"$higherbid2",'80')
			v=string.gsub(v,"$ranknum2",'5')
			v=string.gsub(v,"$rank2",'Member')
			v=string.gsub(v,"$name2",'Unz')
			v=string.gsub(v,"$class2",'Warrior')
			v=string.gsub(v,"$net",'200')
			v=string.gsub(v,"$total",'1000')
			v=string.gsub(v,"$spent",'800')
			v=string.gsub(v,"$roll",'45')
			v=string.gsub(v,"$vroll",'45')
			v=string.gsub(v,"$minbid",'10')
			v=string.gsub(v,"$mintowin",'81')
			v=string.gsub(v,"$name",'Boboo')
			v=string.gsub(v,"$isinguild",'true')
			v=string.gsub(v,"$isexternal",'false')
			v=string.gsub(v,"$isalt",'false')
			v=string.gsub(v,"$ranknum",'3')
			v=string.gsub(v,"$rank",'Officer')
			v=string.gsub(v,"$class",'Hunter')
			v=string.gsub(v,"$itemtype",'Weapon')
			v=string.gsub(v,"$itemsubtype",'Two-Handed Axe')
			v=string.gsub(v,"$itemrarity",'4')
			v=string.gsub(v,"$itemlevel",'300')
			v=string.gsub(v,"$itemstackcount",'1')
			v=string.gsub(v,"$itemequiploc",'Weapon')
		--	v=string.gsub(v,"$itemprice",)
			v=string.gsub(v,"$item",'Axe of Uberness')
			v=string.gsub(v,"$n",'80')
			local Exec,value
			if string.sub(v,1,9)=='function ' then Exec,value=loadstring(string.sub(v,10))
			else Exec,value=loadstring("return "..v)
			end
			if not Exec then 
				QDKP2_Msg('Error compiling '..i..' field.\n'..value, 'ERROR')
				return
			end
			local callStat; callStat, value= pcall(Exec)
			if not callStat then
				QDKP2_Msg('Error executing '..i..' field.\n'..value,'ERROR')
				return
			end
		end
	end
	QDKP2_Msg('Keyword succesfully tested!')
end



---------------------- Trees -----------------------------


--main
QDKP2_Config.Tree.args.BidManager={
	type = 'group',
	childGroups = 'tab',
	order=30,
	args ={
		BidOptions={
			type = 'group',
			order = 10,
			args={
				BiddingOptionHeader={
					type = 'header',
					order = 10,
				},
				BM_AllowMultiple={
					type = 'toggle',
					order = 20,
				},
				BM_AllowLesser={
					type = 'toggle',
					order = 30,
				},
				BM_OverBid={
					type = 'toggle',
					order = 40,
				},
				BM_GiveToWinner={
				 type = 'toggle',
				 order = 45,
				},
				BM_TestBets={
					type = 'toggle',
					order = 50,
				},
				BM_OutGuild={
					type = 'toggle',
					order = 60,
				},
				BM_CatchRolls={
					type = 'toggle',
					order = 65,
				},
				BM_AutoRoll={
					type = 'toggle',
					order = 70,
				},
				Break16=QDKP2_Config:GetBreak(75),
				
				BM_MinBid={
					type = 'input',
					pattern = '^-?%d+$',
					order = 80,
				},   
				BM_MaxBid={
					type = 'input',
					pattern = '^-?%d+$',
					order = 90,
				},
				AnnouceHeaders={
					type = 'header',
					order = 1000,
				},
				BM_AnnounceStart={
					type = 'toggle',
					order = 1010,
				},
				BM_AnnounceStartChannel={
					type = 'select',
					values = Channels,
					order = 1020,
					style = 'dropdown',
					desc = L.BM_AnnounceChannel_d,
				},
				BM_AnnounceStartText={
					type = 'input',
					width = 'full',
					order = 1030,
				},
				BM_AnnounceWinner={
					type = 'toggle',
					order = 1040,
				},
				BM_ConfirmWinner={
					type='toggle',
					order = 1045,
				},
				BM_AnnounceWinnerChannel={
					type = 'select',
					values = Channels,
					order = 1050,
					style = 'dropdown',
					desc = L.BM_AnnounceChannel_d,
				},
				BM_AnnounceWinnerDKPText={
					type = 'input',
					width = 'full',
					order = 1060,
				},
				BM_AnnounceWinnerText={
					type = 'input',
					width = 'full',
					order =1070,
				},
				BM_AnnounceCancel={
					type = 'toggle',
					order =1080,
				},
				BM_AnnounceCancelChannel={
					type = 'select',
					values = Channels,
					order = 1090,
					style = 'dropdown',
					desc = L.BM_AnnounceChannel_d,
				},
				BM_AnnounceCancelText={
					type = 'input',
					width = 'full',
					order = 1100,
				},
				BM_Countdown={
					type = 'toggle',
					order = 1110,
				},
				BM_CountdownChannel={
					type = 'select',
					values = Channels,
					order = 1120,
					style = 'dropdown',
					desc = L.BM_AnnounceChannel_d,
				},
				BM_CountdownLen={
					type = 'range', min = 1, step = 1, max = 10,
					order = 1130,
				},
				Break8=QDKP2_Config:GetBreak(1140),

				BM_AckBets={
					type = 'toggle',
					order = 1150,
				},
				BM_AckBetsChannel={
					type = 'select',
					order = 1155,
					values = ChannelsPers,
					style = 'dropdown',
					desc = L.BM_AckChannel_d,
				},
				Break7=QDKP2_Config:GetBreak(1157),
				
				BM_AckReject={
					type = 'toggle',
					order = 1160,
				},
				BM_AckRejectChannel={
					type = 'select',
					order = 1165,
					values = ChannelsPers,
					style = 'dropdown',
					desc = L.BM_AckChannel_d,
				},				
				MiscHeader={
					type = 'header',
					order = 1170,
				},
				BM_GetWhispers={
					type = 'toggle',
					order = 1180,
				},
				BM_GetGroup={
					type = 'toggle',
					order = 1190,
				},
				BM_HideWhisp={
					type = 'toggle',
					order = 1200,
				},
				BM_LogBets={
					type = 'toggle',
					order = 1210,
				},
				BM_RoundValue={
					type = 'toggle',
					order = 1220,
				},
			},
		},
		BidKeywords={
			type='group',
			order=20,
			args={
				DefaultKWProfile={
					type='select',
					get=GetPreset,
					set=SetPreset,
					confirm=function(info) if GetPreset(info)=="CUSTOM" then return L.DefaultKWProfile_c; else return false; end; end,
					order=10,
				},
				ProfileDesc={
					type='description',
					name=function(info) local i=GetPreset(info); return QDKP2_Config.KeywordPresets[i].description; end,
					order=20,
				},
				AddNewKeyword={
					type='execute',
					func=AddKeyword,
					order=30,
				},
			},
		},
	},
}


QDKP2_Config.KeywordPresets={
--not localized yet

--SIMPLE BIDDING
	A={
		name = 'Simple Bidding',
		description=
'A simple bidding system. Every guild player can place bets regardless of rank, class or anything, and the winner is charged by the plain bet amount (if any).This bidding system can also be used when loot council is used, as it will import "need" and "greed" words as 0 dkp bets.\
To place bets, players have simply to say a number ("bid #" and "need #" will work, too). Players can place default bets by saying "all" or "all in", and that will place all the DKP they have, "half" that will place half that amount, and "min" will place the minimum set bid amount.',
		keys={
			{keywords="need,greed"},
			{keywords="$n,bid $n,need $n"},
			{keywords="half", value="$net/2"},
			{keywords="all,max,all in",value="$net"},
			{keywords="min,minimum",value="$minbid"},
		},
	},
	
--SPEND ONE MORE
	B={
		name = 'Spend one more ',
		description=
'In this bidding system the winner is not necessarly charged for the full amount he bet, but only for the strict amount needed to win, and that is the amount bet by the second highest bidder plus 1, or the minimum bid if no one else is bidding.\
The bid value will be the full bet amount, so you can still sort by value to get the winner, and the DKP amount to charge the winner for will be calculated as the bidding is closed.\
The keywords used in this template are the same used in the simple bidding. To place bets, players have simply to say a number ("bid #" and "need #" will work, too)  Players can place default bets by saying "all" or "all in", and that will place all the DKP they have, "half" that will place half that amount, and "min" will place the minimum set bid amount.',
		keys={
			{keywords="need,greed"},
			{keywords="$n,bid $n,need $n", value="$n", dkp="$mintowin"},
			{keywords="half", value="$net/2", dkp="$mintowin"},
			{keywords="all,max,all in",value="$net",  dkp="$mintowin"},
			{keywords="min,minimum",value="$minbid",  dkp="$mintowin"},
		},
	},

--FIXED STEPS	
	C={	
		name = 'Fixed steps',
		description=
'Every bet made in this bidding system must be greater than the curret highest one by a fixed amount. It can speedup bid process whenever you have multiple public bets and your members increase their bet one by one to the point it becomes tedious.\
To place bets, players have simply to say a number, but "bid #" and "need #" will work, too. By saying "bid", a player will place an automatic bet that is one step above the current highest one, or the minimum bet if no other bet are placed.\
The step used in this template is 10, but you can modify it to whatever amount you like, just make sure to change it everywhere in the keywords.',
		keys={
			{keywords="$n, bid $n, need $n", min="($higherbid1 or ($minbid-10))+10"},
			{keywords="all,max,all in",value="$net",  dkp="$mintowin"},
			{keywords="bid", value="($higherbid1 or ($minbid-10))+10"},
		},
	},

--ROLL INFLUENCED
	D={
		name = 'Roll influenced',
		description=
'Some people finds DKP bidding systems to be too much predictable or even boring, up to the point that some guild drops it. For those guilds, a roll influenced bet can bring back the thrill they seek for. In this looting system the DKP amount or a bet is modified by a roll so that one can win an item even if he placed less DKP than someone else.\
In this template, players can place a bid as normal. The bet is then modified by a coefficent that is one if the roll is 0 and tops 3 if the roll is 100. That way a player gan get his bet DKP amount triplicated with a lucky roll. If the player has /rolled before placing a bet then its roll will be used, else QDKP will do an internal 1-100 roll (if "Auto Roll" is enabled in the general bidding options).\
The keywords used are the same as in the simple bidding system.',
		keys={
			{keywords="$n,bid $n,need $n" ,value="(1+$roll*2/100)*$n", dkp="$n"},
			{keywords="all,max,all in" ,value="(1+$roll*2/100)*$net", dkp="$net"},
			{keywords="min,minimum" ,value="(1+$roll*2/100)*$minbid", dkp="$minbid"},
			{keywords="half", value="(1+$roll*2/100)*$net/2", dkp="$net/2"},
		},
	},
	
--EP/GP RATIO
	E={
		name = 'EP/GP Ratio',
		description=
'In a relational DKP looting system the number used to decide who loots is not the absolute amount of net DKP the player has, but the ratio between so-called Effort Points (EP, in QDKP this is the total DKP amount) and Gear Points (GP, and those are the spent DKP). When two or more players want the same item, their EP/GP ratio is confronted and the item is given to the player with the highest.\
The main advantage is that it still allow hardcore members to gain first pick most of the time, but will give less frequent raid members a fair chance too.\
It should be noted that this looting system only works with fixed prices. To get precise ratios, you will need to uncheck "Round values" in the general bidding options.\
This implementation will acquire "need", "offspec" and /rolls and will show the Total/Spent ratio as value.\
',
		keys={
			{keywords="need, offspec, /roll", value="$total/$spent"},
		},
	},

--ROLL+NET
	F={
		name = 'Roll+Net',
		description=
"The roll+net bidding system is a simple system where the bet value is calculated as the sum between net DKP and a roll. Has the advantage to be quick and easy like a roll but still advantage the players who raid more.\
If you use this system, you'll want to set a maximum net DKP cap for your members. The standard setting should be 100, you can then adjust it to give more weight to the roll or to the DKP.\
In this implementation, the winner gets charged by half his DKP. All  the players have to do to bet is /roll.",
		keys={
			{keywords="/roll", value="$net+$roll", dkp="$net/2"},
		},
	},
		
	G={
		name = 'Ni Karma',
		description=
'A Ni Karma bidding system is a further implementation of the roll+net concept. Players can perform a "bonus" roll where the bid value is calculated as the roll number plus the players net DKP amount. If the winner player used this bonus roll, he ll pay half his DKP. To be able to place this bet, the player must have at least 50 DKP.\
If a player wants the item as it is a minor upgrade or needs it for offspec but doesnt want to spend DKP on it, he can place a "offspec" roll, where the value is simply the roll itself. a "bonus" roll has priority over "offspec" rolls, so in this implementation the later will be shown as negative numbers (/roll - 100).\
Please note that the Ni Karma system requests a maximum net DKP cap of 100',
		keys={
			{keywords="karma,bonus", value="$roll+$net", dkp="$net/2", min="50"},
			--{keywords="need,no bonus", value="$roll", dkp="5"}, --this keyword is not needed in a pure ni karma system, but can be useful.
			{keywords="offspec", value="$roll-101", dkp="0"},
		},
	},
	
	H={
		name='Fixed price hybrid',
		description=
'In this bidding system set fixed prices are used as bid starting price. The keywords used are the same as in the simple bidding, with the difference that /rolls and "needs" will cost DKP, too.' ,
		keys={
			{keywords="$n,bid $n,need $n", min="$itemprice or $minbid"},
			{keywords="all,max,all in" ,value="$net", min="$itemprice or $minbid"},
			{keywords="min,minimum" ,value="$itemprice or $minbid"},
			{keywords="half", value="$net/2", min="$itemprice or $minbid"},
			{keywords="greed,offspec,/roll", value="$itemprice or $minbid"},
		},
	},

	
	K={
		name='Example complex system',
		description=
	'This is a bidding system with complex keywords. It s only for reference to show various advanced aspects of the Quick DKP bid manager and should not used as it is by anyone.\
	"need 43": Places the given bet. If the player is a defined alt or external, the bet value is halved.\
	"low": Places a bet equal to 10% of players DKP or the minimum bid amount if greater. The value is doubled if the player is not a defined alt.\
	"tank stuff": This will place an high bet with zero DKP, but only if the item is plate armor and the player is a warrior, DK or paladin, or if it is leather and the player is a druid\
	"raise 12": This will place a bet equal to the highest one plus the give value, just like in the poker game.\
	"rankbet": This is a rank-based bet: only player with rank equal or higher to the bidding leader can place this. The DKP price is 10% of the item level.\
	"offspec": Places a zero-value bet. Wont be accepted if anyone placed a real bet.\
	"/roll": Rolls wil be catched and will trigger an "offspec" bet.',
		
		keys={
			{keywords="need $n", value="$n*((($isalt or $isexternal) and 0.5) or 1)", dkp="$n"},
			{keywords="low", value="(($net*10/100>$minbid) and $net*10/100) or $minbid"},
			{keywords="tank stuff", value="9999", dkp="0", eligibile='("$itemsubtype"=="Plate" and ("$class"=="Warrior" or "$class"=="Death Knight" or "$class"=="Paladin")) or ("$itemsubtype"=="Leather" and "$class"=="Druid")'},
			{keywords="raise $n", value="$higherbid1 + $n"},
			{keywords="rankbet", value="$ranknum", dkp="$itemlevel*10/100", eligibile='$ranknum>=$ranknum1'},
			{keywords="offspec",value="0", eligible="$higherbid1>0"},
			{keywords="/roll", value="0", eligible="$higherbid1>0"},
		},
	},
	
--CUSTOM
	CUSTOM={	
		name = 'Custom system',
		description=
'The current looting system has been customized.\
<Insert here a quick refernce about keywords field and variables>\
',
		keys={},
	},
}
--builds values for Preset selector
local Values={}
for i,v in pairs(QDKP2_Config.KeywordPresets) do
	Values[i]=v.name
end
QDKP2_Config.Tree.args.BidManager.args.BidKeywords.args.DefaultKWProfile.values=Values



 --Keywords
local KeywordVoice={
	type='group',
	order=function(info) return tonumber(info[#info]); end,
	name=GetKWField,
	hidden=function(info) if GetKWField(info)=='!!VOID!!' then return true; end; end,
	get=GetKWField,
	set=SetKWField,
	args={
		keywords={
			type='input',
			pattern='.+', --no null strings.
			name=L.BM_KW_Keyword,
			desc=L.BM_KW_Keyword_d,
			order=10,
		},
		value={
			type='input',
			name=L.BM_KW_Value,
			desc=L.BM_KW_Value_d,
			order=20,
		},
		dkp={
			type='input',
			name=L.BM_KW_DKP,
			desc=L.BM_KW_DKP_d,
			order=30,
		},
		min={
			type='input',
			name=L.BM_KW_Min,
			desc=L.BM_KW_Min_d,
			order=40,
		},
		max={
			type='input',
			name=L.BM_KW_Max,
			desc=L.BM_KW_Max_d,
			order=50,
		},
		eligible={
			type='input',
			name=L.BM_KW_Eligible,
			desc=L.BM_KW_Eligible_d,
			order=60,
		},
		BM_KW_Test={
			type='execute',
			func=TestKey,
		},
		BM_KW_Del={
			type='execute',
			func=DelKeyword,
			confirm=true,
			confirmText=L.Confirm,
			order=70,
		},
	},
}

--populates the KW list
for i=1,30 do  --maximum of 30 keywords 
	QDKP2_Config.Tree.args.BidManager.args.BidKeywords.args[tostring(i)]=KeywordVoice
end







