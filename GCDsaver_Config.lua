LibConfig = LibStub("LibConfig")

GCDsaver_Config = {}

local GUI

function GCDsaver_Config.Slash(input)
	if (not GUI) then
		-- parameters: title text, settings table, callback-function
		-- note that you need to have a settings table!
		GUI = LibConfig("GCDsaver v" .. tostring(GCDsaver.Settings.Version), GCDsaver.Settings, true, GCDsaver_Config.SettingsChanged)
		
		GUI:AddTab("Info")
		local infoText
		infoText = GUI("label", "GCDsaver can set a check for abilities that will be ineffective if the target is immune or when the target")
		infoText.label:Font("font_default_text_small")
		infoText.label:Align("left")

		infoText = GUI("label", "has enough stacks from you of the ability's effect. The check will be indicated with these symbols:")
		infoText.label:Font("font_default_text_small")
		infoText.label:Align("left")

		infoText = GUI("label", "1x - One stack")
		infoText.label:Font("font_default_text_small")
		infoText.label:Align("left")

		infoText = GUI("label", "2x - Two stacks")
		infoText.label:Font("font_default_text_small")
		infoText.label:Align("left")

		infoText = GUI("label", "3x - Three stacks")
		infoText.label:Font("font_default_text_small")
		infoText.label:Align("left")

		infoText = GUI("label", "<icon05007> - Immovable")
		infoText.label:Font("font_default_text_small")
		infoText.label:Align("left")

		infoText = GUI("label", "<icon05006> - Unstoppable")
		infoText.label:Font("font_default_text_small")
		infoText.label:Align("left")

		infoText = GUI("label", "When the ability's check is triggered the ability will be disabled (greyed out) on the hotbar.")
		infoText.label:Font("font_default_text_small")
		infoText.label:Align("left")


		infoText = GUI("label", "To toggle the check on an ability SHIFT-LEFT CLICK the ability on your hotbar.")
		infoText.label:Font("font_default_text_small")
		infoText.label:Align("left")

		infoText = GUI("label", "By default targeted abilities that Knock-down, Punt, Stagger, Silence or Disarm are configured accordingly.")
		infoText.label:Font("font_default_text_small")
		infoText.label:Align("left")


		GUI:AddTab("Settings")
		GUI("checkbox", "Enabled", "Enabled")
		GUI("checkbox", "Show Symbols", "Symbols")
		GUI("checkbox", "Show Combat Error messages", "ErrorMessages")

	end
	GUI:Show()
end

function GCDsaver_Config.SettingsChanged()
	GUI:Hide()
	GCDsaver.UpdateSettings()
end