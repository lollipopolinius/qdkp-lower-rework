
local L=QDKP2_Config.Localize

local function TrueIfODDisabled()
	if not QDKP2_ODS_ENABLE then return true; end
end

QDKP2_Config.Tree.args.ODS={
	type = 'group',
	name = L.ODS,
	order=20,
	args ={
		ODS_Enable={
			type = 'toggle',
			order = 10,
		},
		KWHeaders={
			type = 'header',
			order = 15,
		},
		ODS_EnDKP={
			type = 'toggle',
			disabled=TrueIfODDisabled,
			order = 20,
		},
		ODS_EnREPORT={
			type = 'toggle',
			disabled=TrueIfODDisabled,
			order = 30,
		},
		ODS_EnPRICE={
			type = 'toggle',
			disabled=TrueIfODDisabled,
			order = 40,
		},
		ODS_EnBOSS={
			type = 'toggle',
			disabled=TrueIfODDisabled,
			order = 50,
		},
		ODS_EnCLASS={
			type = 'toggle',
			disabled=TrueIfODDisabled,
			order = 60,
		},
		ODS_EnRANK={
			type = 'toggle',
			disabled=TrueIfODDisabled,
			order = 70,
		},
		OptionHeaders={
			type = 'header',
			name = L.OptionHeaders,
			order = 75,
		},
		ODS_ViewWhisp={
			type = 'toggle',
			disabled=TrueIfODDisabled,
			order = 80,
		},
		ODS_ReqAll={
			type = 'toggle',
			disabled=TrueIfODDisabled,
			order = 90,
		},
		ODS_LetExt={
			type = 'toggle',
			disabled=TrueIfODDisabled,
			order = 100,
		},
		ODS_TopTenLen={
			type = 'range', min = 1, step = 1, max = 20,
			disabled=TrueIfODDisabled,
			order = 110,
		},
		ODS_PriceLen={
			type = 'range', min = 1, step = 1, max = 20,
			disabled=TrueIfODDisabled,
			order = 120,
		},
		ODS_BossLen={
			type = 'range', min = 1, step = 1, max = 20,
			disabled=TrueIfODDisabled,
			order = 130,
		},
		ODS_PricesKWLen={
			type = 'range', min = 0, step = 1, max = 10,
			disabled=TrueIfODDisabled,
			order = 140,
		},
		ODS_BossKWLen={
			type = 'range', min = 0, step = 1, max = 10,
			disabled=TrueIfODDisabled,
			order = 150,
		},
	},
}
