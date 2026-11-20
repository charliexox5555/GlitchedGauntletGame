--!strict
-- Authored LobbyWorld defaults. Apply the entry key and GauntletAuthoredData as CollectionService tags.
-- Shared rows let cloned assets retain their configuration.
-- stylua: ignore
return {
	GGAsset_LobbyWorld_1 = { ["Active"] = "V4", ["Origin"] = Vector3.new(-1500, 0, 0), ["V3LightingSaved"] = true, ["V3_Ambient"] = Color3.new(0.20392157137393951, 0.21960784494876862, 0.25098040699958801), ["V3_AtmDensity"] = 0.2199999988079071, ["V3_AtmHaze"] = 0.15000000596046448, ["V3_AtmOffset"] = 0.10000000149011612, ["V3_Bloom"] = Vector3.new(0.60000002384185791, 18, 1.6000000238418579), ["V3_Brightness"] = 2.2999999523162842, ["V3_ClockTime"] = 12.399999618530273, ["V3_ColorShift_Top"] = Color3.new(1, 0.98823529481887817, 0.96470588445663452), ["V3_EnvironmentDiffuseScale"] = 0.20000000298023224, ["V3_EnvironmentSpecularScale"] = 0.079999998211860657, ["V3_ExposureCompensation"] = -0.75, ["V3_GeographicLatitude"] = 8, ["V3_OutdoorAmbient"] = Color3.new(0.35294118523597717, 0.37647059559822083, 0.43137255311012268), ["V3_ShadowSoftness"] = 1 }, -- Workspace.LobbyV4Staging
	GGAsset_LobbyWorld_2 = { ["BX"] = -0.38269999999999998, ["BY"] = -0.92390000000000005, ["BZ"] = 0, ["FX"] = 0, ["FY"] = 0, ["FZ"] = 1, ["Fill"] = 6.5999999999999996, ["Gun"] = "Odin", ["Mount"] = "Lay", ["Scale"] = 2.2999999999999998, ["Spin"] = 0 }, -- Workspace.LobbyV4Staging.Anchors.Table_OdinGun
	GGAsset_LobbyWorld_3 = { ["BX"] = -0.38269999999999998, ["BY"] = 0.92390000000000005, ["BZ"] = 0, ["FX"] = 0, ["FY"] = 0, ["FZ"] = 1, ["Fill"] = 6.5999999999999996, ["Gun"] = "Vandal", ["Mount"] = "Lay", ["Scale"] = 2.2999999999999998, ["Spin"] = 0 }, -- Workspace.LobbyV4Staging.Anchors.Table_VandalGun
	GGAsset_LobbyWorld_4 = { ["BX"] = -0.92390000000000005, ["BY"] = -0.38269999999999998, ["BZ"] = 0, ["FX"] = 0, ["FY"] = 0, ["FZ"] = 1, ["Fill"] = 6.5999999999999996, ["Gun"] = "Operator", ["Mount"] = "Lay", ["Scale"] = 2.2999999999999998, ["Spin"] = 0 }, -- Workspace.LobbyV4Staging.Anchors.Table_OperatorGun
	GGAsset_LobbyWorld_5 = { ["BX"] = -0.92390000000000005, ["BY"] = 0.38269999999999998, ["BZ"] = 0, ["FX"] = 0, ["FY"] = 0, ["FZ"] = 1, ["Fill"] = 6.5999999999999996, ["Gun"] = "Phantom", ["Mount"] = "Lay", ["Scale"] = 2.2999999999999998, ["Spin"] = 0 }, -- Workspace.LobbyV4Staging.Anchors.Table_PhantomGun
	GGAsset_LobbyWorld_6 = { ["BX"] = 0, ["BY"] = 0, ["BZ"] = 1, ["FX"] = 1, ["FY"] = 0, ["FZ"] = 0, ["Fill"] = 0, ["Gun"] = "Knife", ["Mount"] = "Stand", ["Scale"] = 2.6000000000000001, ["Spin"] = 40 }, -- Workspace.LobbyV4Staging.Anchors.KnifeHero
	GGAsset_LobbyWorld_7 = { ["BX"] = 0, ["BY"] = 1, ["BZ"] = 0, ["FX"] = 1, ["FY"] = 0, ["FZ"] = 0, ["Fill"] = 5.9000000000000004, ["Gun"] = "Ares", ["Mount"] = "Wall", ["Scale"] = 1.8999999999999999, ["Spin"] = 0 }, -- Workspace.LobbyV4Staging.Anchors.GunWall_Ares
	GGAsset_LobbyWorld_8 = { ["BX"] = 0, ["BY"] = 1, ["BZ"] = 0, ["FX"] = 1, ["FY"] = 0, ["FZ"] = 0, ["Fill"] = 5.9000000000000004, ["Gun"] = "Bucky", ["Mount"] = "Wall", ["Scale"] = 1.8999999999999999, ["Spin"] = 0 }, -- Workspace.LobbyV4Staging.Anchors.GunWall_Bucky
	GGAsset_LobbyWorld_9 = { ["BX"] = 0, ["BY"] = 1, ["BZ"] = 0, ["FX"] = 1, ["FY"] = 0, ["FZ"] = 0, ["Fill"] = 5.9000000000000004, ["Gun"] = "Bulldog", ["Mount"] = "Wall", ["Scale"] = 1.8999999999999999, ["Spin"] = 0 }, -- Workspace.LobbyV4Staging.Anchors.GunWall_Bulldog
	GGAsset_LobbyWorld_10 = { ["BX"] = 0, ["BY"] = 1, ["BZ"] = 0, ["FX"] = 1, ["FY"] = 0, ["FZ"] = 0, ["Fill"] = 5.9000000000000004, ["Gun"] = "Ghost", ["Mount"] = "Wall", ["Scale"] = 1.8999999999999999, ["Spin"] = 0 }, -- Workspace.LobbyV4Staging.Anchors.GunWall_Ghost
	GGAsset_LobbyWorld_11 = { ["BX"] = 0, ["BY"] = 1, ["BZ"] = 0, ["FX"] = 1, ["FY"] = 0, ["FZ"] = 0, ["Fill"] = 5.9000000000000004, ["Gun"] = "Guardian", ["Mount"] = "Wall", ["Scale"] = 1.8999999999999999, ["Spin"] = 0 }, -- Workspace.LobbyV4Staging.Anchors.GunWall_Guardian
	GGAsset_LobbyWorld_12 = { ["BX"] = 0, ["BY"] = 1, ["BZ"] = 0, ["FX"] = 1, ["FY"] = 0, ["FZ"] = 0, ["Fill"] = 5.9000000000000004, ["Gun"] = "Marshal", ["Mount"] = "Wall", ["Scale"] = 1.8999999999999999, ["Spin"] = 0 }, -- Workspace.LobbyV4Staging.Anchors.GunWall_Marshal
	GGAsset_LobbyWorld_13 = { ["BX"] = 0, ["BY"] = 1, ["BZ"] = 0, ["FX"] = 1, ["FY"] = 0, ["FZ"] = 0, ["Fill"] = 5.9000000000000004, ["Gun"] = "Outlaw", ["Mount"] = "Wall", ["Scale"] = 1.8999999999999999, ["Spin"] = 0 }, -- Workspace.LobbyV4Staging.Anchors.GunWall_Outlaw
	GGAsset_LobbyWorld_14 = { ["BX"] = 0, ["BY"] = 1, ["BZ"] = 0, ["FX"] = 1, ["FY"] = 0, ["FZ"] = 0, ["Fill"] = 5.9000000000000004, ["Gun"] = "Shorty", ["Mount"] = "Wall", ["Scale"] = 1.8999999999999999, ["Spin"] = 0 }, -- Workspace.LobbyV4Staging.Anchors.GunWall_Shorty
	GGAsset_LobbyWorld_15 = { ["BX"] = 0, ["BY"] = 1, ["BZ"] = 0, ["FX"] = 1, ["FY"] = 0, ["FZ"] = 0, ["Fill"] = 5.9000000000000004, ["Gun"] = "Stinger", ["Mount"] = "Wall", ["Scale"] = 1.8999999999999999, ["Spin"] = 0 }, -- Workspace.LobbyV4Staging.Anchors.GunWall_Stinger
	GGAsset_LobbyWorld_16 = { ["BX"] = 0.38269999999999998, ["BY"] = -0.92390000000000005, ["BZ"] = 0, ["FX"] = 0, ["FY"] = 0, ["FZ"] = 1, ["Fill"] = 6.5999999999999996, ["Gun"] = "Judge", ["Mount"] = "Lay", ["Scale"] = 2.2999999999999998, ["Spin"] = 0 }, -- Workspace.LobbyV4Staging.Anchors.Table_JudgeGun
	GGAsset_LobbyWorld_17 = { ["BX"] = 0.38269999999999998, ["BY"] = 0.92390000000000005, ["BZ"] = 0, ["FX"] = 0, ["FY"] = 0, ["FZ"] = 1, ["Fill"] = 6.5999999999999996, ["Gun"] = "Classic", ["Mount"] = "Lay", ["Scale"] = 2.2999999999999998, ["Spin"] = 0 }, -- Workspace.LobbyV4Staging.Anchors.Table_ClassicGun
	GGAsset_LobbyWorld_18 = { ["BX"] = 0.92390000000000005, ["BY"] = -0.38269999999999998, ["BZ"] = 0, ["FX"] = 0, ["FY"] = 0, ["FZ"] = 1, ["Fill"] = 6.5999999999999996, ["Gun"] = "Spectre", ["Mount"] = "Lay", ["Scale"] = 2.2999999999999998, ["Spin"] = 0 }, -- Workspace.LobbyV4Staging.Anchors.Table_SpectreGun
	GGAsset_LobbyWorld_19 = { ["BX"] = 0.92390000000000005, ["BY"] = 0.38269999999999998, ["BZ"] = 0, ["FX"] = 0, ["FY"] = 0, ["FZ"] = 1, ["Fill"] = 6.5999999999999996, ["Gun"] = "Sheriff", ["Mount"] = "Lay", ["Scale"] = 2.2999999999999998, ["Spin"] = 0 }, -- Workspace.LobbyV4Staging.Anchors.Table_SheriffGun
	GGAsset_LobbyWorld_20 = { ["BobAmp"] = 0.17999999999999999, ["BobSpeed"] = 0.22, ["SWGun"] = true, ["SpinSpeed"] = 16 }, -- Workspace.LobbyV4Staging.Shop.FeaturedPedestal.Phantom
	GGAsset_LobbyWorld_21 = { ["BobAmp"] = 0.17999999999999999, ["BobSpeed"] = 0.22, ["SpinSpeed"] = 16 }, -- Workspace.Lobby.Hub.Vault.Guns.Vandal
	GGAsset_LobbyWorld_22 = { ["Ceil"] = false, ["SWMat"] = "E_Alarm", ["SWName"] = "ConcourseD_0419_E_Alarm" }, -- Workspace.LobbyV4Staging.Concourse.Plaques_Range.E_Alarm
	GGAsset_LobbyWorld_23 = { ["Ceil"] = false, ["SWMat"] = "E_Alarm", ["SWName"] = "DuelsD_0248_E_Alarm" }, -- Workspace.LobbyV4Staging.Duels.FrontDetails.E_Alarm
	GGAsset_LobbyWorld_24 = { ["Ceil"] = false, ["SWMat"] = "E_Coral", ["SWName"] = "ConcourseD_0214_E_Coral" }, -- Workspace.LobbyV4Staging.Concourse.Sign_Shop.E_Coral
	GGAsset_LobbyWorld_25 = { ["Ceil"] = false, ["SWMat"] = "E_Coral", ["SWName"] = "ShopD_0168_E_Coral" }, -- Workspace.LobbyV4Staging.Shop.Bay_Featured.Bay_Featured.E_Coral
	GGAsset_LobbyWorld_26 = { ["Ceil"] = false, ["SWMat"] = "E_Coral", ["SWName"] = "ShopD_0190_E_Coral" }, -- Workspace.LobbyV4Staging.Shop.Bay_FeaturedSign.E_Coral
	GGAsset_LobbyWorld_27 = { ["Ceil"] = false, ["SWMat"] = "E_Coral", ["SWName"] = "ShopD_0199_E_Coral" }, -- Workspace.LobbyV4Staging.Shop.Mark_Featured.Mark_Featured.E_Coral
	GGAsset_LobbyWorld_28 = { ["Ceil"] = false, ["SWMat"] = "E_Coral", ["SWName"] = "ShopD_0388_E_Coral" }, -- Workspace.LobbyV4Staging.Shop.Sign_Broker.E_Coral
	GGAsset_LobbyWorld_29 = { ["Ceil"] = false, ["SWMat"] = "E_Gold", ["SWName"] = "ConcourseD_0012_E_Gold" }, -- Workspace.LobbyV4Staging.Concourse.HubFloor.HubFloor.E_Gold
	GGAsset_LobbyWorld_30 = { ["Ceil"] = false, ["SWMat"] = "E_Gold", ["SWName"] = "ConcourseD_0191_E_Gold" }, -- Workspace.LobbyV4Staging.Concourse.Sign_Duels.E_Gold
	GGAsset_LobbyWorld_31 = { ["Ceil"] = false, ["SWMat"] = "E_Gold", ["SWName"] = "ConcourseD_0458_E_Gold" }, -- Workspace.LobbyV4Staging.Concourse.DaisCollar_4.E_Gold
	GGAsset_LobbyWorld_32 = { ["Ceil"] = false, ["SWMat"] = "E_Gold", ["SWName"] = "DuelsD_0006_E_Gold" }, -- Workspace.LobbyV4Staging.Duels.Landing.E_Gold
	GGAsset_LobbyWorld_33 = { ["Ceil"] = false, ["SWMat"] = "E_Gold", ["SWName"] = "DuelsD_0043_E_Gold" }, -- Workspace.LobbyV4Staging.Duels.PadSign.E_Gold
	GGAsset_LobbyWorld_34 = { ["Ceil"] = false, ["SWMat"] = "E_Gold", ["SWName"] = "DuelsD_0066_E_Gold" }, -- Workspace.LobbyV4Staging.Duels.PadSign_2.E_Gold
	GGAsset_LobbyWorld_35 = { ["Ceil"] = false, ["SWMat"] = "E_Gold", ["SWName"] = "DuelsD_0089_E_Gold" }, -- Workspace.LobbyV4Staging.Duels.PadSign_3.E_Gold
	GGAsset_LobbyWorld_36 = { ["Ceil"] = false, ["SWMat"] = "E_Gold", ["SWName"] = "DuelsD_0112_E_Gold" }, -- Workspace.LobbyV4Staging.Duels.PadSign_4.E_Gold
	GGAsset_LobbyWorld_37 = { ["Ceil"] = false, ["SWMat"] = "E_Gold", ["SWName"] = "DuelsD_0141_E_Gold" }, -- Workspace.LobbyV4Staging.Duels.PadSign_5.E_Gold
	GGAsset_LobbyWorld_38 = { ["Ceil"] = false, ["SWMat"] = "E_Gold", ["SWName"] = "DuelsD_0164_E_Gold" }, -- Workspace.LobbyV4Staging.Duels.PadSign_6.E_Gold
	GGAsset_LobbyWorld_39 = { ["Ceil"] = false, ["SWMat"] = "E_Gold", ["SWName"] = "DuelsD_0187_E_Gold" }, -- Workspace.LobbyV4Staging.Duels.PadSign_7.E_Gold
	GGAsset_LobbyWorld_40 = { ["Ceil"] = false, ["SWMat"] = "E_Gold", ["SWName"] = "DuelsD_0210_E_Gold" }, -- Workspace.LobbyV4Staging.Duels.PadSign_8.E_Gold
	GGAsset_LobbyWorld_41 = { ["Ceil"] = false, ["SWMat"] = "E_Gold", ["SWName"] = "DuelsD_0231_E_Gold" }, -- Workspace.LobbyV4Staging.Duels.Sign_Gauntlet.E_Gold
	GGAsset_LobbyWorld_42 = { ["Ceil"] = false, ["SWMat"] = "E_Gold", ["SWName"] = "DuelsD_0376_E_Gold" }, -- Workspace.LobbyV4Staging.Duels.TrophyPlinth.E_Gold
	GGAsset_LobbyWorld_43 = { ["Ceil"] = false, ["SWMat"] = "E_Gold", ["SWName"] = "DuelsD_E_Gold" }, -- Workspace.LobbyV4Staging.Duels.E_Gold
	GGAsset_LobbyWorld_44 = { ["Ceil"] = false, ["SWMat"] = "E_Gold", ["SWName"] = "ShopD_0399_E_Gold" }, -- Workspace.LobbyV4Staging.Shop.BrokerBundleMedal.E_Gold
	GGAsset_LobbyWorld_45 = { ["Ceil"] = false, ["SWMat"] = "E_Gold", ["SWName"] = "ShopD_0405_E_Gold" }, -- Workspace.LobbyV4Staging.Shop.BrokerEffect.E_Gold
	GGAsset_LobbyWorld_46 = { ["Ceil"] = false, ["SWMat"] = "E_Lime", ["SWName"] = "ConcourseD_0260_E_Lime" }, -- Workspace.LobbyV4Staging.Concourse.RangeDoor.E_Lime
	GGAsset_LobbyWorld_47 = { ["Ceil"] = false, ["SWMat"] = "E_Lime", ["SWName"] = "ConcourseD_0263_E_Lime" }, -- Workspace.LobbyV4Staging.Concourse.Sign_Range.E_Lime
	GGAsset_LobbyWorld_48 = { ["Ceil"] = false, ["SWMat"] = "E_Panel", ["SWName"] = "ConcourseD_0141_E_Panel" }, -- Workspace.LobbyV4Staging.Concourse.Lantern.E_Panel
	GGAsset_LobbyWorld_49 = { ["Ceil"] = false, ["SWMat"] = "E_Panel", ["SWName"] = "DuelsD_0382_E_Panel" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.NaveVault.E_Panel
	GGAsset_LobbyWorld_50 = { ["Ceil"] = false, ["SWMat"] = "E_Panel", ["SWName"] = "LockerD_0025_E_Panel" }, -- Workspace.LobbyV4Staging.Locker.RoomVault.E_Panel
	GGAsset_LobbyWorld_51 = { ["Ceil"] = false, ["SWMat"] = "E_Panel", ["SWName"] = "ShopD_0058_E_Panel" }, -- Workspace.LobbyV4Staging.Shop.RoomVault_2.E_Panel
	GGAsset_LobbyWorld_52 = { ["Ceil"] = false, ["SWMat"] = "E_Panel", ["SWName"] = "ShopD_0348_E_Panel" }, -- Workspace.LobbyV4Staging.Shop.RoomVault_3.E_Panel
	GGAsset_LobbyWorld_53 = { ["Ceil"] = false, ["SWMat"] = "E_TeamA", ["SWName"] = "DuelsD_0026_E_TeamA" }, -- Workspace.LobbyV4Staging.Duels.Pad_1v1_2.Pad_1v1_2.E_TeamA
	GGAsset_LobbyWorld_54 = { ["Ceil"] = false, ["SWMat"] = "E_TeamB", ["SWName"] = "DuelsD_0028_E_TeamB" }, -- Workspace.LobbyV4Staging.Duels.Pad_1v1_2.Pad_1v1_2.E_TeamB
	GGAsset_LobbyWorld_55 = { ["Ceil"] = false, ["SWMat"] = "E_ThLilac", ["SWName"] = "ConcourseD_0003_E_ThLilac" }, -- Workspace.LobbyV4Staging.Concourse.HubFloor.HubFloor.E_ThLilac
	GGAsset_LobbyWorld_56 = { ["Ceil"] = false, ["SWMat"] = "E_ThLilac", ["SWName"] = "ConcourseD_0423_E_ThLilac" }, -- Workspace.LobbyV4Staging.Concourse.Holo_Gift.E_ThLilac
	GGAsset_LobbyWorld_57 = { ["Ceil"] = false, ["SWMat"] = "E_ThLilac", ["SWName"] = "ConcourseD_0432_E_ThLilac" }, -- Workspace.LobbyV4Staging.Concourse.Holo_Badge.E_ThLilac
	GGAsset_LobbyWorld_58 = { ["Ceil"] = false, ["SWMat"] = "E_ThLilac", ["SWName"] = "ConcourseD_0441_E_ThLilac" }, -- Workspace.LobbyV4Staging.Concourse.Holo_Rifle.E_ThLilac
	GGAsset_LobbyWorld_59 = { ["Ceil"] = false, ["SWMat"] = "E_ThLilac", ["SWName"] = "ConcourseD_0450_E_ThLilac" }, -- Workspace.LobbyV4Staging.Concourse.Holo_Crate.E_ThLilac
	GGAsset_LobbyWorld_60 = { ["Ceil"] = false, ["SWMat"] = "E_ThLilac", ["SWName"] = "DuelsD_0012_E_ThLilac" }, -- Workspace.LobbyV4Staging.Duels.DuelsFloor.E_ThLilac
	GGAsset_LobbyWorld_61 = { ["Ceil"] = false, ["SWMat"] = "E_ThLilac", ["SWName"] = "ShopD_0414_E_ThLilac" }, -- Workspace.LobbyV4Staging.Shop.Holo_ShopGift.E_ThLilac
	GGAsset_LobbyWorld_62 = { ["Ceil"] = false, ["SWMat"] = "E_ThLilac", ["SWName"] = "ShopD_0423_E_ThLilac" }, -- Workspace.LobbyV4Staging.Shop.Holo_ShopBadge.E_ThLilac
	GGAsset_LobbyWorld_63 = { ["Ceil"] = false, ["SWMat"] = "E_ThLilac", ["SWName"] = "ShopD_0431_E_ThLilac" }, -- Workspace.LobbyV4Staging.Shop.Path_2.E_ThLilac
	GGAsset_LobbyWorld_64 = { ["Ceil"] = false, ["SWMat"] = "E_ThLilac", ["SWName"] = "ShopD_0434_E_ThLilac" }, -- Workspace.LobbyV4Staging.Shop.Path_3.E_ThLilac
	GGAsset_LobbyWorld_65 = { ["Ceil"] = false, ["SWMat"] = "E_ThLilac", ["SWName"] = "ShopD_0437_E_ThLilac" }, -- Workspace.LobbyV4Staging.Shop.PathCorner.E_ThLilac
	GGAsset_LobbyWorld_66 = { ["Ceil"] = false, ["SWMat"] = "E_ThViolet", ["SWName"] = "ConcourseD_0148_E_ThViolet" }, -- Workspace.LobbyV4Staging.Concourse.LightRing.E_ThViolet
	GGAsset_LobbyWorld_67 = { ["Ceil"] = false, ["SWMat"] = "E_ThViolet", ["SWName"] = "ConcourseD_0181_E_ThViolet" }, -- Workspace.LobbyV4Staging.Concourse.Gate_Duels.E_ThViolet
	GGAsset_LobbyWorld_68 = { ["Ceil"] = false, ["SWMat"] = "E_ThViolet", ["SWName"] = "ConcourseD_0204_E_ThViolet" }, -- Workspace.LobbyV4Staging.Concourse.Gate_Shop.E_ThViolet
	GGAsset_LobbyWorld_69 = { ["Ceil"] = false, ["SWMat"] = "E_ThViolet", ["SWName"] = "ConcourseD_0226_E_ThViolet" }, -- Workspace.LobbyV4Staging.Concourse.Gate_Locker.E_ThViolet
	GGAsset_LobbyWorld_70 = { ["Ceil"] = false, ["SWMat"] = "E_ThViolet", ["SWName"] = "ConcourseD_0249_E_ThViolet" }, -- Workspace.LobbyV4Staging.Concourse.Gate_Range.E_ThViolet
	GGAsset_LobbyWorld_71 = { ["Ceil"] = false, ["SWMat"] = "E_ThViolet", ["SWName"] = "ConcourseD_0286_E_ThViolet" }, -- Workspace.LobbyV4Staging.Concourse.TV_TOPWINS.E_ThViolet
	GGAsset_LobbyWorld_72 = { ["Ceil"] = false, ["SWMat"] = "E_ThViolet", ["SWName"] = "ConcourseD_0308_E_ThViolet" }, -- Workspace.LobbyV4Staging.Concourse.TV_WINSTREAKS.E_ThViolet
	GGAsset_LobbyWorld_73 = { ["Ceil"] = false, ["SWMat"] = "E_ThViolet", ["SWName"] = "ConcourseD_0330_E_ThViolet" }, -- Workspace.LobbyV4Staging.Concourse.TV_News.E_ThViolet
	GGAsset_LobbyWorld_74 = { ["Ceil"] = false, ["SWMat"] = "E_ThViolet", ["SWName"] = "ConcourseD_0352_E_ThViolet" }, -- Workspace.LobbyV4Staging.Concourse.TV_Featured.E_ThViolet
	GGAsset_LobbyWorld_75 = { ["Ceil"] = false, ["SWMat"] = "E_ThViolet", ["SWName"] = "DuelsD_0011_E_ThViolet" }, -- Workspace.LobbyV4Staging.Duels.DuelsFloor.E_ThViolet
	GGAsset_LobbyWorld_76 = { ["Ceil"] = false, ["SWMat"] = "E_ThViolet", ["SWName"] = "DuelsD_0370_E_ThViolet" }, -- Workspace.LobbyV4Staging.Duels.Jumbotron.E_ThViolet
	GGAsset_LobbyWorld_77 = { ["Ceil"] = false, ["SWMat"] = "E_ThViolet", ["SWName"] = "ShopD_0145_E_ThViolet" }, -- Workspace.LobbyV4Staging.Shop.TV_ShopN.E_ThViolet
	GGAsset_LobbyWorld_78 = { ["Ceil"] = false, ["SWMat"] = "E_ThViolet", ["SWName"] = "ShopD_0150_E_ThViolet" }, -- Workspace.LobbyV4Staging.Shop.TV_ShopS.E_ThViolet
	GGAsset_LobbyWorld_79 = { ["Ceil"] = false, ["SWMat"] = "E_ThViolet", ["SWName"] = "ShopD_0212_E_ThViolet" }, -- Workspace.LobbyV4Staging.Shop.Bay_Season.Bay_Season.E_ThViolet
	GGAsset_LobbyWorld_80 = { ["Ceil"] = false, ["SWMat"] = "E_ThViolet", ["SWName"] = "ShopD_0233_E_ThViolet" }, -- Workspace.LobbyV4Staging.Shop.Bay_SeasonSign.E_ThViolet
	GGAsset_LobbyWorld_81 = { ["Ceil"] = false, ["SWMat"] = "E_ThViolet", ["SWName"] = "ShopD_0240_E_ThViolet" }, -- Workspace.LobbyV4Staging.Shop.SeasonCrest.E_ThViolet
	GGAsset_LobbyWorld_82 = { ["Ceil"] = false, ["SWMat"] = "E_ThViolet", ["SWName"] = "ShopD_0242_E_ThViolet" }, -- Workspace.LobbyV4Staging.Shop.Mark_Season.Mark_Season.E_ThViolet
	GGAsset_LobbyWorld_83 = { ["Ceil"] = false, ["SWMat"] = "E_ThViolet", ["SWName"] = "ShopD_0374_E_ThViolet" }, -- Workspace.LobbyV4Staging.Shop.TV_ShopEnd.E_ThViolet
	GGAsset_LobbyWorld_84 = { ["Ceil"] = false, ["SWMat"] = "E_ThViolet", ["SWName"] = "ShopD_0378_E_ThViolet" }, -- Workspace.LobbyV4Staging.Shop.Sign_Market.E_ThViolet
	GGAsset_LobbyWorld_85 = { ["Ceil"] = false, ["SWMat"] = "E_ThViolet", ["SWName"] = "ShopD_0384_E_ThViolet" }, -- Workspace.LobbyV4Staging.Shop.TV_Broker.E_ThViolet
	GGAsset_LobbyWorld_86 = { ["Ceil"] = false, ["SWMat"] = "E_ThViolet", ["SWName"] = "ShopD_0410_E_ThViolet" }, -- Workspace.LobbyV4Staging.Shop.BrokerPlinth.E_ThViolet
	GGAsset_LobbyWorld_87 = { ["Ceil"] = false, ["SWMat"] = "E_Violet", ["SWName"] = "ConcourseD_0237_E_Violet" }, -- Workspace.LobbyV4Staging.Concourse.Sign_Locker.E_Violet
	GGAsset_LobbyWorld_88 = { ["Ceil"] = false, ["SWMat"] = "E_Violet", ["SWName"] = "LockerD_0170_E_Violet" }, -- Workspace.LobbyV4Staging.Locker.Sign_Loadout.E_Violet
	GGAsset_LobbyWorld_89 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ConcourseD_0032_E_White" }, -- Workspace.LobbyV4Staging.Concourse.BarLamp_5.E_White
	GGAsset_LobbyWorld_90 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ConcourseD_0107_E_White" }, -- Workspace.LobbyV4Staging.Concourse.HubCeiling.HubCeiling.E_White
	GGAsset_LobbyWorld_91 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ConcourseD_0109_E_White" }, -- Workspace.LobbyV4Staging.Concourse.HubCeiling.CeilingLamp.E_White
	GGAsset_LobbyWorld_92 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ConcourseD_0112_E_White" }, -- Workspace.LobbyV4Staging.Concourse.HubCeiling.CeilingLamp_2.E_White
	GGAsset_LobbyWorld_93 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ConcourseD_0115_E_White" }, -- Workspace.LobbyV4Staging.Concourse.HubCeiling.CeilingLamp_3.E_White
	GGAsset_LobbyWorld_94 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ConcourseD_0118_E_White" }, -- Workspace.LobbyV4Staging.Concourse.HubCeiling.CeilingLamp_4.E_White
	GGAsset_LobbyWorld_95 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ConcourseD_0121_E_White" }, -- Workspace.LobbyV4Staging.Concourse.HubCeiling.CeilingLamp_5.E_White
	GGAsset_LobbyWorld_96 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ConcourseD_0124_E_White" }, -- Workspace.LobbyV4Staging.Concourse.HubCeiling.CeilingLamp_6.E_White
	GGAsset_LobbyWorld_97 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ConcourseD_0127_E_White" }, -- Workspace.LobbyV4Staging.Concourse.HubCeiling.CeilingLamp_7.E_White
	GGAsset_LobbyWorld_98 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ConcourseD_0130_E_White" }, -- Workspace.LobbyV4Staging.Concourse.HubCeiling.CeilingLamp_8.E_White
	GGAsset_LobbyWorld_99 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ConcourseD_0149_E_White" }, -- Workspace.LobbyV4Staging.Concourse.LightRing.E_White
	GGAsset_LobbyWorld_100 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ConcourseD_0177_E_White" }, -- Workspace.LobbyV4Staging.Concourse.Portal_Duels.E_White
	GGAsset_LobbyWorld_101 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ConcourseD_0184_E_White" }, -- Workspace.LobbyV4Staging.Concourse.Gate_Duels.E_White
	GGAsset_LobbyWorld_102 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ConcourseD_0192_E_White" }, -- Workspace.LobbyV4Staging.Concourse.Sign_Duels.E_White
	GGAsset_LobbyWorld_103 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ConcourseD_0200_E_White" }, -- Workspace.LobbyV4Staging.Concourse.Portal_Shop.E_White
	GGAsset_LobbyWorld_104 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ConcourseD_0207_E_White" }, -- Workspace.LobbyV4Staging.Concourse.Gate_Shop.E_White
	GGAsset_LobbyWorld_105 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ConcourseD_0215_E_White" }, -- Workspace.LobbyV4Staging.Concourse.Sign_Shop.E_White
	GGAsset_LobbyWorld_106 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ConcourseD_0223_E_White" }, -- Workspace.LobbyV4Staging.Concourse.Portal_Locker.E_White
	GGAsset_LobbyWorld_107 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ConcourseD_0230_E_White" }, -- Workspace.LobbyV4Staging.Concourse.Gate_Locker.E_White
	GGAsset_LobbyWorld_108 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ConcourseD_0238_E_White" }, -- Workspace.LobbyV4Staging.Concourse.Sign_Locker.E_White
	GGAsset_LobbyWorld_109 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ConcourseD_0253_E_White" }, -- Workspace.LobbyV4Staging.Concourse.Gate_Range.E_White
	GGAsset_LobbyWorld_110 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ConcourseD_0264_E_White" }, -- Workspace.LobbyV4Staging.Concourse.Sign_Range.E_White
	GGAsset_LobbyWorld_111 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ConcourseD_0278_E_White" }, -- Workspace.LobbyV4Staging.Concourse.Gallery.Deck.E_White
	GGAsset_LobbyWorld_112 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ConcourseD_0287_E_White" }, -- Workspace.LobbyV4Staging.Concourse.TV_TOPWINS.E_White
	GGAsset_LobbyWorld_113 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ConcourseD_0300_E_White" }, -- Workspace.LobbyV4Staging.Concourse.Gallery_2.Deck.E_White
	GGAsset_LobbyWorld_114 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ConcourseD_0309_E_White" }, -- Workspace.LobbyV4Staging.Concourse.TV_WINSTREAKS.E_White
	GGAsset_LobbyWorld_115 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ConcourseD_0322_E_White" }, -- Workspace.LobbyV4Staging.Concourse.Gallery_3.Deck.E_White
	GGAsset_LobbyWorld_116 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ConcourseD_0331_E_White" }, -- Workspace.LobbyV4Staging.Concourse.TV_News.E_White
	GGAsset_LobbyWorld_117 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ConcourseD_0344_E_White" }, -- Workspace.LobbyV4Staging.Concourse.Gallery_4.Deck.E_White
	GGAsset_LobbyWorld_118 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ConcourseD_0353_E_White" }, -- Workspace.LobbyV4Staging.Concourse.TV_Featured.E_White
	GGAsset_LobbyWorld_119 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ConcourseD_0367_E_White" }, -- Workspace.LobbyV4Staging.Concourse.LightingRig.StageSpot.E_White
	GGAsset_LobbyWorld_120 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ConcourseD_0371_E_White" }, -- Workspace.LobbyV4Staging.Concourse.LightingRig.StageSpot_2.E_White
	GGAsset_LobbyWorld_121 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ConcourseD_0375_E_White" }, -- Workspace.LobbyV4Staging.Concourse.LightingRig.StageSpot_3.E_White
	GGAsset_LobbyWorld_122 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ConcourseD_0379_E_White" }, -- Workspace.LobbyV4Staging.Concourse.LightingRig.StageSpot_4.E_White
	GGAsset_LobbyWorld_123 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ConcourseD_0383_E_White" }, -- Workspace.LobbyV4Staging.Concourse.LightingRig.StageSpot_5.E_White
	GGAsset_LobbyWorld_124 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ConcourseD_0387_E_White" }, -- Workspace.LobbyV4Staging.Concourse.LightingRig.StageSpot_6.E_White
	GGAsset_LobbyWorld_125 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ConcourseD_0391_E_White" }, -- Workspace.LobbyV4Staging.Concourse.LightingRig.StageSpot_7.E_White
	GGAsset_LobbyWorld_126 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ConcourseD_0395_E_White" }, -- Workspace.LobbyV4Staging.Concourse.LightingRig.StageSpot_8.E_White
	GGAsset_LobbyWorld_127 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "DuelsD_0036_E_White" }, -- Workspace.LobbyV4Staging.Duels.Pad_1v1_2.Pad_1v1_2.E_White
	GGAsset_LobbyWorld_128 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "DuelsD_0044_E_White" }, -- Workspace.LobbyV4Staging.Duels.PadSign.E_White
	GGAsset_LobbyWorld_129 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "DuelsD_0067_E_White" }, -- Workspace.LobbyV4Staging.Duels.PadSign_2.E_White
	GGAsset_LobbyWorld_130 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "DuelsD_0090_E_White" }, -- Workspace.LobbyV4Staging.Duels.PadSign_3.E_White
	GGAsset_LobbyWorld_131 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "DuelsD_0113_E_White" }, -- Workspace.LobbyV4Staging.Duels.PadSign_4.E_White
	GGAsset_LobbyWorld_132 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "DuelsD_0142_E_White" }, -- Workspace.LobbyV4Staging.Duels.PadSign_5.E_White
	GGAsset_LobbyWorld_133 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "DuelsD_0165_E_White" }, -- Workspace.LobbyV4Staging.Duels.PadSign_6.E_White
	GGAsset_LobbyWorld_134 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "DuelsD_0188_E_White" }, -- Workspace.LobbyV4Staging.Duels.PadSign_7.E_White
	GGAsset_LobbyWorld_135 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "DuelsD_0211_E_White" }, -- Workspace.LobbyV4Staging.Duels.PadSign_8.E_White
	GGAsset_LobbyWorld_136 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "DuelsD_0232_E_White" }, -- Workspace.LobbyV4Staging.Duels.Sign_Gauntlet.E_White
	GGAsset_LobbyWorld_137 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "DuelsD_0263_E_White" }, -- Workspace.LobbyV4Staging.Duels.BarLamp_16.E_White
	GGAsset_LobbyWorld_138 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "DuelsD_0387_E_White" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp.E_White
	GGAsset_LobbyWorld_139 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "DuelsD_0390_E_White" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_2.E_White
	GGAsset_LobbyWorld_140 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "DuelsD_0393_E_White" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_3.E_White
	GGAsset_LobbyWorld_141 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "DuelsD_0396_E_White" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_4.E_White
	GGAsset_LobbyWorld_142 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "DuelsD_0399_E_White" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_5.E_White
	GGAsset_LobbyWorld_143 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "DuelsD_0402_E_White" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_6.E_White
	GGAsset_LobbyWorld_144 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "DuelsD_0405_E_White" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_7.E_White
	GGAsset_LobbyWorld_145 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "DuelsD_0408_E_White" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_8.E_White
	GGAsset_LobbyWorld_146 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "DuelsD_0411_E_White" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_9.E_White
	GGAsset_LobbyWorld_147 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "DuelsD_0414_E_White" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_10.E_White
	GGAsset_LobbyWorld_148 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "DuelsD_0420_E_White" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_11.E_White
	GGAsset_LobbyWorld_149 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "DuelsD_0423_E_White" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_12.E_White
	GGAsset_LobbyWorld_150 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "DuelsD_0426_E_White" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_13.E_White
	GGAsset_LobbyWorld_151 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "DuelsD_0429_E_White" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_14.E_White
	GGAsset_LobbyWorld_152 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "DuelsD_0432_E_White" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_15.E_White
	GGAsset_LobbyWorld_153 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "DuelsD_0435_E_White" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_16.E_White
	GGAsset_LobbyWorld_154 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "DuelsD_0438_E_White" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_17.E_White
	GGAsset_LobbyWorld_155 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "DuelsD_0441_E_White" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_18.E_White
	GGAsset_LobbyWorld_156 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "LockerD_0030_E_White" }, -- Workspace.LobbyV4Staging.Locker.CeilingLamp.E_White
	GGAsset_LobbyWorld_157 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "LockerD_0033_E_White" }, -- Workspace.LobbyV4Staging.Locker.CeilingLamp_2.E_White
	GGAsset_LobbyWorld_158 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "LockerD_0036_E_White" }, -- Workspace.LobbyV4Staging.Locker.CeilingLamp_3.E_White
	GGAsset_LobbyWorld_159 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "LockerD_0039_E_White" }, -- Workspace.LobbyV4Staging.Locker.CeilingLamp_4.E_White
	GGAsset_LobbyWorld_160 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "LockerD_0045_E_White" }, -- Workspace.LobbyV4Staging.Locker.CeilingLamp_5.E_White
	GGAsset_LobbyWorld_161 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "LockerD_0048_E_White" }, -- Workspace.LobbyV4Staging.Locker.CeilingLamp_6.E_White
	GGAsset_LobbyWorld_162 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "LockerD_0100_E_White" }, -- Workspace.LobbyV4Staging.Locker.Table_Vandal.E_White
	GGAsset_LobbyWorld_163 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "LockerD_0109_E_White" }, -- Workspace.LobbyV4Staging.Locker.Table_Phantom.E_White
	GGAsset_LobbyWorld_164 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "LockerD_0118_E_White" }, -- Workspace.LobbyV4Staging.Locker.Table_Operator.E_White
	GGAsset_LobbyWorld_165 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "LockerD_0127_E_White" }, -- Workspace.LobbyV4Staging.Locker.Table_Odin.E_White
	GGAsset_LobbyWorld_166 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "LockerD_0136_E_White" }, -- Workspace.LobbyV4Staging.Locker.Table_Judge.E_White
	GGAsset_LobbyWorld_167 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "LockerD_0145_E_White" }, -- Workspace.LobbyV4Staging.Locker.Table_Spectre.E_White
	GGAsset_LobbyWorld_168 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "LockerD_0154_E_White" }, -- Workspace.LobbyV4Staging.Locker.Table_Sheriff.E_White
	GGAsset_LobbyWorld_169 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "LockerD_0163_E_White" }, -- Workspace.LobbyV4Staging.Locker.Table_Classic.E_White
	GGAsset_LobbyWorld_170 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "LockerD_0171_E_White" }, -- Workspace.LobbyV4Staging.Locker.Sign_Loadout.E_White
	GGAsset_LobbyWorld_171 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "LockerD_0176_E_White" }, -- Workspace.LobbyV4Staging.Locker.HangLamp.E_White
	GGAsset_LobbyWorld_172 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "LockerD_0180_E_White" }, -- Workspace.LobbyV4Staging.Locker.HangLamp_2.E_White
	GGAsset_LobbyWorld_173 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ShopD_0031_E_White" }, -- Workspace.LobbyV4Staging.Shop.BarLamp_28.E_White
	GGAsset_LobbyWorld_174 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ShopD_0063_E_White" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_7.E_White
	GGAsset_LobbyWorld_175 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ShopD_0066_E_White" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_8.E_White
	GGAsset_LobbyWorld_176 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ShopD_0069_E_White" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_9.E_White
	GGAsset_LobbyWorld_177 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ShopD_0072_E_White" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_10.E_White
	GGAsset_LobbyWorld_178 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ShopD_0075_E_White" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_11.E_White
	GGAsset_LobbyWorld_179 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ShopD_0083_E_White" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_12.E_White
	GGAsset_LobbyWorld_180 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ShopD_0086_E_White" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_13.E_White
	GGAsset_LobbyWorld_181 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ShopD_0089_E_White" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_14.E_White
	GGAsset_LobbyWorld_182 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ShopD_0092_E_White" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_15.E_White
	GGAsset_LobbyWorld_183 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ShopD_0095_E_White" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_16.E_White
	GGAsset_LobbyWorld_184 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ShopD_0098_E_White" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_17.E_White
	GGAsset_LobbyWorld_185 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ShopD_0146_E_White" }, -- Workspace.LobbyV4Staging.Shop.TV_ShopN.E_White
	GGAsset_LobbyWorld_186 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ShopD_0151_E_White" }, -- Workspace.LobbyV4Staging.Shop.TV_ShopS.E_White
	GGAsset_LobbyWorld_187 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ShopD_0179_E_White" }, -- Workspace.LobbyV4Staging.Shop.StageSpot.E_White
	GGAsset_LobbyWorld_188 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ShopD_0183_E_White" }, -- Workspace.LobbyV4Staging.Shop.StageSpot_2.E_White
	GGAsset_LobbyWorld_189 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ShopD_0187_E_White" }, -- Workspace.LobbyV4Staging.Shop.StageSpot_3.E_White
	GGAsset_LobbyWorld_190 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ShopD_0191_E_White" }, -- Workspace.LobbyV4Staging.Shop.Bay_FeaturedSign.E_White
	GGAsset_LobbyWorld_191 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ShopD_0222_E_White" }, -- Workspace.LobbyV4Staging.Shop.StageSpot_4.E_White
	GGAsset_LobbyWorld_192 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ShopD_0226_E_White" }, -- Workspace.LobbyV4Staging.Shop.StageSpot_5.E_White
	GGAsset_LobbyWorld_193 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ShopD_0230_E_White" }, -- Workspace.LobbyV4Staging.Shop.StageSpot_6.E_White
	GGAsset_LobbyWorld_194 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ShopD_0234_E_White" }, -- Workspace.LobbyV4Staging.Shop.Bay_SeasonSign.E_White
	GGAsset_LobbyWorld_195 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ShopD_0239_E_White" }, -- Workspace.LobbyV4Staging.Shop.SeasonCrest.E_White
	GGAsset_LobbyWorld_196 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ShopD_0257_E_White" }, -- Workspace.LobbyV4Staging.Shop.Case_Deals.E_White
	GGAsset_LobbyWorld_197 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ShopD_0267_E_White" }, -- Workspace.LobbyV4Staging.Shop.Case_Rare.E_White
	GGAsset_LobbyWorld_198 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ShopD_0277_E_White" }, -- Workspace.LobbyV4Staging.Shop.Case_New.E_White
	GGAsset_LobbyWorld_199 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ShopD_0287_E_White" }, -- Workspace.LobbyV4Staging.Shop.Case_Vault.E_White
	GGAsset_LobbyWorld_200 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ShopD_0353_E_White" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_18.E_White
	GGAsset_LobbyWorld_201 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ShopD_0359_E_White" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_19.E_White
	GGAsset_LobbyWorld_202 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ShopD_0362_E_White" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_20.E_White
	GGAsset_LobbyWorld_203 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ShopD_0375_E_White" }, -- Workspace.LobbyV4Staging.Shop.TV_ShopEnd.E_White
	GGAsset_LobbyWorld_204 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ShopD_0379_E_White" }, -- Workspace.LobbyV4Staging.Shop.Sign_Market.E_White
	GGAsset_LobbyWorld_205 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ShopD_0385_E_White" }, -- Workspace.LobbyV4Staging.Shop.TV_Broker.E_White
	GGAsset_LobbyWorld_206 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ShopD_0389_E_White" }, -- Workspace.LobbyV4Staging.Shop.Sign_Broker.E_White
	GGAsset_LobbyWorld_207 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ShopD_0439_E_White" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_21.E_White
	GGAsset_LobbyWorld_208 = { ["Ceil"] = false, ["SWMat"] = "E_White", ["SWName"] = "ShopD_0442_E_White" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_22.E_White
	GGAsset_LobbyWorld_209 = { ["Ceil"] = false, ["SWMat"] = "G_PadA", ["SWName"] = "DuelsD_0034_G_PadA" }, -- Workspace.LobbyV4Staging.Duels.Pad_1v1_2.Pad_1v1_2.G_PadA
	GGAsset_LobbyWorld_210 = { ["Ceil"] = false, ["SWMat"] = "G_PadB", ["SWName"] = "DuelsD_0038_G_PadB" }, -- Workspace.LobbyV4Staging.Duels.Pad_1v1_2.Pad_1v1_2.G_PadB
	GGAsset_LobbyWorld_211 = { ["Ceil"] = false, ["SWMat"] = "G_Screen", ["SWName"] = "DuelsD_0025_G_Screen" }, -- Workspace.LobbyV4Staging.Duels.Pad_1v1_2.Pad_1v1_2.G_Screen
	GGAsset_LobbyWorld_212 = { ["Ceil"] = false, ["SWMat"] = "G_Screen", ["SWName"] = "DuelsD_0371_G_Screen" }, -- Workspace.LobbyV4Staging.Duels.Jumbotron.G_Screen
	GGAsset_LobbyWorld_213 = { ["Ceil"] = false, ["SWMat"] = "Glass", ["SWName"] = "ShopD_0258_Glass" }, -- Workspace.LobbyV4Staging.Shop.Case_Deals.Glass
	GGAsset_LobbyWorld_214 = { ["Ceil"] = false, ["SWMat"] = "Glass", ["SWName"] = "ShopD_0268_Glass" }, -- Workspace.LobbyV4Staging.Shop.Case_Rare.Glass
	GGAsset_LobbyWorld_215 = { ["Ceil"] = false, ["SWMat"] = "Glass", ["SWName"] = "ShopD_0278_Glass" }, -- Workspace.LobbyV4Staging.Shop.Case_New.Glass
	GGAsset_LobbyWorld_216 = { ["Ceil"] = false, ["SWMat"] = "Glass", ["SWName"] = "ShopD_0288_Glass" }, -- Workspace.LobbyV4Staging.Shop.Case_Vault.Glass
	GGAsset_LobbyWorld_217 = { ["Ceil"] = false, ["SWMat"] = "H_Cone", ["SWName"] = "ConcourseD_0426_H_Cone" }, -- Workspace.LobbyV4Staging.Concourse.Holo_Gift.H_Cone
	GGAsset_LobbyWorld_218 = { ["Ceil"] = false, ["SWMat"] = "H_Cone", ["SWName"] = "ConcourseD_0435_H_Cone" }, -- Workspace.LobbyV4Staging.Concourse.Holo_Badge.H_Cone
	GGAsset_LobbyWorld_219 = { ["Ceil"] = false, ["SWMat"] = "H_Cone", ["SWName"] = "ConcourseD_0444_H_Cone" }, -- Workspace.LobbyV4Staging.Concourse.Holo_Rifle.H_Cone
	GGAsset_LobbyWorld_220 = { ["Ceil"] = false, ["SWMat"] = "H_Cone", ["SWName"] = "ConcourseD_0453_H_Cone" }, -- Workspace.LobbyV4Staging.Concourse.Holo_Crate.H_Cone
	GGAsset_LobbyWorld_221 = { ["Ceil"] = false, ["SWMat"] = "H_Cone", ["SWName"] = "ShopD_0417_H_Cone" }, -- Workspace.LobbyV4Staging.Shop.Holo_ShopGift.H_Cone
	GGAsset_LobbyWorld_222 = { ["Ceil"] = false, ["SWMat"] = "H_Cone", ["SWName"] = "ShopD_0426_H_Cone" }, -- Workspace.LobbyV4Staging.Shop.Holo_ShopBadge.H_Cone
	GGAsset_LobbyWorld_223 = { ["Ceil"] = false, ["SWMat"] = "H_Figure", ["SWName"] = "ShopD_0172_H_Figure" }, -- Workspace.LobbyV4Staging.Shop.Bay_Featured.Bay_FeaturedHolo1.H_Figure
	GGAsset_LobbyWorld_224 = { ["Ceil"] = false, ["SWMat"] = "H_Figure", ["SWName"] = "ShopD_0174_H_Figure" }, -- Workspace.LobbyV4Staging.Shop.Bay_Featured.Bay_FeaturedHolo2.H_Figure
	GGAsset_LobbyWorld_225 = { ["Ceil"] = false, ["SWMat"] = "H_Figure", ["SWName"] = "ShopD_0214_H_Figure" }, -- Workspace.LobbyV4Staging.Shop.Bay_Season.Bay_SeasonHolo1.H_Figure
	GGAsset_LobbyWorld_226 = { ["Ceil"] = false, ["SWMat"] = "H_Figure", ["SWName"] = "ShopD_0216_H_Figure" }, -- Workspace.LobbyV4Staging.Shop.Bay_Season.Bay_SeasonHolo2.H_Figure
	GGAsset_LobbyWorld_227 = { ["Ceil"] = false, ["SWMat"] = "H_Ghost", ["SWName"] = "ConcourseD_0428_H_Ghost" }, -- Workspace.LobbyV4Staging.Concourse.Holo_GiftItem.H_Ghost
	GGAsset_LobbyWorld_228 = { ["Ceil"] = false, ["SWMat"] = "H_Ghost", ["SWName"] = "ConcourseD_0437_H_Ghost" }, -- Workspace.LobbyV4Staging.Concourse.Holo_BadgeItem.H_Ghost
	GGAsset_LobbyWorld_229 = { ["Ceil"] = false, ["SWMat"] = "H_Ghost", ["SWName"] = "ConcourseD_0446_H_Ghost" }, -- Workspace.LobbyV4Staging.Concourse.Holo_RifleItem.H_Ghost
	GGAsset_LobbyWorld_230 = { ["Ceil"] = false, ["SWMat"] = "H_Ghost", ["SWName"] = "ConcourseD_0455_H_Ghost" }, -- Workspace.LobbyV4Staging.Concourse.Holo_CrateItem.H_Ghost
	GGAsset_LobbyWorld_231 = { ["Ceil"] = false, ["SWMat"] = "H_Ghost", ["SWName"] = "ShopD_0419_H_Ghost" }, -- Workspace.LobbyV4Staging.Shop.Holo_ShopGiftItem.H_Ghost
	GGAsset_LobbyWorld_232 = { ["Ceil"] = false, ["SWMat"] = "H_Ghost", ["SWName"] = "ShopD_0428_H_Ghost" }, -- Workspace.LobbyV4Staging.Shop.Holo_ShopBadgeItem.H_Ghost
	GGAsset_LobbyWorld_233 = { ["Ceil"] = false, ["SWMat"] = "H_Item", ["SWName"] = "ConcourseD_0424_H_Item" }, -- Workspace.LobbyV4Staging.Concourse.Holo_Gift.H_Item
	GGAsset_LobbyWorld_234 = { ["Ceil"] = false, ["SWMat"] = "H_Item", ["SWName"] = "ConcourseD_0427_H_Item" }, -- Workspace.LobbyV4Staging.Concourse.Holo_GiftItem.H_Item
	GGAsset_LobbyWorld_235 = { ["Ceil"] = false, ["SWMat"] = "H_Item", ["SWName"] = "ConcourseD_0433_H_Item" }, -- Workspace.LobbyV4Staging.Concourse.Holo_Badge.H_Item
	GGAsset_LobbyWorld_236 = { ["Ceil"] = false, ["SWMat"] = "H_Item", ["SWName"] = "ConcourseD_0436_H_Item" }, -- Workspace.LobbyV4Staging.Concourse.Holo_BadgeItem.H_Item
	GGAsset_LobbyWorld_237 = { ["Ceil"] = false, ["SWMat"] = "H_Item", ["SWName"] = "ConcourseD_0442_H_Item" }, -- Workspace.LobbyV4Staging.Concourse.Holo_Rifle.H_Item
	GGAsset_LobbyWorld_238 = { ["Ceil"] = false, ["SWMat"] = "H_Item", ["SWName"] = "ConcourseD_0445_H_Item" }, -- Workspace.LobbyV4Staging.Concourse.Holo_RifleItem.H_Item
	GGAsset_LobbyWorld_239 = { ["Ceil"] = false, ["SWMat"] = "H_Item", ["SWName"] = "ConcourseD_0451_H_Item" }, -- Workspace.LobbyV4Staging.Concourse.Holo_Crate.H_Item
	GGAsset_LobbyWorld_240 = { ["Ceil"] = false, ["SWMat"] = "H_Item", ["SWName"] = "ConcourseD_0454_H_Item" }, -- Workspace.LobbyV4Staging.Concourse.Holo_CrateItem.H_Item
	GGAsset_LobbyWorld_241 = { ["Ceil"] = false, ["SWMat"] = "H_Item", ["SWName"] = "ShopD_0171_H_Item" }, -- Workspace.LobbyV4Staging.Shop.Bay_Featured.Bay_FeaturedHolo1.H_Item
	GGAsset_LobbyWorld_242 = { ["Ceil"] = false, ["SWMat"] = "H_Item", ["SWName"] = "ShopD_0173_H_Item" }, -- Workspace.LobbyV4Staging.Shop.Bay_Featured.Bay_FeaturedHolo2.H_Item
	GGAsset_LobbyWorld_243 = { ["Ceil"] = false, ["SWMat"] = "H_Item", ["SWName"] = "ShopD_0213_H_Item" }, -- Workspace.LobbyV4Staging.Shop.Bay_Season.Bay_SeasonHolo1.H_Item
	GGAsset_LobbyWorld_244 = { ["Ceil"] = false, ["SWMat"] = "H_Item", ["SWName"] = "ShopD_0215_H_Item" }, -- Workspace.LobbyV4Staging.Shop.Bay_Season.Bay_SeasonHolo2.H_Item
	GGAsset_LobbyWorld_245 = { ["Ceil"] = false, ["SWMat"] = "H_Item", ["SWName"] = "ShopD_0415_H_Item" }, -- Workspace.LobbyV4Staging.Shop.Holo_ShopGift.H_Item
	GGAsset_LobbyWorld_246 = { ["Ceil"] = false, ["SWMat"] = "H_Item", ["SWName"] = "ShopD_0418_H_Item" }, -- Workspace.LobbyV4Staging.Shop.Holo_ShopGiftItem.H_Item
	GGAsset_LobbyWorld_247 = { ["Ceil"] = false, ["SWMat"] = "H_Item", ["SWName"] = "ShopD_0424_H_Item" }, -- Workspace.LobbyV4Staging.Shop.Holo_ShopBadge.H_Item
	GGAsset_LobbyWorld_248 = { ["Ceil"] = false, ["SWMat"] = "H_Item", ["SWName"] = "ShopD_0427_H_Item" }, -- Workspace.LobbyV4Staging.Shop.Holo_ShopBadgeItem.H_Item
	GGAsset_LobbyWorld_249 = { ["Ceil"] = false, ["SWMat"] = "H_Ring", ["SWName"] = "ConcourseD_0425_H_Ring" }, -- Workspace.LobbyV4Staging.Concourse.Holo_Gift.H_Ring
	GGAsset_LobbyWorld_250 = { ["Ceil"] = false, ["SWMat"] = "H_Ring", ["SWName"] = "ConcourseD_0434_H_Ring" }, -- Workspace.LobbyV4Staging.Concourse.Holo_Badge.H_Ring
	GGAsset_LobbyWorld_251 = { ["Ceil"] = false, ["SWMat"] = "H_Ring", ["SWName"] = "ConcourseD_0443_H_Ring" }, -- Workspace.LobbyV4Staging.Concourse.Holo_Rifle.H_Ring
	GGAsset_LobbyWorld_252 = { ["Ceil"] = false, ["SWMat"] = "H_Ring", ["SWName"] = "ConcourseD_0452_H_Ring" }, -- Workspace.LobbyV4Staging.Concourse.Holo_Crate.H_Ring
	GGAsset_LobbyWorld_253 = { ["Ceil"] = false, ["SWMat"] = "H_Ring", ["SWName"] = "ShopD_0416_H_Ring" }, -- Workspace.LobbyV4Staging.Shop.Holo_ShopGift.H_Ring
	GGAsset_LobbyWorld_254 = { ["Ceil"] = false, ["SWMat"] = "H_Ring", ["SWName"] = "ShopD_0425_H_Ring" }, -- Workspace.LobbyV4Staging.Shop.Holo_ShopBadge.H_Ring
	GGAsset_LobbyWorld_255 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "ConcourseD_0025_V_Base" }, -- Workspace.LobbyV4Staging.Concourse.Pier.V_Base
	GGAsset_LobbyWorld_256 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "ConcourseD_0152_V_Base" }, -- Workspace.LobbyV4Staging.Concourse.Wall.V_Base
	GGAsset_LobbyWorld_257 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "ConcourseD_0157_V_Base" }, -- Workspace.LobbyV4Staging.Concourse.Wall_2.V_Base
	GGAsset_LobbyWorld_258 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "ConcourseD_0162_V_Base" }, -- Workspace.LobbyV4Staging.Concourse.Wall_3.V_Base
	GGAsset_LobbyWorld_259 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "ConcourseD_0167_V_Base" }, -- Workspace.LobbyV4Staging.Concourse.Wall_4.V_Base
	GGAsset_LobbyWorld_260 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "ConcourseD_0179_V_Base" }, -- Workspace.LobbyV4Staging.Concourse.Gate_Duels.V_Base
	GGAsset_LobbyWorld_261 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "ConcourseD_0185_V_Base" }, -- Workspace.LobbyV4Staging.Concourse.Hazard.V_Base
	GGAsset_LobbyWorld_262 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "ConcourseD_0187_V_Base" }, -- Workspace.LobbyV4Staging.Concourse.Hazard_2.V_Base
	GGAsset_LobbyWorld_263 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "ConcourseD_0202_V_Base" }, -- Workspace.LobbyV4Staging.Concourse.Gate_Shop.V_Base
	GGAsset_LobbyWorld_264 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "ConcourseD_0208_V_Base" }, -- Workspace.LobbyV4Staging.Concourse.Hazard_3.V_Base
	GGAsset_LobbyWorld_265 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "ConcourseD_0210_V_Base" }, -- Workspace.LobbyV4Staging.Concourse.Hazard_4.V_Base
	GGAsset_LobbyWorld_266 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "ConcourseD_0225_V_Base" }, -- Workspace.LobbyV4Staging.Concourse.Gate_Locker.V_Base
	GGAsset_LobbyWorld_267 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "ConcourseD_0231_V_Base" }, -- Workspace.LobbyV4Staging.Concourse.Hazard_5.V_Base
	GGAsset_LobbyWorld_268 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "ConcourseD_0233_V_Base" }, -- Workspace.LobbyV4Staging.Concourse.Hazard_6.V_Base
	GGAsset_LobbyWorld_269 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "ConcourseD_0248_V_Base" }, -- Workspace.LobbyV4Staging.Concourse.Gate_Range.V_Base
	GGAsset_LobbyWorld_270 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "ConcourseD_0254_V_Base" }, -- Workspace.LobbyV4Staging.Concourse.Hazard_7.V_Base
	GGAsset_LobbyWorld_271 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "ConcourseD_0256_V_Base" }, -- Workspace.LobbyV4Staging.Concourse.Hazard_8.V_Base
	GGAsset_LobbyWorld_272 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "ConcourseD_0267_V_Base" }, -- Workspace.LobbyV4Staging.Concourse.Wall_5.V_Base
	GGAsset_LobbyWorld_273 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "ConcourseD_0289_V_Base" }, -- Workspace.LobbyV4Staging.Concourse.Wall_6.V_Base
	GGAsset_LobbyWorld_274 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "ConcourseD_0311_V_Base" }, -- Workspace.LobbyV4Staging.Concourse.Wall_7.V_Base
	GGAsset_LobbyWorld_275 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "ConcourseD_0333_V_Base" }, -- Workspace.LobbyV4Staging.Concourse.Wall_8.V_Base
	GGAsset_LobbyWorld_276 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "ConcourseD_0398_V_Base" }, -- Workspace.LobbyV4Staging.Concourse.Vents.V_Base
	GGAsset_LobbyWorld_277 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "ConcourseD_0402_V_Base" }, -- Workspace.LobbyV4Staging.Concourse.Vents_2.V_Base
	GGAsset_LobbyWorld_278 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "ConcourseD_0406_V_Base" }, -- Workspace.LobbyV4Staging.Concourse.Vents_3.V_Base
	GGAsset_LobbyWorld_279 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "ConcourseD_0410_V_Base" }, -- Workspace.LobbyV4Staging.Concourse.Vents_4.V_Base
	GGAsset_LobbyWorld_280 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "Concourse_0246_V_Base" }, -- Workspace.LobbyV4Staging.Concourse.Portal_Range.V_Base
	GGAsset_LobbyWorld_281 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "Concourse_0354_V_Base" }, -- Workspace.LobbyV4Staging.Concourse.Bench.V_Base
	GGAsset_LobbyWorld_282 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "Concourse_0420_V_Base" }, -- Workspace.LobbyV4Staging.Concourse.Holo_Gift.V_Base
	GGAsset_LobbyWorld_283 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "Concourse_0429_V_Base" }, -- Workspace.LobbyV4Staging.Concourse.Holo_Badge.V_Base
	GGAsset_LobbyWorld_284 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "Concourse_0438_V_Base" }, -- Workspace.LobbyV4Staging.Concourse.Holo_Rifle.V_Base
	GGAsset_LobbyWorld_285 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "Concourse_0447_V_Base" }, -- Workspace.LobbyV4Staging.Concourse.Holo_Crate.V_Base
	GGAsset_LobbyWorld_286 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "DuelsD_0018_V_Base" }, -- Workspace.LobbyV4Staging.Duels.Wall_9.V_Base
	GGAsset_LobbyWorld_287 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "DuelsD_0030_V_Base" }, -- Workspace.LobbyV4Staging.Duels.Pad_1v1_2.Pad_1v1_2.V_Base
	GGAsset_LobbyWorld_288 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "DuelsD_0039_V_Base" }, -- Workspace.LobbyV4Staging.Duels.Hazard_9.V_Base
	GGAsset_LobbyWorld_289 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "DuelsD_0054_V_Base" }, -- Workspace.LobbyV4Staging.Duels.Pad_1v1_2.Hazard.V_Base
	GGAsset_LobbyWorld_290 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "DuelsD_0062_V_Base" }, -- Workspace.LobbyV4Staging.Duels.Hazard_10.V_Base
	GGAsset_LobbyWorld_291 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "DuelsD_0077_V_Base" }, -- Workspace.LobbyV4Staging.Duels.Pad_2v2.Hazard.V_Base
	GGAsset_LobbyWorld_292 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "DuelsD_0085_V_Base" }, -- Workspace.LobbyV4Staging.Duels.Hazard_11.V_Base
	GGAsset_LobbyWorld_293 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "DuelsD_0100_V_Base" }, -- Workspace.LobbyV4Staging.Duels.Pad_2v2_2.Hazard.V_Base
	GGAsset_LobbyWorld_294 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "DuelsD_0108_V_Base" }, -- Workspace.LobbyV4Staging.Duels.Hazard_12.V_Base
	GGAsset_LobbyWorld_295 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "DuelsD_0116_V_Base" }, -- Workspace.LobbyV4Staging.Duels.Wall_10.V_Base
	GGAsset_LobbyWorld_296 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "DuelsD_0129_V_Base" }, -- Workspace.LobbyV4Staging.Duels.Pad_3v3.Hazard.V_Base
	GGAsset_LobbyWorld_297 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "DuelsD_0137_V_Base" }, -- Workspace.LobbyV4Staging.Duels.Hazard_13.V_Base
	GGAsset_LobbyWorld_298 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "DuelsD_0152_V_Base" }, -- Workspace.LobbyV4Staging.Duels.Pad_3v3_2.Hazard.V_Base
	GGAsset_LobbyWorld_299 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "DuelsD_0160_V_Base" }, -- Workspace.LobbyV4Staging.Duels.Hazard_14.V_Base
	GGAsset_LobbyWorld_300 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "DuelsD_0175_V_Base" }, -- Workspace.LobbyV4Staging.Duels.Pad_4v4.Hazard.V_Base
	GGAsset_LobbyWorld_301 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "DuelsD_0183_V_Base" }, -- Workspace.LobbyV4Staging.Duels.Hazard_15.V_Base
	GGAsset_LobbyWorld_302 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "DuelsD_0198_V_Base" }, -- Workspace.LobbyV4Staging.Duels.Pad_5v5.Hazard.V_Base
	GGAsset_LobbyWorld_303 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "DuelsD_0206_V_Base" }, -- Workspace.LobbyV4Staging.Duels.Hazard_16.V_Base
	GGAsset_LobbyWorld_304 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "DuelsD_0214_V_Base" }, -- Workspace.LobbyV4Staging.Duels.Wall_11.V_Base
	GGAsset_LobbyWorld_305 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "DuelsD_0221_V_Base" }, -- Workspace.LobbyV4Staging.Duels.ApseVents.V_Base
	GGAsset_LobbyWorld_306 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "DuelsD_0224_V_Base" }, -- Workspace.LobbyV4Staging.Duels.Wall_12.V_Base
	GGAsset_LobbyWorld_307 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "DuelsD_0235_V_Base" }, -- Workspace.LobbyV4Staging.Duels.Wall_13.V_Base
	GGAsset_LobbyWorld_308 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "DuelsD_0242_V_Base" }, -- Workspace.LobbyV4Staging.Duels.ApseVents_2.V_Base
	GGAsset_LobbyWorld_309 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "DuelsD_0249_V_Base" }, -- Workspace.LobbyV4Staging.Duels.FrontDetails.V_Base
	GGAsset_LobbyWorld_310 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "DuelsD_0251_V_Base" }, -- Workspace.LobbyV4Staging.Duels.Wall_14.V_Base
	GGAsset_LobbyWorld_311 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "DuelsD_0256_V_Base" }, -- Workspace.LobbyV4Staging.Duels.Pier_10.V_Base
	GGAsset_LobbyWorld_312 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "DuelsD_0320_V_Base" }, -- Workspace.LobbyV4Staging.Duels.CornerPier_4.V_Base
	GGAsset_LobbyWorld_313 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "DuelsD_0379_V_Base" }, -- Workspace.LobbyV4Staging.Duels.Trophy.V_Base
	GGAsset_LobbyWorld_314 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "Duels_0373_V_Base" }, -- Workspace.LobbyV4Staging.Duels.TrophyPlinth.V_Base
	GGAsset_LobbyWorld_315 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "LockerD_0002_V_Base" }, -- Workspace.LobbyV4Staging.Locker.Wall_15.V_Base
	GGAsset_LobbyWorld_316 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "LockerD_0008_V_Base" }, -- Workspace.LobbyV4Staging.Locker.Wall_16.V_Base
	GGAsset_LobbyWorld_317 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "LockerD_0014_V_Base" }, -- Workspace.LobbyV4Staging.Locker.Wall_17.V_Base
	GGAsset_LobbyWorld_318 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "LockerD_0019_V_Base" }, -- Workspace.LobbyV4Staging.Locker.Wall_18.V_Base
	GGAsset_LobbyWorld_319 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "LockerD_0055_V_Base" }, -- Workspace.LobbyV4Staging.Locker.Wall_19.V_Base
	GGAsset_LobbyWorld_320 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "LockerD_0061_V_Base" }, -- Workspace.LobbyV4Staging.Locker.Wall_20.V_Base
	GGAsset_LobbyWorld_321 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "LockerD_0067_V_Base" }, -- Workspace.LobbyV4Staging.Locker.Wall_21.V_Base
	GGAsset_LobbyWorld_322 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "LockerD_0073_V_Base" }, -- Workspace.LobbyV4Staging.Locker.Wall_22.V_Base
	GGAsset_LobbyWorld_323 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "LockerD_0097_V_Base" }, -- Workspace.LobbyV4Staging.Locker.Table_Vandal.V_Base
	GGAsset_LobbyWorld_324 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "LockerD_0106_V_Base" }, -- Workspace.LobbyV4Staging.Locker.Table_Phantom.V_Base
	GGAsset_LobbyWorld_325 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "LockerD_0115_V_Base" }, -- Workspace.LobbyV4Staging.Locker.Table_Operator.V_Base
	GGAsset_LobbyWorld_326 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "LockerD_0124_V_Base" }, -- Workspace.LobbyV4Staging.Locker.Table_Odin.V_Base
	GGAsset_LobbyWorld_327 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "LockerD_0133_V_Base" }, -- Workspace.LobbyV4Staging.Locker.Table_Judge.V_Base
	GGAsset_LobbyWorld_328 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "LockerD_0142_V_Base" }, -- Workspace.LobbyV4Staging.Locker.Table_Spectre.V_Base
	GGAsset_LobbyWorld_329 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "LockerD_0151_V_Base" }, -- Workspace.LobbyV4Staging.Locker.Table_Sheriff.V_Base
	GGAsset_LobbyWorld_330 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "LockerD_0160_V_Base" }, -- Workspace.LobbyV4Staging.Locker.Table_Classic.V_Base
	GGAsset_LobbyWorld_331 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "LockerD_0185_V_Base" }, -- Workspace.LobbyV4Staging.Locker.Vents_N.V_Base
	GGAsset_LobbyWorld_332 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "LockerD_0189_V_Base" }, -- Workspace.LobbyV4Staging.Locker.Vents_S.V_Base
	GGAsset_LobbyWorld_333 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "Locker_0087_V_Base" }, -- Workspace.LobbyV4Staging.Locker.KnifePlinth.V_Base
	GGAsset_LobbyWorld_334 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "ShopD_0002_V_Base" }, -- Workspace.LobbyV4Staging.Shop.Wall_23.V_Base
	GGAsset_LobbyWorld_335 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "ShopD_0008_V_Base" }, -- Workspace.LobbyV4Staging.Shop.Wall_24.V_Base
	GGAsset_LobbyWorld_336 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "ShopD_0014_V_Base" }, -- Workspace.LobbyV4Staging.Shop.Wall_25.V_Base
	GGAsset_LobbyWorld_337 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "ShopD_0020_V_Base" }, -- Workspace.LobbyV4Staging.Shop.Wall_26.V_Base
	GGAsset_LobbyWorld_338 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "ShopD_0024_V_Base" }, -- Workspace.LobbyV4Staging.Shop.CornerPier_13.V_Base
	GGAsset_LobbyWorld_339 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "ShopD_0110_V_Base" }, -- Workspace.LobbyV4Staging.Shop.Pier_19.V_Base
	GGAsset_LobbyWorld_340 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "ShopD_0154_V_Base" }, -- Workspace.LobbyV4Staging.Shop.Vents_5.V_Base
	GGAsset_LobbyWorld_341 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "ShopD_0158_V_Base" }, -- Workspace.LobbyV4Staging.Shop.Vents_6.V_Base
	GGAsset_LobbyWorld_342 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "ShopD_0193_V_Base" }, -- Workspace.LobbyV4Staging.Shop.FeaturedPedestal.V_Base
	GGAsset_LobbyWorld_343 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "ShopD_0198_V_Base" }, -- Workspace.LobbyV4Staging.Shop.Mark_Featured.Mark_Featured.V_Base
	GGAsset_LobbyWorld_344 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "ShopD_0202_V_Base" }, -- Workspace.LobbyV4Staging.Shop.Mark_Featured.Hazard.V_Base
	GGAsset_LobbyWorld_345 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "ShopD_0236_V_Base" }, -- Workspace.LobbyV4Staging.Shop.SeasonCrest.V_Base
	GGAsset_LobbyWorld_346 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "ShopD_0241_V_Base" }, -- Workspace.LobbyV4Staging.Shop.Mark_Season.Mark_Season.V_Base
	GGAsset_LobbyWorld_347 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "ShopD_0245_V_Base" }, -- Workspace.LobbyV4Staging.Shop.Mark_Season.Hazard.V_Base
	GGAsset_LobbyWorld_348 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "ShopD_0252_V_Base" }, -- Workspace.LobbyV4Staging.Shop.Case_Deals.V_Base
	GGAsset_LobbyWorld_349 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "ShopD_0262_V_Base" }, -- Workspace.LobbyV4Staging.Shop.Case_Rare.V_Base
	GGAsset_LobbyWorld_350 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "ShopD_0272_V_Base" }, -- Workspace.LobbyV4Staging.Shop.Case_New.V_Base
	GGAsset_LobbyWorld_351 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "ShopD_0282_V_Base" }, -- Workspace.LobbyV4Staging.Shop.Case_Vault.V_Base
	GGAsset_LobbyWorld_352 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "ShopD_0292_V_Base" }, -- Workspace.LobbyV4Staging.Shop.Wall_27.V_Base
	GGAsset_LobbyWorld_353 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "ShopD_0298_V_Base" }, -- Workspace.LobbyV4Staging.Shop.Wall_28.V_Base
	GGAsset_LobbyWorld_354 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "ShopD_0303_V_Base" }, -- Workspace.LobbyV4Staging.Shop.Wall_29.V_Base
	GGAsset_LobbyWorld_355 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "ShopD_0309_V_Base" }, -- Workspace.LobbyV4Staging.Shop.Wall_30.V_Base
	GGAsset_LobbyWorld_356 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "ShopD_0429_V_Base" }, -- Workspace.LobbyV4Staging.Shop.Path_2.V_Base
	GGAsset_LobbyWorld_357 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "ShopD_0432_V_Base" }, -- Workspace.LobbyV4Staging.Shop.Path_3.V_Base
	GGAsset_LobbyWorld_358 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "ShopD_0435_V_Base" }, -- Workspace.LobbyV4Staging.Shop.PathCorner.V_Base
	GGAsset_LobbyWorld_359 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "Shop_0391_V_Base" }, -- Workspace.LobbyV4Staging.Shop.BrokerBundle.V_Base
	GGAsset_LobbyWorld_360 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "Shop_0400_V_Base" }, -- Workspace.LobbyV4Staging.Shop.BrokerEffect.V_Base
	GGAsset_LobbyWorld_361 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "Shop_0411_V_Base" }, -- Workspace.LobbyV4Staging.Shop.Holo_ShopGift.V_Base
	GGAsset_LobbyWorld_362 = { ["Ceil"] = false, ["SWMat"] = "V_Base", ["SWName"] = "Shop_0420_V_Base" }, -- Workspace.LobbyV4Staging.Shop.Holo_ShopBadge.V_Base
	GGAsset_LobbyWorld_363 = { ["Ceil"] = false, ["SWMat"] = "V_Beam", ["SWName"] = "ConcourseD_0146_V_Beam" }, -- Workspace.LobbyV4Staging.Concourse.Lantern.V_Beam
	GGAsset_LobbyWorld_364 = { ["Ceil"] = false, ["SWMat"] = "V_Beam", ["SWName"] = "DuelsD_0385_V_Beam" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.NaveVault.V_Beam
	GGAsset_LobbyWorld_365 = { ["Ceil"] = false, ["SWMat"] = "V_Beam", ["SWName"] = "DuelsD_0418_V_Beam" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.DuelsCeiling.V_Beam
	GGAsset_LobbyWorld_366 = { ["Ceil"] = false, ["SWMat"] = "V_Beam", ["SWName"] = "LockerD_0028_V_Beam" }, -- Workspace.LobbyV4Staging.Locker.RoomVault.V_Beam
	GGAsset_LobbyWorld_367 = { ["Ceil"] = false, ["SWMat"] = "V_Beam", ["SWName"] = "ShopD_0061_V_Beam" }, -- Workspace.LobbyV4Staging.Shop.RoomVault_2.V_Beam
	GGAsset_LobbyWorld_368 = { ["Ceil"] = false, ["SWMat"] = "V_Beam", ["SWName"] = "ShopD_0080_V_Beam" }, -- Workspace.LobbyV4Staging.Shop.Beam.V_Beam
	GGAsset_LobbyWorld_369 = { ["Ceil"] = false, ["SWMat"] = "V_Beam", ["SWName"] = "ShopD_0081_V_Beam" }, -- Workspace.LobbyV4Staging.Shop.Beam_2.V_Beam
	GGAsset_LobbyWorld_370 = { ["Ceil"] = false, ["SWMat"] = "V_Beam", ["SWName"] = "ShopD_0351_V_Beam" }, -- Workspace.LobbyV4Staging.Shop.RoomVault_3.V_Beam
	GGAsset_LobbyWorld_371 = { ["Ceil"] = false, ["SWMat"] = "V_Ceil", ["SWName"] = "Duels_0380_V_Ceil" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.Ceiling.V_Ceil
	GGAsset_LobbyWorld_372 = { ["Ceil"] = false, ["SWMat"] = "V_Ceil", ["SWName"] = "Duels_0384_V_Ceil" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.NaveVault.V_Ceil
	GGAsset_LobbyWorld_373 = { ["Ceil"] = false, ["SWMat"] = "V_Ceil", ["SWName"] = "Duels_0416_V_Ceil" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.DuelsCeiling.V_Ceil
	GGAsset_LobbyWorld_374 = { ["Ceil"] = false, ["SWMat"] = "V_Ceil", ["SWName"] = "Locker_0023_V_Ceil" }, -- Workspace.LobbyV4Staging.Locker.Ceiling.V_Ceil
	GGAsset_LobbyWorld_375 = { ["Ceil"] = false, ["SWMat"] = "V_Ceil", ["SWName"] = "Locker_0027_V_Ceil" }, -- Workspace.LobbyV4Staging.Locker.RoomVault.V_Ceil
	GGAsset_LobbyWorld_376 = { ["Ceil"] = false, ["SWMat"] = "V_Ceil", ["SWName"] = "Shop_0056_V_Ceil" }, -- Workspace.LobbyV4Staging.Shop.Ceiling_2.V_Ceil
	GGAsset_LobbyWorld_377 = { ["Ceil"] = false, ["SWMat"] = "V_Ceil", ["SWName"] = "Shop_0060_V_Ceil" }, -- Workspace.LobbyV4Staging.Shop.RoomVault_2.V_Ceil
	GGAsset_LobbyWorld_378 = { ["Ceil"] = false, ["SWMat"] = "V_Ceil", ["SWName"] = "Shop_0346_V_Ceil" }, -- Workspace.LobbyV4Staging.Shop.Ceiling_3.V_Ceil
	GGAsset_LobbyWorld_379 = { ["Ceil"] = false, ["SWMat"] = "V_Ceil", ["SWName"] = "Shop_0350_V_Ceil" }, -- Workspace.LobbyV4Staging.Shop.RoomVault_3.V_Ceil
	GGAsset_LobbyWorld_380 = { ["Ceil"] = false, ["SWMat"] = "V_Crate", ["SWName"] = "LockerD_0098_V_Crate" }, -- Workspace.LobbyV4Staging.Locker.Table_Vandal.V_Crate
	GGAsset_LobbyWorld_381 = { ["Ceil"] = false, ["SWMat"] = "V_Crate", ["SWName"] = "LockerD_0107_V_Crate" }, -- Workspace.LobbyV4Staging.Locker.Table_Phantom.V_Crate
	GGAsset_LobbyWorld_382 = { ["Ceil"] = false, ["SWMat"] = "V_Crate", ["SWName"] = "LockerD_0116_V_Crate" }, -- Workspace.LobbyV4Staging.Locker.Table_Operator.V_Crate
	GGAsset_LobbyWorld_383 = { ["Ceil"] = false, ["SWMat"] = "V_Crate", ["SWName"] = "LockerD_0125_V_Crate" }, -- Workspace.LobbyV4Staging.Locker.Table_Odin.V_Crate
	GGAsset_LobbyWorld_384 = { ["Ceil"] = false, ["SWMat"] = "V_Crate", ["SWName"] = "LockerD_0134_V_Crate" }, -- Workspace.LobbyV4Staging.Locker.Table_Judge.V_Crate
	GGAsset_LobbyWorld_385 = { ["Ceil"] = false, ["SWMat"] = "V_Crate", ["SWName"] = "LockerD_0143_V_Crate" }, -- Workspace.LobbyV4Staging.Locker.Table_Spectre.V_Crate
	GGAsset_LobbyWorld_386 = { ["Ceil"] = false, ["SWMat"] = "V_Crate", ["SWName"] = "LockerD_0152_V_Crate" }, -- Workspace.LobbyV4Staging.Locker.Table_Sheriff.V_Crate
	GGAsset_LobbyWorld_387 = { ["Ceil"] = false, ["SWMat"] = "V_Crate", ["SWName"] = "LockerD_0161_V_Crate" }, -- Workspace.LobbyV4Staging.Locker.Table_Classic.V_Crate
	GGAsset_LobbyWorld_388 = { ["Ceil"] = false, ["SWMat"] = "V_Crate", ["SWName"] = "ShopD_0395_V_Crate" }, -- Workspace.LobbyV4Staging.Shop.BrokerBundle.V_Crate
	GGAsset_LobbyWorld_389 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ConcourseD_0011_V_Dark" }, -- Workspace.LobbyV4Staging.Concourse.HubFloor.HubFloor.V_Dark
	GGAsset_LobbyWorld_390 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ConcourseD_0031_V_Dark" }, -- Workspace.LobbyV4Staging.Concourse.BarLamp_5.V_Dark
	GGAsset_LobbyWorld_391 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ConcourseD_0108_V_Dark" }, -- Workspace.LobbyV4Staging.Concourse.HubCeiling.CeilingLamp.V_Dark
	GGAsset_LobbyWorld_392 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ConcourseD_0111_V_Dark" }, -- Workspace.LobbyV4Staging.Concourse.HubCeiling.CeilingLamp_2.V_Dark
	GGAsset_LobbyWorld_393 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ConcourseD_0114_V_Dark" }, -- Workspace.LobbyV4Staging.Concourse.HubCeiling.CeilingLamp_3.V_Dark
	GGAsset_LobbyWorld_394 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ConcourseD_0117_V_Dark" }, -- Workspace.LobbyV4Staging.Concourse.HubCeiling.CeilingLamp_4.V_Dark
	GGAsset_LobbyWorld_395 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ConcourseD_0120_V_Dark" }, -- Workspace.LobbyV4Staging.Concourse.HubCeiling.CeilingLamp_5.V_Dark
	GGAsset_LobbyWorld_396 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ConcourseD_0123_V_Dark" }, -- Workspace.LobbyV4Staging.Concourse.HubCeiling.CeilingLamp_6.V_Dark
	GGAsset_LobbyWorld_397 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ConcourseD_0126_V_Dark" }, -- Workspace.LobbyV4Staging.Concourse.HubCeiling.CeilingLamp_7.V_Dark
	GGAsset_LobbyWorld_398 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ConcourseD_0129_V_Dark" }, -- Workspace.LobbyV4Staging.Concourse.HubCeiling.CeilingLamp_8.V_Dark
	GGAsset_LobbyWorld_399 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ConcourseD_0147_V_Dark" }, -- Workspace.LobbyV4Staging.Concourse.LightRing.V_Dark
	GGAsset_LobbyWorld_400 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ConcourseD_0183_V_Dark" }, -- Workspace.LobbyV4Staging.Concourse.Gate_Duels.V_Dark
	GGAsset_LobbyWorld_401 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ConcourseD_0189_V_Dark" }, -- Workspace.LobbyV4Staging.Concourse.Sign_Duels.V_Dark
	GGAsset_LobbyWorld_402 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ConcourseD_0206_V_Dark" }, -- Workspace.LobbyV4Staging.Concourse.Gate_Shop.V_Dark
	GGAsset_LobbyWorld_403 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ConcourseD_0212_V_Dark" }, -- Workspace.LobbyV4Staging.Concourse.Sign_Shop.V_Dark
	GGAsset_LobbyWorld_404 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ConcourseD_0229_V_Dark" }, -- Workspace.LobbyV4Staging.Concourse.Gate_Locker.V_Dark
	GGAsset_LobbyWorld_405 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ConcourseD_0235_V_Dark" }, -- Workspace.LobbyV4Staging.Concourse.Sign_Locker.V_Dark
	GGAsset_LobbyWorld_406 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ConcourseD_0252_V_Dark" }, -- Workspace.LobbyV4Staging.Concourse.Gate_Range.V_Dark
	GGAsset_LobbyWorld_407 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ConcourseD_0259_V_Dark" }, -- Workspace.LobbyV4Staging.Concourse.RangeDoor.V_Dark
	GGAsset_LobbyWorld_408 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ConcourseD_0261_V_Dark" }, -- Workspace.LobbyV4Staging.Concourse.Sign_Range.V_Dark
	GGAsset_LobbyWorld_409 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ConcourseD_0276_V_Dark" }, -- Workspace.LobbyV4Staging.Concourse.Gallery.Deck.V_Dark
	GGAsset_LobbyWorld_410 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ConcourseD_0285_V_Dark" }, -- Workspace.LobbyV4Staging.Concourse.TV_TOPWINS.V_Dark
	GGAsset_LobbyWorld_411 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ConcourseD_0298_V_Dark" }, -- Workspace.LobbyV4Staging.Concourse.Gallery_2.Deck.V_Dark
	GGAsset_LobbyWorld_412 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ConcourseD_0307_V_Dark" }, -- Workspace.LobbyV4Staging.Concourse.TV_WINSTREAKS.V_Dark
	GGAsset_LobbyWorld_413 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ConcourseD_0320_V_Dark" }, -- Workspace.LobbyV4Staging.Concourse.Gallery_3.Deck.V_Dark
	GGAsset_LobbyWorld_414 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ConcourseD_0329_V_Dark" }, -- Workspace.LobbyV4Staging.Concourse.TV_News.V_Dark
	GGAsset_LobbyWorld_415 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ConcourseD_0342_V_Dark" }, -- Workspace.LobbyV4Staging.Concourse.Gallery_4.Deck.V_Dark
	GGAsset_LobbyWorld_416 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ConcourseD_0351_V_Dark" }, -- Workspace.LobbyV4Staging.Concourse.TV_Featured.V_Dark
	GGAsset_LobbyWorld_417 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ConcourseD_0362_V_Dark" }, -- Workspace.LobbyV4Staging.Concourse.LightingRig.LightingRig.V_Dark
	GGAsset_LobbyWorld_418 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ConcourseD_0364_V_Dark" }, -- Workspace.LobbyV4Staging.Concourse.LightingRig.StageSpot.V_Dark
	GGAsset_LobbyWorld_419 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ConcourseD_0368_V_Dark" }, -- Workspace.LobbyV4Staging.Concourse.LightingRig.StageSpot_2.V_Dark
	GGAsset_LobbyWorld_420 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ConcourseD_0372_V_Dark" }, -- Workspace.LobbyV4Staging.Concourse.LightingRig.StageSpot_3.V_Dark
	GGAsset_LobbyWorld_421 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ConcourseD_0376_V_Dark" }, -- Workspace.LobbyV4Staging.Concourse.LightingRig.StageSpot_4.V_Dark
	GGAsset_LobbyWorld_422 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ConcourseD_0380_V_Dark" }, -- Workspace.LobbyV4Staging.Concourse.LightingRig.StageSpot_5.V_Dark
	GGAsset_LobbyWorld_423 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ConcourseD_0384_V_Dark" }, -- Workspace.LobbyV4Staging.Concourse.LightingRig.StageSpot_6.V_Dark
	GGAsset_LobbyWorld_424 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ConcourseD_0388_V_Dark" }, -- Workspace.LobbyV4Staging.Concourse.LightingRig.StageSpot_7.V_Dark
	GGAsset_LobbyWorld_425 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ConcourseD_0392_V_Dark" }, -- Workspace.LobbyV4Staging.Concourse.LightingRig.StageSpot_8.V_Dark
	GGAsset_LobbyWorld_426 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ConcourseD_0418_V_Dark" }, -- Workspace.LobbyV4Staging.Concourse.Plaques_Range.V_Dark
	GGAsset_LobbyWorld_427 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ConcourseD_0422_V_Dark" }, -- Workspace.LobbyV4Staging.Concourse.Holo_Gift.V_Dark
	GGAsset_LobbyWorld_428 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ConcourseD_0431_V_Dark" }, -- Workspace.LobbyV4Staging.Concourse.Holo_Badge.V_Dark
	GGAsset_LobbyWorld_429 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ConcourseD_0440_V_Dark" }, -- Workspace.LobbyV4Staging.Concourse.Holo_Rifle.V_Dark
	GGAsset_LobbyWorld_430 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ConcourseD_0449_V_Dark" }, -- Workspace.LobbyV4Staging.Concourse.Holo_Crate.V_Dark
	GGAsset_LobbyWorld_431 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "DuelsD_0024_V_Dark" }, -- Workspace.LobbyV4Staging.Duels.Pad_1v1_2.Pad_1v1_2.V_Dark
	GGAsset_LobbyWorld_432 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "DuelsD_0041_V_Dark" }, -- Workspace.LobbyV4Staging.Duels.PadSign.V_Dark
	GGAsset_LobbyWorld_433 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "DuelsD_0064_V_Dark" }, -- Workspace.LobbyV4Staging.Duels.PadSign_2.V_Dark
	GGAsset_LobbyWorld_434 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "DuelsD_0087_V_Dark" }, -- Workspace.LobbyV4Staging.Duels.PadSign_3.V_Dark
	GGAsset_LobbyWorld_435 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "DuelsD_0110_V_Dark" }, -- Workspace.LobbyV4Staging.Duels.PadSign_4.V_Dark
	GGAsset_LobbyWorld_436 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "DuelsD_0139_V_Dark" }, -- Workspace.LobbyV4Staging.Duels.PadSign_5.V_Dark
	GGAsset_LobbyWorld_437 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "DuelsD_0162_V_Dark" }, -- Workspace.LobbyV4Staging.Duels.PadSign_6.V_Dark
	GGAsset_LobbyWorld_438 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "DuelsD_0185_V_Dark" }, -- Workspace.LobbyV4Staging.Duels.PadSign_7.V_Dark
	GGAsset_LobbyWorld_439 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "DuelsD_0208_V_Dark" }, -- Workspace.LobbyV4Staging.Duels.PadSign_8.V_Dark
	GGAsset_LobbyWorld_440 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "DuelsD_0229_V_Dark" }, -- Workspace.LobbyV4Staging.Duels.Sign_Gauntlet.V_Dark
	GGAsset_LobbyWorld_441 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "DuelsD_0247_V_Dark" }, -- Workspace.LobbyV4Staging.Duels.FrontDetails.V_Dark
	GGAsset_LobbyWorld_442 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "DuelsD_0262_V_Dark" }, -- Workspace.LobbyV4Staging.Duels.BarLamp_16.V_Dark
	GGAsset_LobbyWorld_443 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "DuelsD_0368_V_Dark" }, -- Workspace.LobbyV4Staging.Duels.Jumbotron.V_Dark
	GGAsset_LobbyWorld_444 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "DuelsD_0386_V_Dark" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp.V_Dark
	GGAsset_LobbyWorld_445 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "DuelsD_0389_V_Dark" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_2.V_Dark
	GGAsset_LobbyWorld_446 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "DuelsD_0392_V_Dark" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_3.V_Dark
	GGAsset_LobbyWorld_447 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "DuelsD_0395_V_Dark" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_4.V_Dark
	GGAsset_LobbyWorld_448 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "DuelsD_0398_V_Dark" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_5.V_Dark
	GGAsset_LobbyWorld_449 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "DuelsD_0401_V_Dark" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_6.V_Dark
	GGAsset_LobbyWorld_450 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "DuelsD_0404_V_Dark" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_7.V_Dark
	GGAsset_LobbyWorld_451 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "DuelsD_0407_V_Dark" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_8.V_Dark
	GGAsset_LobbyWorld_452 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "DuelsD_0410_V_Dark" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_9.V_Dark
	GGAsset_LobbyWorld_453 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "DuelsD_0413_V_Dark" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_10.V_Dark
	GGAsset_LobbyWorld_454 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "DuelsD_0419_V_Dark" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_11.V_Dark
	GGAsset_LobbyWorld_455 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "DuelsD_0422_V_Dark" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_12.V_Dark
	GGAsset_LobbyWorld_456 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "DuelsD_0425_V_Dark" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_13.V_Dark
	GGAsset_LobbyWorld_457 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "DuelsD_0428_V_Dark" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_14.V_Dark
	GGAsset_LobbyWorld_458 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "DuelsD_0431_V_Dark" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_15.V_Dark
	GGAsset_LobbyWorld_459 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "DuelsD_0434_V_Dark" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_16.V_Dark
	GGAsset_LobbyWorld_460 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "DuelsD_0437_V_Dark" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_17.V_Dark
	GGAsset_LobbyWorld_461 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "DuelsD_0440_V_Dark" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_18.V_Dark
	GGAsset_LobbyWorld_462 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "LockerD_0029_V_Dark" }, -- Workspace.LobbyV4Staging.Locker.CeilingLamp.V_Dark
	GGAsset_LobbyWorld_463 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "LockerD_0032_V_Dark" }, -- Workspace.LobbyV4Staging.Locker.CeilingLamp_2.V_Dark
	GGAsset_LobbyWorld_464 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "LockerD_0035_V_Dark" }, -- Workspace.LobbyV4Staging.Locker.CeilingLamp_3.V_Dark
	GGAsset_LobbyWorld_465 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "LockerD_0038_V_Dark" }, -- Workspace.LobbyV4Staging.Locker.CeilingLamp_4.V_Dark
	GGAsset_LobbyWorld_466 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "LockerD_0044_V_Dark" }, -- Workspace.LobbyV4Staging.Locker.CeilingLamp_5.V_Dark
	GGAsset_LobbyWorld_467 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "LockerD_0047_V_Dark" }, -- Workspace.LobbyV4Staging.Locker.CeilingLamp_6.V_Dark
	GGAsset_LobbyWorld_468 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "LockerD_0094_V_Dark" }, -- Workspace.LobbyV4Staging.Locker.Table_Vandal.V_Dark
	GGAsset_LobbyWorld_469 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "LockerD_0103_V_Dark" }, -- Workspace.LobbyV4Staging.Locker.Table_Phantom.V_Dark
	GGAsset_LobbyWorld_470 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "LockerD_0112_V_Dark" }, -- Workspace.LobbyV4Staging.Locker.Table_Operator.V_Dark
	GGAsset_LobbyWorld_471 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "LockerD_0121_V_Dark" }, -- Workspace.LobbyV4Staging.Locker.Table_Odin.V_Dark
	GGAsset_LobbyWorld_472 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "LockerD_0130_V_Dark" }, -- Workspace.LobbyV4Staging.Locker.Table_Judge.V_Dark
	GGAsset_LobbyWorld_473 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "LockerD_0139_V_Dark" }, -- Workspace.LobbyV4Staging.Locker.Table_Spectre.V_Dark
	GGAsset_LobbyWorld_474 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "LockerD_0148_V_Dark" }, -- Workspace.LobbyV4Staging.Locker.Table_Sheriff.V_Dark
	GGAsset_LobbyWorld_475 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "LockerD_0157_V_Dark" }, -- Workspace.LobbyV4Staging.Locker.Table_Classic.V_Dark
	GGAsset_LobbyWorld_476 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "LockerD_0164_V_Dark" }, -- Workspace.LobbyV4Staging.Locker.GunWall.V_Dark
	GGAsset_LobbyWorld_477 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "LockerD_0168_V_Dark" }, -- Workspace.LobbyV4Staging.Locker.Sign_Loadout.V_Dark
	GGAsset_LobbyWorld_478 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "LockerD_0175_V_Dark" }, -- Workspace.LobbyV4Staging.Locker.HangLamp.V_Dark
	GGAsset_LobbyWorld_479 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "LockerD_0179_V_Dark" }, -- Workspace.LobbyV4Staging.Locker.HangLamp_2.V_Dark
	GGAsset_LobbyWorld_480 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ShopD_0030_V_Dark" }, -- Workspace.LobbyV4Staging.Shop.BarLamp_28.V_Dark
	GGAsset_LobbyWorld_481 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ShopD_0062_V_Dark" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_7.V_Dark
	GGAsset_LobbyWorld_482 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ShopD_0065_V_Dark" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_8.V_Dark
	GGAsset_LobbyWorld_483 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ShopD_0068_V_Dark" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_9.V_Dark
	GGAsset_LobbyWorld_484 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ShopD_0071_V_Dark" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_10.V_Dark
	GGAsset_LobbyWorld_485 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ShopD_0074_V_Dark" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_11.V_Dark
	GGAsset_LobbyWorld_486 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ShopD_0082_V_Dark" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_12.V_Dark
	GGAsset_LobbyWorld_487 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ShopD_0085_V_Dark" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_13.V_Dark
	GGAsset_LobbyWorld_488 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ShopD_0088_V_Dark" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_14.V_Dark
	GGAsset_LobbyWorld_489 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ShopD_0091_V_Dark" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_15.V_Dark
	GGAsset_LobbyWorld_490 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ShopD_0094_V_Dark" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_16.V_Dark
	GGAsset_LobbyWorld_491 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ShopD_0097_V_Dark" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_17.V_Dark
	GGAsset_LobbyWorld_492 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ShopD_0144_V_Dark" }, -- Workspace.LobbyV4Staging.Shop.TV_ShopN.V_Dark
	GGAsset_LobbyWorld_493 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ShopD_0149_V_Dark" }, -- Workspace.LobbyV4Staging.Shop.TV_ShopS.V_Dark
	GGAsset_LobbyWorld_494 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ShopD_0165_V_Dark" }, -- Workspace.LobbyV4Staging.Shop.Bay_Featured.Bay_Featured.V_Dark
	GGAsset_LobbyWorld_495 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ShopD_0176_V_Dark" }, -- Workspace.LobbyV4Staging.Shop.StageSpot.V_Dark
	GGAsset_LobbyWorld_496 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ShopD_0180_V_Dark" }, -- Workspace.LobbyV4Staging.Shop.StageSpot_2.V_Dark
	GGAsset_LobbyWorld_497 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ShopD_0184_V_Dark" }, -- Workspace.LobbyV4Staging.Shop.StageSpot_3.V_Dark
	GGAsset_LobbyWorld_498 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ShopD_0188_V_Dark" }, -- Workspace.LobbyV4Staging.Shop.Bay_FeaturedSign.V_Dark
	GGAsset_LobbyWorld_499 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ShopD_0217_V_Dark" }, -- Workspace.LobbyV4Staging.Shop.Bay_Season.Bay_Season.V_Dark
	GGAsset_LobbyWorld_500 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ShopD_0219_V_Dark" }, -- Workspace.LobbyV4Staging.Shop.StageSpot_4.V_Dark
	GGAsset_LobbyWorld_501 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ShopD_0223_V_Dark" }, -- Workspace.LobbyV4Staging.Shop.StageSpot_5.V_Dark
	GGAsset_LobbyWorld_502 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ShopD_0227_V_Dark" }, -- Workspace.LobbyV4Staging.Shop.StageSpot_6.V_Dark
	GGAsset_LobbyWorld_503 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ShopD_0231_V_Dark" }, -- Workspace.LobbyV4Staging.Shop.Bay_SeasonSign.V_Dark
	GGAsset_LobbyWorld_504 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ShopD_0255_V_Dark" }, -- Workspace.LobbyV4Staging.Shop.Case_Deals.V_Dark
	GGAsset_LobbyWorld_505 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ShopD_0265_V_Dark" }, -- Workspace.LobbyV4Staging.Shop.Case_Rare.V_Dark
	GGAsset_LobbyWorld_506 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ShopD_0275_V_Dark" }, -- Workspace.LobbyV4Staging.Shop.Case_New.V_Dark
	GGAsset_LobbyWorld_507 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ShopD_0285_V_Dark" }, -- Workspace.LobbyV4Staging.Shop.Case_Vault.V_Dark
	GGAsset_LobbyWorld_508 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ShopD_0352_V_Dark" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_18.V_Dark
	GGAsset_LobbyWorld_509 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ShopD_0358_V_Dark" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_19.V_Dark
	GGAsset_LobbyWorld_510 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ShopD_0361_V_Dark" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_20.V_Dark
	GGAsset_LobbyWorld_511 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ShopD_0373_V_Dark" }, -- Workspace.LobbyV4Staging.Shop.TV_ShopEnd.V_Dark
	GGAsset_LobbyWorld_512 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ShopD_0376_V_Dark" }, -- Workspace.LobbyV4Staging.Shop.Sign_Market.V_Dark
	GGAsset_LobbyWorld_513 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ShopD_0383_V_Dark" }, -- Workspace.LobbyV4Staging.Shop.TV_Broker.V_Dark
	GGAsset_LobbyWorld_514 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ShopD_0386_V_Dark" }, -- Workspace.LobbyV4Staging.Shop.Sign_Broker.V_Dark
	GGAsset_LobbyWorld_515 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ShopD_0396_V_Dark" }, -- Workspace.LobbyV4Staging.Shop.BrokerBundle.V_Dark
	GGAsset_LobbyWorld_516 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ShopD_0404_V_Dark" }, -- Workspace.LobbyV4Staging.Shop.BrokerEffect.V_Dark
	GGAsset_LobbyWorld_517 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ShopD_0413_V_Dark" }, -- Workspace.LobbyV4Staging.Shop.Holo_ShopGift.V_Dark
	GGAsset_LobbyWorld_518 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ShopD_0422_V_Dark" }, -- Workspace.LobbyV4Staging.Shop.Holo_ShopBadge.V_Dark
	GGAsset_LobbyWorld_519 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ShopD_0438_V_Dark" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_21.V_Dark
	GGAsset_LobbyWorld_520 = { ["Ceil"] = false, ["SWMat"] = "V_Dark", ["SWName"] = "ShopD_0441_V_Dark" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_22.V_Dark
	GGAsset_LobbyWorld_521 = { ["Ceil"] = false, ["SWMat"] = "V_Floor", ["SWName"] = "ConcourseD_0004_V_Floor" }, -- Workspace.LobbyV4Staging.Concourse.HubFloor.HubFloor.V_Floor
	GGAsset_LobbyWorld_522 = { ["Ceil"] = false, ["SWMat"] = "V_Floor", ["SWName"] = "DuelsD_0008_V_Floor" }, -- Workspace.LobbyV4Staging.Duels.DuelsFloor.V_Floor
	GGAsset_LobbyWorld_523 = { ["Ceil"] = false, ["SWMat"] = "V_Floor", ["SWName"] = "LockerD_0042_V_Floor" }, -- Workspace.LobbyV4Staging.Locker.Floor.V_Floor
	GGAsset_LobbyWorld_524 = { ["Ceil"] = false, ["SWMat"] = "V_Floor", ["SWName"] = "ShopD_0078_V_Floor" }, -- Workspace.LobbyV4Staging.Shop.Floor_2.V_Floor
	GGAsset_LobbyWorld_525 = { ["Ceil"] = false, ["SWMat"] = "V_Floor", ["SWName"] = "ShopD_0356_V_Floor" }, -- Workspace.LobbyV4Staging.Shop.Floor_3.V_Floor
	GGAsset_LobbyWorld_526 = { ["Ceil"] = false, ["SWMat"] = "V_Floor2", ["SWName"] = "ConcourseD_0005_V_Floor2" }, -- Workspace.LobbyV4Staging.Concourse.HubFloor.HubFloor.V_Floor2
	GGAsset_LobbyWorld_527 = { ["Ceil"] = false, ["SWMat"] = "V_Floor2", ["SWName"] = "ConcourseD_0176_V_Floor2" }, -- Workspace.LobbyV4Staging.Concourse.Portal_Duels.V_Floor2
	GGAsset_LobbyWorld_528 = { ["Ceil"] = false, ["SWMat"] = "V_Floor2", ["SWName"] = "ConcourseD_0199_V_Floor2" }, -- Workspace.LobbyV4Staging.Concourse.Portal_Shop.V_Floor2
	GGAsset_LobbyWorld_529 = { ["Ceil"] = false, ["SWMat"] = "V_Floor2", ["SWName"] = "ConcourseD_0222_V_Floor2" }, -- Workspace.LobbyV4Staging.Concourse.Portal_Locker.V_Floor2
	GGAsset_LobbyWorld_530 = { ["Ceil"] = false, ["SWMat"] = "V_Floor2", ["SWName"] = "ConcourseD_0245_V_Floor2" }, -- Workspace.LobbyV4Staging.Concourse.Portal_Range.V_Floor2
	GGAsset_LobbyWorld_531 = { ["Ceil"] = false, ["SWMat"] = "V_Floor2", ["SWName"] = "Concourse_0002_V_Floor2" }, -- Workspace.LobbyV4Staging.Concourse.HubFloor.HubFloor.V_Floor2
	GGAsset_LobbyWorld_532 = { ["Ceil"] = false, ["SWMat"] = "V_Floor2", ["SWName"] = "DuelsD_0002_V_Floor2" }, -- Workspace.LobbyV4Staging.Duels.Landing.V_Floor2
	GGAsset_LobbyWorld_533 = { ["Ceil"] = false, ["SWMat"] = "V_Floor2", ["SWName"] = "DuelsD_0009_V_Floor2" }, -- Workspace.LobbyV4Staging.Duels.DuelsFloor.V_Floor2
	GGAsset_LobbyWorld_534 = { ["Ceil"] = false, ["SWMat"] = "V_Floor2", ["SWName"] = "DuelsD_0029_V_Floor2" }, -- Workspace.LobbyV4Staging.Duels.Pad_1v1_2.Pad_1v1_2.V_Floor2
	GGAsset_LobbyWorld_535 = { ["Ceil"] = false, ["SWMat"] = "V_Floor2", ["SWName"] = "Duels_0001_V_Floor2" }, -- Workspace.LobbyV4Staging.Duels.Landing.V_Floor2
	GGAsset_LobbyWorld_536 = { ["Ceil"] = false, ["SWMat"] = "V_Floor2", ["SWName"] = "LockerD_0043_V_Floor2" }, -- Workspace.LobbyV4Staging.Locker.Floor.V_Floor2
	GGAsset_LobbyWorld_537 = { ["Ceil"] = false, ["SWMat"] = "V_Floor2", ["SWName"] = "LockerD_0081_V_Floor2" }, -- Workspace.LobbyV4Staging.Locker.Threshold.V_Floor2
	GGAsset_LobbyWorld_538 = { ["Ceil"] = false, ["SWMat"] = "V_Floor2", ["SWName"] = "Locker_0173_V_Floor2" }, -- Workspace.LobbyV4Staging.Locker.ArmorerStep.V_Floor2
	GGAsset_LobbyWorld_539 = { ["Ceil"] = false, ["SWMat"] = "V_Floor2", ["SWName"] = "ShopD_0079_V_Floor2" }, -- Workspace.LobbyV4Staging.Shop.Floor_2.V_Floor2
	GGAsset_LobbyWorld_540 = { ["Ceil"] = false, ["SWMat"] = "V_Floor2", ["SWName"] = "ShopD_0107_V_Floor2" }, -- Workspace.LobbyV4Staging.Shop.Threshold_2.V_Floor2
	GGAsset_LobbyWorld_541 = { ["Ceil"] = false, ["SWMat"] = "V_Floor2", ["SWName"] = "ShopD_0167_V_Floor2" }, -- Workspace.LobbyV4Staging.Shop.Bay_Featured.Bay_Featured.V_Floor2
	GGAsset_LobbyWorld_542 = { ["Ceil"] = false, ["SWMat"] = "V_Floor2", ["SWName"] = "ShopD_0211_V_Floor2" }, -- Workspace.LobbyV4Staging.Shop.Bay_Season.Bay_Season.V_Floor2
	GGAsset_LobbyWorld_543 = { ["Ceil"] = false, ["SWMat"] = "V_Floor2", ["SWName"] = "ShopD_0250_V_Floor2" }, -- Workspace.LobbyV4Staging.Shop.Threshold_3.V_Floor2
	GGAsset_LobbyWorld_544 = { ["Ceil"] = false, ["SWMat"] = "V_Floor2", ["SWName"] = "ShopD_0357_V_Floor2" }, -- Workspace.LobbyV4Staging.Shop.Floor_3.V_Floor2
	GGAsset_LobbyWorld_545 = { ["Ceil"] = false, ["SWMat"] = "V_Floor2", ["SWName"] = "Shop_0407_V_Floor2" }, -- Workspace.LobbyV4Staging.Shop.BrokerPlinth.V_Floor2
	GGAsset_LobbyWorld_546 = { ["Ceil"] = false, ["SWMat"] = "V_Gold", ["SWName"] = "DuelsD_0377_V_Gold" }, -- Workspace.LobbyV4Staging.Duels.Trophy.V_Gold
	GGAsset_LobbyWorld_547 = { ["Ceil"] = false, ["SWMat"] = "V_Gold", ["SWName"] = "ShopD_0238_V_Gold" }, -- Workspace.LobbyV4Staging.Shop.SeasonCrest.V_Gold
	GGAsset_LobbyWorld_548 = { ["Ceil"] = false, ["SWMat"] = "V_Gold", ["SWName"] = "ShopD_0397_V_Gold" }, -- Workspace.LobbyV4Staging.Shop.BrokerBundleMedal.V_Gold
	GGAsset_LobbyWorld_549 = { ["Ceil"] = false, ["SWMat"] = "V_Gold", ["SWName"] = "ShopD_0406_V_Gold" }, -- Workspace.LobbyV4Staging.Shop.BrokerEffect.V_Gold
	GGAsset_LobbyWorld_550 = { ["Ceil"] = false, ["SWMat"] = "V_GoldPaint", ["SWName"] = "ConcourseD_0186_V_GoldPaint" }, -- Workspace.LobbyV4Staging.Concourse.Hazard.V_GoldPaint
	GGAsset_LobbyWorld_551 = { ["Ceil"] = false, ["SWMat"] = "V_GoldPaint", ["SWName"] = "ConcourseD_0188_V_GoldPaint" }, -- Workspace.LobbyV4Staging.Concourse.Hazard_2.V_GoldPaint
	GGAsset_LobbyWorld_552 = { ["Ceil"] = false, ["SWMat"] = "V_GoldPaint", ["SWName"] = "ConcourseD_0209_V_GoldPaint" }, -- Workspace.LobbyV4Staging.Concourse.Hazard_3.V_GoldPaint
	GGAsset_LobbyWorld_553 = { ["Ceil"] = false, ["SWMat"] = "V_GoldPaint", ["SWName"] = "ConcourseD_0211_V_GoldPaint" }, -- Workspace.LobbyV4Staging.Concourse.Hazard_4.V_GoldPaint
	GGAsset_LobbyWorld_554 = { ["Ceil"] = false, ["SWMat"] = "V_GoldPaint", ["SWName"] = "ConcourseD_0232_V_GoldPaint" }, -- Workspace.LobbyV4Staging.Concourse.Hazard_5.V_GoldPaint
	GGAsset_LobbyWorld_555 = { ["Ceil"] = false, ["SWMat"] = "V_GoldPaint", ["SWName"] = "ConcourseD_0234_V_GoldPaint" }, -- Workspace.LobbyV4Staging.Concourse.Hazard_6.V_GoldPaint
	GGAsset_LobbyWorld_556 = { ["Ceil"] = false, ["SWMat"] = "V_GoldPaint", ["SWName"] = "ConcourseD_0255_V_GoldPaint" }, -- Workspace.LobbyV4Staging.Concourse.Hazard_7.V_GoldPaint
	GGAsset_LobbyWorld_557 = { ["Ceil"] = false, ["SWMat"] = "V_GoldPaint", ["SWName"] = "ConcourseD_0257_V_GoldPaint" }, -- Workspace.LobbyV4Staging.Concourse.Hazard_8.V_GoldPaint
	GGAsset_LobbyWorld_558 = { ["Ceil"] = false, ["SWMat"] = "V_GoldPaint", ["SWName"] = "DuelsD_0040_V_GoldPaint" }, -- Workspace.LobbyV4Staging.Duels.Hazard_9.V_GoldPaint
	GGAsset_LobbyWorld_559 = { ["Ceil"] = false, ["SWMat"] = "V_GoldPaint", ["SWName"] = "DuelsD_0055_V_GoldPaint" }, -- Workspace.LobbyV4Staging.Duels.Pad_1v1_2.Hazard.V_GoldPaint
	GGAsset_LobbyWorld_560 = { ["Ceil"] = false, ["SWMat"] = "V_GoldPaint", ["SWName"] = "DuelsD_0063_V_GoldPaint" }, -- Workspace.LobbyV4Staging.Duels.Hazard_10.V_GoldPaint
	GGAsset_LobbyWorld_561 = { ["Ceil"] = false, ["SWMat"] = "V_GoldPaint", ["SWName"] = "DuelsD_0078_V_GoldPaint" }, -- Workspace.LobbyV4Staging.Duels.Pad_2v2.Hazard.V_GoldPaint
	GGAsset_LobbyWorld_562 = { ["Ceil"] = false, ["SWMat"] = "V_GoldPaint", ["SWName"] = "DuelsD_0086_V_GoldPaint" }, -- Workspace.LobbyV4Staging.Duels.Hazard_11.V_GoldPaint
	GGAsset_LobbyWorld_563 = { ["Ceil"] = false, ["SWMat"] = "V_GoldPaint", ["SWName"] = "DuelsD_0101_V_GoldPaint" }, -- Workspace.LobbyV4Staging.Duels.Pad_2v2_2.Hazard.V_GoldPaint
	GGAsset_LobbyWorld_564 = { ["Ceil"] = false, ["SWMat"] = "V_GoldPaint", ["SWName"] = "DuelsD_0109_V_GoldPaint" }, -- Workspace.LobbyV4Staging.Duels.Hazard_12.V_GoldPaint
	GGAsset_LobbyWorld_565 = { ["Ceil"] = false, ["SWMat"] = "V_GoldPaint", ["SWName"] = "DuelsD_0130_V_GoldPaint" }, -- Workspace.LobbyV4Staging.Duels.Pad_3v3.Hazard.V_GoldPaint
	GGAsset_LobbyWorld_566 = { ["Ceil"] = false, ["SWMat"] = "V_GoldPaint", ["SWName"] = "DuelsD_0138_V_GoldPaint" }, -- Workspace.LobbyV4Staging.Duels.Hazard_13.V_GoldPaint
	GGAsset_LobbyWorld_567 = { ["Ceil"] = false, ["SWMat"] = "V_GoldPaint", ["SWName"] = "DuelsD_0153_V_GoldPaint" }, -- Workspace.LobbyV4Staging.Duels.Pad_3v3_2.Hazard.V_GoldPaint
	GGAsset_LobbyWorld_568 = { ["Ceil"] = false, ["SWMat"] = "V_GoldPaint", ["SWName"] = "DuelsD_0161_V_GoldPaint" }, -- Workspace.LobbyV4Staging.Duels.Hazard_14.V_GoldPaint
	GGAsset_LobbyWorld_569 = { ["Ceil"] = false, ["SWMat"] = "V_GoldPaint", ["SWName"] = "DuelsD_0176_V_GoldPaint" }, -- Workspace.LobbyV4Staging.Duels.Pad_4v4.Hazard.V_GoldPaint
	GGAsset_LobbyWorld_570 = { ["Ceil"] = false, ["SWMat"] = "V_GoldPaint", ["SWName"] = "DuelsD_0184_V_GoldPaint" }, -- Workspace.LobbyV4Staging.Duels.Hazard_15.V_GoldPaint
	GGAsset_LobbyWorld_571 = { ["Ceil"] = false, ["SWMat"] = "V_GoldPaint", ["SWName"] = "DuelsD_0199_V_GoldPaint" }, -- Workspace.LobbyV4Staging.Duels.Pad_5v5.Hazard.V_GoldPaint
	GGAsset_LobbyWorld_572 = { ["Ceil"] = false, ["SWMat"] = "V_GoldPaint", ["SWName"] = "DuelsD_0207_V_GoldPaint" }, -- Workspace.LobbyV4Staging.Duels.Hazard_16.V_GoldPaint
	GGAsset_LobbyWorld_573 = { ["Ceil"] = false, ["SWMat"] = "V_GoldPaint", ["SWName"] = "LockerD_0099_V_GoldPaint" }, -- Workspace.LobbyV4Staging.Locker.Table_Vandal.V_GoldPaint
	GGAsset_LobbyWorld_574 = { ["Ceil"] = false, ["SWMat"] = "V_GoldPaint", ["SWName"] = "LockerD_0108_V_GoldPaint" }, -- Workspace.LobbyV4Staging.Locker.Table_Phantom.V_GoldPaint
	GGAsset_LobbyWorld_575 = { ["Ceil"] = false, ["SWMat"] = "V_GoldPaint", ["SWName"] = "LockerD_0117_V_GoldPaint" }, -- Workspace.LobbyV4Staging.Locker.Table_Operator.V_GoldPaint
	GGAsset_LobbyWorld_576 = { ["Ceil"] = false, ["SWMat"] = "V_GoldPaint", ["SWName"] = "LockerD_0126_V_GoldPaint" }, -- Workspace.LobbyV4Staging.Locker.Table_Odin.V_GoldPaint
	GGAsset_LobbyWorld_577 = { ["Ceil"] = false, ["SWMat"] = "V_GoldPaint", ["SWName"] = "LockerD_0135_V_GoldPaint" }, -- Workspace.LobbyV4Staging.Locker.Table_Judge.V_GoldPaint
	GGAsset_LobbyWorld_578 = { ["Ceil"] = false, ["SWMat"] = "V_GoldPaint", ["SWName"] = "LockerD_0144_V_GoldPaint" }, -- Workspace.LobbyV4Staging.Locker.Table_Spectre.V_GoldPaint
	GGAsset_LobbyWorld_579 = { ["Ceil"] = false, ["SWMat"] = "V_GoldPaint", ["SWName"] = "LockerD_0153_V_GoldPaint" }, -- Workspace.LobbyV4Staging.Locker.Table_Sheriff.V_GoldPaint
	GGAsset_LobbyWorld_580 = { ["Ceil"] = false, ["SWMat"] = "V_GoldPaint", ["SWName"] = "LockerD_0162_V_GoldPaint" }, -- Workspace.LobbyV4Staging.Locker.Table_Classic.V_GoldPaint
	GGAsset_LobbyWorld_581 = { ["Ceil"] = false, ["SWMat"] = "V_GoldPaint", ["SWName"] = "ShopD_0203_V_GoldPaint" }, -- Workspace.LobbyV4Staging.Shop.Mark_Featured.Hazard.V_GoldPaint
	GGAsset_LobbyWorld_582 = { ["Ceil"] = false, ["SWMat"] = "V_GoldPaint", ["SWName"] = "ShopD_0246_V_GoldPaint" }, -- Workspace.LobbyV4Staging.Shop.Mark_Season.Hazard.V_GoldPaint
	GGAsset_LobbyWorld_583 = { ["Ceil"] = false, ["SWMat"] = "V_Lane", ["SWName"] = "Concourse_0009_V_Lane" }, -- Workspace.LobbyV4Staging.Concourse.HubFloor.HubFloor.V_Lane
	GGAsset_LobbyWorld_584 = { ["Ceil"] = false, ["SWMat"] = "V_Lane", ["SWName"] = "DuelsD_0010_V_Lane" }, -- Workspace.LobbyV4Staging.Duels.DuelsFloor.V_Lane
	GGAsset_LobbyWorld_585 = { ["Ceil"] = false, ["SWMat"] = "V_Lane", ["SWName"] = "Shop_0408_V_Lane" }, -- Workspace.LobbyV4Staging.Shop.BrokerPlinth.V_Lane
	GGAsset_LobbyWorld_586 = { ["Ceil"] = false, ["SWMat"] = "V_Low", ["SWName"] = "ConcourseD_0028_V_Low" }, -- Workspace.LobbyV4Staging.Concourse.Pier.V_Low
	GGAsset_LobbyWorld_587 = { ["Ceil"] = false, ["SWMat"] = "V_Low", ["SWName"] = "ConcourseD_0153_V_Low" }, -- Workspace.LobbyV4Staging.Concourse.Wall.V_Low
	GGAsset_LobbyWorld_588 = { ["Ceil"] = false, ["SWMat"] = "V_Low", ["SWName"] = "ConcourseD_0158_V_Low" }, -- Workspace.LobbyV4Staging.Concourse.Wall_2.V_Low
	GGAsset_LobbyWorld_589 = { ["Ceil"] = false, ["SWMat"] = "V_Low", ["SWName"] = "ConcourseD_0163_V_Low" }, -- Workspace.LobbyV4Staging.Concourse.Wall_3.V_Low
	GGAsset_LobbyWorld_590 = { ["Ceil"] = false, ["SWMat"] = "V_Low", ["SWName"] = "ConcourseD_0168_V_Low" }, -- Workspace.LobbyV4Staging.Concourse.Wall_4.V_Low
	GGAsset_LobbyWorld_591 = { ["Ceil"] = false, ["SWMat"] = "V_Low", ["SWName"] = "ConcourseD_0173_V_Low" }, -- Workspace.LobbyV4Staging.Concourse.Portal_Duels.V_Low
	GGAsset_LobbyWorld_592 = { ["Ceil"] = false, ["SWMat"] = "V_Low", ["SWName"] = "ConcourseD_0180_V_Low" }, -- Workspace.LobbyV4Staging.Concourse.Gate_Duels.V_Low
	GGAsset_LobbyWorld_593 = { ["Ceil"] = false, ["SWMat"] = "V_Low", ["SWName"] = "ConcourseD_0196_V_Low" }, -- Workspace.LobbyV4Staging.Concourse.Portal_Shop.V_Low
	GGAsset_LobbyWorld_594 = { ["Ceil"] = false, ["SWMat"] = "V_Low", ["SWName"] = "ConcourseD_0203_V_Low" }, -- Workspace.LobbyV4Staging.Concourse.Gate_Shop.V_Low
	GGAsset_LobbyWorld_595 = { ["Ceil"] = false, ["SWMat"] = "V_Low", ["SWName"] = "ConcourseD_0219_V_Low" }, -- Workspace.LobbyV4Staging.Concourse.Portal_Locker.V_Low
	GGAsset_LobbyWorld_596 = { ["Ceil"] = false, ["SWMat"] = "V_Low", ["SWName"] = "ConcourseD_0227_V_Low" }, -- Workspace.LobbyV4Staging.Concourse.Gate_Locker.V_Low
	GGAsset_LobbyWorld_597 = { ["Ceil"] = false, ["SWMat"] = "V_Low", ["SWName"] = "ConcourseD_0242_V_Low" }, -- Workspace.LobbyV4Staging.Concourse.Portal_Range.V_Low
	GGAsset_LobbyWorld_598 = { ["Ceil"] = false, ["SWMat"] = "V_Low", ["SWName"] = "ConcourseD_0250_V_Low" }, -- Workspace.LobbyV4Staging.Concourse.Gate_Range.V_Low
	GGAsset_LobbyWorld_599 = { ["Ceil"] = false, ["SWMat"] = "V_Low", ["SWName"] = "ConcourseD_0268_V_Low" }, -- Workspace.LobbyV4Staging.Concourse.Wall_5.V_Low
	GGAsset_LobbyWorld_600 = { ["Ceil"] = false, ["SWMat"] = "V_Low", ["SWName"] = "ConcourseD_0290_V_Low" }, -- Workspace.LobbyV4Staging.Concourse.Wall_6.V_Low
	GGAsset_LobbyWorld_601 = { ["Ceil"] = false, ["SWMat"] = "V_Low", ["SWName"] = "ConcourseD_0312_V_Low" }, -- Workspace.LobbyV4Staging.Concourse.Wall_7.V_Low
	GGAsset_LobbyWorld_602 = { ["Ceil"] = false, ["SWMat"] = "V_Low", ["SWName"] = "ConcourseD_0334_V_Low" }, -- Workspace.LobbyV4Staging.Concourse.Wall_8.V_Low
	GGAsset_LobbyWorld_603 = { ["Ceil"] = false, ["SWMat"] = "V_Low", ["SWName"] = "DuelsD_0007_V_Low" }, -- Workspace.LobbyV4Staging.Duels.Landing.V_Low
	GGAsset_LobbyWorld_604 = { ["Ceil"] = false, ["SWMat"] = "V_Low", ["SWName"] = "DuelsD_0019_V_Low" }, -- Workspace.LobbyV4Staging.Duels.Wall_9.V_Low
	GGAsset_LobbyWorld_605 = { ["Ceil"] = false, ["SWMat"] = "V_Low", ["SWName"] = "DuelsD_0117_V_Low" }, -- Workspace.LobbyV4Staging.Duels.Wall_10.V_Low
	GGAsset_LobbyWorld_606 = { ["Ceil"] = false, ["SWMat"] = "V_Low", ["SWName"] = "DuelsD_0215_V_Low" }, -- Workspace.LobbyV4Staging.Duels.Wall_11.V_Low
	GGAsset_LobbyWorld_607 = { ["Ceil"] = false, ["SWMat"] = "V_Low", ["SWName"] = "DuelsD_0225_V_Low" }, -- Workspace.LobbyV4Staging.Duels.Wall_12.V_Low
	GGAsset_LobbyWorld_608 = { ["Ceil"] = false, ["SWMat"] = "V_Low", ["SWName"] = "DuelsD_0236_V_Low" }, -- Workspace.LobbyV4Staging.Duels.Wall_13.V_Low
	GGAsset_LobbyWorld_609 = { ["Ceil"] = false, ["SWMat"] = "V_Low", ["SWName"] = "DuelsD_0252_V_Low" }, -- Workspace.LobbyV4Staging.Duels.Wall_14.V_Low
	GGAsset_LobbyWorld_610 = { ["Ceil"] = false, ["SWMat"] = "V_Low", ["SWName"] = "DuelsD_0259_V_Low" }, -- Workspace.LobbyV4Staging.Duels.Pier_10.V_Low
	GGAsset_LobbyWorld_611 = { ["Ceil"] = false, ["SWMat"] = "V_Low", ["SWName"] = "DuelsD_0323_V_Low" }, -- Workspace.LobbyV4Staging.Duels.CornerPier_4.V_Low
	GGAsset_LobbyWorld_612 = { ["Ceil"] = false, ["SWMat"] = "V_Low", ["SWName"] = "Duels_0004_V_Low" }, -- Workspace.LobbyV4Staging.Duels.Landing.V_Low
	GGAsset_LobbyWorld_613 = { ["Ceil"] = false, ["SWMat"] = "V_Low", ["SWName"] = "LockerD_0003_V_Low" }, -- Workspace.LobbyV4Staging.Locker.Wall_15.V_Low
	GGAsset_LobbyWorld_614 = { ["Ceil"] = false, ["SWMat"] = "V_Low", ["SWName"] = "LockerD_0009_V_Low" }, -- Workspace.LobbyV4Staging.Locker.Wall_16.V_Low
	GGAsset_LobbyWorld_615 = { ["Ceil"] = false, ["SWMat"] = "V_Low", ["SWName"] = "LockerD_0015_V_Low" }, -- Workspace.LobbyV4Staging.Locker.Wall_17.V_Low
	GGAsset_LobbyWorld_616 = { ["Ceil"] = false, ["SWMat"] = "V_Low", ["SWName"] = "LockerD_0020_V_Low" }, -- Workspace.LobbyV4Staging.Locker.Wall_18.V_Low
	GGAsset_LobbyWorld_617 = { ["Ceil"] = false, ["SWMat"] = "V_Low", ["SWName"] = "LockerD_0056_V_Low" }, -- Workspace.LobbyV4Staging.Locker.Wall_19.V_Low
	GGAsset_LobbyWorld_618 = { ["Ceil"] = false, ["SWMat"] = "V_Low", ["SWName"] = "LockerD_0062_V_Low" }, -- Workspace.LobbyV4Staging.Locker.Wall_20.V_Low
	GGAsset_LobbyWorld_619 = { ["Ceil"] = false, ["SWMat"] = "V_Low", ["SWName"] = "LockerD_0068_V_Low" }, -- Workspace.LobbyV4Staging.Locker.Wall_21.V_Low
	GGAsset_LobbyWorld_620 = { ["Ceil"] = false, ["SWMat"] = "V_Low", ["SWName"] = "LockerD_0074_V_Low" }, -- Workspace.LobbyV4Staging.Locker.Wall_22.V_Low
	GGAsset_LobbyWorld_621 = { ["Ceil"] = false, ["SWMat"] = "V_Low", ["SWName"] = "LockerD_0080_V_Low" }, -- Workspace.LobbyV4Staging.Locker.Mouth.V_Low
	GGAsset_LobbyWorld_622 = { ["Ceil"] = false, ["SWMat"] = "V_Low", ["SWName"] = "ShopD_0003_V_Low" }, -- Workspace.LobbyV4Staging.Shop.Wall_23.V_Low
	GGAsset_LobbyWorld_623 = { ["Ceil"] = false, ["SWMat"] = "V_Low", ["SWName"] = "ShopD_0009_V_Low" }, -- Workspace.LobbyV4Staging.Shop.Wall_24.V_Low
	GGAsset_LobbyWorld_624 = { ["Ceil"] = false, ["SWMat"] = "V_Low", ["SWName"] = "ShopD_0015_V_Low" }, -- Workspace.LobbyV4Staging.Shop.Wall_25.V_Low
	GGAsset_LobbyWorld_625 = { ["Ceil"] = false, ["SWMat"] = "V_Low", ["SWName"] = "ShopD_0021_V_Low" }, -- Workspace.LobbyV4Staging.Shop.Wall_26.V_Low
	GGAsset_LobbyWorld_626 = { ["Ceil"] = false, ["SWMat"] = "V_Low", ["SWName"] = "ShopD_0027_V_Low" }, -- Workspace.LobbyV4Staging.Shop.CornerPier_13.V_Low
	GGAsset_LobbyWorld_627 = { ["Ceil"] = false, ["SWMat"] = "V_Low", ["SWName"] = "ShopD_0106_V_Low" }, -- Workspace.LobbyV4Staging.Shop.Mouth_2.V_Low
	GGAsset_LobbyWorld_628 = { ["Ceil"] = false, ["SWMat"] = "V_Low", ["SWName"] = "ShopD_0113_V_Low" }, -- Workspace.LobbyV4Staging.Shop.Pier_19.V_Low
	GGAsset_LobbyWorld_629 = { ["Ceil"] = false, ["SWMat"] = "V_Low", ["SWName"] = "ShopD_0162_V_Low" }, -- Workspace.LobbyV4Staging.Shop.Bay_Featured.Bay_Featured.V_Low
	GGAsset_LobbyWorld_630 = { ["Ceil"] = false, ["SWMat"] = "V_Low", ["SWName"] = "ShopD_0206_V_Low" }, -- Workspace.LobbyV4Staging.Shop.Bay_Season.Bay_Season.V_Low
	GGAsset_LobbyWorld_631 = { ["Ceil"] = false, ["SWMat"] = "V_Low", ["SWName"] = "ShopD_0249_V_Low" }, -- Workspace.LobbyV4Staging.Shop.Mouth_3.V_Low
	GGAsset_LobbyWorld_632 = { ["Ceil"] = false, ["SWMat"] = "V_Low", ["SWName"] = "ShopD_0293_V_Low" }, -- Workspace.LobbyV4Staging.Shop.Wall_27.V_Low
	GGAsset_LobbyWorld_633 = { ["Ceil"] = false, ["SWMat"] = "V_Low", ["SWName"] = "ShopD_0299_V_Low" }, -- Workspace.LobbyV4Staging.Shop.Wall_28.V_Low
	GGAsset_LobbyWorld_634 = { ["Ceil"] = false, ["SWMat"] = "V_Low", ["SWName"] = "ShopD_0304_V_Low" }, -- Workspace.LobbyV4Staging.Shop.Wall_29.V_Low
	GGAsset_LobbyWorld_635 = { ["Ceil"] = false, ["SWMat"] = "V_Low", ["SWName"] = "ShopD_0310_V_Low" }, -- Workspace.LobbyV4Staging.Shop.Wall_30.V_Low
	GGAsset_LobbyWorld_636 = { ["Ceil"] = false, ["SWMat"] = "V_Low", ["SWName"] = "ShopD_0370_V_Low" }, -- Workspace.LobbyV4Staging.Shop.Mouth_4.V_Low
	GGAsset_LobbyWorld_637 = { ["Ceil"] = false, ["SWMat"] = "V_Paint", ["SWName"] = "ShopD_0200_V_Paint" }, -- Workspace.LobbyV4Staging.Shop.Mark_Featured.Mark_Featured.V_Paint
	GGAsset_LobbyWorld_638 = { ["Ceil"] = false, ["SWMat"] = "V_Paint", ["SWName"] = "ShopD_0243_V_Paint" }, -- Workspace.LobbyV4Staging.Shop.Mark_Season.Mark_Season.V_Paint
	GGAsset_LobbyWorld_639 = { ["Ceil"] = false, ["SWMat"] = "V_Panel", ["SWName"] = "ConcourseD_0270_V_Panel" }, -- Workspace.LobbyV4Staging.Concourse.Wall_5.V_Panel
	GGAsset_LobbyWorld_640 = { ["Ceil"] = false, ["SWMat"] = "V_Panel", ["SWName"] = "ConcourseD_0292_V_Panel" }, -- Workspace.LobbyV4Staging.Concourse.Wall_6.V_Panel
	GGAsset_LobbyWorld_641 = { ["Ceil"] = false, ["SWMat"] = "V_Panel", ["SWName"] = "ConcourseD_0314_V_Panel" }, -- Workspace.LobbyV4Staging.Concourse.Wall_7.V_Panel
	GGAsset_LobbyWorld_642 = { ["Ceil"] = false, ["SWMat"] = "V_Panel", ["SWName"] = "ConcourseD_0336_V_Panel" }, -- Workspace.LobbyV4Staging.Concourse.Wall_8.V_Panel
	GGAsset_LobbyWorld_643 = { ["Ceil"] = false, ["SWMat"] = "V_Panel", ["SWName"] = "Concourse_0355_V_Panel" }, -- Workspace.LobbyV4Staging.Concourse.Bench.V_Panel
	GGAsset_LobbyWorld_644 = { ["Ceil"] = false, ["SWMat"] = "V_Panel", ["SWName"] = "DuelsD_0021_V_Panel" }, -- Workspace.LobbyV4Staging.Duels.Wall_9.V_Panel
	GGAsset_LobbyWorld_645 = { ["Ceil"] = false, ["SWMat"] = "V_Panel", ["SWName"] = "DuelsD_0119_V_Panel" }, -- Workspace.LobbyV4Staging.Duels.Wall_10.V_Panel
	GGAsset_LobbyWorld_646 = { ["Ceil"] = false, ["SWMat"] = "V_Panel", ["SWName"] = "DuelsD_0217_V_Panel" }, -- Workspace.LobbyV4Staging.Duels.Wall_11.V_Panel
	GGAsset_LobbyWorld_647 = { ["Ceil"] = false, ["SWMat"] = "V_Panel", ["SWName"] = "DuelsD_0227_V_Panel" }, -- Workspace.LobbyV4Staging.Duels.Wall_12.V_Panel
	GGAsset_LobbyWorld_648 = { ["Ceil"] = false, ["SWMat"] = "V_Panel", ["SWName"] = "DuelsD_0238_V_Panel" }, -- Workspace.LobbyV4Staging.Duels.Wall_13.V_Panel
	GGAsset_LobbyWorld_649 = { ["Ceil"] = false, ["SWMat"] = "V_Panel", ["SWName"] = "DuelsD_0254_V_Panel" }, -- Workspace.LobbyV4Staging.Duels.Wall_14.V_Panel
	GGAsset_LobbyWorld_650 = { ["Ceil"] = false, ["SWMat"] = "V_Panel", ["SWName"] = "LockerD_0005_V_Panel" }, -- Workspace.LobbyV4Staging.Locker.Wall_15.V_Panel
	GGAsset_LobbyWorld_651 = { ["Ceil"] = false, ["SWMat"] = "V_Panel", ["SWName"] = "LockerD_0011_V_Panel" }, -- Workspace.LobbyV4Staging.Locker.Wall_16.V_Panel
	GGAsset_LobbyWorld_652 = { ["Ceil"] = false, ["SWMat"] = "V_Panel", ["SWName"] = "LockerD_0058_V_Panel" }, -- Workspace.LobbyV4Staging.Locker.Wall_19.V_Panel
	GGAsset_LobbyWorld_653 = { ["Ceil"] = false, ["SWMat"] = "V_Panel", ["SWName"] = "LockerD_0064_V_Panel" }, -- Workspace.LobbyV4Staging.Locker.Wall_20.V_Panel
	GGAsset_LobbyWorld_654 = { ["Ceil"] = false, ["SWMat"] = "V_Panel", ["SWName"] = "LockerD_0070_V_Panel" }, -- Workspace.LobbyV4Staging.Locker.Wall_21.V_Panel
	GGAsset_LobbyWorld_655 = { ["Ceil"] = false, ["SWMat"] = "V_Panel", ["SWName"] = "LockerD_0076_V_Panel" }, -- Workspace.LobbyV4Staging.Locker.Wall_22.V_Panel
	GGAsset_LobbyWorld_656 = { ["Ceil"] = false, ["SWMat"] = "V_Panel", ["SWName"] = "LockerD_0166_V_Panel" }, -- Workspace.LobbyV4Staging.Locker.GunWall.V_Panel
	GGAsset_LobbyWorld_657 = { ["Ceil"] = false, ["SWMat"] = "V_Panel", ["SWName"] = "ShopD_0005_V_Panel" }, -- Workspace.LobbyV4Staging.Shop.Wall_23.V_Panel
	GGAsset_LobbyWorld_658 = { ["Ceil"] = false, ["SWMat"] = "V_Panel", ["SWName"] = "ShopD_0011_V_Panel" }, -- Workspace.LobbyV4Staging.Shop.Wall_24.V_Panel
	GGAsset_LobbyWorld_659 = { ["Ceil"] = false, ["SWMat"] = "V_Panel", ["SWName"] = "ShopD_0017_V_Panel" }, -- Workspace.LobbyV4Staging.Shop.Wall_25.V_Panel
	GGAsset_LobbyWorld_660 = { ["Ceil"] = false, ["SWMat"] = "V_Panel", ["SWName"] = "ShopD_0254_V_Panel" }, -- Workspace.LobbyV4Staging.Shop.Case_Deals.V_Panel
	GGAsset_LobbyWorld_661 = { ["Ceil"] = false, ["SWMat"] = "V_Panel", ["SWName"] = "ShopD_0264_V_Panel" }, -- Workspace.LobbyV4Staging.Shop.Case_Rare.V_Panel
	GGAsset_LobbyWorld_662 = { ["Ceil"] = false, ["SWMat"] = "V_Panel", ["SWName"] = "ShopD_0274_V_Panel" }, -- Workspace.LobbyV4Staging.Shop.Case_New.V_Panel
	GGAsset_LobbyWorld_663 = { ["Ceil"] = false, ["SWMat"] = "V_Panel", ["SWName"] = "ShopD_0284_V_Panel" }, -- Workspace.LobbyV4Staging.Shop.Case_Vault.V_Panel
	GGAsset_LobbyWorld_664 = { ["Ceil"] = false, ["SWMat"] = "V_Panel", ["SWName"] = "ShopD_0295_V_Panel" }, -- Workspace.LobbyV4Staging.Shop.Wall_27.V_Panel
	GGAsset_LobbyWorld_665 = { ["Ceil"] = false, ["SWMat"] = "V_Panel", ["SWName"] = "ShopD_0306_V_Panel" }, -- Workspace.LobbyV4Staging.Shop.Wall_29.V_Panel
	GGAsset_LobbyWorld_666 = { ["Ceil"] = false, ["SWMat"] = "V_Panel", ["SWName"] = "ShopD_0312_V_Panel" }, -- Workspace.LobbyV4Staging.Shop.Wall_30.V_Panel
	GGAsset_LobbyWorld_667 = { ["Ceil"] = false, ["SWMat"] = "V_Pink", ["SWName"] = "ShopD_0166_V_Pink" }, -- Workspace.LobbyV4Staging.Shop.Bay_Featured.Bay_Featured.V_Pink
	GGAsset_LobbyWorld_668 = { ["Ceil"] = false, ["SWMat"] = "V_Pink", ["SWName"] = "ShopD_0169_V_Pink" }, -- Workspace.LobbyV4Staging.Shop.Bay_Featured.Bay_FeaturedCurtains.V_Pink
	GGAsset_LobbyWorld_669 = { ["Ceil"] = false, ["SWMat"] = "V_Pink", ["SWName"] = "ShopD_0195_V_Pink" }, -- Workspace.LobbyV4Staging.Shop.FeaturedPedestal.V_Pink
	GGAsset_LobbyWorld_670 = { ["Ceil"] = false, ["SWMat"] = "V_Pink", ["SWName"] = "ShopD_0201_V_Pink" }, -- Workspace.LobbyV4Staging.Shop.Mark_Featured.Mark_Featured.V_Pink
	GGAsset_LobbyWorld_671 = { ["Ceil"] = false, ["SWMat"] = "V_Pink", ["SWName"] = "ShopD_0394_V_Pink" }, -- Workspace.LobbyV4Staging.Shop.BrokerBundle.V_Pink
	GGAsset_LobbyWorld_672 = { ["Ceil"] = false, ["SWMat"] = "V_Seat", ["SWName"] = "Concourse_0356_V_Seat" }, -- Workspace.LobbyV4Staging.Concourse.Bench.V_Seat
	GGAsset_LobbyWorld_673 = { ["Ceil"] = false, ["SWMat"] = "V_Slab", ["SWName"] = "ConcourseD_0007_V_Slab" }, -- Workspace.LobbyV4Staging.Concourse.HubFloor.HubFloor.V_Slab
	GGAsset_LobbyWorld_674 = { ["Ceil"] = false, ["SWMat"] = "V_Slab", ["SWName"] = "Concourse_0001_V_Slab" }, -- Workspace.LobbyV4Staging.Concourse.HubFloor.HubFloor.V_Slab
	GGAsset_LobbyWorld_675 = { ["Ceil"] = false, ["SWMat"] = "V_Slab", ["SWName"] = "Concourse_0175_V_Slab" }, -- Workspace.LobbyV4Staging.Concourse.Portal_Duels.V_Slab
	GGAsset_LobbyWorld_676 = { ["Ceil"] = false, ["SWMat"] = "V_Slab", ["SWName"] = "Concourse_0198_V_Slab" }, -- Workspace.LobbyV4Staging.Concourse.Portal_Shop.V_Slab
	GGAsset_LobbyWorld_677 = { ["Ceil"] = false, ["SWMat"] = "V_Slab", ["SWName"] = "Concourse_0221_V_Slab" }, -- Workspace.LobbyV4Staging.Concourse.Portal_Locker.V_Slab
	GGAsset_LobbyWorld_678 = { ["Ceil"] = false, ["SWMat"] = "V_Slab", ["SWName"] = "Concourse_0244_V_Slab" }, -- Workspace.LobbyV4Staging.Concourse.Portal_Range.V_Slab
	GGAsset_LobbyWorld_679 = { ["Ceil"] = false, ["SWMat"] = "V_Slab", ["SWName"] = "DuelsD_0014_V_Slab" }, -- Workspace.LobbyV4Staging.Duels.DuelsFloor.V_Slab
	GGAsset_LobbyWorld_680 = { ["Ceil"] = false, ["SWMat"] = "V_Slab", ["SWName"] = "Duels_0417_V_Slab" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.DuelsCeiling.V_Slab
	GGAsset_LobbyWorld_681 = { ["Ceil"] = false, ["SWMat"] = "V_Slab", ["SWName"] = "Locker_0041_V_Slab" }, -- Workspace.LobbyV4Staging.Locker.Floor.V_Slab
	GGAsset_LobbyWorld_682 = { ["Ceil"] = false, ["SWMat"] = "V_Slab", ["SWName"] = "Shop_0077_V_Slab" }, -- Workspace.LobbyV4Staging.Shop.Floor_2.V_Slab
	GGAsset_LobbyWorld_683 = { ["Ceil"] = false, ["SWMat"] = "V_Slab", ["SWName"] = "Shop_0164_V_Slab" }, -- Workspace.LobbyV4Staging.Shop.Bay_Featured.Bay_Featured.V_Slab
	GGAsset_LobbyWorld_684 = { ["Ceil"] = false, ["SWMat"] = "V_Slab", ["SWName"] = "Shop_0208_V_Slab" }, -- Workspace.LobbyV4Staging.Shop.Bay_Season.Bay_Season.V_Slab
	GGAsset_LobbyWorld_685 = { ["Ceil"] = false, ["SWMat"] = "V_Slab", ["SWName"] = "Shop_0355_V_Slab" }, -- Workspace.LobbyV4Staging.Shop.Floor_3.V_Slab
	GGAsset_LobbyWorld_686 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0006_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.HubFloor.HubFloor.V_Steel
	GGAsset_LobbyWorld_687 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0029_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.BarLamp_5.V_Steel
	GGAsset_LobbyWorld_688 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0034_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.PierCollar.V_Steel
	GGAsset_LobbyWorld_689 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0110_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.HubCeiling.CeilingLamp.V_Steel
	GGAsset_LobbyWorld_690 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0113_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.HubCeiling.CeilingLamp_2.V_Steel
	GGAsset_LobbyWorld_691 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0116_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.HubCeiling.CeilingLamp_3.V_Steel
	GGAsset_LobbyWorld_692 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0119_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.HubCeiling.CeilingLamp_4.V_Steel
	GGAsset_LobbyWorld_693 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0122_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.HubCeiling.CeilingLamp_5.V_Steel
	GGAsset_LobbyWorld_694 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0125_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.HubCeiling.CeilingLamp_6.V_Steel
	GGAsset_LobbyWorld_695 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0128_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.HubCeiling.CeilingLamp_7.V_Steel
	GGAsset_LobbyWorld_696 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0131_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.HubCeiling.CeilingLamp_8.V_Steel
	GGAsset_LobbyWorld_697 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0142_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.Lantern.V_Steel
	GGAsset_LobbyWorld_698 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0150_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.LightRing.V_Steel
	GGAsset_LobbyWorld_699 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0193_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.Sign_Duels.V_Steel
	GGAsset_LobbyWorld_700 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0216_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.Sign_Shop.V_Steel
	GGAsset_LobbyWorld_701 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0239_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.Sign_Locker.V_Steel
	GGAsset_LobbyWorld_702 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0258_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.RangeDoor.V_Steel
	GGAsset_LobbyWorld_703 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0265_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.Sign_Range.V_Steel
	GGAsset_LobbyWorld_704 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0272_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.Conduit.V_Steel
	GGAsset_LobbyWorld_705 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0277_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.Gallery.Deck.V_Steel
	GGAsset_LobbyWorld_706 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0279_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.Gallery.Braces.V_Steel
	GGAsset_LobbyWorld_707 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0282_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.Gallery.Railing.V_Steel
	GGAsset_LobbyWorld_708 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0283_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.TV_TOPWINS.V_Steel
	GGAsset_LobbyWorld_709 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0294_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.Conduit_2.V_Steel
	GGAsset_LobbyWorld_710 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0299_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.Gallery_2.Deck.V_Steel
	GGAsset_LobbyWorld_711 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0301_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.Gallery_2.Braces.V_Steel
	GGAsset_LobbyWorld_712 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0304_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.Gallery_2.Railing.V_Steel
	GGAsset_LobbyWorld_713 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0305_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.TV_WINSTREAKS.V_Steel
	GGAsset_LobbyWorld_714 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0316_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.Conduit_3.V_Steel
	GGAsset_LobbyWorld_715 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0321_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.Gallery_3.Deck.V_Steel
	GGAsset_LobbyWorld_716 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0323_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.Gallery_3.Braces.V_Steel
	GGAsset_LobbyWorld_717 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0326_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.Gallery_3.Railing.V_Steel
	GGAsset_LobbyWorld_718 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0327_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.TV_News.V_Steel
	GGAsset_LobbyWorld_719 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0338_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.Conduit_4.V_Steel
	GGAsset_LobbyWorld_720 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0343_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.Gallery_4.Deck.V_Steel
	GGAsset_LobbyWorld_721 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0345_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.Gallery_4.Braces.V_Steel
	GGAsset_LobbyWorld_722 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0348_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.Gallery_4.Railing.V_Steel
	GGAsset_LobbyWorld_723 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0349_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.TV_Featured.V_Steel
	GGAsset_LobbyWorld_724 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0363_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.LightingRig.LightingRig.V_Steel
	GGAsset_LobbyWorld_725 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0363_V_Steel_2" }, -- Workspace.LobbyV4Staging.Concourse.LightingRig.LightingRig.V_Steel
	GGAsset_LobbyWorld_726 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0365_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.LightingRig.StageSpot.V_Steel
	GGAsset_LobbyWorld_727 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0369_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.LightingRig.StageSpot_2.V_Steel
	GGAsset_LobbyWorld_728 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0373_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.LightingRig.StageSpot_3.V_Steel
	GGAsset_LobbyWorld_729 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0377_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.LightingRig.StageSpot_4.V_Steel
	GGAsset_LobbyWorld_730 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0381_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.LightingRig.StageSpot_5.V_Steel
	GGAsset_LobbyWorld_731 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0385_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.LightingRig.StageSpot_6.V_Steel
	GGAsset_LobbyWorld_732 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0389_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.LightingRig.StageSpot_7.V_Steel
	GGAsset_LobbyWorld_733 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0393_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.LightingRig.StageSpot_8.V_Steel
	GGAsset_LobbyWorld_734 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0399_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.Vents.V_Steel
	GGAsset_LobbyWorld_735 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0403_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.Vents_2.V_Steel
	GGAsset_LobbyWorld_736 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0407_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.Vents_3.V_Steel
	GGAsset_LobbyWorld_737 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0411_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.Vents_4.V_Steel
	GGAsset_LobbyWorld_738 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0412_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.Plaques_Locker.V_Steel
	GGAsset_LobbyWorld_739 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0415_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.Plaques_Range.V_Steel
	GGAsset_LobbyWorld_740 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0421_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.Holo_Gift.V_Steel
	GGAsset_LobbyWorld_741 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0430_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.Holo_Badge.V_Steel
	GGAsset_LobbyWorld_742 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0439_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.Holo_Rifle.V_Steel
	GGAsset_LobbyWorld_743 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ConcourseD_0448_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.Holo_Crate.V_Steel
	GGAsset_LobbyWorld_744 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "Concourse_0274_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.Gallery.Deck.V_Steel
	GGAsset_LobbyWorld_745 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "Concourse_0296_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.Gallery_2.Deck.V_Steel
	GGAsset_LobbyWorld_746 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "Concourse_0318_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.Gallery_3.Deck.V_Steel
	GGAsset_LobbyWorld_747 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "Concourse_0340_V_Steel" }, -- Workspace.LobbyV4Staging.Concourse.Gallery_4.Deck.V_Steel
	GGAsset_LobbyWorld_748 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "DuelsD_0013_V_Steel" }, -- Workspace.LobbyV4Staging.Duels.DuelsFloor.V_Steel
	GGAsset_LobbyWorld_749 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "DuelsD_0013_V_Steel_2" }, -- Workspace.LobbyV4Staging.Duels.DuelsFloor.V_Steel
	GGAsset_LobbyWorld_750 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "DuelsD_0013_V_Steel_3" }, -- Workspace.LobbyV4Staging.Duels.DuelsFloor.V_Steel
	GGAsset_LobbyWorld_751 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "DuelsD_0013_V_Steel_4" }, -- Workspace.LobbyV4Staging.Duels.DuelsFloor.V_Steel
	GGAsset_LobbyWorld_752 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "DuelsD_0027_V_Steel" }, -- Workspace.LobbyV4Staging.Duels.Pad_1v1_2.Pad_1v1_2.V_Steel
	GGAsset_LobbyWorld_753 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "DuelsD_0045_V_Steel" }, -- Workspace.LobbyV4Staging.Duels.PadSign.V_Steel
	GGAsset_LobbyWorld_754 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "DuelsD_0068_V_Steel" }, -- Workspace.LobbyV4Staging.Duels.PadSign_2.V_Steel
	GGAsset_LobbyWorld_755 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "DuelsD_0091_V_Steel" }, -- Workspace.LobbyV4Staging.Duels.PadSign_3.V_Steel
	GGAsset_LobbyWorld_756 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "DuelsD_0114_V_Steel" }, -- Workspace.LobbyV4Staging.Duels.PadSign_4.V_Steel
	GGAsset_LobbyWorld_757 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "DuelsD_0143_V_Steel" }, -- Workspace.LobbyV4Staging.Duels.PadSign_5.V_Steel
	GGAsset_LobbyWorld_758 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "DuelsD_0166_V_Steel" }, -- Workspace.LobbyV4Staging.Duels.PadSign_6.V_Steel
	GGAsset_LobbyWorld_759 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "DuelsD_0189_V_Steel" }, -- Workspace.LobbyV4Staging.Duels.PadSign_7.V_Steel
	GGAsset_LobbyWorld_760 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "DuelsD_0212_V_Steel" }, -- Workspace.LobbyV4Staging.Duels.PadSign_8.V_Steel
	GGAsset_LobbyWorld_761 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "DuelsD_0222_V_Steel" }, -- Workspace.LobbyV4Staging.Duels.ApseVents.V_Steel
	GGAsset_LobbyWorld_762 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "DuelsD_0233_V_Steel" }, -- Workspace.LobbyV4Staging.Duels.Sign_Gauntlet.V_Steel
	GGAsset_LobbyWorld_763 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "DuelsD_0243_V_Steel" }, -- Workspace.LobbyV4Staging.Duels.ApseVents_2.V_Steel
	GGAsset_LobbyWorld_764 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "DuelsD_0244_V_Steel" }, -- Workspace.LobbyV4Staging.Duels.FrontDetails.V_Steel
	GGAsset_LobbyWorld_765 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "DuelsD_0260_V_Steel" }, -- Workspace.LobbyV4Staging.Duels.BarLamp_16.V_Steel
	GGAsset_LobbyWorld_766 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "DuelsD_0372_V_Steel" }, -- Workspace.LobbyV4Staging.Duels.Jumbotron.V_Steel
	GGAsset_LobbyWorld_767 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "DuelsD_0383_V_Steel" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.NaveVault.V_Steel
	GGAsset_LobbyWorld_768 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "DuelsD_0388_V_Steel" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp.V_Steel
	GGAsset_LobbyWorld_769 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "DuelsD_0391_V_Steel" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_2.V_Steel
	GGAsset_LobbyWorld_770 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "DuelsD_0394_V_Steel" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_3.V_Steel
	GGAsset_LobbyWorld_771 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "DuelsD_0397_V_Steel" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_4.V_Steel
	GGAsset_LobbyWorld_772 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "DuelsD_0400_V_Steel" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_5.V_Steel
	GGAsset_LobbyWorld_773 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "DuelsD_0403_V_Steel" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_6.V_Steel
	GGAsset_LobbyWorld_774 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "DuelsD_0406_V_Steel" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_7.V_Steel
	GGAsset_LobbyWorld_775 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "DuelsD_0409_V_Steel" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_8.V_Steel
	GGAsset_LobbyWorld_776 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "DuelsD_0412_V_Steel" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_9.V_Steel
	GGAsset_LobbyWorld_777 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "DuelsD_0415_V_Steel" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_10.V_Steel
	GGAsset_LobbyWorld_778 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "DuelsD_0421_V_Steel" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_11.V_Steel
	GGAsset_LobbyWorld_779 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "DuelsD_0424_V_Steel" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_12.V_Steel
	GGAsset_LobbyWorld_780 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "DuelsD_0427_V_Steel" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_13.V_Steel
	GGAsset_LobbyWorld_781 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "DuelsD_0430_V_Steel" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_14.V_Steel
	GGAsset_LobbyWorld_782 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "DuelsD_0433_V_Steel" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_15.V_Steel
	GGAsset_LobbyWorld_783 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "DuelsD_0436_V_Steel" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_16.V_Steel
	GGAsset_LobbyWorld_784 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "DuelsD_0439_V_Steel" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_17.V_Steel
	GGAsset_LobbyWorld_785 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "DuelsD_0442_V_Steel" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_18.V_Steel
	GGAsset_LobbyWorld_786 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "LockerD_0026_V_Steel" }, -- Workspace.LobbyV4Staging.Locker.RoomVault.V_Steel
	GGAsset_LobbyWorld_787 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "LockerD_0031_V_Steel" }, -- Workspace.LobbyV4Staging.Locker.CeilingLamp.V_Steel
	GGAsset_LobbyWorld_788 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "LockerD_0034_V_Steel" }, -- Workspace.LobbyV4Staging.Locker.CeilingLamp_2.V_Steel
	GGAsset_LobbyWorld_789 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "LockerD_0037_V_Steel" }, -- Workspace.LobbyV4Staging.Locker.CeilingLamp_3.V_Steel
	GGAsset_LobbyWorld_790 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "LockerD_0040_V_Steel" }, -- Workspace.LobbyV4Staging.Locker.CeilingLamp_4.V_Steel
	GGAsset_LobbyWorld_791 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "LockerD_0046_V_Steel" }, -- Workspace.LobbyV4Staging.Locker.CeilingLamp_5.V_Steel
	GGAsset_LobbyWorld_792 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "LockerD_0049_V_Steel" }, -- Workspace.LobbyV4Staging.Locker.CeilingLamp_6.V_Steel
	GGAsset_LobbyWorld_793 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "LockerD_0050_V_Steel" }, -- Workspace.LobbyV4Staging.Locker.Conduit_5.V_Steel
	GGAsset_LobbyWorld_794 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "LockerD_0052_V_Steel" }, -- Workspace.LobbyV4Staging.Locker.Conduit_6.V_Steel
	GGAsset_LobbyWorld_795 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "LockerD_0091_V_Steel" }, -- Workspace.LobbyV4Staging.Locker.KnifePlinth.V_Steel
	GGAsset_LobbyWorld_796 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "LockerD_0096_V_Steel" }, -- Workspace.LobbyV4Staging.Locker.Table_Vandal.V_Steel
	GGAsset_LobbyWorld_797 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "LockerD_0105_V_Steel" }, -- Workspace.LobbyV4Staging.Locker.Table_Phantom.V_Steel
	GGAsset_LobbyWorld_798 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "LockerD_0114_V_Steel" }, -- Workspace.LobbyV4Staging.Locker.Table_Operator.V_Steel
	GGAsset_LobbyWorld_799 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "LockerD_0123_V_Steel" }, -- Workspace.LobbyV4Staging.Locker.Table_Odin.V_Steel
	GGAsset_LobbyWorld_800 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "LockerD_0132_V_Steel" }, -- Workspace.LobbyV4Staging.Locker.Table_Judge.V_Steel
	GGAsset_LobbyWorld_801 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "LockerD_0141_V_Steel" }, -- Workspace.LobbyV4Staging.Locker.Table_Spectre.V_Steel
	GGAsset_LobbyWorld_802 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "LockerD_0150_V_Steel" }, -- Workspace.LobbyV4Staging.Locker.Table_Sheriff.V_Steel
	GGAsset_LobbyWorld_803 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "LockerD_0159_V_Steel" }, -- Workspace.LobbyV4Staging.Locker.Table_Classic.V_Steel
	GGAsset_LobbyWorld_804 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "LockerD_0167_V_Steel" }, -- Workspace.LobbyV4Staging.Locker.GunWall.V_Steel
	GGAsset_LobbyWorld_805 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "LockerD_0172_V_Steel" }, -- Workspace.LobbyV4Staging.Locker.Sign_Loadout.V_Steel
	GGAsset_LobbyWorld_806 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "LockerD_0178_V_Steel" }, -- Workspace.LobbyV4Staging.Locker.HangLamp.V_Steel
	GGAsset_LobbyWorld_807 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "LockerD_0182_V_Steel" }, -- Workspace.LobbyV4Staging.Locker.HangLamp_2.V_Steel
	GGAsset_LobbyWorld_808 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "LockerD_0186_V_Steel" }, -- Workspace.LobbyV4Staging.Locker.Vents_N.V_Steel
	GGAsset_LobbyWorld_809 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "LockerD_0190_V_Steel" }, -- Workspace.LobbyV4Staging.Locker.Vents_S.V_Steel
	GGAsset_LobbyWorld_810 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0028_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.BarLamp_28.V_Steel
	GGAsset_LobbyWorld_811 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0059_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.RoomVault_2.V_Steel
	GGAsset_LobbyWorld_812 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0064_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_7.V_Steel
	GGAsset_LobbyWorld_813 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0067_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_8.V_Steel
	GGAsset_LobbyWorld_814 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0070_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_9.V_Steel
	GGAsset_LobbyWorld_815 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0073_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_10.V_Steel
	GGAsset_LobbyWorld_816 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0076_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_11.V_Steel
	GGAsset_LobbyWorld_817 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0084_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_12.V_Steel
	GGAsset_LobbyWorld_818 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0087_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_13.V_Steel
	GGAsset_LobbyWorld_819 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0090_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_14.V_Steel
	GGAsset_LobbyWorld_820 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0093_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_15.V_Steel
	GGAsset_LobbyWorld_821 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0096_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_16.V_Steel
	GGAsset_LobbyWorld_822 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0099_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_17.V_Steel
	GGAsset_LobbyWorld_823 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0100_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.Conduit_7.V_Steel
	GGAsset_LobbyWorld_824 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0102_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.Conduit_8.V_Steel
	GGAsset_LobbyWorld_825 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0142_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.TV_ShopN.V_Steel
	GGAsset_LobbyWorld_826 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0147_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.TV_ShopS.V_Steel
	GGAsset_LobbyWorld_827 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0155_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.Vents_5.V_Steel
	GGAsset_LobbyWorld_828 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0159_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.Vents_6.V_Steel
	GGAsset_LobbyWorld_829 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0170_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.Bay_Featured.Bay_FeaturedCurtains.V_Steel
	GGAsset_LobbyWorld_830 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0175_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.Bay_Featured.Bay_Featured.V_Steel
	GGAsset_LobbyWorld_831 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0177_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.StageSpot.V_Steel
	GGAsset_LobbyWorld_832 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0181_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.StageSpot_2.V_Steel
	GGAsset_LobbyWorld_833 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0185_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.StageSpot_3.V_Steel
	GGAsset_LobbyWorld_834 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0192_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.Bay_FeaturedSign.V_Steel
	GGAsset_LobbyWorld_835 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0197_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.FeaturedPedestal.V_Steel
	GGAsset_LobbyWorld_836 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0218_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.Bay_Season.Bay_Season.V_Steel
	GGAsset_LobbyWorld_837 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0220_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.StageSpot_4.V_Steel
	GGAsset_LobbyWorld_838 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0224_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.StageSpot_5.V_Steel
	GGAsset_LobbyWorld_839 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0228_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.StageSpot_6.V_Steel
	GGAsset_LobbyWorld_840 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0235_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.Bay_SeasonSign.V_Steel
	GGAsset_LobbyWorld_841 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0260_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.Case_Deals.V_Steel
	GGAsset_LobbyWorld_842 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0270_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.Case_Rare.V_Steel
	GGAsset_LobbyWorld_843 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0280_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.Case_New.V_Steel
	GGAsset_LobbyWorld_844 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0290_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.Case_Vault.V_Steel
	GGAsset_LobbyWorld_845 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0349_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.RoomVault_3.V_Steel
	GGAsset_LobbyWorld_846 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0354_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_18.V_Steel
	GGAsset_LobbyWorld_847 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0360_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_19.V_Steel
	GGAsset_LobbyWorld_848 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0363_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_20.V_Steel
	GGAsset_LobbyWorld_849 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0364_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.Conduit_9.V_Steel
	GGAsset_LobbyWorld_850 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0366_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.Conduit_10.V_Steel
	GGAsset_LobbyWorld_851 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0371_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.TV_ShopEnd.V_Steel
	GGAsset_LobbyWorld_852 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0380_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.Sign_Market.V_Steel
	GGAsset_LobbyWorld_853 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0381_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.TV_Broker.V_Steel
	GGAsset_LobbyWorld_854 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0390_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.Sign_Broker.V_Steel
	GGAsset_LobbyWorld_855 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0412_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.Holo_ShopGift.V_Steel
	GGAsset_LobbyWorld_856 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0421_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.Holo_ShopBadge.V_Steel
	GGAsset_LobbyWorld_857 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0430_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.Path_2.V_Steel
	GGAsset_LobbyWorld_858 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0433_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.Path_3.V_Steel
	GGAsset_LobbyWorld_859 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0436_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.PathCorner.V_Steel
	GGAsset_LobbyWorld_860 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0440_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_21.V_Steel
	GGAsset_LobbyWorld_861 = { ["Ceil"] = false, ["SWMat"] = "V_Steel", ["SWName"] = "ShopD_0443_V_Steel" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_22.V_Steel
	GGAsset_LobbyWorld_862 = { ["Ceil"] = false, ["SWMat"] = "V_TeamA", ["SWName"] = "DuelsD_0033_V_TeamA" }, -- Workspace.LobbyV4Staging.Duels.Pad_1v1_2.Pad_1v1_2.V_TeamA
	GGAsset_LobbyWorld_863 = { ["Ceil"] = false, ["SWMat"] = "V_TeamB", ["SWName"] = "DuelsD_0037_V_TeamB" }, -- Workspace.LobbyV4Staging.Duels.Pad_1v1_2.Pad_1v1_2.V_TeamB
	GGAsset_LobbyWorld_864 = { ["Ceil"] = false, ["SWMat"] = "V_ThLilac", ["SWName"] = "ConcourseD_0010_V_ThLilac" }, -- Workspace.LobbyV4Staging.Concourse.HubFloor.HubFloor.V_ThLilac
	GGAsset_LobbyWorld_865 = { ["Ceil"] = false, ["SWMat"] = "V_ThLilac", ["SWName"] = "LockerD_0086_V_ThLilac" }, -- Workspace.LobbyV4Staging.Locker.FloorEmblem.V_ThLilac
	GGAsset_LobbyWorld_866 = { ["Ceil"] = false, ["SWMat"] = "V_ThLilac", ["SWName"] = "ShopD_0209_V_ThLilac" }, -- Workspace.LobbyV4Staging.Shop.Bay_Season.Bay_Season.V_ThLilac
	GGAsset_LobbyWorld_867 = { ["Ceil"] = false, ["SWMat"] = "V_ThViolet", ["SWName"] = "LockerD_0085_V_ThViolet" }, -- Workspace.LobbyV4Staging.Locker.FloorEmblem.V_ThViolet
	GGAsset_LobbyWorld_868 = { ["Ceil"] = false, ["SWMat"] = "V_ThViolet", ["SWName"] = "LockerD_0089_V_ThViolet" }, -- Workspace.LobbyV4Staging.Locker.KnifePlinth.V_ThViolet
	GGAsset_LobbyWorld_869 = { ["Ceil"] = false, ["SWMat"] = "V_ThViolet", ["SWName"] = "LockerD_0095_V_ThViolet" }, -- Workspace.LobbyV4Staging.Locker.Table_Vandal.V_ThViolet
	GGAsset_LobbyWorld_870 = { ["Ceil"] = false, ["SWMat"] = "V_ThViolet", ["SWName"] = "LockerD_0104_V_ThViolet" }, -- Workspace.LobbyV4Staging.Locker.Table_Phantom.V_ThViolet
	GGAsset_LobbyWorld_871 = { ["Ceil"] = false, ["SWMat"] = "V_ThViolet", ["SWName"] = "LockerD_0113_V_ThViolet" }, -- Workspace.LobbyV4Staging.Locker.Table_Operator.V_ThViolet
	GGAsset_LobbyWorld_872 = { ["Ceil"] = false, ["SWMat"] = "V_ThViolet", ["SWName"] = "LockerD_0122_V_ThViolet" }, -- Workspace.LobbyV4Staging.Locker.Table_Odin.V_ThViolet
	GGAsset_LobbyWorld_873 = { ["Ceil"] = false, ["SWMat"] = "V_ThViolet", ["SWName"] = "LockerD_0131_V_ThViolet" }, -- Workspace.LobbyV4Staging.Locker.Table_Judge.V_ThViolet
	GGAsset_LobbyWorld_874 = { ["Ceil"] = false, ["SWMat"] = "V_ThViolet", ["SWName"] = "LockerD_0140_V_ThViolet" }, -- Workspace.LobbyV4Staging.Locker.Table_Spectre.V_ThViolet
	GGAsset_LobbyWorld_875 = { ["Ceil"] = false, ["SWMat"] = "V_ThViolet", ["SWName"] = "LockerD_0149_V_ThViolet" }, -- Workspace.LobbyV4Staging.Locker.Table_Sheriff.V_ThViolet
	GGAsset_LobbyWorld_876 = { ["Ceil"] = false, ["SWMat"] = "V_ThViolet", ["SWName"] = "LockerD_0158_V_ThViolet" }, -- Workspace.LobbyV4Staging.Locker.Table_Classic.V_ThViolet
	GGAsset_LobbyWorld_877 = { ["Ceil"] = false, ["SWMat"] = "V_ThViolet", ["SWName"] = "ShopD_0108_V_ThViolet" }, -- Workspace.LobbyV4Staging.Shop.WallBand.V_ThViolet
	GGAsset_LobbyWorld_878 = { ["Ceil"] = false, ["SWMat"] = "V_ThViolet", ["SWName"] = "ShopD_0109_V_ThViolet" }, -- Workspace.LobbyV4Staging.Shop.WallBand_2.V_ThViolet
	GGAsset_LobbyWorld_879 = { ["Ceil"] = false, ["SWMat"] = "V_ThViolet", ["SWName"] = "ShopD_0210_V_ThViolet" }, -- Workspace.LobbyV4Staging.Shop.Bay_Season.Bay_Season.V_ThViolet
	GGAsset_LobbyWorld_880 = { ["Ceil"] = false, ["SWMat"] = "V_ThViolet", ["SWName"] = "ShopD_0244_V_ThViolet" }, -- Workspace.LobbyV4Staging.Shop.Mark_Season.Mark_Season.V_ThViolet
	GGAsset_LobbyWorld_881 = { ["Ceil"] = false, ["SWMat"] = "V_ThViolet", ["SWName"] = "ShopD_0259_V_ThViolet" }, -- Workspace.LobbyV4Staging.Shop.Case_Deals.V_ThViolet
	GGAsset_LobbyWorld_882 = { ["Ceil"] = false, ["SWMat"] = "V_ThViolet", ["SWName"] = "ShopD_0269_V_ThViolet" }, -- Workspace.LobbyV4Staging.Shop.Case_Rare.V_ThViolet
	GGAsset_LobbyWorld_883 = { ["Ceil"] = false, ["SWMat"] = "V_ThViolet", ["SWName"] = "ShopD_0279_V_ThViolet" }, -- Workspace.LobbyV4Staging.Shop.Case_New.V_ThViolet
	GGAsset_LobbyWorld_884 = { ["Ceil"] = false, ["SWMat"] = "V_ThViolet", ["SWName"] = "ShopD_0289_V_ThViolet" }, -- Workspace.LobbyV4Staging.Shop.Case_Vault.V_ThViolet
	GGAsset_LobbyWorld_885 = { ["Ceil"] = false, ["SWMat"] = "V_ThViolet", ["SWName"] = "ShopD_0403_V_ThViolet" }, -- Workspace.LobbyV4Staging.Shop.BrokerEffect.V_ThViolet
	GGAsset_LobbyWorld_886 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0027_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.Pier.V_Trim
	GGAsset_LobbyWorld_887 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0030_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.BarLamp_5.V_Trim
	GGAsset_LobbyWorld_888 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0033_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.PierCollar.V_Trim
	GGAsset_LobbyWorld_889 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0143_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.Lantern.V_Trim
	GGAsset_LobbyWorld_890 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0154_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.Wall.V_Trim
	GGAsset_LobbyWorld_891 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0159_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.Wall_2.V_Trim
	GGAsset_LobbyWorld_892 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0164_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.Wall_3.V_Trim
	GGAsset_LobbyWorld_893 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0169_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.Wall_4.V_Trim
	GGAsset_LobbyWorld_894 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0171_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.Portal_Duels.V_Trim
	GGAsset_LobbyWorld_895 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0182_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.Gate_Duels.V_Trim
	GGAsset_LobbyWorld_896 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0190_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.Sign_Duels.V_Trim
	GGAsset_LobbyWorld_897 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0194_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.Portal_Shop.V_Trim
	GGAsset_LobbyWorld_898 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0205_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.Gate_Shop.V_Trim
	GGAsset_LobbyWorld_899 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0213_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.Sign_Shop.V_Trim
	GGAsset_LobbyWorld_900 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0217_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.Portal_Locker.V_Trim
	GGAsset_LobbyWorld_901 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0228_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.Gate_Locker.V_Trim
	GGAsset_LobbyWorld_902 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0236_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.Sign_Locker.V_Trim
	GGAsset_LobbyWorld_903 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0240_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.Portal_Range.V_Trim
	GGAsset_LobbyWorld_904 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0251_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.Gate_Range.V_Trim
	GGAsset_LobbyWorld_905 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0262_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.Sign_Range.V_Trim
	GGAsset_LobbyWorld_906 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0269_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.Wall_5.V_Trim
	GGAsset_LobbyWorld_907 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0273_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.Conduit.V_Trim
	GGAsset_LobbyWorld_908 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0275_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.Gallery.Deck.V_Trim
	GGAsset_LobbyWorld_909 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0280_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.Gallery.Braces.V_Trim
	GGAsset_LobbyWorld_910 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0281_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.Gallery.Railing.V_Trim
	GGAsset_LobbyWorld_911 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0284_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.TV_TOPWINS.V_Trim
	GGAsset_LobbyWorld_912 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0291_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.Wall_6.V_Trim
	GGAsset_LobbyWorld_913 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0295_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.Conduit_2.V_Trim
	GGAsset_LobbyWorld_914 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0297_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.Gallery_2.Deck.V_Trim
	GGAsset_LobbyWorld_915 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0302_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.Gallery_2.Braces.V_Trim
	GGAsset_LobbyWorld_916 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0303_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.Gallery_2.Railing.V_Trim
	GGAsset_LobbyWorld_917 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0306_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.TV_WINSTREAKS.V_Trim
	GGAsset_LobbyWorld_918 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0313_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.Wall_7.V_Trim
	GGAsset_LobbyWorld_919 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0317_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.Conduit_3.V_Trim
	GGAsset_LobbyWorld_920 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0319_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.Gallery_3.Deck.V_Trim
	GGAsset_LobbyWorld_921 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0324_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.Gallery_3.Braces.V_Trim
	GGAsset_LobbyWorld_922 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0325_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.Gallery_3.Railing.V_Trim
	GGAsset_LobbyWorld_923 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0328_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.TV_News.V_Trim
	GGAsset_LobbyWorld_924 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0335_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.Wall_8.V_Trim
	GGAsset_LobbyWorld_925 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0339_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.Conduit_4.V_Trim
	GGAsset_LobbyWorld_926 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0341_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.Gallery_4.Deck.V_Trim
	GGAsset_LobbyWorld_927 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0346_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.Gallery_4.Braces.V_Trim
	GGAsset_LobbyWorld_928 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0347_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.Gallery_4.Railing.V_Trim
	GGAsset_LobbyWorld_929 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0350_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.TV_Featured.V_Trim
	GGAsset_LobbyWorld_930 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0366_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.LightingRig.StageSpot.V_Trim
	GGAsset_LobbyWorld_931 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0370_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.LightingRig.StageSpot_2.V_Trim
	GGAsset_LobbyWorld_932 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0374_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.LightingRig.StageSpot_3.V_Trim
	GGAsset_LobbyWorld_933 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0378_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.LightingRig.StageSpot_4.V_Trim
	GGAsset_LobbyWorld_934 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0382_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.LightingRig.StageSpot_5.V_Trim
	GGAsset_LobbyWorld_935 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0386_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.LightingRig.StageSpot_6.V_Trim
	GGAsset_LobbyWorld_936 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0390_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.LightingRig.StageSpot_7.V_Trim
	GGAsset_LobbyWorld_937 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0394_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.LightingRig.StageSpot_8.V_Trim
	GGAsset_LobbyWorld_938 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0397_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.Vents.V_Trim
	GGAsset_LobbyWorld_939 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0401_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.Vents_2.V_Trim
	GGAsset_LobbyWorld_940 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0405_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.Vents_3.V_Trim
	GGAsset_LobbyWorld_941 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0409_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.Vents_4.V_Trim
	GGAsset_LobbyWorld_942 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0414_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.Plaques_Locker.V_Trim
	GGAsset_LobbyWorld_943 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0417_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.Plaques_Range.V_Trim
	GGAsset_LobbyWorld_944 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ConcourseD_0457_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.DaisCollar_4.V_Trim
	GGAsset_LobbyWorld_945 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "Concourse_0008_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.HubFloor.HubFloor.V_Trim
	GGAsset_LobbyWorld_946 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "Concourse_0357_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.Bench.V_Trim
	GGAsset_LobbyWorld_947 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "DuelsD_0003_V_Trim" }, -- Workspace.LobbyV4Staging.Duels.Landing.V_Trim
	GGAsset_LobbyWorld_948 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "DuelsD_0020_V_Trim" }, -- Workspace.LobbyV4Staging.Duels.Wall_9.V_Trim
	GGAsset_LobbyWorld_949 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "DuelsD_0023_V_Trim" }, -- Workspace.LobbyV4Staging.Duels.Pad_1v1_2.Pad_1v1_2.V_Trim
	GGAsset_LobbyWorld_950 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "DuelsD_0042_V_Trim" }, -- Workspace.LobbyV4Staging.Duels.PadSign.V_Trim
	GGAsset_LobbyWorld_951 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "DuelsD_0065_V_Trim" }, -- Workspace.LobbyV4Staging.Duels.PadSign_2.V_Trim
	GGAsset_LobbyWorld_952 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "DuelsD_0088_V_Trim" }, -- Workspace.LobbyV4Staging.Duels.PadSign_3.V_Trim
	GGAsset_LobbyWorld_953 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "DuelsD_0111_V_Trim" }, -- Workspace.LobbyV4Staging.Duels.PadSign_4.V_Trim
	GGAsset_LobbyWorld_954 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "DuelsD_0118_V_Trim" }, -- Workspace.LobbyV4Staging.Duels.Wall_10.V_Trim
	GGAsset_LobbyWorld_955 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "DuelsD_0140_V_Trim" }, -- Workspace.LobbyV4Staging.Duels.PadSign_5.V_Trim
	GGAsset_LobbyWorld_956 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "DuelsD_0163_V_Trim" }, -- Workspace.LobbyV4Staging.Duels.PadSign_6.V_Trim
	GGAsset_LobbyWorld_957 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "DuelsD_0186_V_Trim" }, -- Workspace.LobbyV4Staging.Duels.PadSign_7.V_Trim
	GGAsset_LobbyWorld_958 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "DuelsD_0209_V_Trim" }, -- Workspace.LobbyV4Staging.Duels.PadSign_8.V_Trim
	GGAsset_LobbyWorld_959 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "DuelsD_0216_V_Trim" }, -- Workspace.LobbyV4Staging.Duels.Wall_11.V_Trim
	GGAsset_LobbyWorld_960 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "DuelsD_0220_V_Trim" }, -- Workspace.LobbyV4Staging.Duels.ApseVents.V_Trim
	GGAsset_LobbyWorld_961 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "DuelsD_0226_V_Trim" }, -- Workspace.LobbyV4Staging.Duels.Wall_12.V_Trim
	GGAsset_LobbyWorld_962 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "DuelsD_0230_V_Trim" }, -- Workspace.LobbyV4Staging.Duels.Sign_Gauntlet.V_Trim
	GGAsset_LobbyWorld_963 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "DuelsD_0237_V_Trim" }, -- Workspace.LobbyV4Staging.Duels.Wall_13.V_Trim
	GGAsset_LobbyWorld_964 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "DuelsD_0241_V_Trim" }, -- Workspace.LobbyV4Staging.Duels.ApseVents_2.V_Trim
	GGAsset_LobbyWorld_965 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "DuelsD_0246_V_Trim" }, -- Workspace.LobbyV4Staging.Duels.FrontDetails.V_Trim
	GGAsset_LobbyWorld_966 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "DuelsD_0253_V_Trim" }, -- Workspace.LobbyV4Staging.Duels.Wall_14.V_Trim
	GGAsset_LobbyWorld_967 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "DuelsD_0258_V_Trim" }, -- Workspace.LobbyV4Staging.Duels.Pier_10.V_Trim
	GGAsset_LobbyWorld_968 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "DuelsD_0261_V_Trim" }, -- Workspace.LobbyV4Staging.Duels.BarLamp_16.V_Trim
	GGAsset_LobbyWorld_969 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "DuelsD_0322_V_Trim" }, -- Workspace.LobbyV4Staging.Duels.CornerPier_4.V_Trim
	GGAsset_LobbyWorld_970 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "DuelsD_0369_V_Trim" }, -- Workspace.LobbyV4Staging.Duels.Jumbotron.V_Trim
	GGAsset_LobbyWorld_971 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "DuelsD_0375_V_Trim" }, -- Workspace.LobbyV4Staging.Duels.TrophyPlinth.V_Trim
	GGAsset_LobbyWorld_972 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "DuelsD_0378_V_Trim" }, -- Workspace.LobbyV4Staging.Duels.Trophy.V_Trim
	GGAsset_LobbyWorld_973 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "LockerD_0004_V_Trim" }, -- Workspace.LobbyV4Staging.Locker.Wall_15.V_Trim
	GGAsset_LobbyWorld_974 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "LockerD_0010_V_Trim" }, -- Workspace.LobbyV4Staging.Locker.Wall_16.V_Trim
	GGAsset_LobbyWorld_975 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "LockerD_0016_V_Trim" }, -- Workspace.LobbyV4Staging.Locker.Wall_17.V_Trim
	GGAsset_LobbyWorld_976 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "LockerD_0021_V_Trim" }, -- Workspace.LobbyV4Staging.Locker.Wall_18.V_Trim
	GGAsset_LobbyWorld_977 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "LockerD_0051_V_Trim" }, -- Workspace.LobbyV4Staging.Locker.Conduit_5.V_Trim
	GGAsset_LobbyWorld_978 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "LockerD_0053_V_Trim" }, -- Workspace.LobbyV4Staging.Locker.Conduit_6.V_Trim
	GGAsset_LobbyWorld_979 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "LockerD_0057_V_Trim" }, -- Workspace.LobbyV4Staging.Locker.Wall_19.V_Trim
	GGAsset_LobbyWorld_980 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "LockerD_0063_V_Trim" }, -- Workspace.LobbyV4Staging.Locker.Wall_20.V_Trim
	GGAsset_LobbyWorld_981 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "LockerD_0069_V_Trim" }, -- Workspace.LobbyV4Staging.Locker.Wall_21.V_Trim
	GGAsset_LobbyWorld_982 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "LockerD_0075_V_Trim" }, -- Workspace.LobbyV4Staging.Locker.Wall_22.V_Trim
	GGAsset_LobbyWorld_983 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "LockerD_0078_V_Trim" }, -- Workspace.LobbyV4Staging.Locker.Mouth.V_Trim
	GGAsset_LobbyWorld_984 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "LockerD_0090_V_Trim" }, -- Workspace.LobbyV4Staging.Locker.KnifePlinth.V_Trim
	GGAsset_LobbyWorld_985 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "LockerD_0093_V_Trim" }, -- Workspace.LobbyV4Staging.Locker.Table_Vandal.V_Trim
	GGAsset_LobbyWorld_986 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "LockerD_0102_V_Trim" }, -- Workspace.LobbyV4Staging.Locker.Table_Phantom.V_Trim
	GGAsset_LobbyWorld_987 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "LockerD_0111_V_Trim" }, -- Workspace.LobbyV4Staging.Locker.Table_Operator.V_Trim
	GGAsset_LobbyWorld_988 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "LockerD_0120_V_Trim" }, -- Workspace.LobbyV4Staging.Locker.Table_Odin.V_Trim
	GGAsset_LobbyWorld_989 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "LockerD_0129_V_Trim" }, -- Workspace.LobbyV4Staging.Locker.Table_Judge.V_Trim
	GGAsset_LobbyWorld_990 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "LockerD_0138_V_Trim" }, -- Workspace.LobbyV4Staging.Locker.Table_Spectre.V_Trim
	GGAsset_LobbyWorld_991 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "LockerD_0147_V_Trim" }, -- Workspace.LobbyV4Staging.Locker.Table_Sheriff.V_Trim
	GGAsset_LobbyWorld_992 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "LockerD_0156_V_Trim" }, -- Workspace.LobbyV4Staging.Locker.Table_Classic.V_Trim
	GGAsset_LobbyWorld_993 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "LockerD_0165_V_Trim" }, -- Workspace.LobbyV4Staging.Locker.GunWall.V_Trim
	GGAsset_LobbyWorld_994 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "LockerD_0169_V_Trim" }, -- Workspace.LobbyV4Staging.Locker.Sign_Loadout.V_Trim
	GGAsset_LobbyWorld_995 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "LockerD_0174_V_Trim" }, -- Workspace.LobbyV4Staging.Locker.ArmorerStep.V_Trim
	GGAsset_LobbyWorld_996 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "LockerD_0177_V_Trim" }, -- Workspace.LobbyV4Staging.Locker.HangLamp.V_Trim
	GGAsset_LobbyWorld_997 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "LockerD_0181_V_Trim" }, -- Workspace.LobbyV4Staging.Locker.HangLamp_2.V_Trim
	GGAsset_LobbyWorld_998 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "LockerD_0184_V_Trim" }, -- Workspace.LobbyV4Staging.Locker.Vents_N.V_Trim
	GGAsset_LobbyWorld_999 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "LockerD_0188_V_Trim" }, -- Workspace.LobbyV4Staging.Locker.Vents_S.V_Trim
	GGAsset_LobbyWorld_1000 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ShopD_0004_V_Trim" }, -- Workspace.LobbyV4Staging.Shop.Wall_23.V_Trim
	GGAsset_LobbyWorld_1001 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ShopD_0010_V_Trim" }, -- Workspace.LobbyV4Staging.Shop.Wall_24.V_Trim
	GGAsset_LobbyWorld_1002 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ShopD_0016_V_Trim" }, -- Workspace.LobbyV4Staging.Shop.Wall_25.V_Trim
	GGAsset_LobbyWorld_1003 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ShopD_0022_V_Trim" }, -- Workspace.LobbyV4Staging.Shop.Wall_26.V_Trim
	GGAsset_LobbyWorld_1004 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ShopD_0026_V_Trim" }, -- Workspace.LobbyV4Staging.Shop.CornerPier_13.V_Trim
	GGAsset_LobbyWorld_1005 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ShopD_0029_V_Trim" }, -- Workspace.LobbyV4Staging.Shop.BarLamp_28.V_Trim
	GGAsset_LobbyWorld_1006 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ShopD_0101_V_Trim" }, -- Workspace.LobbyV4Staging.Shop.Conduit_7.V_Trim
	GGAsset_LobbyWorld_1007 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ShopD_0103_V_Trim" }, -- Workspace.LobbyV4Staging.Shop.Conduit_8.V_Trim
	GGAsset_LobbyWorld_1008 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ShopD_0104_V_Trim" }, -- Workspace.LobbyV4Staging.Shop.Mouth_2.V_Trim
	GGAsset_LobbyWorld_1009 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ShopD_0112_V_Trim" }, -- Workspace.LobbyV4Staging.Shop.Pier_19.V_Trim
	GGAsset_LobbyWorld_1010 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ShopD_0143_V_Trim" }, -- Workspace.LobbyV4Staging.Shop.TV_ShopN.V_Trim
	GGAsset_LobbyWorld_1011 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ShopD_0148_V_Trim" }, -- Workspace.LobbyV4Staging.Shop.TV_ShopS.V_Trim
	GGAsset_LobbyWorld_1012 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ShopD_0153_V_Trim" }, -- Workspace.LobbyV4Staging.Shop.Vents_5.V_Trim
	GGAsset_LobbyWorld_1013 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ShopD_0157_V_Trim" }, -- Workspace.LobbyV4Staging.Shop.Vents_6.V_Trim
	GGAsset_LobbyWorld_1014 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ShopD_0160_V_Trim" }, -- Workspace.LobbyV4Staging.Shop.Bay_Featured.Bay_Featured.V_Trim
	GGAsset_LobbyWorld_1015 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ShopD_0178_V_Trim" }, -- Workspace.LobbyV4Staging.Shop.StageSpot.V_Trim
	GGAsset_LobbyWorld_1016 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ShopD_0182_V_Trim" }, -- Workspace.LobbyV4Staging.Shop.StageSpot_2.V_Trim
	GGAsset_LobbyWorld_1017 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ShopD_0186_V_Trim" }, -- Workspace.LobbyV4Staging.Shop.StageSpot_3.V_Trim
	GGAsset_LobbyWorld_1018 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ShopD_0189_V_Trim" }, -- Workspace.LobbyV4Staging.Shop.Bay_FeaturedSign.V_Trim
	GGAsset_LobbyWorld_1019 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ShopD_0196_V_Trim" }, -- Workspace.LobbyV4Staging.Shop.FeaturedPedestal.V_Trim
	GGAsset_LobbyWorld_1020 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ShopD_0204_V_Trim" }, -- Workspace.LobbyV4Staging.Shop.Bay_Season.Bay_Season.V_Trim
	GGAsset_LobbyWorld_1021 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ShopD_0221_V_Trim" }, -- Workspace.LobbyV4Staging.Shop.StageSpot_4.V_Trim
	GGAsset_LobbyWorld_1022 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ShopD_0225_V_Trim" }, -- Workspace.LobbyV4Staging.Shop.StageSpot_5.V_Trim
	GGAsset_LobbyWorld_1023 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ShopD_0229_V_Trim" }, -- Workspace.LobbyV4Staging.Shop.StageSpot_6.V_Trim
	GGAsset_LobbyWorld_1024 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ShopD_0232_V_Trim" }, -- Workspace.LobbyV4Staging.Shop.Bay_SeasonSign.V_Trim
	GGAsset_LobbyWorld_1025 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ShopD_0237_V_Trim" }, -- Workspace.LobbyV4Staging.Shop.SeasonCrest.V_Trim
	GGAsset_LobbyWorld_1026 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ShopD_0247_V_Trim" }, -- Workspace.LobbyV4Staging.Shop.Mouth_3.V_Trim
	GGAsset_LobbyWorld_1027 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ShopD_0253_V_Trim" }, -- Workspace.LobbyV4Staging.Shop.Case_Deals.V_Trim
	GGAsset_LobbyWorld_1028 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ShopD_0263_V_Trim" }, -- Workspace.LobbyV4Staging.Shop.Case_Rare.V_Trim
	GGAsset_LobbyWorld_1029 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ShopD_0273_V_Trim" }, -- Workspace.LobbyV4Staging.Shop.Case_New.V_Trim
	GGAsset_LobbyWorld_1030 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ShopD_0283_V_Trim" }, -- Workspace.LobbyV4Staging.Shop.Case_Vault.V_Trim
	GGAsset_LobbyWorld_1031 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ShopD_0294_V_Trim" }, -- Workspace.LobbyV4Staging.Shop.Wall_27.V_Trim
	GGAsset_LobbyWorld_1032 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ShopD_0300_V_Trim" }, -- Workspace.LobbyV4Staging.Shop.Wall_28.V_Trim
	GGAsset_LobbyWorld_1033 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ShopD_0305_V_Trim" }, -- Workspace.LobbyV4Staging.Shop.Wall_29.V_Trim
	GGAsset_LobbyWorld_1034 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ShopD_0311_V_Trim" }, -- Workspace.LobbyV4Staging.Shop.Wall_30.V_Trim
	GGAsset_LobbyWorld_1035 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ShopD_0365_V_Trim" }, -- Workspace.LobbyV4Staging.Shop.Conduit_9.V_Trim
	GGAsset_LobbyWorld_1036 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ShopD_0367_V_Trim" }, -- Workspace.LobbyV4Staging.Shop.Conduit_10.V_Trim
	GGAsset_LobbyWorld_1037 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ShopD_0368_V_Trim" }, -- Workspace.LobbyV4Staging.Shop.Mouth_4.V_Trim
	GGAsset_LobbyWorld_1038 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ShopD_0372_V_Trim" }, -- Workspace.LobbyV4Staging.Shop.TV_ShopEnd.V_Trim
	GGAsset_LobbyWorld_1039 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ShopD_0377_V_Trim" }, -- Workspace.LobbyV4Staging.Shop.Sign_Market.V_Trim
	GGAsset_LobbyWorld_1040 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ShopD_0382_V_Trim" }, -- Workspace.LobbyV4Staging.Shop.TV_Broker.V_Trim
	GGAsset_LobbyWorld_1041 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ShopD_0387_V_Trim" }, -- Workspace.LobbyV4Staging.Shop.Sign_Broker.V_Trim
	GGAsset_LobbyWorld_1042 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ShopD_0393_V_Trim" }, -- Workspace.LobbyV4Staging.Shop.BrokerBundle.V_Trim
	GGAsset_LobbyWorld_1043 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ShopD_0398_V_Trim" }, -- Workspace.LobbyV4Staging.Shop.BrokerBundleMedal.V_Trim
	GGAsset_LobbyWorld_1044 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ShopD_0402_V_Trim" }, -- Workspace.LobbyV4Staging.Shop.BrokerEffect.V_Trim
	GGAsset_LobbyWorld_1045 = { ["Ceil"] = false, ["SWMat"] = "V_Trim", ["SWName"] = "ShopD_0409_V_Trim" }, -- Workspace.LobbyV4Staging.Shop.BrokerPlinth.V_Trim
	GGAsset_LobbyWorld_1046 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "ConcourseD_0026_V_Wall" }, -- Workspace.LobbyV4Staging.Concourse.Pier.V_Wall
	GGAsset_LobbyWorld_1047 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "ConcourseD_0155_V_Wall" }, -- Workspace.LobbyV4Staging.Concourse.Wall.V_Wall
	GGAsset_LobbyWorld_1048 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "ConcourseD_0160_V_Wall" }, -- Workspace.LobbyV4Staging.Concourse.Wall_2.V_Wall
	GGAsset_LobbyWorld_1049 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "ConcourseD_0165_V_Wall" }, -- Workspace.LobbyV4Staging.Concourse.Wall_3.V_Wall
	GGAsset_LobbyWorld_1050 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "ConcourseD_0170_V_Wall" }, -- Workspace.LobbyV4Staging.Concourse.Wall_4.V_Wall
	GGAsset_LobbyWorld_1051 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "ConcourseD_0172_V_Wall" }, -- Workspace.LobbyV4Staging.Concourse.Portal_Duels.V_Wall
	GGAsset_LobbyWorld_1052 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "ConcourseD_0195_V_Wall" }, -- Workspace.LobbyV4Staging.Concourse.Portal_Shop.V_Wall
	GGAsset_LobbyWorld_1053 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "ConcourseD_0218_V_Wall" }, -- Workspace.LobbyV4Staging.Concourse.Portal_Locker.V_Wall
	GGAsset_LobbyWorld_1054 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "ConcourseD_0241_V_Wall" }, -- Workspace.LobbyV4Staging.Concourse.Portal_Range.V_Wall
	GGAsset_LobbyWorld_1055 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "ConcourseD_0271_V_Wall" }, -- Workspace.LobbyV4Staging.Concourse.Wall_5.V_Wall
	GGAsset_LobbyWorld_1056 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "ConcourseD_0293_V_Wall" }, -- Workspace.LobbyV4Staging.Concourse.Wall_6.V_Wall
	GGAsset_LobbyWorld_1057 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "ConcourseD_0315_V_Wall" }, -- Workspace.LobbyV4Staging.Concourse.Wall_7.V_Wall
	GGAsset_LobbyWorld_1058 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "ConcourseD_0337_V_Wall" }, -- Workspace.LobbyV4Staging.Concourse.Wall_8.V_Wall
	GGAsset_LobbyWorld_1059 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "ConcourseD_0396_V_Wall" }, -- Workspace.LobbyV4Staging.Concourse.Vents.V_Wall
	GGAsset_LobbyWorld_1060 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "ConcourseD_0400_V_Wall" }, -- Workspace.LobbyV4Staging.Concourse.Vents_2.V_Wall
	GGAsset_LobbyWorld_1061 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "ConcourseD_0404_V_Wall" }, -- Workspace.LobbyV4Staging.Concourse.Vents_3.V_Wall
	GGAsset_LobbyWorld_1062 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "ConcourseD_0408_V_Wall" }, -- Workspace.LobbyV4Staging.Concourse.Vents_4.V_Wall
	GGAsset_LobbyWorld_1063 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "ConcourseD_0413_V_Wall" }, -- Workspace.LobbyV4Staging.Concourse.Plaques_Locker.V_Wall
	GGAsset_LobbyWorld_1064 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "ConcourseD_0416_V_Wall" }, -- Workspace.LobbyV4Staging.Concourse.Plaques_Range.V_Wall
	GGAsset_LobbyWorld_1065 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Concourse_0151_V_Wall" }, -- Workspace.LobbyV4Staging.Concourse.Wall.V_Wall
	GGAsset_LobbyWorld_1066 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Concourse_0156_V_Wall" }, -- Workspace.LobbyV4Staging.Concourse.Wall_2.V_Wall
	GGAsset_LobbyWorld_1067 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Concourse_0161_V_Wall" }, -- Workspace.LobbyV4Staging.Concourse.Wall_3.V_Wall
	GGAsset_LobbyWorld_1068 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Concourse_0166_V_Wall" }, -- Workspace.LobbyV4Staging.Concourse.Wall_4.V_Wall
	GGAsset_LobbyWorld_1069 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Concourse_0174_V_Wall" }, -- Workspace.LobbyV4Staging.Concourse.Portal_Duels.V_Wall
	GGAsset_LobbyWorld_1070 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Concourse_0178_V_Wall" }, -- Workspace.LobbyV4Staging.Concourse.Gate_Duels.V_Wall
	GGAsset_LobbyWorld_1071 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Concourse_0197_V_Wall" }, -- Workspace.LobbyV4Staging.Concourse.Portal_Shop.V_Wall
	GGAsset_LobbyWorld_1072 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Concourse_0201_V_Wall" }, -- Workspace.LobbyV4Staging.Concourse.Gate_Shop.V_Wall
	GGAsset_LobbyWorld_1073 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Concourse_0220_V_Wall" }, -- Workspace.LobbyV4Staging.Concourse.Portal_Locker.V_Wall
	GGAsset_LobbyWorld_1074 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Concourse_0224_V_Wall" }, -- Workspace.LobbyV4Staging.Concourse.Gate_Locker.V_Wall
	GGAsset_LobbyWorld_1075 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Concourse_0243_V_Wall" }, -- Workspace.LobbyV4Staging.Concourse.Portal_Range.V_Wall
	GGAsset_LobbyWorld_1076 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Concourse_0247_V_Wall" }, -- Workspace.LobbyV4Staging.Concourse.Gate_Range.V_Wall
	GGAsset_LobbyWorld_1077 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Concourse_0266_V_Wall" }, -- Workspace.LobbyV4Staging.Concourse.Wall_5.V_Wall
	GGAsset_LobbyWorld_1078 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Concourse_0288_V_Wall" }, -- Workspace.LobbyV4Staging.Concourse.Wall_6.V_Wall
	GGAsset_LobbyWorld_1079 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Concourse_0310_V_Wall" }, -- Workspace.LobbyV4Staging.Concourse.Wall_7.V_Wall
	GGAsset_LobbyWorld_1080 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Concourse_0332_V_Wall" }, -- Workspace.LobbyV4Staging.Concourse.Wall_8.V_Wall
	GGAsset_LobbyWorld_1081 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Concourse_0456_V_Wall" }, -- Workspace.LobbyV4Staging.Concourse.DaisCollar_4.V_Wall
	GGAsset_LobbyWorld_1082 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "DuelsD_0005_V_Wall" }, -- Workspace.LobbyV4Staging.Duels.Landing.V_Wall
	GGAsset_LobbyWorld_1083 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "DuelsD_0022_V_Wall" }, -- Workspace.LobbyV4Staging.Duels.Wall_9.V_Wall
	GGAsset_LobbyWorld_1084 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "DuelsD_0035_V_Wall" }, -- Workspace.LobbyV4Staging.Duels.Pad_1v1_2.Pad_1v1_2.V_Wall
	GGAsset_LobbyWorld_1085 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "DuelsD_0120_V_Wall" }, -- Workspace.LobbyV4Staging.Duels.Wall_10.V_Wall
	GGAsset_LobbyWorld_1086 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "DuelsD_0218_V_Wall" }, -- Workspace.LobbyV4Staging.Duels.Wall_11.V_Wall
	GGAsset_LobbyWorld_1087 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "DuelsD_0219_V_Wall" }, -- Workspace.LobbyV4Staging.Duels.ApseVents.V_Wall
	GGAsset_LobbyWorld_1088 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "DuelsD_0228_V_Wall" }, -- Workspace.LobbyV4Staging.Duels.Wall_12.V_Wall
	GGAsset_LobbyWorld_1089 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "DuelsD_0239_V_Wall" }, -- Workspace.LobbyV4Staging.Duels.Wall_13.V_Wall
	GGAsset_LobbyWorld_1090 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "DuelsD_0240_V_Wall" }, -- Workspace.LobbyV4Staging.Duels.ApseVents_2.V_Wall
	GGAsset_LobbyWorld_1091 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "DuelsD_0245_V_Wall" }, -- Workspace.LobbyV4Staging.Duels.FrontDetails.V_Wall
	GGAsset_LobbyWorld_1092 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "DuelsD_0255_V_Wall" }, -- Workspace.LobbyV4Staging.Duels.Wall_14.V_Wall
	GGAsset_LobbyWorld_1093 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "DuelsD_0257_V_Wall" }, -- Workspace.LobbyV4Staging.Duels.Pier_10.V_Wall
	GGAsset_LobbyWorld_1094 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "DuelsD_0321_V_Wall" }, -- Workspace.LobbyV4Staging.Duels.CornerPier_4.V_Wall
	GGAsset_LobbyWorld_1095 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Duels_0017_V_Wall" }, -- Workspace.LobbyV4Staging.Duels.Wall_9.V_Wall
	GGAsset_LobbyWorld_1096 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Duels_0115_V_Wall" }, -- Workspace.LobbyV4Staging.Duels.Wall_10.V_Wall
	GGAsset_LobbyWorld_1097 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Duels_0213_V_Wall" }, -- Workspace.LobbyV4Staging.Duels.Wall_11.V_Wall
	GGAsset_LobbyWorld_1098 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Duels_0223_V_Wall" }, -- Workspace.LobbyV4Staging.Duels.Wall_12.V_Wall
	GGAsset_LobbyWorld_1099 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Duels_0234_V_Wall" }, -- Workspace.LobbyV4Staging.Duels.Wall_13.V_Wall
	GGAsset_LobbyWorld_1100 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Duels_0250_V_Wall" }, -- Workspace.LobbyV4Staging.Duels.Wall_14.V_Wall
	GGAsset_LobbyWorld_1101 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Duels_0374_V_Wall" }, -- Workspace.LobbyV4Staging.Duels.TrophyPlinth.V_Wall
	GGAsset_LobbyWorld_1102 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Duels_0381_V_Wall" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.NaveVault.V_Wall
	GGAsset_LobbyWorld_1103 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Duels_V_Wall" }, -- Workspace.LobbyV4Staging.Duels.V_Wall
	GGAsset_LobbyWorld_1104 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "LockerD_0006_V_Wall" }, -- Workspace.LobbyV4Staging.Locker.Wall_15.V_Wall
	GGAsset_LobbyWorld_1105 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "LockerD_0012_V_Wall" }, -- Workspace.LobbyV4Staging.Locker.Wall_16.V_Wall
	GGAsset_LobbyWorld_1106 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "LockerD_0017_V_Wall" }, -- Workspace.LobbyV4Staging.Locker.Wall_17.V_Wall
	GGAsset_LobbyWorld_1107 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "LockerD_0022_V_Wall" }, -- Workspace.LobbyV4Staging.Locker.Wall_18.V_Wall
	GGAsset_LobbyWorld_1108 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "LockerD_0059_V_Wall" }, -- Workspace.LobbyV4Staging.Locker.Wall_19.V_Wall
	GGAsset_LobbyWorld_1109 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "LockerD_0065_V_Wall" }, -- Workspace.LobbyV4Staging.Locker.Wall_20.V_Wall
	GGAsset_LobbyWorld_1110 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "LockerD_0071_V_Wall" }, -- Workspace.LobbyV4Staging.Locker.Wall_21.V_Wall
	GGAsset_LobbyWorld_1111 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "LockerD_0077_V_Wall" }, -- Workspace.LobbyV4Staging.Locker.Wall_22.V_Wall
	GGAsset_LobbyWorld_1112 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "LockerD_0079_V_Wall" }, -- Workspace.LobbyV4Staging.Locker.Mouth.V_Wall
	GGAsset_LobbyWorld_1113 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "LockerD_0183_V_Wall" }, -- Workspace.LobbyV4Staging.Locker.Vents_N.V_Wall
	GGAsset_LobbyWorld_1114 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "LockerD_0187_V_Wall" }, -- Workspace.LobbyV4Staging.Locker.Vents_S.V_Wall
	GGAsset_LobbyWorld_1115 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Locker_0001_V_Wall" }, -- Workspace.LobbyV4Staging.Locker.Wall_15.V_Wall
	GGAsset_LobbyWorld_1116 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Locker_0007_V_Wall" }, -- Workspace.LobbyV4Staging.Locker.Wall_16.V_Wall
	GGAsset_LobbyWorld_1117 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Locker_0013_V_Wall" }, -- Workspace.LobbyV4Staging.Locker.Wall_17.V_Wall
	GGAsset_LobbyWorld_1118 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Locker_0018_V_Wall" }, -- Workspace.LobbyV4Staging.Locker.Wall_18.V_Wall
	GGAsset_LobbyWorld_1119 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Locker_0024_V_Wall" }, -- Workspace.LobbyV4Staging.Locker.RoomVault.V_Wall
	GGAsset_LobbyWorld_1120 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Locker_0054_V_Wall" }, -- Workspace.LobbyV4Staging.Locker.Wall_19.V_Wall
	GGAsset_LobbyWorld_1121 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Locker_0060_V_Wall" }, -- Workspace.LobbyV4Staging.Locker.Wall_20.V_Wall
	GGAsset_LobbyWorld_1122 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Locker_0066_V_Wall" }, -- Workspace.LobbyV4Staging.Locker.Wall_21.V_Wall
	GGAsset_LobbyWorld_1123 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Locker_0072_V_Wall" }, -- Workspace.LobbyV4Staging.Locker.Wall_22.V_Wall
	GGAsset_LobbyWorld_1124 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Locker_0088_V_Wall" }, -- Workspace.LobbyV4Staging.Locker.KnifePlinth.V_Wall
	GGAsset_LobbyWorld_1125 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Locker_0092_V_Wall" }, -- Workspace.LobbyV4Staging.Locker.Table_Vandal.V_Wall
	GGAsset_LobbyWorld_1126 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Locker_0101_V_Wall" }, -- Workspace.LobbyV4Staging.Locker.Table_Phantom.V_Wall
	GGAsset_LobbyWorld_1127 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Locker_0110_V_Wall" }, -- Workspace.LobbyV4Staging.Locker.Table_Operator.V_Wall
	GGAsset_LobbyWorld_1128 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Locker_0119_V_Wall" }, -- Workspace.LobbyV4Staging.Locker.Table_Odin.V_Wall
	GGAsset_LobbyWorld_1129 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Locker_0128_V_Wall" }, -- Workspace.LobbyV4Staging.Locker.Table_Judge.V_Wall
	GGAsset_LobbyWorld_1130 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Locker_0137_V_Wall" }, -- Workspace.LobbyV4Staging.Locker.Table_Spectre.V_Wall
	GGAsset_LobbyWorld_1131 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Locker_0146_V_Wall" }, -- Workspace.LobbyV4Staging.Locker.Table_Sheriff.V_Wall
	GGAsset_LobbyWorld_1132 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Locker_0155_V_Wall" }, -- Workspace.LobbyV4Staging.Locker.Table_Classic.V_Wall
	GGAsset_LobbyWorld_1133 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "ShopD_0006_V_Wall" }, -- Workspace.LobbyV4Staging.Shop.Wall_23.V_Wall
	GGAsset_LobbyWorld_1134 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "ShopD_0012_V_Wall" }, -- Workspace.LobbyV4Staging.Shop.Wall_24.V_Wall
	GGAsset_LobbyWorld_1135 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "ShopD_0018_V_Wall" }, -- Workspace.LobbyV4Staging.Shop.Wall_25.V_Wall
	GGAsset_LobbyWorld_1136 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "ShopD_0023_V_Wall" }, -- Workspace.LobbyV4Staging.Shop.Wall_26.V_Wall
	GGAsset_LobbyWorld_1137 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "ShopD_0025_V_Wall" }, -- Workspace.LobbyV4Staging.Shop.CornerPier_13.V_Wall
	GGAsset_LobbyWorld_1138 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "ShopD_0105_V_Wall" }, -- Workspace.LobbyV4Staging.Shop.Mouth_2.V_Wall
	GGAsset_LobbyWorld_1139 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "ShopD_0111_V_Wall" }, -- Workspace.LobbyV4Staging.Shop.Pier_19.V_Wall
	GGAsset_LobbyWorld_1140 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "ShopD_0152_V_Wall" }, -- Workspace.LobbyV4Staging.Shop.Vents_5.V_Wall
	GGAsset_LobbyWorld_1141 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "ShopD_0156_V_Wall" }, -- Workspace.LobbyV4Staging.Shop.Vents_6.V_Wall
	GGAsset_LobbyWorld_1142 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "ShopD_0161_V_Wall" }, -- Workspace.LobbyV4Staging.Shop.Bay_Featured.Bay_Featured.V_Wall
	GGAsset_LobbyWorld_1143 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "ShopD_0194_V_Wall" }, -- Workspace.LobbyV4Staging.Shop.FeaturedPedestal.V_Wall
	GGAsset_LobbyWorld_1144 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "ShopD_0205_V_Wall" }, -- Workspace.LobbyV4Staging.Shop.Bay_Season.Bay_Season.V_Wall
	GGAsset_LobbyWorld_1145 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "ShopD_0248_V_Wall" }, -- Workspace.LobbyV4Staging.Shop.Mouth_3.V_Wall
	GGAsset_LobbyWorld_1146 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "ShopD_0256_V_Wall" }, -- Workspace.LobbyV4Staging.Shop.Case_Deals.V_Wall
	GGAsset_LobbyWorld_1147 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "ShopD_0266_V_Wall" }, -- Workspace.LobbyV4Staging.Shop.Case_Rare.V_Wall
	GGAsset_LobbyWorld_1148 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "ShopD_0276_V_Wall" }, -- Workspace.LobbyV4Staging.Shop.Case_New.V_Wall
	GGAsset_LobbyWorld_1149 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "ShopD_0286_V_Wall" }, -- Workspace.LobbyV4Staging.Shop.Case_Vault.V_Wall
	GGAsset_LobbyWorld_1150 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "ShopD_0296_V_Wall" }, -- Workspace.LobbyV4Staging.Shop.Wall_27.V_Wall
	GGAsset_LobbyWorld_1151 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "ShopD_0301_V_Wall" }, -- Workspace.LobbyV4Staging.Shop.Wall_28.V_Wall
	GGAsset_LobbyWorld_1152 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "ShopD_0307_V_Wall" }, -- Workspace.LobbyV4Staging.Shop.Wall_29.V_Wall
	GGAsset_LobbyWorld_1153 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "ShopD_0313_V_Wall" }, -- Workspace.LobbyV4Staging.Shop.Wall_30.V_Wall
	GGAsset_LobbyWorld_1154 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "ShopD_0369_V_Wall" }, -- Workspace.LobbyV4Staging.Shop.Mouth_4.V_Wall
	GGAsset_LobbyWorld_1155 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Shop_0001_V_Wall" }, -- Workspace.LobbyV4Staging.Shop.Wall_23.V_Wall
	GGAsset_LobbyWorld_1156 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Shop_0007_V_Wall" }, -- Workspace.LobbyV4Staging.Shop.Wall_24.V_Wall
	GGAsset_LobbyWorld_1157 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Shop_0013_V_Wall" }, -- Workspace.LobbyV4Staging.Shop.Wall_25.V_Wall
	GGAsset_LobbyWorld_1158 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Shop_0019_V_Wall" }, -- Workspace.LobbyV4Staging.Shop.Wall_26.V_Wall
	GGAsset_LobbyWorld_1159 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Shop_0057_V_Wall" }, -- Workspace.LobbyV4Staging.Shop.RoomVault_2.V_Wall
	GGAsset_LobbyWorld_1160 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Shop_0163_V_Wall" }, -- Workspace.LobbyV4Staging.Shop.Bay_Featured.Bay_Featured.V_Wall
	GGAsset_LobbyWorld_1161 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Shop_0207_V_Wall" }, -- Workspace.LobbyV4Staging.Shop.Bay_Season.Bay_Season.V_Wall
	GGAsset_LobbyWorld_1162 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Shop_0251_V_Wall" }, -- Workspace.LobbyV4Staging.Shop.Case_Deals.V_Wall
	GGAsset_LobbyWorld_1163 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Shop_0261_V_Wall" }, -- Workspace.LobbyV4Staging.Shop.Case_Rare.V_Wall
	GGAsset_LobbyWorld_1164 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Shop_0271_V_Wall" }, -- Workspace.LobbyV4Staging.Shop.Case_New.V_Wall
	GGAsset_LobbyWorld_1165 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Shop_0281_V_Wall" }, -- Workspace.LobbyV4Staging.Shop.Case_Vault.V_Wall
	GGAsset_LobbyWorld_1166 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Shop_0291_V_Wall" }, -- Workspace.LobbyV4Staging.Shop.Wall_27.V_Wall
	GGAsset_LobbyWorld_1167 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Shop_0297_V_Wall" }, -- Workspace.LobbyV4Staging.Shop.Wall_28.V_Wall
	GGAsset_LobbyWorld_1168 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Shop_0302_V_Wall" }, -- Workspace.LobbyV4Staging.Shop.Wall_29.V_Wall
	GGAsset_LobbyWorld_1169 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Shop_0308_V_Wall" }, -- Workspace.LobbyV4Staging.Shop.Wall_30.V_Wall
	GGAsset_LobbyWorld_1170 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Shop_0347_V_Wall" }, -- Workspace.LobbyV4Staging.Shop.RoomVault_3.V_Wall
	GGAsset_LobbyWorld_1171 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Shop_0392_V_Wall" }, -- Workspace.LobbyV4Staging.Shop.BrokerBundle.V_Wall
	GGAsset_LobbyWorld_1172 = { ["Ceil"] = false, ["SWMat"] = "V_Wall", ["SWName"] = "Shop_0401_V_Wall" }, -- Workspace.LobbyV4Staging.Shop.BrokerEffect.V_Wall
	GGAsset_LobbyWorld_1173 = { ["Ceil"] = true, ["SWMat"] = "V_Beam", ["SWName"] = "ConcourseCD_0106_V_Beam" }, -- Workspace.LobbyV4Staging.Concourse.HubCeiling.HubCeiling.V_Beam
	GGAsset_LobbyWorld_1174 = { ["Ceil"] = true, ["SWMat"] = "V_Beam", ["SWName"] = "ConcourseCD_0132_V_Beam" }, -- Workspace.LobbyV4Staging.Concourse.HubCeiling.Beam_8.V_Beam
	GGAsset_LobbyWorld_1175 = { ["Ceil"] = true, ["SWMat"] = "V_Ceil", ["SWName"] = "Concourse_Ceil_0105_V_Ceil" }, -- Workspace.LobbyV4Staging.Concourse.HubCeiling.HubCeiling.V_Ceil
	GGAsset_LobbyWorld_1176 = { ["Ceil"] = true, ["SWMat"] = "V_Ceil", ["SWName"] = "Concourse_Ceil_0145_V_Ceil" }, -- Workspace.LobbyV4Staging.Concourse.Lantern.V_Ceil
	GGAsset_LobbyWorld_1177 = { ["Ceil"] = true, ["SWMat"] = "V_Trim", ["SWName"] = "Concourse_Ceil_0144_V_Trim" }, -- Workspace.LobbyV4Staging.Concourse.Lantern.V_Trim
	GGAsset_LobbyWorld_1178 = { ["Ceil"] = true, ["SWMat"] = "V_Wall", ["SWName"] = "Concourse_Ceil_0140_V_Wall" }, -- Workspace.LobbyV4Staging.Concourse.Lantern.V_Wall
	GGAsset_LobbyWorld_1179 = { ["ColArea"] = "Concourse" }, -- Workspace.LobbyV4Staging.Concourse.Shell.c1.C
	GGAsset_LobbyWorld_1180 = { ["ColArea"] = "Duels" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.NaveVault.C
	GGAsset_LobbyWorld_1181 = { ["ColArea"] = "Locker" }, -- Workspace.LobbyV4Staging.Locker.Shell.c1.C
	GGAsset_LobbyWorld_1182 = { ["ColArea"] = "Shop" }, -- Workspace.LobbyV4Staging.Shop.Bay_Featured.Bay_Featured.C
	GGAsset_LobbyWorld_1183 = { ["Color"] = "#7A4CF0", ["Kind"] = "embers", ["Rate"] = 10, ["Spread"] = 1.2 }, -- Workspace.LobbyV4Staging.Anchors.BrokerEffectFX
	GGAsset_LobbyWorld_1184 = { ["Color"] = "#8E6CFF", ["Kind"] = "sparkle", ["Rate"] = 5, ["Spread"] = 2 }, -- Workspace.LobbyV4Staging.Anchors.HeroFX
	GGAsset_LobbyWorld_1185 = { ["Color"] = "#C5B7D9", ["Kind"] = "sparkle", ["Rate"] = 8, ["Spread"] = 3.3999999999999999 }, -- Workspace.LobbyV4Staging.Anchors.SeasonFX
	GGAsset_LobbyWorld_1186 = { ["Color"] = "#C9B0FF", ["Kind"] = "sparkle", ["Rate"] = 7, ["Spread"] = 1.5600000000000001 }, -- Workspace.LobbyV4Staging.Anchors.Holo_ShopBadgeFX
	GGAsset_LobbyWorld_1187 = { ["Color"] = "#C9B0FF", ["Kind"] = "sparkle", ["Rate"] = 7, ["Spread"] = 1.8 }, -- Workspace.LobbyV4Staging.Anchors.Holo_GiftFX
	GGAsset_LobbyWorld_1188 = { ["Color"] = "#F4F1EA", ["Kind"] = "cone", ["To"] = "0.000,0.000,2.200", ["W0"] = 7, ["W1"] = 16 }, -- Workspace.LobbyV4Staging.Anchors.Sunshaft
	GGAsset_LobbyWorld_1189 = { ["Color"] = "#FF5C8A", ["Kind"] = "sparkle", ["Rate"] = 8, ["Spread"] = 1.6000000000000001 }, -- Workspace.LobbyV4Staging.Anchors.BrokerBundleFX
	GGAsset_LobbyWorld_1190 = { ["Color"] = "#FF5C8A", ["Kind"] = "sparkle", ["Rate"] = 8, ["Spread"] = 3.3999999999999999 }, -- Workspace.LobbyV4Staging.Anchors.FeaturedFX
	GGAsset_LobbyWorld_1191 = { ["Color"] = "#FFF4E0", ["Kind"] = "cone", ["To"] = "-94.000,0.000,3.800", ["W0"] = 1, ["W1"] = 6.5 }, -- Workspace.LobbyV4Staging.Anchors.HeroCone
	GGAsset_LobbyWorld_1192 = { ["Color"] = "#FFF4E0", ["Kind"] = "cone", ["To"] = "104.000,-29.000,2.200", ["W0"] = 0.5, ["W1"] = 4.5 }, -- Workspace.LobbyV4Staging.Anchors.Bay_FeaturedCone
	GGAsset_LobbyWorld_1193 = { ["Color"] = "#FFF4E0", ["Kind"] = "cone", ["To"] = "104.000,29.000,2.200", ["W0"] = 0.5, ["W1"] = 4.5 }, -- Workspace.LobbyV4Staging.Anchors.Bay_SeasonCone
	GGAsset_LobbyWorld_1194 = { ["Color"] = "#FFF4E0", ["Kind"] = "cone", ["To"] = "165.500,40.000,2.800", ["W0"] = 1, ["W1"] = 6 }, -- Workspace.LobbyV4Staging.Anchors.BrokerBundleCone
	GGAsset_LobbyWorld_1195 = { ["Color"] = "#FFF4E0", ["Kind"] = "cone", ["To"] = "182.500,40.000,2.800", ["W0"] = 1, ["W1"] = 6 }, -- Workspace.LobbyV4Staging.Anchors.BrokerEffectCone
	GGAsset_LobbyWorld_1196 = { ["Color"] = "#FFF4E0", ["Kind"] = "dust", ["Spread"] = 10 }, -- Workspace.LobbyV4Staging.Anchors.LanternDust
	GGAsset_LobbyWorld_1197 = { ["Color"] = "#FFF4E0", ["Kind"] = "dust", ["Spread"] = 9.5999999999999996 }, -- Workspace.LobbyV4Staging.Anchors.Bay_FeaturedDust
	GGAsset_LobbyWorld_1198 = { ["DX"] = -1, ["DY"] = 0, ["Length"] = 15.6, ["Spacing"] = 3, ["Speed"] = 26, ["Tone"] = "violet", ["Width"] = 6 }, -- Workspace.LobbyV4Staging.Anchors.PathPadL3
	GGAsset_LobbyWorld_1199 = { ["DX"] = 0, ["DY"] = 1, ["Length"] = 126, ["Spacing"] = 4, ["Speed"] = 42, ["Tone"] = "lilac", ["Width"] = 7 }, -- Workspace.LobbyV4Staging.Anchors.PathAisle
	GGAsset_LobbyWorld_1200 = { ["DX"] = 0, ["DY"] = 1, ["Length"] = 154.19999999999999, ["Tone"] = "lilac", ["Width"] = 0.5 }, -- Workspace.LobbyV4Staging.Anchors.LineAisleR
	GGAsset_LobbyWorld_1201 = { ["DX"] = 0, ["DY"] = 1, ["Length"] = 154.19999999999999, ["Tone"] = "violet", ["Width"] = 0.5 }, -- Workspace.LobbyV4Staging.Anchors.LineAisleL
	GGAsset_LobbyWorld_1202 = { ["DX"] = 1, ["DY"] = 0, ["Length"] = 15.6, ["Spacing"] = 3, ["Speed"] = 26, ["Tone"] = "violet", ["Width"] = 6 }, -- Workspace.LobbyV4Staging.Anchors.PathPadR4
	GGAsset_LobbyWorld_1203 = { ["Glow"] = true }, -- Workspace.Lobby.Art.RangeFar.Roof.LightBar.RangeLightBar_Diffuser_Glow
	GGAsset_LobbyWorld_1204 = { ["H"] = 5.7999999999999998, ["NX"] = -0, ["NY"] = -1, ["W"] = 10.6 }, -- Workspace.LobbyV4Staging.Anchors.HallBoard_3
	GGAsset_LobbyWorld_1205 = { ["H"] = 5.7999999999999998, ["NX"] = -1, ["NY"] = 0, ["W"] = 10.6 }, -- Workspace.LobbyV4Staging.Anchors.HallBoard_2
	GGAsset_LobbyWorld_1206 = { ["H"] = 5.7999999999999998, ["NX"] = 0, ["NY"] = 1, ["W"] = 10.6 }, -- Workspace.LobbyV4Staging.Anchors.HallBoard_1
	GGAsset_LobbyWorld_1207 = { ["H"] = 5.7999999999999998, ["NX"] = 1, ["NY"] = 0, ["W"] = 10.6 }, -- Workspace.LobbyV4Staging.Anchors.HallBoard_4
	GGAsset_LobbyWorld_1208 = { ["Kind"] = "Barrel", ["Yaw"] = -8 }, -- Workspace.LobbyV4Staging.Anchors.Prop
	GGAsset_LobbyWorld_1209 = { ["Kind"] = "Barrel", ["Yaw"] = 10 }, -- Workspace.LobbyV4Staging.Anchors.Prop
	GGAsset_LobbyWorld_1210 = { ["Kind"] = "Barrel", ["Yaw"] = 147 }, -- Workspace.LobbyV4Staging.Anchors.Prop
	GGAsset_LobbyWorld_1211 = { ["Kind"] = "Barrel", ["Yaw"] = 8 }, -- Workspace.LobbyV4Staging.Anchors.Prop
	GGAsset_LobbyWorld_1212 = { ["Kind"] = "Container02", ["Yaw"] = -45 }, -- Workspace.LobbyV4Staging.Anchors.Prop
	GGAsset_LobbyWorld_1213 = { ["Kind"] = "Container02", ["Yaw"] = 3 }, -- Workspace.LobbyV4Staging.Anchors.Prop
	GGAsset_LobbyWorld_1214 = { ["Kind"] = "Container02", ["Yaw"] = 6 }, -- Workspace.LobbyV4Staging.Anchors.Prop
	GGAsset_LobbyWorld_1215 = { ["Kind"] = "Crate02", ["Yaw"] = -6 }, -- Workspace.LobbyV4Staging.Anchors.Prop
	GGAsset_LobbyWorld_1216 = { ["Kind"] = "Crate02", ["Yaw"] = -8 }, -- Workspace.LobbyV4Staging.Anchors.Prop
	GGAsset_LobbyWorld_1217 = { ["Kind"] = "Crate02", ["Yaw"] = 10 }, -- Workspace.LobbyV4Staging.Anchors.Prop
	GGAsset_LobbyWorld_1218 = { ["Kind"] = "Crate02", ["Yaw"] = 128 }, -- Workspace.LobbyV4Staging.Anchors.Prop
	GGAsset_LobbyWorld_1219 = { ["Kind"] = "Crate02", ["Yaw"] = 36.509999999999998 }, -- Workspace.LobbyV4Staging.Anchors.CrateSmall
	GGAsset_LobbyWorld_1220 = { ["Kind"] = "Crate03b", ["Yaw"] = -45 }, -- Workspace.LobbyV4Staging.Anchors.Prop
	GGAsset_LobbyWorld_1221 = { ["Kind"] = "Crate07", ["Yaw"] = 45 }, -- Workspace.LobbyV4Staging.Anchors.Prop
	GGAsset_LobbyWorld_1222 = { ["Kind"] = "Explosive Barrel", ["Yaw"] = -14 }, -- Workspace.LobbyV4Staging.Anchors.Prop
	GGAsset_LobbyWorld_1223 = { ["Kind"] = "Explosive Barrel", ["Yaw"] = 115 }, -- Workspace.LobbyV4Staging.Anchors.Prop
	GGAsset_LobbyWorld_1224 = { ["Kind"] = "Ski Crate", ["Yaw"] = -176 }, -- Workspace.LobbyV4Staging.Anchors.HardCase
	GGAsset_LobbyWorld_1225 = { ["Kind"] = "Ski Crate", ["Yaw"] = -38.509999999999998 }, -- Workspace.LobbyV4Staging.Anchors.HardCase
	GGAsset_LobbyWorld_1226 = { ["Kind"] = "Ski Crate", ["Yaw"] = -44.509999999999998 }, -- Workspace.LobbyV4Staging.Anchors.HardCase
	GGAsset_LobbyWorld_1227 = { ["Kind"] = "Ski Crate", ["Yaw"] = -8 }, -- Workspace.LobbyV4Staging.Anchors.StageCase
	GGAsset_LobbyWorld_1228 = { ["Kind"] = "Ski Crate", ["Yaw"] = 178 }, -- Workspace.LobbyV4Staging.Anchors.HardCase
	GGAsset_LobbyWorld_1229 = { ["Kind"] = "Ski Crate", ["Yaw"] = 40 }, -- Workspace.LobbyV4Staging.Anchors.Prop
	GGAsset_LobbyWorld_1230 = { ["Kind"] = "Ski Crate", ["Yaw"] = 45 }, -- Workspace.LobbyV4Staging.Anchors.Prop
	GGAsset_LobbyWorld_1231 = { ["Kind"] = "Ski Crate", ["Yaw"] = 8 }, -- Workspace.LobbyV4Staging.Anchors.StageCase
	GGAsset_LobbyWorld_1232 = { ["Kind"] = "Wep Crate", ["Yaw"] = -177 }, -- Workspace.LobbyV4Staging.Anchors.Crate
	GGAsset_LobbyWorld_1233 = { ["Kind"] = "Wep Crate", ["Yaw"] = -4 }, -- Workspace.LobbyV4Staging.Anchors.Prop
	GGAsset_LobbyWorld_1234 = { ["Kind"] = "Wep Crate", ["Yaw"] = -45.509999999999998 }, -- Workspace.LobbyV4Staging.Anchors.Crate
	GGAsset_LobbyWorld_1235 = { ["Kind"] = "Wep Crate", ["Yaw"] = -6 }, -- Workspace.LobbyV4Staging.Anchors.Prop
	GGAsset_LobbyWorld_1236 = { ["Kind"] = "Wep Crate", ["Yaw"] = 0 }, -- Workspace.LobbyV4Staging.Anchors.Prop
	GGAsset_LobbyWorld_1237 = { ["Kind"] = "Wep Crate", ["Yaw"] = 135 }, -- Workspace.LobbyV4Staging.Anchors.Prop
	GGAsset_LobbyWorld_1238 = { ["Kind"] = "Wep Crate", ["Yaw"] = 139 }, -- Workspace.LobbyV4Staging.Anchors.Prop
	GGAsset_LobbyWorld_1239 = { ["Kind"] = "Wep Crate", ["Yaw"] = 4 }, -- Workspace.LobbyV4Staging.Anchors.Prop
	GGAsset_LobbyWorld_1240 = { ["Kind"] = "Wep Crate", ["Yaw"] = 45.509999999999998 }, -- Workspace.LobbyV4Staging.Anchors.Crate
	GGAsset_LobbyWorld_1241 = { ["KitGroup"] = "Range" }, -- Workspace.Lobby.Art.RangeFar.Walls.WallPanel
	GGAsset_LobbyWorld_1242 = { ["LightArea"] = "Concourse" }, -- Workspace.LobbyV4Staging.Concourse.Lights.Light
	GGAsset_LobbyWorld_1243 = { ["LightArea"] = "Duels" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.DuelsCeiling.Light
	GGAsset_LobbyWorld_1244 = { ["LightArea"] = "Locker" }, -- Workspace.LobbyV4Staging.Locker.Lights.Light
	GGAsset_LobbyWorld_1245 = { ["LightArea"] = "Shop" }, -- Workspace.LobbyV4Staging.Shop.Lights.Light
	GGAsset_LobbyWorld_1246 = { ["Look"] = "armorer", ["Scale"] = 1.6000000000000001, ["Talk"] = "armorer", ["Title"] = "ARMORER", ["Yaw"] = -90 }, -- Workspace.LobbyV4Staging.Anchors.Armorer
	GGAsset_LobbyWorld_1247 = { ["Look"] = "broker", ["Scale"] = 1.8, ["Title"] = "BROKER", ["Yaw"] = 180 }, -- Workspace.LobbyV4Staging.Anchors.Broker
	GGAsset_LobbyWorld_1248 = { ["Mode"] = "1v1", ["NX"] = 1, ["NY"] = 0, ["Pad"] = 1, ["Team"] = 1 }, -- Workspace.LobbyV4Staging.Anchors.PadBoard_1_A
	GGAsset_LobbyWorld_1249 = { ["Mode"] = "1v1", ["NX"] = 1, ["NY"] = 0, ["Pad"] = 1, ["Team"] = 2 }, -- Workspace.LobbyV4Staging.Anchors.PadBoard_1_B
	GGAsset_LobbyWorld_1250 = { ["Mode"] = "1v1", ["NX"] = 1, ["NY"] = 0, ["Pad"] = 2, ["Team"] = 1 }, -- Workspace.LobbyV4Staging.Anchors.PadBoard_2_A
	GGAsset_LobbyWorld_1251 = { ["Mode"] = "1v1", ["NX"] = 1, ["NY"] = 0, ["Pad"] = 2, ["Team"] = 2 }, -- Workspace.LobbyV4Staging.Anchors.PadBoard_2_B
	GGAsset_LobbyWorld_1252 = { ["Mode"] = "1v1", ["Pad"] = 1, ["Team"] = 1 }, -- Workspace.LobbyV4Staging.Anchors.PadSquare_1_A
	GGAsset_LobbyWorld_1253 = { ["Mode"] = "1v1", ["Pad"] = 1, ["Team"] = 2 }, -- Workspace.LobbyV4Staging.Anchors.PadSquare_1_B
	GGAsset_LobbyWorld_1254 = { ["Mode"] = "1v1", ["Pad"] = 2, ["Team"] = 1 }, -- Workspace.LobbyV4Staging.Anchors.PadSquare_2_A
	GGAsset_LobbyWorld_1255 = { ["Mode"] = "1v1", ["Pad"] = 2, ["Team"] = 2 }, -- Workspace.LobbyV4Staging.Anchors.PadSquare_2_B
	GGAsset_LobbyWorld_1256 = { ["Mode"] = "1v1", ["PadId"] = "1v1_AE" }, -- Workspace.Lobby.Hub.Anchors.QueueZone
	GGAsset_LobbyWorld_1257 = { ["Mode"] = "1v1", ["PadId"] = "1v1_AW" }, -- Workspace.Lobby.Hub.Anchors.QueueZone
	GGAsset_LobbyWorld_1258 = { ["Mode"] = "1v1", ["PadId"] = "1v1_BE" }, -- Workspace.Lobby.Hub.Anchors.QueueZone
	GGAsset_LobbyWorld_1259 = { ["Mode"] = "1v1", ["PadId"] = "1v1_BW" }, -- Workspace.Lobby.Hub.Anchors.QueueZone
	GGAsset_LobbyWorld_1260 = { ["Mode"] = "1v1", ["PadId"] = "1v1_CE" }, -- Workspace.Lobby.Hub.Anchors.QueueZone
	GGAsset_LobbyWorld_1261 = { ["Mode"] = "1v1", ["PadId"] = "1v1_CW" }, -- Workspace.Lobby.Hub.Anchors.QueueZone
	GGAsset_LobbyWorld_1262 = { ["Mode"] = "1v1", ["PadId"] = "1v1_DE" }, -- Workspace.Lobby.Hub.Anchors.QueueZone
	GGAsset_LobbyWorld_1263 = { ["Mode"] = "1v1", ["PadId"] = "1v1_DW" }, -- Workspace.Lobby.Hub.Anchors.QueueZone
	GGAsset_LobbyWorld_1264 = { ["Mode"] = "1v1", ["Trigger"] = "Step" }, -- Workspace.LobbyV4Staging.Anchors.Queue_2_1v1
	GGAsset_LobbyWorld_1265 = { ["Mode"] = "2v2", ["NX"] = 1, ["NY"] = 0, ["Pad"] = 3, ["Team"] = 1 }, -- Workspace.LobbyV4Staging.Anchors.PadBoard_3_A
	GGAsset_LobbyWorld_1266 = { ["Mode"] = "2v2", ["NX"] = 1, ["NY"] = 0, ["Pad"] = 3, ["Team"] = 2 }, -- Workspace.LobbyV4Staging.Anchors.PadBoard_3_B
	GGAsset_LobbyWorld_1267 = { ["Mode"] = "2v2", ["NX"] = 1, ["NY"] = 0, ["Pad"] = 4, ["Team"] = 1 }, -- Workspace.LobbyV4Staging.Anchors.PadBoard_4_A
	GGAsset_LobbyWorld_1268 = { ["Mode"] = "2v2", ["NX"] = 1, ["NY"] = 0, ["Pad"] = 4, ["Team"] = 2 }, -- Workspace.LobbyV4Staging.Anchors.PadBoard_4_B
	GGAsset_LobbyWorld_1269 = { ["Mode"] = "2v2", ["Pad"] = 3, ["Team"] = 1 }, -- Workspace.LobbyV4Staging.Anchors.PadSquare_3_A
	GGAsset_LobbyWorld_1270 = { ["Mode"] = "2v2", ["Pad"] = 3, ["Team"] = 2 }, -- Workspace.LobbyV4Staging.Anchors.PadSquare_3_B
	GGAsset_LobbyWorld_1271 = { ["Mode"] = "2v2", ["Pad"] = 4, ["Team"] = 1 }, -- Workspace.LobbyV4Staging.Anchors.PadSquare_4_A
	GGAsset_LobbyWorld_1272 = { ["Mode"] = "2v2", ["Pad"] = 4, ["Team"] = 2 }, -- Workspace.LobbyV4Staging.Anchors.PadSquare_4_B
	GGAsset_LobbyWorld_1273 = { ["Mode"] = "2v2", ["PadId"] = "2v2_AE" }, -- Workspace.Lobby.Hub.Anchors.QueueZone
	GGAsset_LobbyWorld_1274 = { ["Mode"] = "2v2", ["PadId"] = "2v2_AW" }, -- Workspace.Lobby.Hub.Anchors.QueueZone
	GGAsset_LobbyWorld_1275 = { ["Mode"] = "2v2", ["PadId"] = "2v2_BE" }, -- Workspace.Lobby.Hub.Anchors.QueueZone
	GGAsset_LobbyWorld_1276 = { ["Mode"] = "2v2", ["PadId"] = "2v2_BW" }, -- Workspace.Lobby.Hub.Anchors.QueueZone
	GGAsset_LobbyWorld_1277 = { ["Mode"] = "2v2", ["Trigger"] = "Step" }, -- Workspace.LobbyV4Staging.Anchors.Queue_3_2v2
	GGAsset_LobbyWorld_1278 = { ["Mode"] = "3v3", ["NX"] = -1, ["NY"] = 0, ["Pad"] = 5, ["Team"] = 1 }, -- Workspace.LobbyV4Staging.Anchors.PadBoard_5_A
	GGAsset_LobbyWorld_1279 = { ["Mode"] = "3v3", ["NX"] = -1, ["NY"] = 0, ["Pad"] = 5, ["Team"] = 2 }, -- Workspace.LobbyV4Staging.Anchors.PadBoard_5_B
	GGAsset_LobbyWorld_1280 = { ["Mode"] = "3v3", ["NX"] = -1, ["NY"] = 0, ["Pad"] = 6, ["Team"] = 1 }, -- Workspace.LobbyV4Staging.Anchors.PadBoard_6_A
	GGAsset_LobbyWorld_1281 = { ["Mode"] = "3v3", ["NX"] = -1, ["NY"] = 0, ["Pad"] = 6, ["Team"] = 2 }, -- Workspace.LobbyV4Staging.Anchors.PadBoard_6_B
	GGAsset_LobbyWorld_1282 = { ["Mode"] = "3v3", ["Pad"] = 5, ["Team"] = 1 }, -- Workspace.LobbyV4Staging.Anchors.PadSquare_5_A
	GGAsset_LobbyWorld_1283 = { ["Mode"] = "3v3", ["Pad"] = 5, ["Team"] = 2 }, -- Workspace.LobbyV4Staging.Anchors.PadSquare_5_B
	GGAsset_LobbyWorld_1284 = { ["Mode"] = "3v3", ["Pad"] = 6, ["Team"] = 1 }, -- Workspace.LobbyV4Staging.Anchors.PadSquare_6_A
	GGAsset_LobbyWorld_1285 = { ["Mode"] = "3v3", ["Pad"] = 6, ["Team"] = 2 }, -- Workspace.LobbyV4Staging.Anchors.PadSquare_6_B
	GGAsset_LobbyWorld_1286 = { ["Mode"] = "3v3", ["PadId"] = "3v3_AE" }, -- Workspace.Lobby.Hub.Anchors.QueueZone
	GGAsset_LobbyWorld_1287 = { ["Mode"] = "3v3", ["PadId"] = "3v3_AW" }, -- Workspace.Lobby.Hub.Anchors.QueueZone
	GGAsset_LobbyWorld_1288 = { ["Mode"] = "3v3", ["PadId"] = "3v3_BE" }, -- Workspace.Lobby.Hub.Anchors.QueueZone
	GGAsset_LobbyWorld_1289 = { ["Mode"] = "3v3", ["PadId"] = "3v3_BW" }, -- Workspace.Lobby.Hub.Anchors.QueueZone
	GGAsset_LobbyWorld_1290 = { ["Mode"] = "3v3", ["Trigger"] = "Step" }, -- Workspace.LobbyV4Staging.Anchors.Queue_6_3v3
	GGAsset_LobbyWorld_1291 = { ["Mode"] = "4v4", ["NX"] = -1, ["NY"] = 0, ["Pad"] = 7, ["Team"] = 1 }, -- Workspace.LobbyV4Staging.Anchors.PadBoard_7_A
	GGAsset_LobbyWorld_1292 = { ["Mode"] = "4v4", ["NX"] = -1, ["NY"] = 0, ["Pad"] = 7, ["Team"] = 2 }, -- Workspace.LobbyV4Staging.Anchors.PadBoard_7_B
	GGAsset_LobbyWorld_1293 = { ["Mode"] = "4v4", ["Pad"] = 7, ["Team"] = 1 }, -- Workspace.LobbyV4Staging.Anchors.PadSquare_7_A
	GGAsset_LobbyWorld_1294 = { ["Mode"] = "4v4", ["Pad"] = 7, ["Team"] = 2 }, -- Workspace.LobbyV4Staging.Anchors.PadSquare_7_B
	GGAsset_LobbyWorld_1295 = { ["Mode"] = "5v5", ["NX"] = -1, ["NY"] = 0, ["Pad"] = 8, ["Team"] = 1 }, -- Workspace.LobbyV4Staging.Anchors.PadBoard_8_A
	GGAsset_LobbyWorld_1296 = { ["Mode"] = "5v5", ["NX"] = -1, ["NY"] = 0, ["Pad"] = 8, ["Team"] = 2 }, -- Workspace.LobbyV4Staging.Anchors.PadBoard_8_B
	GGAsset_LobbyWorld_1297 = { ["Mode"] = "5v5", ["Pad"] = 8, ["Team"] = 1 }, -- Workspace.LobbyV4Staging.Anchors.PadSquare_8_A
	GGAsset_LobbyWorld_1298 = { ["Mode"] = "5v5", ["Pad"] = 8, ["Team"] = 2 }, -- Workspace.LobbyV4Staging.Anchors.PadSquare_8_B
	GGAsset_LobbyWorld_1299 = { ["Note"] = "Range exit lands here, facing the hub" }, -- Workspace.Lobby.Hub.Markers.RangeReturnPoint
	GGAsset_LobbyWorld_1300 = { ["PieceFolder"] = "Bay_Featured" }, -- Workspace.LobbyV4Staging.Shop.Bay_Featured
	GGAsset_LobbyWorld_1301 = { ["PieceFolder"] = "Bay_Season" }, -- Workspace.LobbyV4Staging.Shop.Bay_Season
	GGAsset_LobbyWorld_1302 = { ["PieceFolder"] = "DuelsCeiling" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling
	GGAsset_LobbyWorld_1303 = { ["PieceFolder"] = "Gallery" }, -- Workspace.LobbyV4Staging.Concourse.Gallery
	GGAsset_LobbyWorld_1304 = { ["PieceFolder"] = "Gallery_2" }, -- Workspace.LobbyV4Staging.Concourse.Gallery_2
	GGAsset_LobbyWorld_1305 = { ["PieceFolder"] = "Gallery_3" }, -- Workspace.LobbyV4Staging.Concourse.Gallery_3
	GGAsset_LobbyWorld_1306 = { ["PieceFolder"] = "Gallery_4" }, -- Workspace.LobbyV4Staging.Concourse.Gallery_4
	GGAsset_LobbyWorld_1307 = { ["PieceFolder"] = "HubCeiling" }, -- Workspace.LobbyV4Staging.Concourse.HubCeiling
	GGAsset_LobbyWorld_1308 = { ["PieceFolder"] = "HubFloor" }, -- Workspace.LobbyV4Staging.Concourse.HubFloor
	GGAsset_LobbyWorld_1309 = { ["PieceFolder"] = "LightingRig" }, -- Workspace.LobbyV4Staging.Concourse.LightingRig
	GGAsset_LobbyWorld_1310 = { ["PieceFolder"] = "Mark_Featured" }, -- Workspace.LobbyV4Staging.Shop.Mark_Featured
	GGAsset_LobbyWorld_1311 = { ["PieceFolder"] = "Mark_Season" }, -- Workspace.LobbyV4Staging.Shop.Mark_Season
	GGAsset_LobbyWorld_1312 = { ["PieceFolder"] = "Pad_1v1_2" }, -- Workspace.LobbyV4Staging.Duels.Pad_1v1_2
	GGAsset_LobbyWorld_1313 = { ["PieceFolder"] = "Pad_2v2" }, -- Workspace.LobbyV4Staging.Duels.Pad_2v2
	GGAsset_LobbyWorld_1314 = { ["PieceFolder"] = "Pad_2v2_2" }, -- Workspace.LobbyV4Staging.Duels.Pad_2v2_2
	GGAsset_LobbyWorld_1315 = { ["PieceFolder"] = "Pad_3v3" }, -- Workspace.LobbyV4Staging.Duels.Pad_3v3
	GGAsset_LobbyWorld_1316 = { ["PieceFolder"] = "Pad_3v3_2" }, -- Workspace.LobbyV4Staging.Duels.Pad_3v3_2
	GGAsset_LobbyWorld_1317 = { ["PieceFolder"] = "Pad_4v4" }, -- Workspace.LobbyV4Staging.Duels.Pad_4v4
	GGAsset_LobbyWorld_1318 = { ["PieceFolder"] = "Pad_5v5" }, -- Workspace.LobbyV4Staging.Duels.Pad_5v5
	GGAsset_LobbyWorld_1319 = { ["PiecePath"] = "ApseVents" }, -- Workspace.LobbyV4Staging.Duels.ApseVents
	GGAsset_LobbyWorld_1320 = { ["PiecePath"] = "ApseVents_2" }, -- Workspace.LobbyV4Staging.Duels.ApseVents_2
	GGAsset_LobbyWorld_1321 = { ["PiecePath"] = "ArmorerStep" }, -- Workspace.LobbyV4Staging.Locker.ArmorerStep
	GGAsset_LobbyWorld_1322 = { ["PiecePath"] = "BarLamp" }, -- Workspace.LobbyV4Staging.Concourse.BarLamp
	GGAsset_LobbyWorld_1323 = { ["PiecePath"] = "BarLamp_10", ["SharedWith"] = "BarLamp_9" }, -- Workspace.LobbyV4Staging.Duels.BarLamp_10
	GGAsset_LobbyWorld_1324 = { ["PiecePath"] = "BarLamp_11", ["SharedWith"] = "BarLamp_9" }, -- Workspace.LobbyV4Staging.Duels.BarLamp_11
	GGAsset_LobbyWorld_1325 = { ["PiecePath"] = "BarLamp_12", ["SharedWith"] = "BarLamp_9" }, -- Workspace.LobbyV4Staging.Duels.BarLamp_12
	GGAsset_LobbyWorld_1326 = { ["PiecePath"] = "BarLamp_13", ["SharedWith"] = "BarLamp_9" }, -- Workspace.LobbyV4Staging.Duels.BarLamp_13
	GGAsset_LobbyWorld_1327 = { ["PiecePath"] = "BarLamp_14", ["SharedWith"] = "BarLamp_9" }, -- Workspace.LobbyV4Staging.Duels.BarLamp_14
	GGAsset_LobbyWorld_1328 = { ["PiecePath"] = "BarLamp_15", ["SharedWith"] = "BarLamp_9" }, -- Workspace.LobbyV4Staging.Duels.BarLamp_15
	GGAsset_LobbyWorld_1329 = { ["PiecePath"] = "BarLamp_16", ["SharedWith"] = "BarLamp_9" }, -- Workspace.LobbyV4Staging.Duels.BarLamp_16
	GGAsset_LobbyWorld_1330 = { ["PiecePath"] = "BarLamp_17", ["SharedWith"] = "BarLamp_9" }, -- Workspace.LobbyV4Staging.Duels.BarLamp_17
	GGAsset_LobbyWorld_1331 = { ["PiecePath"] = "BarLamp_18", ["SharedWith"] = "BarLamp_9" }, -- Workspace.LobbyV4Staging.Duels.BarLamp_18
	GGAsset_LobbyWorld_1332 = { ["PiecePath"] = "BarLamp_19", ["SharedWith"] = "BarLamp_9" }, -- Workspace.LobbyV4Staging.Duels.BarLamp_19
	GGAsset_LobbyWorld_1333 = { ["PiecePath"] = "BarLamp_2", ["SharedWith"] = "BarLamp" }, -- Workspace.LobbyV4Staging.Concourse.BarLamp_2
	GGAsset_LobbyWorld_1334 = { ["PiecePath"] = "BarLamp_20", ["SharedWith"] = "BarLamp_9" }, -- Workspace.LobbyV4Staging.Duels.BarLamp_20
	GGAsset_LobbyWorld_1335 = { ["PiecePath"] = "BarLamp_21", ["SharedWith"] = "BarLamp_9" }, -- Workspace.LobbyV4Staging.Duels.BarLamp_21
	GGAsset_LobbyWorld_1336 = { ["PiecePath"] = "BarLamp_22", ["SharedWith"] = "BarLamp_9" }, -- Workspace.LobbyV4Staging.Duels.BarLamp_22
	GGAsset_LobbyWorld_1337 = { ["PiecePath"] = "BarLamp_23" }, -- Workspace.LobbyV4Staging.Shop.BarLamp_23
	GGAsset_LobbyWorld_1338 = { ["PiecePath"] = "BarLamp_24", ["SharedWith"] = "BarLamp_23" }, -- Workspace.LobbyV4Staging.Shop.BarLamp_24
	GGAsset_LobbyWorld_1339 = { ["PiecePath"] = "BarLamp_25", ["SharedWith"] = "BarLamp_23" }, -- Workspace.LobbyV4Staging.Shop.BarLamp_25
	GGAsset_LobbyWorld_1340 = { ["PiecePath"] = "BarLamp_26", ["SharedWith"] = "BarLamp_23" }, -- Workspace.LobbyV4Staging.Shop.BarLamp_26
	GGAsset_LobbyWorld_1341 = { ["PiecePath"] = "BarLamp_27", ["SharedWith"] = "BarLamp_23" }, -- Workspace.LobbyV4Staging.Shop.BarLamp_27
	GGAsset_LobbyWorld_1342 = { ["PiecePath"] = "BarLamp_28", ["SharedWith"] = "BarLamp_23" }, -- Workspace.LobbyV4Staging.Shop.BarLamp_28
	GGAsset_LobbyWorld_1343 = { ["PiecePath"] = "BarLamp_29", ["SharedWith"] = "BarLamp_23" }, -- Workspace.LobbyV4Staging.Shop.BarLamp_29
	GGAsset_LobbyWorld_1344 = { ["PiecePath"] = "BarLamp_3", ["SharedWith"] = "BarLamp" }, -- Workspace.LobbyV4Staging.Concourse.BarLamp_3
	GGAsset_LobbyWorld_1345 = { ["PiecePath"] = "BarLamp_30", ["SharedWith"] = "BarLamp_23" }, -- Workspace.LobbyV4Staging.Shop.BarLamp_30
	GGAsset_LobbyWorld_1346 = { ["PiecePath"] = "BarLamp_31", ["SharedWith"] = "BarLamp_23" }, -- Workspace.LobbyV4Staging.Shop.BarLamp_31
	GGAsset_LobbyWorld_1347 = { ["PiecePath"] = "BarLamp_32", ["SharedWith"] = "BarLamp_23" }, -- Workspace.LobbyV4Staging.Shop.BarLamp_32
	GGAsset_LobbyWorld_1348 = { ["PiecePath"] = "BarLamp_33", ["SharedWith"] = "BarLamp_23" }, -- Workspace.LobbyV4Staging.Shop.BarLamp_33
	GGAsset_LobbyWorld_1349 = { ["PiecePath"] = "BarLamp_34", ["SharedWith"] = "BarLamp_23" }, -- Workspace.LobbyV4Staging.Shop.BarLamp_34
	GGAsset_LobbyWorld_1350 = { ["PiecePath"] = "BarLamp_4", ["SharedWith"] = "BarLamp" }, -- Workspace.LobbyV4Staging.Concourse.BarLamp_4
	GGAsset_LobbyWorld_1351 = { ["PiecePath"] = "BarLamp_5", ["SharedWith"] = "BarLamp" }, -- Workspace.LobbyV4Staging.Concourse.BarLamp_5
	GGAsset_LobbyWorld_1352 = { ["PiecePath"] = "BarLamp_6", ["SharedWith"] = "BarLamp" }, -- Workspace.LobbyV4Staging.Concourse.BarLamp_6
	GGAsset_LobbyWorld_1353 = { ["PiecePath"] = "BarLamp_7", ["SharedWith"] = "BarLamp" }, -- Workspace.LobbyV4Staging.Concourse.BarLamp_7
	GGAsset_LobbyWorld_1354 = { ["PiecePath"] = "BarLamp_8", ["SharedWith"] = "BarLamp" }, -- Workspace.LobbyV4Staging.Concourse.BarLamp_8
	GGAsset_LobbyWorld_1355 = { ["PiecePath"] = "BarLamp_9" }, -- Workspace.LobbyV4Staging.Duels.BarLamp_9
	GGAsset_LobbyWorld_1356 = { ["PiecePath"] = "Bay_Featured" }, -- Workspace.LobbyV4Staging.Shop.Bay_Featured.Bay_Featured
	GGAsset_LobbyWorld_1357 = { ["PiecePath"] = "Bay_Featured/Bay_FeaturedCurtains" }, -- Workspace.LobbyV4Staging.Shop.Bay_Featured.Bay_FeaturedCurtains
	GGAsset_LobbyWorld_1358 = { ["PiecePath"] = "Bay_Featured/Bay_FeaturedHolo1" }, -- Workspace.LobbyV4Staging.Shop.Bay_Featured.Bay_FeaturedHolo1
	GGAsset_LobbyWorld_1359 = { ["PiecePath"] = "Bay_Featured/Bay_FeaturedHolo2" }, -- Workspace.LobbyV4Staging.Shop.Bay_Featured.Bay_FeaturedHolo2
	GGAsset_LobbyWorld_1360 = { ["PiecePath"] = "Bay_FeaturedSign" }, -- Workspace.LobbyV4Staging.Shop.Bay_FeaturedSign
	GGAsset_LobbyWorld_1361 = { ["PiecePath"] = "Bay_Season" }, -- Workspace.LobbyV4Staging.Shop.Bay_Season.Bay_Season
	GGAsset_LobbyWorld_1362 = { ["PiecePath"] = "Bay_Season/Bay_SeasonHolo1" }, -- Workspace.LobbyV4Staging.Shop.Bay_Season.Bay_SeasonHolo1
	GGAsset_LobbyWorld_1363 = { ["PiecePath"] = "Bay_Season/Bay_SeasonHolo2" }, -- Workspace.LobbyV4Staging.Shop.Bay_Season.Bay_SeasonHolo2
	GGAsset_LobbyWorld_1364 = { ["PiecePath"] = "Bay_SeasonSign" }, -- Workspace.LobbyV4Staging.Shop.Bay_SeasonSign
	GGAsset_LobbyWorld_1365 = { ["PiecePath"] = "Beam" }, -- Workspace.LobbyV4Staging.Shop.Beam
	GGAsset_LobbyWorld_1366 = { ["PiecePath"] = "Beam_2" }, -- Workspace.LobbyV4Staging.Shop.Beam_2
	GGAsset_LobbyWorld_1367 = { ["PiecePath"] = "Bench" }, -- Workspace.LobbyV4Staging.Concourse.Bench
	GGAsset_LobbyWorld_1368 = { ["PiecePath"] = "Bench_2", ["SharedWith"] = "Bench" }, -- Workspace.LobbyV4Staging.Concourse.Bench_2
	GGAsset_LobbyWorld_1369 = { ["PiecePath"] = "BrokerBundle" }, -- Workspace.LobbyV4Staging.Shop.BrokerBundle
	GGAsset_LobbyWorld_1370 = { ["PiecePath"] = "BrokerBundleMedal", ["SpinAxis"] = Vector3.new(0, 1, -0), ["SpinSpeed"] = 40 }, -- Workspace.LobbyV4Staging.Shop.BrokerBundleMedal
	GGAsset_LobbyWorld_1371 = { ["PiecePath"] = "BrokerEffect" }, -- Workspace.LobbyV4Staging.Shop.BrokerEffect
	GGAsset_LobbyWorld_1372 = { ["PiecePath"] = "BrokerPlinth" }, -- Workspace.LobbyV4Staging.Shop.BrokerPlinth
	GGAsset_LobbyWorld_1373 = { ["PiecePath"] = "Case_Deals" }, -- Workspace.LobbyV4Staging.Shop.Case_Deals
	GGAsset_LobbyWorld_1374 = { ["PiecePath"] = "Case_New" }, -- Workspace.LobbyV4Staging.Shop.Case_New
	GGAsset_LobbyWorld_1375 = { ["PiecePath"] = "Case_Rare" }, -- Workspace.LobbyV4Staging.Shop.Case_Rare
	GGAsset_LobbyWorld_1376 = { ["PiecePath"] = "Case_Vault" }, -- Workspace.LobbyV4Staging.Shop.Case_Vault
	GGAsset_LobbyWorld_1377 = { ["PiecePath"] = "Ceiling" }, -- Workspace.LobbyV4Staging.Locker.Ceiling
	GGAsset_LobbyWorld_1378 = { ["PiecePath"] = "CeilingLamp" }, -- Workspace.LobbyV4Staging.Locker.CeilingLamp
	GGAsset_LobbyWorld_1379 = { ["PiecePath"] = "CeilingLamp_10" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_10
	GGAsset_LobbyWorld_1380 = { ["PiecePath"] = "CeilingLamp_11" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_11
	GGAsset_LobbyWorld_1381 = { ["PiecePath"] = "CeilingLamp_12" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_12
	GGAsset_LobbyWorld_1382 = { ["PiecePath"] = "CeilingLamp_13" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_13
	GGAsset_LobbyWorld_1383 = { ["PiecePath"] = "CeilingLamp_14" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_14
	GGAsset_LobbyWorld_1384 = { ["PiecePath"] = "CeilingLamp_15" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_15
	GGAsset_LobbyWorld_1385 = { ["PiecePath"] = "CeilingLamp_16" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_16
	GGAsset_LobbyWorld_1386 = { ["PiecePath"] = "CeilingLamp_17" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_17
	GGAsset_LobbyWorld_1387 = { ["PiecePath"] = "CeilingLamp_18" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_18
	GGAsset_LobbyWorld_1388 = { ["PiecePath"] = "CeilingLamp_19" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_19
	GGAsset_LobbyWorld_1389 = { ["PiecePath"] = "CeilingLamp_2" }, -- Workspace.LobbyV4Staging.Locker.CeilingLamp_2
	GGAsset_LobbyWorld_1390 = { ["PiecePath"] = "CeilingLamp_20" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_20
	GGAsset_LobbyWorld_1391 = { ["PiecePath"] = "CeilingLamp_21" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_21
	GGAsset_LobbyWorld_1392 = { ["PiecePath"] = "CeilingLamp_22" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_22
	GGAsset_LobbyWorld_1393 = { ["PiecePath"] = "CeilingLamp_3" }, -- Workspace.LobbyV4Staging.Locker.CeilingLamp_3
	GGAsset_LobbyWorld_1394 = { ["PiecePath"] = "CeilingLamp_4" }, -- Workspace.LobbyV4Staging.Locker.CeilingLamp_4
	GGAsset_LobbyWorld_1395 = { ["PiecePath"] = "CeilingLamp_5" }, -- Workspace.LobbyV4Staging.Locker.CeilingLamp_5
	GGAsset_LobbyWorld_1396 = { ["PiecePath"] = "CeilingLamp_6" }, -- Workspace.LobbyV4Staging.Locker.CeilingLamp_6
	GGAsset_LobbyWorld_1397 = { ["PiecePath"] = "CeilingLamp_7" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_7
	GGAsset_LobbyWorld_1398 = { ["PiecePath"] = "CeilingLamp_8" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_8
	GGAsset_LobbyWorld_1399 = { ["PiecePath"] = "CeilingLamp_9" }, -- Workspace.LobbyV4Staging.Shop.CeilingLamp_9
	GGAsset_LobbyWorld_1400 = { ["PiecePath"] = "Ceiling_2" }, -- Workspace.LobbyV4Staging.Shop.Ceiling_2
	GGAsset_LobbyWorld_1401 = { ["PiecePath"] = "Ceiling_3" }, -- Workspace.LobbyV4Staging.Shop.Ceiling_3
	GGAsset_LobbyWorld_1402 = { ["PiecePath"] = "Conduit" }, -- Workspace.LobbyV4Staging.Concourse.Conduit
	GGAsset_LobbyWorld_1403 = { ["PiecePath"] = "Conduit_10" }, -- Workspace.LobbyV4Staging.Shop.Conduit_10
	GGAsset_LobbyWorld_1404 = { ["PiecePath"] = "Conduit_2" }, -- Workspace.LobbyV4Staging.Concourse.Conduit_2
	GGAsset_LobbyWorld_1405 = { ["PiecePath"] = "Conduit_3" }, -- Workspace.LobbyV4Staging.Concourse.Conduit_3
	GGAsset_LobbyWorld_1406 = { ["PiecePath"] = "Conduit_4" }, -- Workspace.LobbyV4Staging.Concourse.Conduit_4
	GGAsset_LobbyWorld_1407 = { ["PiecePath"] = "Conduit_5" }, -- Workspace.LobbyV4Staging.Locker.Conduit_5
	GGAsset_LobbyWorld_1408 = { ["PiecePath"] = "Conduit_6" }, -- Workspace.LobbyV4Staging.Locker.Conduit_6
	GGAsset_LobbyWorld_1409 = { ["PiecePath"] = "Conduit_7" }, -- Workspace.LobbyV4Staging.Shop.Conduit_7
	GGAsset_LobbyWorld_1410 = { ["PiecePath"] = "Conduit_8" }, -- Workspace.LobbyV4Staging.Shop.Conduit_8
	GGAsset_LobbyWorld_1411 = { ["PiecePath"] = "Conduit_9" }, -- Workspace.LobbyV4Staging.Shop.Conduit_9
	GGAsset_LobbyWorld_1412 = { ["PiecePath"] = "CornerPier" }, -- Workspace.LobbyV4Staging.Duels.CornerPier
	GGAsset_LobbyWorld_1413 = { ["PiecePath"] = "CornerPier_10", ["SharedWith"] = "CornerPier_7" }, -- Workspace.LobbyV4Staging.Shop.CornerPier_10
	GGAsset_LobbyWorld_1414 = { ["PiecePath"] = "CornerPier_11", ["SharedWith"] = "CornerPier_7" }, -- Workspace.LobbyV4Staging.Shop.CornerPier_11
	GGAsset_LobbyWorld_1415 = { ["PiecePath"] = "CornerPier_12", ["SharedWith"] = "CornerPier_7" }, -- Workspace.LobbyV4Staging.Shop.CornerPier_12
	GGAsset_LobbyWorld_1416 = { ["PiecePath"] = "CornerPier_13", ["SharedWith"] = "CornerPier_7" }, -- Workspace.LobbyV4Staging.Shop.CornerPier_13
	GGAsset_LobbyWorld_1417 = { ["PiecePath"] = "CornerPier_14", ["SharedWith"] = "CornerPier_7" }, -- Workspace.LobbyV4Staging.Shop.CornerPier_14
	GGAsset_LobbyWorld_1418 = { ["PiecePath"] = "CornerPier_2", ["SharedWith"] = "CornerPier" }, -- Workspace.LobbyV4Staging.Duels.CornerPier_2
	GGAsset_LobbyWorld_1419 = { ["PiecePath"] = "CornerPier_3", ["SharedWith"] = "CornerPier" }, -- Workspace.LobbyV4Staging.Duels.CornerPier_3
	GGAsset_LobbyWorld_1420 = { ["PiecePath"] = "CornerPier_4", ["SharedWith"] = "CornerPier" }, -- Workspace.LobbyV4Staging.Duels.CornerPier_4
	GGAsset_LobbyWorld_1421 = { ["PiecePath"] = "CornerPier_5", ["SharedWith"] = "CornerPier" }, -- Workspace.LobbyV4Staging.Duels.CornerPier_5
	GGAsset_LobbyWorld_1422 = { ["PiecePath"] = "CornerPier_6", ["SharedWith"] = "CornerPier" }, -- Workspace.LobbyV4Staging.Duels.CornerPier_6
	GGAsset_LobbyWorld_1423 = { ["PiecePath"] = "CornerPier_7" }, -- Workspace.LobbyV4Staging.Shop.CornerPier_7
	GGAsset_LobbyWorld_1424 = { ["PiecePath"] = "CornerPier_8", ["SharedWith"] = "CornerPier_7" }, -- Workspace.LobbyV4Staging.Shop.CornerPier_8
	GGAsset_LobbyWorld_1425 = { ["PiecePath"] = "CornerPier_9", ["SharedWith"] = "CornerPier_7" }, -- Workspace.LobbyV4Staging.Shop.CornerPier_9
	GGAsset_LobbyWorld_1426 = { ["PiecePath"] = "DaisCollar" }, -- Workspace.LobbyV4Staging.Concourse.DaisCollar
	GGAsset_LobbyWorld_1427 = { ["PiecePath"] = "DaisCollar_2", ["SharedWith"] = "DaisCollar" }, -- Workspace.LobbyV4Staging.Concourse.DaisCollar_2
	GGAsset_LobbyWorld_1428 = { ["PiecePath"] = "DaisCollar_3", ["SharedWith"] = "DaisCollar" }, -- Workspace.LobbyV4Staging.Concourse.DaisCollar_3
	GGAsset_LobbyWorld_1429 = { ["PiecePath"] = "DaisCollar_4", ["SharedWith"] = "DaisCollar" }, -- Workspace.LobbyV4Staging.Concourse.DaisCollar_4
	GGAsset_LobbyWorld_1430 = { ["PiecePath"] = "DuelsCeiling" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.DuelsCeiling
	GGAsset_LobbyWorld_1431 = { ["PiecePath"] = "DuelsCeiling/Ceiling" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.Ceiling
	GGAsset_LobbyWorld_1432 = { ["PiecePath"] = "DuelsCeiling/CeilingLamp" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp
	GGAsset_LobbyWorld_1433 = { ["PiecePath"] = "DuelsCeiling/CeilingLamp_10" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_10
	GGAsset_LobbyWorld_1434 = { ["PiecePath"] = "DuelsCeiling/CeilingLamp_11" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_11
	GGAsset_LobbyWorld_1435 = { ["PiecePath"] = "DuelsCeiling/CeilingLamp_12" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_12
	GGAsset_LobbyWorld_1436 = { ["PiecePath"] = "DuelsCeiling/CeilingLamp_13" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_13
	GGAsset_LobbyWorld_1437 = { ["PiecePath"] = "DuelsCeiling/CeilingLamp_14" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_14
	GGAsset_LobbyWorld_1438 = { ["PiecePath"] = "DuelsCeiling/CeilingLamp_15" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_15
	GGAsset_LobbyWorld_1439 = { ["PiecePath"] = "DuelsCeiling/CeilingLamp_16" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_16
	GGAsset_LobbyWorld_1440 = { ["PiecePath"] = "DuelsCeiling/CeilingLamp_17" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_17
	GGAsset_LobbyWorld_1441 = { ["PiecePath"] = "DuelsCeiling/CeilingLamp_18" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_18
	GGAsset_LobbyWorld_1442 = { ["PiecePath"] = "DuelsCeiling/CeilingLamp_2" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_2
	GGAsset_LobbyWorld_1443 = { ["PiecePath"] = "DuelsCeiling/CeilingLamp_3" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_3
	GGAsset_LobbyWorld_1444 = { ["PiecePath"] = "DuelsCeiling/CeilingLamp_4" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_4
	GGAsset_LobbyWorld_1445 = { ["PiecePath"] = "DuelsCeiling/CeilingLamp_5" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_5
	GGAsset_LobbyWorld_1446 = { ["PiecePath"] = "DuelsCeiling/CeilingLamp_6" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_6
	GGAsset_LobbyWorld_1447 = { ["PiecePath"] = "DuelsCeiling/CeilingLamp_7" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_7
	GGAsset_LobbyWorld_1448 = { ["PiecePath"] = "DuelsCeiling/CeilingLamp_8" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_8
	GGAsset_LobbyWorld_1449 = { ["PiecePath"] = "DuelsCeiling/CeilingLamp_9" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.CeilingLamp_9
	GGAsset_LobbyWorld_1450 = { ["PiecePath"] = "DuelsCeiling/NaveVault" }, -- Workspace.LobbyV4Staging.Duels.DuelsCeiling.NaveVault
	GGAsset_LobbyWorld_1451 = { ["PiecePath"] = "DuelsFloor" }, -- Workspace.LobbyV4Staging.Duels.DuelsFloor
	GGAsset_LobbyWorld_1452 = { ["PiecePath"] = "FeaturedPedestal" }, -- Workspace.LobbyV4Staging.Shop.FeaturedPedestal
	GGAsset_LobbyWorld_1453 = { ["PiecePath"] = "Floor" }, -- Workspace.LobbyV4Staging.Locker.Floor
	GGAsset_LobbyWorld_1454 = { ["PiecePath"] = "FloorEmblem" }, -- Workspace.LobbyV4Staging.Locker.FloorEmblem
	GGAsset_LobbyWorld_1455 = { ["PiecePath"] = "Floor_2" }, -- Workspace.LobbyV4Staging.Shop.Floor_2
	GGAsset_LobbyWorld_1456 = { ["PiecePath"] = "Floor_3" }, -- Workspace.LobbyV4Staging.Shop.Floor_3
	GGAsset_LobbyWorld_1457 = { ["PiecePath"] = "FrontDetails" }, -- Workspace.LobbyV4Staging.Duels.FrontDetails
	GGAsset_LobbyWorld_1458 = { ["PiecePath"] = "Gallery" }, -- Workspace.LobbyV4Staging.Concourse.Gallery.Gallery
	GGAsset_LobbyWorld_1459 = { ["PiecePath"] = "Gallery/Braces" }, -- Workspace.LobbyV4Staging.Concourse.Gallery.Braces
	GGAsset_LobbyWorld_1460 = { ["PiecePath"] = "Gallery/Deck" }, -- Workspace.LobbyV4Staging.Concourse.Gallery.Deck
	GGAsset_LobbyWorld_1461 = { ["PiecePath"] = "Gallery/Railing" }, -- Workspace.LobbyV4Staging.Concourse.Gallery.Railing
	GGAsset_LobbyWorld_1462 = { ["PiecePath"] = "Gallery_2" }, -- Workspace.LobbyV4Staging.Concourse.Gallery_2.Gallery_2
	GGAsset_LobbyWorld_1463 = { ["PiecePath"] = "Gallery_2/Braces" }, -- Workspace.LobbyV4Staging.Concourse.Gallery_2.Braces
	GGAsset_LobbyWorld_1464 = { ["PiecePath"] = "Gallery_2/Deck" }, -- Workspace.LobbyV4Staging.Concourse.Gallery_2.Deck
	GGAsset_LobbyWorld_1465 = { ["PiecePath"] = "Gallery_2/Railing" }, -- Workspace.LobbyV4Staging.Concourse.Gallery_2.Railing
	GGAsset_LobbyWorld_1466 = { ["PiecePath"] = "Gallery_3" }, -- Workspace.LobbyV4Staging.Concourse.Gallery_3.Gallery_3
	GGAsset_LobbyWorld_1467 = { ["PiecePath"] = "Gallery_3/Braces" }, -- Workspace.LobbyV4Staging.Concourse.Gallery_3.Braces
	GGAsset_LobbyWorld_1468 = { ["PiecePath"] = "Gallery_3/Deck" }, -- Workspace.LobbyV4Staging.Concourse.Gallery_3.Deck
	GGAsset_LobbyWorld_1469 = { ["PiecePath"] = "Gallery_3/Railing" }, -- Workspace.LobbyV4Staging.Concourse.Gallery_3.Railing
	GGAsset_LobbyWorld_1470 = { ["PiecePath"] = "Gallery_4" }, -- Workspace.LobbyV4Staging.Concourse.Gallery_4.Gallery_4
	GGAsset_LobbyWorld_1471 = { ["PiecePath"] = "Gallery_4/Braces" }, -- Workspace.LobbyV4Staging.Concourse.Gallery_4.Braces
	GGAsset_LobbyWorld_1472 = { ["PiecePath"] = "Gallery_4/Deck" }, -- Workspace.LobbyV4Staging.Concourse.Gallery_4.Deck
	GGAsset_LobbyWorld_1473 = { ["PiecePath"] = "Gallery_4/Railing" }, -- Workspace.LobbyV4Staging.Concourse.Gallery_4.Railing
	GGAsset_LobbyWorld_1474 = { ["PiecePath"] = "Gate_Duels" }, -- Workspace.LobbyV4Staging.Concourse.Gate_Duels
	GGAsset_LobbyWorld_1475 = { ["PiecePath"] = "Gate_Locker" }, -- Workspace.LobbyV4Staging.Concourse.Gate_Locker
	GGAsset_LobbyWorld_1476 = { ["PiecePath"] = "Gate_Range" }, -- Workspace.LobbyV4Staging.Concourse.Gate_Range
	GGAsset_LobbyWorld_1477 = { ["PiecePath"] = "Gate_Shop" }, -- Workspace.LobbyV4Staging.Concourse.Gate_Shop
	GGAsset_LobbyWorld_1478 = { ["PiecePath"] = "GunWall" }, -- Workspace.LobbyV4Staging.Locker.GunWall
	GGAsset_LobbyWorld_1479 = { ["PiecePath"] = "HangLamp" }, -- Workspace.LobbyV4Staging.Locker.HangLamp
	GGAsset_LobbyWorld_1480 = { ["PiecePath"] = "HangLamp_2" }, -- Workspace.LobbyV4Staging.Locker.HangLamp_2
	GGAsset_LobbyWorld_1481 = { ["PiecePath"] = "Hazard" }, -- Workspace.LobbyV4Staging.Concourse.Hazard
	GGAsset_LobbyWorld_1482 = { ["PiecePath"] = "Hazard_10" }, -- Workspace.LobbyV4Staging.Duels.Hazard_10
	GGAsset_LobbyWorld_1483 = { ["PiecePath"] = "Hazard_11" }, -- Workspace.LobbyV4Staging.Duels.Hazard_11
	GGAsset_LobbyWorld_1484 = { ["PiecePath"] = "Hazard_12" }, -- Workspace.LobbyV4Staging.Duels.Hazard_12
	GGAsset_LobbyWorld_1485 = { ["PiecePath"] = "Hazard_13" }, -- Workspace.LobbyV4Staging.Duels.Hazard_13
	GGAsset_LobbyWorld_1486 = { ["PiecePath"] = "Hazard_14" }, -- Workspace.LobbyV4Staging.Duels.Hazard_14
	GGAsset_LobbyWorld_1487 = { ["PiecePath"] = "Hazard_15" }, -- Workspace.LobbyV4Staging.Duels.Hazard_15
	GGAsset_LobbyWorld_1488 = { ["PiecePath"] = "Hazard_16" }, -- Workspace.LobbyV4Staging.Duels.Hazard_16
	GGAsset_LobbyWorld_1489 = { ["PiecePath"] = "Hazard_2" }, -- Workspace.LobbyV4Staging.Concourse.Hazard_2
	GGAsset_LobbyWorld_1490 = { ["PiecePath"] = "Hazard_3" }, -- Workspace.LobbyV4Staging.Concourse.Hazard_3
	GGAsset_LobbyWorld_1491 = { ["PiecePath"] = "Hazard_4" }, -- Workspace.LobbyV4Staging.Concourse.Hazard_4
	GGAsset_LobbyWorld_1492 = { ["PiecePath"] = "Hazard_5" }, -- Workspace.LobbyV4Staging.Concourse.Hazard_5
	GGAsset_LobbyWorld_1493 = { ["PiecePath"] = "Hazard_6" }, -- Workspace.LobbyV4Staging.Concourse.Hazard_6
	GGAsset_LobbyWorld_1494 = { ["PiecePath"] = "Hazard_7" }, -- Workspace.LobbyV4Staging.Concourse.Hazard_7
	GGAsset_LobbyWorld_1495 = { ["PiecePath"] = "Hazard_8" }, -- Workspace.LobbyV4Staging.Concourse.Hazard_8
	GGAsset_LobbyWorld_1496 = { ["PiecePath"] = "Hazard_9" }, -- Workspace.LobbyV4Staging.Duels.Hazard_9
	GGAsset_LobbyWorld_1497 = { ["PiecePath"] = "Holo_Badge" }, -- Workspace.LobbyV4Staging.Concourse.Holo_Badge
	GGAsset_LobbyWorld_1498 = { ["PiecePath"] = "Holo_BadgeItem", ["SpinAxis"] = Vector3.new(0, 1, -0), ["SpinSpeed"] = 24 }, -- Workspace.LobbyV4Staging.Concourse.Holo_BadgeItem
	GGAsset_LobbyWorld_1499 = { ["PiecePath"] = "Holo_Crate" }, -- Workspace.LobbyV4Staging.Concourse.Holo_Crate
	GGAsset_LobbyWorld_1500 = { ["PiecePath"] = "Holo_CrateItem", ["SpinAxis"] = Vector3.new(0, 1, -0), ["SpinSpeed"] = 24 }, -- Workspace.LobbyV4Staging.Concourse.Holo_CrateItem
	GGAsset_LobbyWorld_1501 = { ["PiecePath"] = "Holo_Gift" }, -- Workspace.LobbyV4Staging.Concourse.Holo_Gift
	GGAsset_LobbyWorld_1502 = { ["PiecePath"] = "Holo_GiftItem", ["SpinAxis"] = Vector3.new(0, 1, -0), ["SpinSpeed"] = 24 }, -- Workspace.LobbyV4Staging.Concourse.Holo_GiftItem
	GGAsset_LobbyWorld_1503 = { ["PiecePath"] = "Holo_Rifle" }, -- Workspace.LobbyV4Staging.Concourse.Holo_Rifle
	GGAsset_LobbyWorld_1504 = { ["PiecePath"] = "Holo_RifleItem", ["SpinAxis"] = Vector3.new(0, 1, -0), ["SpinSpeed"] = 24 }, -- Workspace.LobbyV4Staging.Concourse.Holo_RifleItem
	GGAsset_LobbyWorld_1505 = { ["PiecePath"] = "Holo_ShopBadge" }, -- Workspace.LobbyV4Staging.Shop.Holo_ShopBadge
	GGAsset_LobbyWorld_1506 = { ["PiecePath"] = "Holo_ShopBadgeItem", ["SpinAxis"] = Vector3.new(0, 1, -0), ["SpinSpeed"] = 24 }, -- Workspace.LobbyV4Staging.Shop.Holo_ShopBadgeItem
	GGAsset_LobbyWorld_1507 = { ["PiecePath"] = "Holo_ShopGift" }, -- Workspace.LobbyV4Staging.Shop.Holo_ShopGift
	GGAsset_LobbyWorld_1508 = { ["PiecePath"] = "Holo_ShopGiftItem", ["SpinAxis"] = Vector3.new(0, 1, -0), ["SpinSpeed"] = 24 }, -- Workspace.LobbyV4Staging.Shop.Holo_ShopGiftItem
	GGAsset_LobbyWorld_1509 = { ["PiecePath"] = "HubCeiling" }, -- Workspace.LobbyV4Staging.Concourse.HubCeiling.HubCeiling
	GGAsset_LobbyWorld_1510 = { ["PiecePath"] = "HubCeiling/Beam" }, -- Workspace.LobbyV4Staging.Concourse.HubCeiling.Beam
	GGAsset_LobbyWorld_1511 = { ["PiecePath"] = "HubCeiling/Beam_2", ["SharedWith"] = "HubCeiling/Beam" }, -- Workspace.LobbyV4Staging.Concourse.HubCeiling.Beam_2
	GGAsset_LobbyWorld_1512 = { ["PiecePath"] = "HubCeiling/Beam_3", ["SharedWith"] = "HubCeiling/Beam" }, -- Workspace.LobbyV4Staging.Concourse.HubCeiling.Beam_3
	GGAsset_LobbyWorld_1513 = { ["PiecePath"] = "HubCeiling/Beam_4", ["SharedWith"] = "HubCeiling/Beam" }, -- Workspace.LobbyV4Staging.Concourse.HubCeiling.Beam_4
	GGAsset_LobbyWorld_1514 = { ["PiecePath"] = "HubCeiling/Beam_5", ["SharedWith"] = "HubCeiling/Beam" }, -- Workspace.LobbyV4Staging.Concourse.HubCeiling.Beam_5
	GGAsset_LobbyWorld_1515 = { ["PiecePath"] = "HubCeiling/Beam_6", ["SharedWith"] = "HubCeiling/Beam" }, -- Workspace.LobbyV4Staging.Concourse.HubCeiling.Beam_6
	GGAsset_LobbyWorld_1516 = { ["PiecePath"] = "HubCeiling/Beam_7", ["SharedWith"] = "HubCeiling/Beam" }, -- Workspace.LobbyV4Staging.Concourse.HubCeiling.Beam_7
	GGAsset_LobbyWorld_1517 = { ["PiecePath"] = "HubCeiling/Beam_8", ["SharedWith"] = "HubCeiling/Beam" }, -- Workspace.LobbyV4Staging.Concourse.HubCeiling.Beam_8
	GGAsset_LobbyWorld_1518 = { ["PiecePath"] = "HubCeiling/CeilingLamp" }, -- Workspace.LobbyV4Staging.Concourse.HubCeiling.CeilingLamp
	GGAsset_LobbyWorld_1519 = { ["PiecePath"] = "HubCeiling/CeilingLamp_2" }, -- Workspace.LobbyV4Staging.Concourse.HubCeiling.CeilingLamp_2
	GGAsset_LobbyWorld_1520 = { ["PiecePath"] = "HubCeiling/CeilingLamp_3" }, -- Workspace.LobbyV4Staging.Concourse.HubCeiling.CeilingLamp_3
	GGAsset_LobbyWorld_1521 = { ["PiecePath"] = "HubCeiling/CeilingLamp_4" }, -- Workspace.LobbyV4Staging.Concourse.HubCeiling.CeilingLamp_4
	GGAsset_LobbyWorld_1522 = { ["PiecePath"] = "HubCeiling/CeilingLamp_5" }, -- Workspace.LobbyV4Staging.Concourse.HubCeiling.CeilingLamp_5
	GGAsset_LobbyWorld_1523 = { ["PiecePath"] = "HubCeiling/CeilingLamp_6" }, -- Workspace.LobbyV4Staging.Concourse.HubCeiling.CeilingLamp_6
	GGAsset_LobbyWorld_1524 = { ["PiecePath"] = "HubCeiling/CeilingLamp_7" }, -- Workspace.LobbyV4Staging.Concourse.HubCeiling.CeilingLamp_7
	GGAsset_LobbyWorld_1525 = { ["PiecePath"] = "HubCeiling/CeilingLamp_8" }, -- Workspace.LobbyV4Staging.Concourse.HubCeiling.CeilingLamp_8
	GGAsset_LobbyWorld_1526 = { ["PiecePath"] = "HubFloor" }, -- Workspace.LobbyV4Staging.Concourse.HubFloor.HubFloor
	GGAsset_LobbyWorld_1527 = { ["PiecePath"] = "Jumbotron" }, -- Workspace.LobbyV4Staging.Duels.Jumbotron
	GGAsset_LobbyWorld_1528 = { ["PiecePath"] = "KnifePlinth" }, -- Workspace.LobbyV4Staging.Locker.KnifePlinth
	GGAsset_LobbyWorld_1529 = { ["PiecePath"] = "Landing" }, -- Workspace.LobbyV4Staging.Duels.Landing
	GGAsset_LobbyWorld_1530 = { ["PiecePath"] = "Lantern" }, -- Workspace.LobbyV4Staging.Concourse.Lantern
	GGAsset_LobbyWorld_1531 = { ["PiecePath"] = "LightRing" }, -- Workspace.LobbyV4Staging.Concourse.LightRing
	GGAsset_LobbyWorld_1532 = { ["PiecePath"] = "LightingRig" }, -- Workspace.LobbyV4Staging.Concourse.LightingRig.LightingRig
	GGAsset_LobbyWorld_1533 = { ["PiecePath"] = "LightingRig/StageSpot" }, -- Workspace.LobbyV4Staging.Concourse.LightingRig.StageSpot
	GGAsset_LobbyWorld_1534 = { ["PiecePath"] = "LightingRig/StageSpot_2" }, -- Workspace.LobbyV4Staging.Concourse.LightingRig.StageSpot_2
	GGAsset_LobbyWorld_1535 = { ["PiecePath"] = "LightingRig/StageSpot_3" }, -- Workspace.LobbyV4Staging.Concourse.LightingRig.StageSpot_3
	GGAsset_LobbyWorld_1536 = { ["PiecePath"] = "LightingRig/StageSpot_4" }, -- Workspace.LobbyV4Staging.Concourse.LightingRig.StageSpot_4
	GGAsset_LobbyWorld_1537 = { ["PiecePath"] = "LightingRig/StageSpot_5" }, -- Workspace.LobbyV4Staging.Concourse.LightingRig.StageSpot_5
	GGAsset_LobbyWorld_1538 = { ["PiecePath"] = "LightingRig/StageSpot_6" }, -- Workspace.LobbyV4Staging.Concourse.LightingRig.StageSpot_6
	GGAsset_LobbyWorld_1539 = { ["PiecePath"] = "LightingRig/StageSpot_7" }, -- Workspace.LobbyV4Staging.Concourse.LightingRig.StageSpot_7
	GGAsset_LobbyWorld_1540 = { ["PiecePath"] = "LightingRig/StageSpot_8" }, -- Workspace.LobbyV4Staging.Concourse.LightingRig.StageSpot_8
	GGAsset_LobbyWorld_1541 = { ["PiecePath"] = "Mark_Featured" }, -- Workspace.LobbyV4Staging.Shop.Mark_Featured.Mark_Featured
	GGAsset_LobbyWorld_1542 = { ["PiecePath"] = "Mark_Featured/Hazard" }, -- Workspace.LobbyV4Staging.Shop.Mark_Featured.Hazard
	GGAsset_LobbyWorld_1543 = { ["PiecePath"] = "Mark_Season" }, -- Workspace.LobbyV4Staging.Shop.Mark_Season.Mark_Season
	GGAsset_LobbyWorld_1544 = { ["PiecePath"] = "Mark_Season/Hazard" }, -- Workspace.LobbyV4Staging.Shop.Mark_Season.Hazard
	GGAsset_LobbyWorld_1545 = { ["PiecePath"] = "Mouth" }, -- Workspace.LobbyV4Staging.Locker.Mouth
	GGAsset_LobbyWorld_1546 = { ["PiecePath"] = "Mouth_2" }, -- Workspace.LobbyV4Staging.Shop.Mouth_2
	GGAsset_LobbyWorld_1547 = { ["PiecePath"] = "Mouth_3" }, -- Workspace.LobbyV4Staging.Shop.Mouth_3
	GGAsset_LobbyWorld_1548 = { ["PiecePath"] = "Mouth_4" }, -- Workspace.LobbyV4Staging.Shop.Mouth_4
	GGAsset_LobbyWorld_1549 = { ["PiecePath"] = "PadSign" }, -- Workspace.LobbyV4Staging.Duels.PadSign
	GGAsset_LobbyWorld_1550 = { ["PiecePath"] = "PadSign_2" }, -- Workspace.LobbyV4Staging.Duels.PadSign_2
	GGAsset_LobbyWorld_1551 = { ["PiecePath"] = "PadSign_3" }, -- Workspace.LobbyV4Staging.Duels.PadSign_3
	GGAsset_LobbyWorld_1552 = { ["PiecePath"] = "PadSign_4" }, -- Workspace.LobbyV4Staging.Duels.PadSign_4
	GGAsset_LobbyWorld_1553 = { ["PiecePath"] = "PadSign_5" }, -- Workspace.LobbyV4Staging.Duels.PadSign_5
	GGAsset_LobbyWorld_1554 = { ["PiecePath"] = "PadSign_6" }, -- Workspace.LobbyV4Staging.Duels.PadSign_6
	GGAsset_LobbyWorld_1555 = { ["PiecePath"] = "PadSign_7" }, -- Workspace.LobbyV4Staging.Duels.PadSign_7
	GGAsset_LobbyWorld_1556 = { ["PiecePath"] = "PadSign_8" }, -- Workspace.LobbyV4Staging.Duels.PadSign_8
	GGAsset_LobbyWorld_1557 = { ["PiecePath"] = "Pad_1v1_2", ["SharedWith"] = "Pad_1v1" }, -- Workspace.LobbyV4Staging.Duels.Pad_1v1_2.Pad_1v1_2
	GGAsset_LobbyWorld_1558 = { ["PiecePath"] = "Pad_1v1_2/Hazard" }, -- Workspace.LobbyV4Staging.Duels.Pad_1v1_2.Hazard
	GGAsset_LobbyWorld_1559 = { ["PiecePath"] = "Pad_2v2", ["SharedWith"] = "Pad_1v1" }, -- Workspace.LobbyV4Staging.Duels.Pad_2v2.Pad_2v2
	GGAsset_LobbyWorld_1560 = { ["PiecePath"] = "Pad_2v2/Hazard" }, -- Workspace.LobbyV4Staging.Duels.Pad_2v2.Hazard
	GGAsset_LobbyWorld_1561 = { ["PiecePath"] = "Pad_2v2_2", ["SharedWith"] = "Pad_1v1" }, -- Workspace.LobbyV4Staging.Duels.Pad_2v2_2.Pad_2v2_2
	GGAsset_LobbyWorld_1562 = { ["PiecePath"] = "Pad_2v2_2/Hazard" }, -- Workspace.LobbyV4Staging.Duels.Pad_2v2_2.Hazard
	GGAsset_LobbyWorld_1563 = { ["PiecePath"] = "Pad_3v3", ["SharedWith"] = "Pad_1v1" }, -- Workspace.LobbyV4Staging.Duels.Pad_3v3.Pad_3v3
	GGAsset_LobbyWorld_1564 = { ["PiecePath"] = "Pad_3v3/Hazard" }, -- Workspace.LobbyV4Staging.Duels.Pad_3v3.Hazard
	GGAsset_LobbyWorld_1565 = { ["PiecePath"] = "Pad_3v3_2", ["SharedWith"] = "Pad_1v1" }, -- Workspace.LobbyV4Staging.Duels.Pad_3v3_2.Pad_3v3_2
	GGAsset_LobbyWorld_1566 = { ["PiecePath"] = "Pad_3v3_2/Hazard" }, -- Workspace.LobbyV4Staging.Duels.Pad_3v3_2.Hazard
	GGAsset_LobbyWorld_1567 = { ["PiecePath"] = "Pad_4v4", ["SharedWith"] = "Pad_1v1" }, -- Workspace.LobbyV4Staging.Duels.Pad_4v4.Pad_4v4
	GGAsset_LobbyWorld_1568 = { ["PiecePath"] = "Pad_4v4/Hazard" }, -- Workspace.LobbyV4Staging.Duels.Pad_4v4.Hazard
	GGAsset_LobbyWorld_1569 = { ["PiecePath"] = "Pad_5v5", ["SharedWith"] = "Pad_1v1" }, -- Workspace.LobbyV4Staging.Duels.Pad_5v5.Pad_5v5
	GGAsset_LobbyWorld_1570 = { ["PiecePath"] = "Pad_5v5/Hazard" }, -- Workspace.LobbyV4Staging.Duels.Pad_5v5.Hazard
	GGAsset_LobbyWorld_1571 = { ["PiecePath"] = "PathCorner" }, -- Workspace.LobbyV4Staging.Shop.PathCorner
	GGAsset_LobbyWorld_1572 = { ["PiecePath"] = "Path_2" }, -- Workspace.LobbyV4Staging.Shop.Path_2
	GGAsset_LobbyWorld_1573 = { ["PiecePath"] = "Path_3" }, -- Workspace.LobbyV4Staging.Shop.Path_3
	GGAsset_LobbyWorld_1574 = { ["PiecePath"] = "Pier" }, -- Workspace.LobbyV4Staging.Concourse.Pier
	GGAsset_LobbyWorld_1575 = { ["PiecePath"] = "PierCollar" }, -- Workspace.LobbyV4Staging.Concourse.PierCollar
	GGAsset_LobbyWorld_1576 = { ["PiecePath"] = "PierCollar_2", ["SharedWith"] = "PierCollar" }, -- Workspace.LobbyV4Staging.Concourse.PierCollar_2
	GGAsset_LobbyWorld_1577 = { ["PiecePath"] = "PierCollar_3", ["SharedWith"] = "PierCollar" }, -- Workspace.LobbyV4Staging.Concourse.PierCollar_3
	GGAsset_LobbyWorld_1578 = { ["PiecePath"] = "PierCollar_4", ["SharedWith"] = "PierCollar" }, -- Workspace.LobbyV4Staging.Concourse.PierCollar_4
	GGAsset_LobbyWorld_1579 = { ["PiecePath"] = "PierCollar_5", ["SharedWith"] = "PierCollar" }, -- Workspace.LobbyV4Staging.Concourse.PierCollar_5
	GGAsset_LobbyWorld_1580 = { ["PiecePath"] = "PierCollar_6", ["SharedWith"] = "PierCollar" }, -- Workspace.LobbyV4Staging.Concourse.PierCollar_6
	GGAsset_LobbyWorld_1581 = { ["PiecePath"] = "PierCollar_7", ["SharedWith"] = "PierCollar" }, -- Workspace.LobbyV4Staging.Concourse.PierCollar_7
	GGAsset_LobbyWorld_1582 = { ["PiecePath"] = "PierCollar_8", ["SharedWith"] = "PierCollar" }, -- Workspace.LobbyV4Staging.Concourse.PierCollar_8
	GGAsset_LobbyWorld_1583 = { ["PiecePath"] = "Pier_10", ["SharedWith"] = "Pier_9" }, -- Workspace.LobbyV4Staging.Duels.Pier_10
	GGAsset_LobbyWorld_1584 = { ["PiecePath"] = "Pier_11", ["SharedWith"] = "Pier_9" }, -- Workspace.LobbyV4Staging.Duels.Pier_11
	GGAsset_LobbyWorld_1585 = { ["PiecePath"] = "Pier_12", ["SharedWith"] = "Pier_9" }, -- Workspace.LobbyV4Staging.Duels.Pier_12
	GGAsset_LobbyWorld_1586 = { ["PiecePath"] = "Pier_13", ["SharedWith"] = "Pier_9" }, -- Workspace.LobbyV4Staging.Duels.Pier_13
	GGAsset_LobbyWorld_1587 = { ["PiecePath"] = "Pier_14", ["SharedWith"] = "Pier_9" }, -- Workspace.LobbyV4Staging.Duels.Pier_14
	GGAsset_LobbyWorld_1588 = { ["PiecePath"] = "Pier_15", ["SharedWith"] = "Pier_9" }, -- Workspace.LobbyV4Staging.Duels.Pier_15
	GGAsset_LobbyWorld_1589 = { ["PiecePath"] = "Pier_16", ["SharedWith"] = "Pier_9" }, -- Workspace.LobbyV4Staging.Duels.Pier_16
	GGAsset_LobbyWorld_1590 = { ["PiecePath"] = "Pier_17" }, -- Workspace.LobbyV4Staging.Shop.Pier_17
	GGAsset_LobbyWorld_1591 = { ["PiecePath"] = "Pier_18", ["SharedWith"] = "Pier_17" }, -- Workspace.LobbyV4Staging.Shop.Pier_18
	GGAsset_LobbyWorld_1592 = { ["PiecePath"] = "Pier_19", ["SharedWith"] = "Pier_17" }, -- Workspace.LobbyV4Staging.Shop.Pier_19
	GGAsset_LobbyWorld_1593 = { ["PiecePath"] = "Pier_2", ["SharedWith"] = "Pier" }, -- Workspace.LobbyV4Staging.Concourse.Pier_2
	GGAsset_LobbyWorld_1594 = { ["PiecePath"] = "Pier_20", ["SharedWith"] = "Pier_17" }, -- Workspace.LobbyV4Staging.Shop.Pier_20
	GGAsset_LobbyWorld_1595 = { ["PiecePath"] = "Pier_3", ["SharedWith"] = "Pier" }, -- Workspace.LobbyV4Staging.Concourse.Pier_3
	GGAsset_LobbyWorld_1596 = { ["PiecePath"] = "Pier_4", ["SharedWith"] = "Pier" }, -- Workspace.LobbyV4Staging.Concourse.Pier_4
	GGAsset_LobbyWorld_1597 = { ["PiecePath"] = "Pier_5", ["SharedWith"] = "Pier" }, -- Workspace.LobbyV4Staging.Concourse.Pier_5
	GGAsset_LobbyWorld_1598 = { ["PiecePath"] = "Pier_6", ["SharedWith"] = "Pier" }, -- Workspace.LobbyV4Staging.Concourse.Pier_6
	GGAsset_LobbyWorld_1599 = { ["PiecePath"] = "Pier_7", ["SharedWith"] = "Pier" }, -- Workspace.LobbyV4Staging.Concourse.Pier_7
	GGAsset_LobbyWorld_1600 = { ["PiecePath"] = "Pier_8", ["SharedWith"] = "Pier" }, -- Workspace.LobbyV4Staging.Concourse.Pier_8
	GGAsset_LobbyWorld_1601 = { ["PiecePath"] = "Pier_9" }, -- Workspace.LobbyV4Staging.Duels.Pier_9
	GGAsset_LobbyWorld_1602 = { ["PiecePath"] = "Plaques_Locker" }, -- Workspace.LobbyV4Staging.Concourse.Plaques_Locker
	GGAsset_LobbyWorld_1603 = { ["PiecePath"] = "Plaques_Range" }, -- Workspace.LobbyV4Staging.Concourse.Plaques_Range
	GGAsset_LobbyWorld_1604 = { ["PiecePath"] = "Portal_Duels" }, -- Workspace.LobbyV4Staging.Concourse.Portal_Duels
	GGAsset_LobbyWorld_1605 = { ["PiecePath"] = "Portal_Locker" }, -- Workspace.LobbyV4Staging.Concourse.Portal_Locker
	GGAsset_LobbyWorld_1606 = { ["PiecePath"] = "Portal_Range" }, -- Workspace.LobbyV4Staging.Concourse.Portal_Range
	GGAsset_LobbyWorld_1607 = { ["PiecePath"] = "Portal_Shop" }, -- Workspace.LobbyV4Staging.Concourse.Portal_Shop
	GGAsset_LobbyWorld_1608 = { ["PiecePath"] = "RangeDoor" }, -- Workspace.LobbyV4Staging.Concourse.RangeDoor
	GGAsset_LobbyWorld_1609 = { ["PiecePath"] = "RoomVault" }, -- Workspace.LobbyV4Staging.Locker.RoomVault
	GGAsset_LobbyWorld_1610 = { ["PiecePath"] = "RoomVault_2" }, -- Workspace.LobbyV4Staging.Shop.RoomVault_2
	GGAsset_LobbyWorld_1611 = { ["PiecePath"] = "RoomVault_3" }, -- Workspace.LobbyV4Staging.Shop.RoomVault_3
	GGAsset_LobbyWorld_1612 = { ["PiecePath"] = "SeasonCrest" }, -- Workspace.LobbyV4Staging.Shop.SeasonCrest
	GGAsset_LobbyWorld_1613 = { ["PiecePath"] = "Sign_Broker" }, -- Workspace.LobbyV4Staging.Shop.Sign_Broker
	GGAsset_LobbyWorld_1614 = { ["PiecePath"] = "Sign_Duels" }, -- Workspace.LobbyV4Staging.Concourse.Sign_Duels
	GGAsset_LobbyWorld_1615 = { ["PiecePath"] = "Sign_Gauntlet" }, -- Workspace.LobbyV4Staging.Duels.Sign_Gauntlet
	GGAsset_LobbyWorld_1616 = { ["PiecePath"] = "Sign_Loadout" }, -- Workspace.LobbyV4Staging.Locker.Sign_Loadout
	GGAsset_LobbyWorld_1617 = { ["PiecePath"] = "Sign_Locker" }, -- Workspace.LobbyV4Staging.Concourse.Sign_Locker
	GGAsset_LobbyWorld_1618 = { ["PiecePath"] = "Sign_Market" }, -- Workspace.LobbyV4Staging.Shop.Sign_Market
	GGAsset_LobbyWorld_1619 = { ["PiecePath"] = "Sign_Range" }, -- Workspace.LobbyV4Staging.Concourse.Sign_Range
	GGAsset_LobbyWorld_1620 = { ["PiecePath"] = "Sign_Shop" }, -- Workspace.LobbyV4Staging.Concourse.Sign_Shop
	GGAsset_LobbyWorld_1621 = { ["PiecePath"] = "StageSpot" }, -- Workspace.LobbyV4Staging.Shop.StageSpot
	GGAsset_LobbyWorld_1622 = { ["PiecePath"] = "StageSpot_2" }, -- Workspace.LobbyV4Staging.Shop.StageSpot_2
	GGAsset_LobbyWorld_1623 = { ["PiecePath"] = "StageSpot_3" }, -- Workspace.LobbyV4Staging.Shop.StageSpot_3
	GGAsset_LobbyWorld_1624 = { ["PiecePath"] = "StageSpot_4" }, -- Workspace.LobbyV4Staging.Shop.StageSpot_4
	GGAsset_LobbyWorld_1625 = { ["PiecePath"] = "StageSpot_5" }, -- Workspace.LobbyV4Staging.Shop.StageSpot_5
	GGAsset_LobbyWorld_1626 = { ["PiecePath"] = "StageSpot_6" }, -- Workspace.LobbyV4Staging.Shop.StageSpot_6
	GGAsset_LobbyWorld_1627 = { ["PiecePath"] = "TV_Broker" }, -- Workspace.LobbyV4Staging.Shop.TV_Broker
	GGAsset_LobbyWorld_1628 = { ["PiecePath"] = "TV_Featured" }, -- Workspace.LobbyV4Staging.Concourse.TV_Featured
	GGAsset_LobbyWorld_1629 = { ["PiecePath"] = "TV_News" }, -- Workspace.LobbyV4Staging.Concourse.TV_News
	GGAsset_LobbyWorld_1630 = { ["PiecePath"] = "TV_ShopEnd" }, -- Workspace.LobbyV4Staging.Shop.TV_ShopEnd
	GGAsset_LobbyWorld_1631 = { ["PiecePath"] = "TV_ShopN" }, -- Workspace.LobbyV4Staging.Shop.TV_ShopN
	GGAsset_LobbyWorld_1632 = { ["PiecePath"] = "TV_ShopS" }, -- Workspace.LobbyV4Staging.Shop.TV_ShopS
	GGAsset_LobbyWorld_1633 = { ["PiecePath"] = "TV_TOPWINS" }, -- Workspace.LobbyV4Staging.Concourse.TV_TOPWINS
	GGAsset_LobbyWorld_1634 = { ["PiecePath"] = "TV_WINSTREAKS" }, -- Workspace.LobbyV4Staging.Concourse.TV_WINSTREAKS
	GGAsset_LobbyWorld_1635 = { ["PiecePath"] = "Table_Classic" }, -- Workspace.LobbyV4Staging.Locker.Table_Classic
	GGAsset_LobbyWorld_1636 = { ["PiecePath"] = "Table_Judge" }, -- Workspace.LobbyV4Staging.Locker.Table_Judge
	GGAsset_LobbyWorld_1637 = { ["PiecePath"] = "Table_Odin" }, -- Workspace.LobbyV4Staging.Locker.Table_Odin
	GGAsset_LobbyWorld_1638 = { ["PiecePath"] = "Table_Operator" }, -- Workspace.LobbyV4Staging.Locker.Table_Operator
	GGAsset_LobbyWorld_1639 = { ["PiecePath"] = "Table_Phantom" }, -- Workspace.LobbyV4Staging.Locker.Table_Phantom
	GGAsset_LobbyWorld_1640 = { ["PiecePath"] = "Table_Sheriff" }, -- Workspace.LobbyV4Staging.Locker.Table_Sheriff
	GGAsset_LobbyWorld_1641 = { ["PiecePath"] = "Table_Spectre" }, -- Workspace.LobbyV4Staging.Locker.Table_Spectre
	GGAsset_LobbyWorld_1642 = { ["PiecePath"] = "Table_Vandal" }, -- Workspace.LobbyV4Staging.Locker.Table_Vandal
	GGAsset_LobbyWorld_1643 = { ["PiecePath"] = "Threshold" }, -- Workspace.LobbyV4Staging.Locker.Threshold
	GGAsset_LobbyWorld_1644 = { ["PiecePath"] = "Threshold_2" }, -- Workspace.LobbyV4Staging.Shop.Threshold_2
	GGAsset_LobbyWorld_1645 = { ["PiecePath"] = "Threshold_3" }, -- Workspace.LobbyV4Staging.Shop.Threshold_3
	GGAsset_LobbyWorld_1646 = { ["PiecePath"] = "Trophy", ["SpinAxis"] = Vector3.new(0, 1, -0), ["SpinSpeed"] = 9 }, -- Workspace.LobbyV4Staging.Duels.Trophy
	GGAsset_LobbyWorld_1647 = { ["PiecePath"] = "TrophyPlinth" }, -- Workspace.LobbyV4Staging.Duels.TrophyPlinth
	GGAsset_LobbyWorld_1648 = { ["PiecePath"] = "Vents" }, -- Workspace.LobbyV4Staging.Concourse.Vents
	GGAsset_LobbyWorld_1649 = { ["PiecePath"] = "Vents_2" }, -- Workspace.LobbyV4Staging.Concourse.Vents_2
	GGAsset_LobbyWorld_1650 = { ["PiecePath"] = "Vents_3" }, -- Workspace.LobbyV4Staging.Concourse.Vents_3
	GGAsset_LobbyWorld_1651 = { ["PiecePath"] = "Vents_4" }, -- Workspace.LobbyV4Staging.Concourse.Vents_4
	GGAsset_LobbyWorld_1652 = { ["PiecePath"] = "Vents_5" }, -- Workspace.LobbyV4Staging.Shop.Vents_5
	GGAsset_LobbyWorld_1653 = { ["PiecePath"] = "Vents_6" }, -- Workspace.LobbyV4Staging.Shop.Vents_6
	GGAsset_LobbyWorld_1654 = { ["PiecePath"] = "Vents_N" }, -- Workspace.LobbyV4Staging.Locker.Vents_N
	GGAsset_LobbyWorld_1655 = { ["PiecePath"] = "Vents_S" }, -- Workspace.LobbyV4Staging.Locker.Vents_S
	GGAsset_LobbyWorld_1656 = { ["PiecePath"] = "Wall" }, -- Workspace.LobbyV4Staging.Concourse.Wall
	GGAsset_LobbyWorld_1657 = { ["PiecePath"] = "WallBand" }, -- Workspace.LobbyV4Staging.Shop.WallBand
	GGAsset_LobbyWorld_1658 = { ["PiecePath"] = "WallBand_2" }, -- Workspace.LobbyV4Staging.Shop.WallBand_2
	GGAsset_LobbyWorld_1659 = { ["PiecePath"] = "Wall_10" }, -- Workspace.LobbyV4Staging.Duels.Wall_10
	GGAsset_LobbyWorld_1660 = { ["PiecePath"] = "Wall_11" }, -- Workspace.LobbyV4Staging.Duels.Wall_11
	GGAsset_LobbyWorld_1661 = { ["PiecePath"] = "Wall_12" }, -- Workspace.LobbyV4Staging.Duels.Wall_12
	GGAsset_LobbyWorld_1662 = { ["PiecePath"] = "Wall_13" }, -- Workspace.LobbyV4Staging.Duels.Wall_13
	GGAsset_LobbyWorld_1663 = { ["PiecePath"] = "Wall_14" }, -- Workspace.LobbyV4Staging.Duels.Wall_14
	GGAsset_LobbyWorld_1664 = { ["PiecePath"] = "Wall_15" }, -- Workspace.LobbyV4Staging.Locker.Wall_15
	GGAsset_LobbyWorld_1665 = { ["PiecePath"] = "Wall_16" }, -- Workspace.LobbyV4Staging.Locker.Wall_16
	GGAsset_LobbyWorld_1666 = { ["PiecePath"] = "Wall_17" }, -- Workspace.LobbyV4Staging.Locker.Wall_17
	GGAsset_LobbyWorld_1667 = { ["PiecePath"] = "Wall_18" }, -- Workspace.LobbyV4Staging.Locker.Wall_18
	GGAsset_LobbyWorld_1668 = { ["PiecePath"] = "Wall_19" }, -- Workspace.LobbyV4Staging.Locker.Wall_19
	GGAsset_LobbyWorld_1669 = { ["PiecePath"] = "Wall_2" }, -- Workspace.LobbyV4Staging.Concourse.Wall_2
	GGAsset_LobbyWorld_1670 = { ["PiecePath"] = "Wall_20" }, -- Workspace.LobbyV4Staging.Locker.Wall_20
	GGAsset_LobbyWorld_1671 = { ["PiecePath"] = "Wall_21" }, -- Workspace.LobbyV4Staging.Locker.Wall_21
	GGAsset_LobbyWorld_1672 = { ["PiecePath"] = "Wall_22" }, -- Workspace.LobbyV4Staging.Locker.Wall_22
	GGAsset_LobbyWorld_1673 = { ["PiecePath"] = "Wall_23" }, -- Workspace.LobbyV4Staging.Shop.Wall_23
	GGAsset_LobbyWorld_1674 = { ["PiecePath"] = "Wall_24" }, -- Workspace.LobbyV4Staging.Shop.Wall_24
	GGAsset_LobbyWorld_1675 = { ["PiecePath"] = "Wall_25" }, -- Workspace.LobbyV4Staging.Shop.Wall_25
	GGAsset_LobbyWorld_1676 = { ["PiecePath"] = "Wall_26" }, -- Workspace.LobbyV4Staging.Shop.Wall_26
	GGAsset_LobbyWorld_1677 = { ["PiecePath"] = "Wall_27" }, -- Workspace.LobbyV4Staging.Shop.Wall_27
	GGAsset_LobbyWorld_1678 = { ["PiecePath"] = "Wall_28" }, -- Workspace.LobbyV4Staging.Shop.Wall_28
	GGAsset_LobbyWorld_1679 = { ["PiecePath"] = "Wall_29" }, -- Workspace.LobbyV4Staging.Shop.Wall_29
	GGAsset_LobbyWorld_1680 = { ["PiecePath"] = "Wall_3" }, -- Workspace.LobbyV4Staging.Concourse.Wall_3
	GGAsset_LobbyWorld_1681 = { ["PiecePath"] = "Wall_30" }, -- Workspace.LobbyV4Staging.Shop.Wall_30
	GGAsset_LobbyWorld_1682 = { ["PiecePath"] = "Wall_4" }, -- Workspace.LobbyV4Staging.Concourse.Wall_4
	GGAsset_LobbyWorld_1683 = { ["PiecePath"] = "Wall_5" }, -- Workspace.LobbyV4Staging.Concourse.Wall_5
	GGAsset_LobbyWorld_1684 = { ["PiecePath"] = "Wall_6" }, -- Workspace.LobbyV4Staging.Concourse.Wall_6
	GGAsset_LobbyWorld_1685 = { ["PiecePath"] = "Wall_7" }, -- Workspace.LobbyV4Staging.Concourse.Wall_7
	GGAsset_LobbyWorld_1686 = { ["PiecePath"] = "Wall_8" }, -- Workspace.LobbyV4Staging.Concourse.Wall_8
	GGAsset_LobbyWorld_1687 = { ["PiecePath"] = "Wall_9" }, -- Workspace.LobbyV4Staging.Duels.Wall_9
	GGAsset_LobbyWorld_1689 = { ["SWGun"] = true }, -- Workspace.LobbyV4Staging.Shop.Case_Vault.Bucky
	GGAsset_LobbyWorld_1690 = { ["SWScreen"] = true }, -- Workspace.LobbyV4Staging.Concourse.TV_News.Screen_news
	GGAsset_LobbyWorld_1691 = { ["SpinSpeed"] = -22 }, -- Workspace.Lobby.Hub.Vault.Visual.AnimHolo
	GGAsset_LobbyWorld_1692 = { ["SpinSpeed"] = 16 }, -- Workspace.Lobby.Hub.Market.Visual.AnimFeatured
	GGAsset_LobbyWorld_1693 = { ["SpinSpeed"] = 8 }, -- Workspace.Lobby.Hub.Hub.Visual.AnimGauntlet
	GGAsset_LobbyWorld_1694 = { ["Talk"] = "armorer", ["Title"] = "ARMORER" }, -- Workspace.LobbyV4Staging.NPCs.Armorer
	GGAsset_LobbyWorld_1695 = { ["Trigger"] = "Step" }, -- Workspace.LobbyV4Staging.Anchors.Mark_FeaturedHook
	GGAsset_LobbyWorld_1696 = { ["V3"] = true }, -- Workspace.Lobby.Hub
	GGAsset_LobbyWorld_1697 = { ["V3Mat"] = "Baffle" }, -- Workspace.Lobby.Hub.Range.Visual.Range_Ceil_Baffle
	GGAsset_LobbyWorld_1698 = { ["V3Mat"] = "BayBack" }, -- Workspace.Lobby.Hub.Vault.Visual.Vault_BayBack
	GGAsset_LobbyWorld_1699 = { ["V3Mat"] = "BenchBase" }, -- Workspace.Lobby.Hub.Hub.Visual.PropsHub_BenchBase
	GGAsset_LobbyWorld_1700 = { ["V3Mat"] = "BenchPad" }, -- Workspace.Lobby.Hub.Hub.Visual.PropsHub_BenchPad
	GGAsset_LobbyWorld_1701 = { ["V3Mat"] = "Brass" }, -- Workspace.Lobby.Hub.Hub.Visual.Hub_Brass
	GGAsset_LobbyWorld_1702 = { ["V3Mat"] = "Brushed" }, -- Workspace.Lobby.Hub.Hub.Visual.PropsHub_Brushed
	GGAsset_LobbyWorld_1703 = { ["V3Mat"] = "Cabinet" }, -- Workspace.Lobby.Hub.Vault.Visual.Vault_Cabinet
	GGAsset_LobbyWorld_1704 = { ["V3Mat"] = "CaseDark" }, -- Workspace.Lobby.Hub.Hub.Visual.PropsHub_CaseDark
	GGAsset_LobbyWorld_1705 = { ["V3Mat"] = "CaseOlive" }, -- Workspace.Lobby.Hub.Hub.Visual.PropsHub_CaseOlive
	GGAsset_LobbyWorld_1706 = { ["V3Mat"] = "CaseSand" }, -- Workspace.Lobby.Hub.Hub.Visual.PropsHub_CaseSand
	GGAsset_LobbyWorld_1707 = { ["V3Mat"] = "Concrete" }, -- Workspace.Lobby.Hub.Hub.Visual.Hub_Concrete
	GGAsset_LobbyWorld_1708 = { ["V3Mat"] = "ConcreteCeil" }, -- Workspace.Lobby.Hub.Hub.Visual.Hub_Ceil_ConcreteCeil
	GGAsset_LobbyWorld_1709 = { ["V3Mat"] = "ConcreteDark" }, -- Workspace.Lobby.Hub.Hub.Visual.GateDuels_ConcreteDark
	GGAsset_LobbyWorld_1710 = { ["V3Mat"] = "ConcreteDuels" }, -- Workspace.Lobby.Hub.Duels.Visual.Duels_ConcreteDuels
	GGAsset_LobbyWorld_1711 = { ["V3Mat"] = "ConcreteHub" }, -- Workspace.Lobby.Hub.Hub.Visual.GateDuels_ConcreteHub
	GGAsset_LobbyWorld_1712 = { ["V3Mat"] = "ConcreteLight" }, -- Workspace.Lobby.Hub.Hub.Visual.GateMarket_ConcreteLight
	GGAsset_LobbyWorld_1713 = { ["V3Mat"] = "ConcreteRange" }, -- Workspace.Lobby.Hub.Range.Visual.Range_ConcreteRange
	GGAsset_LobbyWorld_1714 = { ["V3Mat"] = "Crate" }, -- Workspace.Lobby.Hub.Market.Visual.PropsMarket_Crate
	GGAsset_LobbyWorld_1715 = { ["V3Mat"] = "DuelFloor" }, -- Workspace.Lobby.Hub.Duels.Visual.Duels_DuelFloor
	GGAsset_LobbyWorld_1716 = { ["V3Mat"] = "DuelPier" }, -- Workspace.Lobby.Hub.Duels.Visual.PropsDuels_DuelPier
	GGAsset_LobbyWorld_1717 = { ["V3Mat"] = "DuelStage" }, -- Workspace.Lobby.Hub.Duels.Visual.Duels_DuelStage
	GGAsset_LobbyWorld_1718 = { ["V3Mat"] = "DuelUpper" }, -- Workspace.Lobby.Hub.Duels.Visual.Duels_DuelUpper
	GGAsset_LobbyWorld_1719 = { ["V3Mat"] = "E_Cool" }, -- Workspace.Lobby.Hub.Hub.Visual.GateRange_E_Cool
	GGAsset_LobbyWorld_1720 = { ["V3Mat"] = "E_Cove" }, -- Workspace.Lobby.Hub.Hub.Visual.Hub_E_Cove
	GGAsset_LobbyWorld_1721 = { ["V3Mat"] = "E_CoveCool" }, -- Workspace.Lobby.Hub.Vault.Visual.Vault_E_CoveCool
	GGAsset_LobbyWorld_1722 = { ["V3Mat"] = "E_CoveSoft" }, -- Workspace.Lobby.Hub.Market.Visual.Market_E_CoveSoft
	GGAsset_LobbyWorld_1723 = { ["V3Mat"] = "E_Down" }, -- Workspace.Lobby.Hub.Hub.Visual.Hub_Ceil_E_Down
	GGAsset_LobbyWorld_1724 = { ["V3Mat"] = "E_Duels" }, -- Workspace.Lobby.Hub.Hub.Visual.GateDuels_E_Duels
	GGAsset_LobbyWorld_1725 = { ["V3Mat"] = "E_Lantern" }, -- Workspace.Lobby.Hub.Market.Visual.Market_E_Lantern
	GGAsset_LobbyWorld_1726 = { ["V3Mat"] = "E_Lens" }, -- Workspace.Lobby.Hub.Vault.Visual.Vault_E_Lens
	GGAsset_LobbyWorld_1727 = { ["V3Mat"] = "E_PierStrip" }, -- Workspace.Lobby.Hub.Duels.Visual.Duels_E_PierStrip
	GGAsset_LobbyWorld_1728 = { ["V3Mat"] = "E_Range" }, -- Workspace.Lobby.Hub.Hub.Visual.GateRange_E_Range
	GGAsset_LobbyWorld_1729 = { ["V3Mat"] = "E_RangeBar" }, -- Workspace.Lobby.Hub.Range.Visual.Range_Ceil_E_RangeBar
	GGAsset_LobbyWorld_1730 = { ["V3Mat"] = "E_RangeHall" }, -- Workspace.Lobby.Hub.Range.Visual.Range_Ceil_E_RangeHall
	GGAsset_LobbyWorld_1731 = { ["V3Mat"] = "E_Spine" }, -- Workspace.Lobby.Hub.Duels.Visual.Duels_Ceil_E_Spine
	GGAsset_LobbyWorld_1732 = { ["V3Mat"] = "E_Trophy" }, -- Workspace.Lobby.Hub.Hub.Visual.AnimGauntlet.AnimGauntlet_E_Trophy
	GGAsset_LobbyWorld_1733 = { ["V3Mat"] = "E_Vault" }, -- Workspace.Lobby.Hub.Hub.Visual.GateVault_E_Vault
	GGAsset_LobbyWorld_1734 = { ["V3Mat"] = "E_VaultLamp" }, -- Workspace.Lobby.Hub.Vault.Visual.Vault_Ceil_E_VaultLamp
	GGAsset_LobbyWorld_1735 = { ["V3Mat"] = "E_Warm" }, -- Workspace.Lobby.Hub.Hub.Visual.GateDuels_E_Warm
	GGAsset_LobbyWorld_1736 = { ["V3Mat"] = "FloorDark" }, -- Workspace.Lobby.Hub.Hub.Visual.GateDuels_FloorDark
	GGAsset_LobbyWorld_1737 = { ["V3Mat"] = "FloorHub" }, -- Workspace.Lobby.Hub.Hub.Visual.Hub_FloorHub
	GGAsset_LobbyWorld_1738 = { ["V3Mat"] = "FloorPale" }, -- Workspace.Lobby.Hub.Hub.Visual.GateMarket_FloorPale
	GGAsset_LobbyWorld_1739 = { ["V3Mat"] = "FloorWarm" }, -- Workspace.Lobby.Hub.Market.Visual.Market_FloorWarm
	GGAsset_LobbyWorld_1740 = { ["V3Mat"] = "GDark" }, -- Workspace.Lobby.Hub.Hub.Visual.AnimGauntlet.AnimGauntlet_GDark
	GGAsset_LobbyWorld_1741 = { ["V3Mat"] = "GGold" }, -- Workspace.Lobby.Hub.Hub.Visual.AnimGauntlet.AnimGauntlet_GGold
	GGAsset_LobbyWorld_1742 = { ["V3Mat"] = "GSteel" }, -- Workspace.Lobby.Hub.Hub.Visual.AnimGauntlet.AnimGauntlet_GSteel
	GGAsset_LobbyWorld_1743 = { ["V3Mat"] = "Glass" }, -- Workspace.Lobby.Hub.Vault.Visual.Vault_Glass
	GGAsset_LobbyWorld_1744 = { ["V3Mat"] = "Hazard" }, -- Workspace.Lobby.Hub.Hub.Visual.GateDuels_Hazard
	GGAsset_LobbyWorld_1745 = { ["V3Mat"] = "HazardBlack" }, -- Workspace.Lobby.Hub.Hub.Visual.GateRange_HazardBlack
	GGAsset_LobbyWorld_1746 = { ["V3Mat"] = "Holo" }, -- Workspace.Lobby.Hub.Vault.Visual.AnimHolo.AnimHolo_Holo
	GGAsset_LobbyWorld_1747 = { ["V3Mat"] = "HoloGate" }, -- Workspace.Lobby.Hub.Duels.Visual.PropsDuels_Text_HoloGate
	GGAsset_LobbyWorld_1748 = { ["V3Mat"] = "HoloLine" }, -- Workspace.Lobby.Hub.Duels.Visual.PropsDuels_Text_HoloLine_11
	GGAsset_LobbyWorld_1749 = { ["V3Mat"] = "HoloPane" }, -- Workspace.Lobby.Hub.Duels.Visual.Duels_HoloPane
	GGAsset_LobbyWorld_1750 = { ["V3Mat"] = "Leaf" }, -- Workspace.Lobby.Hub.Market.Visual.PropsMarket_Leaf
	GGAsset_LobbyWorld_1751 = { ["V3Mat"] = "N_Duels" }, -- Workspace.Lobby.Hub.Hub.Visual.SignDuels_N_Duels
	GGAsset_LobbyWorld_1752 = { ["V3Mat"] = "N_Market" }, -- Workspace.Lobby.Hub.Hub.Visual.SignMarket_N_Market
	GGAsset_LobbyWorld_1753 = { ["V3Mat"] = "N_Range" }, -- Workspace.Lobby.Hub.Hub.Visual.SignRange_Text_N_Range
	GGAsset_LobbyWorld_1754 = { ["V3Mat"] = "N_TeamA" }, -- Workspace.Lobby.Hub.Duels.Visual.Duels_N_TeamA
	GGAsset_LobbyWorld_1755 = { ["V3Mat"] = "N_TeamB" }, -- Workspace.Lobby.Hub.Duels.Visual.Duels_N_TeamB
	GGAsset_LobbyWorld_1756 = { ["V3Mat"] = "N_Vault" }, -- Workspace.Lobby.Hub.Hub.Visual.SignVault_Text_N_Vault
	GGAsset_LobbyWorld_1757 = { ["V3Mat"] = "Oak" }, -- Workspace.Lobby.Hub.Market.Visual.Market_Oak
	GGAsset_LobbyWorld_1758 = { ["V3Mat"] = "OakApse" }, -- Workspace.Lobby.Hub.Market.Visual.Market_OakApse
	GGAsset_LobbyWorld_1759 = { ["V3Mat"] = "OakDark" }, -- Workspace.Lobby.Hub.Hub.Visual.GateMarket_OakDark
	GGAsset_LobbyWorld_1760 = { ["V3Mat"] = "P_2v2" }, -- Workspace.Lobby.Hub.Market.Visual.PropsMarket_P_2v2
	GGAsset_LobbyWorld_1761 = { ["V3Mat"] = "P_3v3" }, -- Workspace.Lobby.Hub.Market.Visual.PropsMarket_P_3v3
	GGAsset_LobbyWorld_1762 = { ["V3Mat"] = "P_Duels" }, -- Workspace.Lobby.Hub.Hub.Visual.SignDuels_P_Duels
	GGAsset_LobbyWorld_1763 = { ["V3Mat"] = "P_Market" }, -- Workspace.Lobby.Hub.Hub.Visual.SignMarket_P_Market
	GGAsset_LobbyWorld_1764 = { ["V3Mat"] = "P_Range" }, -- Workspace.Lobby.Hub.Hub.Visual.SignRange_P_Range
	GGAsset_LobbyWorld_1765 = { ["V3Mat"] = "P_Vault" }, -- Workspace.Lobby.Hub.Hub.Visual.SignVault_P_Vault
	GGAsset_LobbyWorld_1766 = { ["V3Mat"] = "P_White" }, -- Workspace.Lobby.Hub.Hub.Visual.PropsHub_Text_P_White_2
	GGAsset_LobbyWorld_1767 = { ["V3Mat"] = "PadInk" }, -- Workspace.Lobby.Hub.Duels.Visual.Duels_PadInk
	GGAsset_LobbyWorld_1768 = { ["V3Mat"] = "PadOff" }, -- Workspace.Lobby.Hub.Duels.Visual.Duels_PadOff
	GGAsset_LobbyWorld_1769 = { ["V3Mat"] = "Plaster" }, -- Workspace.Lobby.Hub.Market.Visual.Market_Plaster
	GGAsset_LobbyWorld_1770 = { ["V3Mat"] = "PortalPanel" }, -- Workspace.Lobby.Hub.Duels.Visual.Duels_PortalPanel
	GGAsset_LobbyWorld_1771 = { ["V3Mat"] = "Pot" }, -- Workspace.Lobby.Hub.Market.Visual.PropsMarket_Pot
	GGAsset_LobbyWorld_1772 = { ["V3Mat"] = "Rock" }, -- Workspace.Lobby.Hub.Hub.Visual.Hub_Ceil_Rock
	GGAsset_LobbyWorld_1773 = { ["V3Mat"] = "Rubber" }, -- Workspace.Lobby.Hub.Hub.Visual.GateRange_Rubber
	GGAsset_LobbyWorld_1774 = { ["V3Mat"] = "Sack" }, -- Workspace.Lobby.Hub.Range.Visual.PropsRange_Sack
	GGAsset_LobbyWorld_1775 = { ["V3Mat"] = "Screen" }, -- Workspace.Lobby.Hub.Hub.Visual.Hub_Screen
	GGAsset_LobbyWorld_1776 = { ["V3Mat"] = "Seam" }, -- Workspace.Lobby.Hub.Hub.Visual.Hub_Seam
	GGAsset_LobbyWorld_1777 = { ["V3Mat"] = "SignCream" }, -- Workspace.Lobby.Hub.Market.Visual.PropsMarket_Text_SignCream
	GGAsset_LobbyWorld_1778 = { ["V3Mat"] = "SignFace" }, -- Workspace.Lobby.Hub.Hub.Visual.SignVault_Text_SignFace
	GGAsset_LobbyWorld_1779 = { ["V3Mat"] = "SignPlate" }, -- Workspace.Lobby.Hub.Hub.Visual.SignVault_SignPlate
	GGAsset_LobbyWorld_1780 = { ["V3Mat"] = "Steel" }, -- Workspace.Lobby.Hub.Hub.Visual.GateDuels_Steel
	GGAsset_LobbyWorld_1781 = { ["V3Mat"] = "SteelBlue" }, -- Workspace.Lobby.Hub.Hub.Visual.Hub_SteelBlue_2
	GGAsset_LobbyWorld_1782 = { ["V3Mat"] = "SunStone" }, -- Workspace.Lobby.Hub.Hub.Visual.Hub_SunStone
	GGAsset_LobbyWorld_1783 = { ["V3Mat"] = "Target" }, -- Workspace.Lobby.Hub.Range.Visual.PropsRange_Target
	GGAsset_LobbyWorld_1784 = { ["V3Mat"] = "VaultFloor" }, -- Workspace.Lobby.Hub.Vault.Visual.Vault_VaultFloor
	GGAsset_LobbyWorld_1785 = { ["V3Mat"] = "VaultPanel" }, -- Workspace.Lobby.Hub.Vault.Visual.Vault_VaultPanel
	GGAsset_LobbyWorld_1786 = { ["V3Mat"] = "VaultPier" }, -- Workspace.Lobby.Hub.Vault.Visual.Vault_VaultPier
}
