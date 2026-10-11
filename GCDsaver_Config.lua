LibConfig = LibStub("LibConfig")

GCDsaver_Config = {}

local GUI

-- LibConfig packs every control into a 40px row. Wrapped Info text therefore
-- draws over the Save/Cancel/Revert bar. Re-anchor Info labels with real heights.
local function addInfoLine(text, height)
	local element = GUI("label", text)
	element._infoHeight = height
	element.label:Font("font_default_text_small")
	element.label:Align("left")
	element.label:WordWrap(true)
	return element
end

local function layoutInfoTab()
	local layer = GUI.layers[1]
	if not layer or not layer.pages or not layer.pages[1] then return end
	local y = 0
	for _, element in ipairs(layer.pages[1].elements) do
		local height = element._infoHeight or 40
		element:Resize(layer.width, height)
		if element.label then
			element.label:Resize(layer.width, height)
		end
		element:ClearAnchors()
		element:AnchorTo(layer, "topleft", "topleft", 0, y)
		y = y + height
	end
end

function GCDsaver_Config.Slash(input)
	if (not GUI) then
		-- parameters: title text, settings table, callback-function
		-- note that you need to have a settings table!
		GUI = LibConfig("GCDsaver v" .. tostring(GCDsaver.Settings.Version), GCDsaver.Settings, true, GCDsaver_Config.SettingsChanged)
		
		GUI:AddTab("Info")
		addInfoLine("GCDsaver can set a check for abilities that will be ineffective if the target is immune, or when the target already has enough stacks of the ability's effect from you.", 56)
		addInfoLine("The check is shown on the hotbar with these symbols:", 28)
		addInfoLine("1x - One stack", 24)
		addInfoLine("2x - Two stacks", 24)
		addInfoLine("3x - Three stacks", 24)
		addInfoLine("<icon05007> - Immovable", 24)
		addInfoLine("<icon05006> - Unstoppable", 24)
		addInfoLine("When the check triggers, the ability is greyed out on the hotbar.", 32)
		addInfoLine("SHIFT-LEFT CLICK an ability on your hotbar to cycle its check.", 32)
		addInfoLine("By default, targeted Knock-down, Punt, Stagger, Silence and Disarm abilities are configured.", 48)
		layoutInfoTab()

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
