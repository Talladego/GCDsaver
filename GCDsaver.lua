local VERSION = 1.08
local TIME_DELAY = 0.1
local timeLeft = TIME_DELAY
local MAX_STACK = 3
local IMMOVABLE = 4
local UNSTOPPABLE = 5
local MAX_BUTTONS = 60
local eventsRegistered = false
local loadingEnd = false

-- Localized functions
local pairs = pairs
local tostring = tostring
local towstring = towstring
local GetBuffs = GetBuffs
local GetHotbarCooldown = GetHotbarCooldown
local GetAbilityData = GetAbilityData
local GetHotbarData = GetHotbarData
local BroadcastEvent = BroadcastEvent
local TextLogAddEntry = TextLogAddEntry
local RegisterEventHandler = RegisterEventHandler
local UnregisterEventHandler = UnregisterEventHandler

-- Local functions
local function hasFriendlyTarget()
	local target = TargetInfo.m_Units[TargetInfo.FRIENDLY_TARGET]
	if target and target.entityid ~= 0 then
		return true
	end
	return false
end

local function hasHostileTarget()
	local target = TargetInfo.m_Units[TargetInfo.HOSTILE_TARGET]
	if target and target.entityid ~= 0 then
		return true
	end
	return false
end

-- Returns true if the given buff (identified by ability icon and castByPlayer)
-- is present on the target, optionally requiring at least a certain stack count.
-- NOTE: This uses live buff data from the engine, not our *_TargetEffects tables.
local function hasBuff(target, abilityData, stackCount)
	if not target then
		return false
	end
	local buffData = GetBuffs(target)
	if not buffData then
		return false
	end

	for _, buff in pairs(buffData) do
		if buff.iconNum == abilityData.iconNum and buff.castByPlayer then
			-- If a specific stack count is configured, treat "at least" that many stacks as satisfied
			if not stackCount or stackCount == 0 or buff.stackCount >= stackCount then
				return true
			end
		end
	end
	return false
end

-- Maps an ability's targetType (0/1/2) to the appropriate buff list constant.
-- Returns nil for offensive abilities with no hostile target to avoid reading
-- stale/incorrect buffs from the engine in that edge case.
local function getTargetType(targetType)
	if targetType == 0 then
		return GameData.BuffTargetType.SELF
	elseif targetType == 1 and hasHostileTarget() then
		return GameData.BuffTargetType.TARGET_HOSTILE
	elseif targetType == 1 then
		return nil -- Ugly workaround to correct for incorrect buffs when no hostile target
	elseif targetType == 2 and hasFriendlyTarget() then
		return GameData.BuffTargetType.TARGET_FRIENDLY
	elseif targetType == 2 then
		return GameData.BuffTargetType.SELF
	else
		return GameData.BuffTargetType.SELF
	end
end

-- Convenience wrapper for firing a combat-style floating error message,
-- obeying the user's global combat message settings.
local function alertText(text)
	if SettingsWindowTabInterface.SavedMessageSettings.combat then
		SystemData.AlertText.VecType = {SystemData.AlertText.Types.COMBAT}
		SystemData.AlertText.VecText = {towstring(text)}
		BroadcastEvent(SystemData.Events.SHOW_ALERT_TEXT)
	end
end

-- Simple in-session cache for ability data, to avoid repeated GetAbilityData
-- calls from hot paths like click handling and enabled-state updates.
local abilityDataCache = {}
local function getAbilityDataCached(actionId)
	if not actionId or actionId == 0 then return nil end
	local data = abilityDataCache[actionId]
	if not data then
		data = GetAbilityData(actionId)
		abilityDataCache[actionId] = data
	end
	return data
end

-- Refresh icons and enabled state for all hotbar slots
-- that contain the given abilityId. Used when the user
-- shift-clicks to (re)configure an ability so all copies
-- stay visually in sync.
local function RefreshAllSlotsForAbility(actionId)
	if not actionId or actionId == 0 then return end
	for slot = 1, MAX_BUTTONS do
		local actionType, slotActionId = GetHotbarData(slot)
		if slotActionId == actionId then
			local check = GCDsaver.Settings.Abilities[actionId]
			if check then
				GCDsaver.ConfiguredSlots[slot] = true
			else
				GCDsaver.ConfiguredSlots[slot] = nil
			end
			GCDsaver.UpdateButtonIcon(slot, check)
			GCDsaver.UpdateButtonEnabledState(slot)
		end
	end
end

local function chatInfo(actionId, state)
	local abilityData = getAbilityDataCached(actionId)
	if not abilityData then return end
	local name = tostring(abilityData.name)
	local icon = "<icon".. tostring(abilityData.iconNum) .. ">"
	if not state then
		TextLogAddEntry("Chat", 0, towstring("GCDsaver: Clearing check for " .. icon .. " " .. name))
	elseif state >= 1 and state <= 3 then
		TextLogAddEntry("Chat", 0, towstring("GCDsaver: Setting (" .. state ..  "x) Stack check for " .. icon .. " " .. name))
	elseif state == IMMOVABLE then
		TextLogAddEntry("Chat", 0, towstring("GCDsaver: Setting <icon05007> Immovable check for " .. icon .. " " .. name))
	elseif state == UNSTOPPABLE then
		TextLogAddEntry("Chat", 0, towstring("GCDsaver: Setting <icon05006> Unstoppable check for " .. icon .. " " .. name))
	end
end

local function isAbilityBlocked(actionId)
	if GCDsaver.Settings.Enabled then
		local abilityData = getAbilityDataCached(actionId)
		if not abilityData then
			return false
		end
		
		if GCDsaver.TargetImmovable and GCDsaver.Settings.Abilities[actionId] and GCDsaver.Settings.Abilities[actionId] == IMMOVABLE then
			if GCDsaver.Settings.ErrorMessages then alertText("Target is Immovable") end
			return true
		elseif GCDsaver.TargetUnstoppable and GCDsaver.Settings.Abilities[actionId] and GCDsaver.Settings.Abilities[actionId] == UNSTOPPABLE then
			if GCDsaver.Settings.ErrorMessages then alertText("Target is Unstoppable") end
			return true
		elseif GCDsaver.Settings.Abilities[actionId] and hasBuff(getTargetType(abilityData.targetType), abilityData, GCDsaver.Settings.Abilities[actionId]) then
			if GCDsaver.Settings.ErrorMessages then
				local stacks = GCDsaver.Settings.Abilities[actionId]
				if stacks and stacks >= 1 and stacks <= MAX_STACK then
					alertText("Target already has " .. tostring(stacks) .. " stack" .. (stacks > 1 and "s" or "") .. " of that effect")
				else
					alertText("Target already has that effect")
				end
			end
			return true
		else
			return false
		end
	else
		return false
	end

end

local orgWindowGameAction = WindowGameAction
-- No-op stand-in for WindowGameAction used while we want to prevent the
-- engine from executing the underlying game action for a click.
local function blockedWindowGameAction(windowName)
end

-- GCDsaver
GCDsaver = GCDsaver or {}
GCDsaver.FriendlyTargetId = 0
GCDsaver.HostileTargetId = 0
GCDsaver.TargetImmovable = false
GCDsaver.TargetUnstoppable = false
GCDsaver.SelfTargetEffects = {}
GCDsaver.FriendlyTargetEffects = {}
GCDsaver.HostileTargetEffects = {}
GCDsaver.EnabledStatesNeedUpdate = true -- Throttle calls to GCDsaver.UpdateButtonsEnabledStates()
GCDsaver.ButtonIconsNeedUpdate = true -- Throttle calls to GCDsaver.UpdateButtonIcons()
GCDsaver.ConfiguredSlots = {}

GCDsaver.DefaultSettings = {
	Version = VERSION,
	Enabled = true,
	Symbols = true,
	ErrorMessages = true,
	Abilities = {
		-- Ironbreaker
		[1384] = UNSTOPPABLE,	-- Cave-In
		[1369] = UNSTOPPABLE,	-- Shield of Reprisal
		[1365] = IMMOVABLE,		-- Away With Ye
		-- Slayer
		[1443] = UNSTOPPABLE,	-- Incapacitate
		-- Runepriest
		[1613] = UNSTOPPABLE,	-- Rune of Binding
		[1607] = UNSTOPPABLE,	-- Spellbinding Rune
		-- Engineer
		[1536] = UNSTOPPABLE,	-- Crack Shot
		[1531] = IMMOVABLE,		-- Concussion Grenade
		-- Black Orc
		[1688] = UNSTOPPABLE,	-- Down Ya Go
		[1683] = UNSTOPPABLE,	-- Shut Yer Face
		[1686] = IMMOVABLE,	-- Git Out
		-- Choppa
		[1755] = UNSTOPPABLE,	-- Sit Down!
		-- Shaman
		[1929] = IMMOVABLE,		-- Geddoff!
		[1917] = UNSTOPPABLE,	-- You Got Nuthin!
		-- Squig Herder
		[1839] = UNSTOPPABLE,	-- Choking Arrer
		[1837] = UNSTOPPABLE,	-- Drop That!!
		--[1835] = UNSTOPPABLE,	-- Not So Fast!
		-- Witch Hunter
		[8110] = UNSTOPPABLE,	-- Dragon Gun
		[8086] = UNSTOPPABLE,	-- Confess!
		[8115] = UNSTOPPABLE,	-- Pistol Whip
		[8100] = UNSTOPPABLE,	-- Silence The Heretic
		--[8094] = UNSTOPPABLE,	-- Declare Anathema
		-- Knight of the Blazing Sun
		[8018] = UNSTOPPABLE,	-- Smashing Counter
		[8017] = IMMOVABLE,		-- Repel Darkness
		-- Bright Wizard
		[8186] = UNSTOPPABLE,	-- Stop, Drop, and Roll
		[8174] = UNSTOPPABLE,	-- Choking Smoke
		-- Warrior Priest
		[8256] = UNSTOPPABLE,	-- Vow of Silence
		-- Chosen
		[8346] = UNSTOPPABLE,	-- Downfall
		[8329] = IMMOVABLE,		-- Repel
		-- Marauder
		[8412] = UNSTOPPABLE,	-- Mutated Energy
		[8405] = UNSTOPPABLE,	-- Death Grip
		[8410] = IMMOVABLE,		-- Terrible Embrace
		-- Zealot
		[8571] = UNSTOPPABLE,	-- Aethyric Shock
		[8565] = UNSTOPPABLE,	-- Tzeentch's Lash
		-- Magus
		[8495] = UNSTOPPABLE,	-- Perils of The Warp
		[8483] = IMMOVABLE,		-- Warping Blast
		-- Swordmaster
		--[9032] = IMMOVABLE,		-- Redirected Force
		[9024] = IMMOVABLE,		-- Mighty Gale
		[9028] = UNSTOPPABLE,	-- Chrashing Wave
		-- Shadow Warrior
		--[9096] = UNSTOPPABLE,	-- Eye Shot
		[9108] = UNSTOPPABLE,	-- Exploit Weakness
		[9098] = UNSTOPPABLE,	-- Opportunistic Strike
		-- White Lion
		[9193] = UNSTOPPABLE,	-- Brutal Pounce
		[9177] = UNSTOPPABLE,	-- Throat Bite
		[9178] = IMMOVABLE,		-- Fetch!
		-- Archmage
		[9266] = IMMOVABLE,		-- Cleansing Flare
		[9253] = UNSTOPPABLE,	-- Law of Gold
		-- Blackguard
		[2888] = UNSTOPPABLE,	-- Malignant Strike!
		[9321] = UNSTOPPABLE,	-- Spiteful Slam
		[9328] = IMMOVABLE,		-- Exile
		-- Witch Elf
		[9422] = UNSTOPPABLE,	-- On Your Knees!
		[9400] = UNSTOPPABLE,	-- Sever Limb
		[9427] = UNSTOPPABLE,	-- Heart Seeker
		[9409] = UNSTOPPABLE,	-- Throat Slitter
		--[9396] = UNSTOPPABLE,	-- Agile Escape
		-- Disciple of Khaine
		[9565] = UNSTOPPABLE,	-- Consume Thought
		-- Sorcerer
		[9482] = UNSTOPPABLE,	-- Frostbite
		[9489] = UNSTOPPABLE,	-- Stricken Voices
	},
}


function GCDsaver.Initialize()
	-- Fresh install: deep-copy defaults so we don't share tables
	if not GCDsaver.Settings or type(GCDsaver.Settings) ~= "table" then
		GCDsaver.Settings = DataUtils.CopyTable(GCDsaver.DefaultSettings)
	else
		-- Upgrade existing settings: keep user values, ensure new keys exist
		if type(GCDsaver.Settings.Abilities) ~= "table" then
			GCDsaver.Settings.Abilities = DataUtils.CopyTable(GCDsaver.DefaultSettings.Abilities)
		end
		GCDsaver.Settings.Version = VERSION
	end
	
	LibSlash.RegisterSlashCmd("gcdsaver", function(input) GCDsaver_Config.Slash(input) end)
	
	if GCDsaver.Settings.Enabled then GCDsaver.RegisterEvents()	end
	
	TextLogAddEntry("Chat", 0, towstring("<icon57> GCDsaver loaded. Type /gcdsaver for settings."))
end

function GCDsaver.OnShutdown()
	GCDsaver.UnregisterEvents()
end

function GCDsaver.RegisterEvents()
	if not eventsRegistered then
		RegisterEventHandler(SystemData.Events.ENTER_WORLD, "GCDsaver.ENTER_WORLD")
		RegisterEventHandler(SystemData.Events.PLAYER_ZONE_CHANGED, "GCDsaver.PLAYER_ZONE_CHANGED")
		RegisterEventHandler(SystemData.Events.INTERFACE_RELOADED, "GCDsaver.INTERFACE_RELOADED")
		RegisterEventHandler(SystemData.Events.PLAYER_TARGET_UPDATED, "GCDsaver.PLAYER_TARGET_UPDATED")
		RegisterEventHandler(SystemData.Events.PLAYER_TARGET_IS_IMMUNE_TO_MOVEMENT_IMPARING, "GCDsaver.PLAYER_TARGET_IS_IMMUNE_TO_MOVEMENT_IMPARING")
		RegisterEventHandler(SystemData.Events.PLAYER_TARGET_IS_IMMUNE_TO_DISABLES, "GCDsaver.PLAYER_TARGET_IS_IMMUNE_TO_DISABLES")
		RegisterEventHandler(SystemData.Events.PLAYER_EFFECTS_UPDATED, "GCDsaver.PLAYER_EFFECTS_UPDATED")
		RegisterEventHandler(SystemData.Events.PLAYER_TARGET_EFFECTS_UPDATED, "GCDsaver.PLAYER_TARGET_EFFECTS_UPDATED")
		RegisterEventHandler(SystemData.Events.PLAYER_HOT_BAR_UPDATED, "GCDsaver.PLAYER_HOT_BAR_UPDATED")
	end
	eventsRegistered = true
end

function GCDsaver.UnregisterEvents()
	if eventsRegistered then
		UnregisterEventHandler(SystemData.Events.ENTER_WORLD, "GCDsaver.ENTER_WORLD")
		UnregisterEventHandler(SystemData.Events.PLAYER_ZONE_CHANGED, "GCDsaver.PLAYER_ZONE_CHANGED")
		UnregisterEventHandler(SystemData.Events.INTERFACE_RELOADED, "GCDsaver.INTERFACE_RELOADED")
		UnregisterEventHandler(SystemData.Events.PLAYER_TARGET_UPDATED, "GCDsaver.PLAYER_TARGET_UPDATED")
		UnregisterEventHandler(SystemData.Events.PLAYER_TARGET_IS_IMMUNE_TO_MOVEMENT_IMPARING, "GCDsaver.PLAYER_TARGET_IS_IMMUNE_TO_MOVEMENT_IMPARING")
		UnregisterEventHandler(SystemData.Events.PLAYER_TARGET_IS_IMMUNE_TO_DISABLES, "GCDsaver.PLAYER_TARGET_IS_IMMUNE_TO_DISABLES")
		UnregisterEventHandler(SystemData.Events.PLAYER_EFFECTS_UPDATED, "GCDsaver.PLAYER_EFFECTS_UPDATED")
		UnregisterEventHandler(SystemData.Events.PLAYER_TARGET_EFFECTS_UPDATED, "GCDsaver.PLAYER_TARGET_EFFECTS_UPDATED")
		UnregisterEventHandler(SystemData.Events.PLAYER_HOT_BAR_UPDATED, "GCDsaver.PLAYER_HOT_BAR_UPDATED")
	end
	eventsRegistered = false
end

-- Event handlers
function GCDsaver.ENTER_WORLD()
	loadingEnd = true
	GCDsaver.ButtonIconsNeedUpdate = true
end

function GCDsaver.PLAYER_ZONE_CHANGED()
	loadingEnd = true
	GCDsaver.ButtonIconsNeedUpdate = true
end

function GCDsaver.INTERFACE_RELOADED()
	loadingEnd = true
	GCDsaver.ButtonIconsNeedUpdate = true
end

function GCDsaver.PLAYER_TARGET_UPDATED(targetClassification, targetId, targetType)
	-- Ignore mouseover target changes
	if targetClassification == TargetInfo.FRIENDLY_TARGET and GCDsaver.FriendlyTargetId ~= targetId then
		GCDsaver.FriendlyTargetId = targetId
		GCDsaver.FriendlyTargetEffects = {}
		GCDsaver.TargetImmovable = false
		GCDsaver.TargetUnstoppable = false
		GCDsaver.EnabledStatesNeedUpdate = true
	elseif targetClassification == TargetInfo.HOSTILE_TARGET and GCDsaver.HostileTargetId ~= targetId then
		GCDsaver.HostileTargetId = targetId
		GCDsaver.HostileTargetEffects = {}
		GCDsaver.TargetImmovable = false
		GCDsaver.TargetUnstoppable = false
		GCDsaver.EnabledStatesNeedUpdate = true
	end
end

function GCDsaver.PLAYER_TARGET_IS_IMMUNE_TO_DISABLES(state)
	GCDsaver.TargetUnstoppable = state
	GCDsaver.EnabledStatesNeedUpdate = true
end

function GCDsaver.PLAYER_TARGET_IS_IMMUNE_TO_MOVEMENT_IMPARING(state)
	GCDsaver.TargetImmovable = state
	GCDsaver.EnabledStatesNeedUpdate = true
end

function GCDsaver.PLAYER_EFFECTS_UPDATED(updatedEffects, isFullList)
	if not updatedEffects then return end
	for k, v in pairs(updatedEffects) do
		if v.castByPlayer then
			GCDsaver.SelfTargetEffects[k] = v.abilityId
			GCDsaver.EnabledStatesNeedUpdate = true
		elseif GCDsaver.SelfTargetEffects[k] then
			GCDsaver.SelfTargetEffects[k] = nil
			GCDsaver.EnabledStatesNeedUpdate = true
		end
	end
end

function GCDsaver.PLAYER_TARGET_EFFECTS_UPDATED(updateType, updatedEffects, isFullList)
	if not updatedEffects then return end
	for k, v in pairs(updatedEffects) do
		if updateType == GameData.BuffTargetType.TARGET_HOSTILE then
			-- Effect cast by player applied on hostile target
			if v.castByPlayer then
				GCDsaver.HostileTargetEffects[k] = v.abilityId
				GCDsaver.EnabledStatesNeedUpdate = true
			-- Effect cast by player removed from hostile target
			elseif GCDsaver.HostileTargetEffects[k] then
				GCDsaver.HostileTargetEffects[k] = nil
				GCDsaver.EnabledStatesNeedUpdate = true
			end
		elseif updateType == GameData.BuffTargetType.TARGET_FRIENDLY then
			-- Effect cast by player applied on friendly target
			if v.castByPlayer then
				GCDsaver.FriendlyTargetEffects[k] = v.abilityId
				GCDsaver.EnabledStatesNeedUpdate = true
			-- Effect cast by player removed from friendly target
			elseif GCDsaver.FriendlyTargetEffects[k] then
				GCDsaver.FriendlyTargetEffects[k] = nil
				GCDsaver.EnabledStatesNeedUpdate = true
			end
		end
	end
end

function GCDsaver.PLAYER_HOT_BAR_UPDATED(slot, actionType, actionId)
	local check = GCDsaver.Settings.Abilities[actionId]
	if check then
		GCDsaver.ConfiguredSlots[slot] = true
	else
		GCDsaver.ConfiguredSlots[slot] = nil
	end
	GCDsaver.UpdateButtonIcon(slot, check)
	GCDsaver.UpdateButtonEnabledState(slot)
end

-- Main update function
-- Periodic, throttled update driving icon overlays and enabled-state refreshes.
-- Only touches slots that are known to be configured to keep costs low.
function GCDsaver.OnUpdate(elapsed)
	if not loadingEnd then return end
	if not GCDsaver.Settings.Enabled then return end
	
	timeLeft = timeLeft - elapsed
    if timeLeft > 0 then
        return
    end
    timeLeft = TIME_DELAY
	
	if GCDsaver.ButtonIconsNeedUpdate then
		GCDsaver.UpdateButtonIcons()
		GCDsaver.ButtonIconsNeedUpdate = false
	end
	
	if GCDsaver.EnabledStatesNeedUpdate then
		GCDsaver.UpdateButtonsEnabledStates()
		GCDsaver.EnabledStatesNeedUpdate = false
	end
end

function GCDsaver.UpdateSettings()
	if GCDsaver.Settings.Enabled and not eventsRegistered then
		GCDsaver.RegisterEvents()
	elseif not GCDsaver.Settings.Enabled and eventsRegistered then
		GCDsaver.UnregisterEvents()
	end
	
	GCDsaver.UpdateButtonIcons()

	TextLogAddEntry("Chat", 0, towstring("GCDsaver v" .. tostring(GCDsaver.Settings.Version) .. " settings: /gcdsaver"))
	if GCDsaver.Settings.Enabled then
		TextLogAddEntry("Chat", 0, L"--- <icon57> Enabled")
	else
		TextLogAddEntry("Chat", 0, L"--- <icon58> Enabled")
	end
	if GCDsaver.Settings.Symbols then
		TextLogAddEntry("Chat", 0, L"--- <icon57> Show Symbols")
	else
		TextLogAddEntry("Chat", 0, L"--- <icon58> Show Symbols")
	end
	if GCDsaver.Settings.ErrorMessages then
		TextLogAddEntry("Chat", 0, L"--- <icon57> Show Combat Error Messages")
	else
		TextLogAddEntry("Chat", 0, L"--- <icon58> Show Combat Error Messages")
	end
end

-- Walks all currently configured slots and ensures their overlay icon/text
-- matches both the global addon settings and the per-ability check type.
function GCDsaver.UpdateButtonIcons()
	local actionType, actionId, isSlotEnabled, isTargetValid, isSlotBlocked
	for slot in pairs(GCDsaver.ConfiguredSlots) do
		actionType, actionId, isSlotEnabled, isTargetValid, isSlotBlocked = GetHotbarData(slot)
		local check = GCDsaver.Settings.Abilities[actionId]
		if GCDsaver.Settings.Enabled and GCDsaver.Settings.Symbols and check then
			GCDsaver.UpdateButtonIcon(slot, check)
		elseif (not GCDsaver.Settings.Enabled or not GCDsaver.Settings.Symbols) and check then
			GCDsaver.UpdateButtonIcon(slot, 0)
		else
			GCDsaver.ConfiguredSlots[slot] = nil
			GCDsaver.UpdateButtonIcon(slot, 0)
		end
	end
end

-- Apply or clear the small overlay in button window[7] used to visualize
-- GCDsaver's checks (stack count or Immovable/Unstoppable icons).
function GCDsaver.UpdateButtonIcon(slot, check)
	local hbar, buttonid, button
	local buttonActionId
	hbar, buttonid = ActionBars:BarAndButtonIdFromSlot(slot)
	if hbar and buttonid then
		button = hbar.m_Buttons[buttonid]
		if not check then
			--button.m_Windows[7]:Show(false)
		elseif check == IMMOVABLE then
			button.m_Windows[7]:Show(true)
			button.m_Windows[7]:SetText("<icon05007>")
		elseif check == UNSTOPPABLE then
			button.m_Windows[7]:Show(true)
			button.m_Windows[7]:SetText("<icon05006>")
		elseif check >= 1 and check <= 3 then
			button.m_Windows[7]:Show(true)
			button.m_Windows[7]:SetFont("font_default_war_heading", WindowUtils.FONT_DEFAULT_TEXT_LINESPACING)
			button.m_Windows[7]:SetTextColor(255, 255, 0)
			button.m_Windows[7]:SetText(tostring(check).."x")
		elseif check == 0 then
			button.m_Windows[7]:Show(false)
		end
	end
end

-- Re-evaluates enabled/disabled state for all configured hotbar slots.
-- The actual greying logic lives in our ActionBars.UpdateSlotEnabledState hook.
function GCDsaver.UpdateButtonsEnabledStates()
	for slot in pairs(GCDsaver.ConfiguredSlots) do
		GCDsaver.UpdateButtonEnabledState(slot)
	end
end

-- Sync a single slot's enabled-state with the engine, and ensure we stop
-- managing it once its ability no longer has a GCDsaver check configured.
function GCDsaver.UpdateButtonEnabledState(slot)
	local actionType, actionId, isSlotEnabled, isTargetValid, isSlotBlocked = GetHotbarData(slot)
	local check = GCDsaver.Settings.Abilities[actionId]
	if check then
		GCDsaver.ConfiguredSlots[slot] = true
		ActionBars.UpdateSlotEnabledState(slot, isSlotEnabled, isTargetValid, isSlotBlocked)
	else
		-- This slot is no longer managed by GCDsaver:
		-- 1) Forget it from our configured set so we stop overriding state
		-- 2) Send one last enabled-state update using the engine's current flags
		-- 3) Ask the default UI to fully refresh the button from engine data
		GCDsaver.ConfiguredSlots[slot] = nil
		if actionType and actionType ~= 0 then
			-- Reapply the current engine view of enabled/target/blocked through
			-- the normal UpdateSlotEnabledState chain (including our hook), so
			-- any previous GCDsaver-forced disabled state is cleared.
			ActionBars.UpdateSlotEnabledState(slot, isSlotEnabled, isTargetValid, isSlotBlocked)
			-- Then fully rebuild the button from hotbar data.
			ActionBars.UpdateActionButtons(slot, actionType, actionId)
		end
	end
end

-- Hooked Functions

-- Wraps the default click handler to support shift-click configuration
-- and to optionally block actions by no-oping WindowGameAction
local orgActionButtonOnLButtonDown = ActionButton.OnLButtonDown

function ActionButton.OnLButtonDown(self, flags, x, y)
	-- Shift-click: configure GCDsaver behavior but do not fire the ability
	if flags == SystemData.ButtonFlags.SHIFT and self.m_ActionId ~= 0 then
		if not GCDsaver.Settings.Abilities[self.m_ActionId] then
			GCDsaver.Settings.Abilities[self.m_ActionId] = 1
		elseif GCDsaver.Settings.Abilities[self.m_ActionId] < 5 then
			GCDsaver.Settings.Abilities[self.m_ActionId] = GCDsaver.Settings.Abilities[self.m_ActionId] + 1
		else
			GCDsaver.Settings.Abilities[self.m_ActionId] = nil
		end

		GCDsaver.UpdateButtonIcon(self.m_HotBarSlot, GCDsaver.Settings.Abilities[self.m_ActionId] or 0)
		GCDsaver.UpdateButtonEnabledState(self.m_HotBarSlot)
		chatInfo(self.m_ActionId, GCDsaver.Settings.Abilities[self.m_ActionId])
		-- Ensure all hotbar copies of this ability reflect the new config
		RefreshAllSlotsForAbility(self.m_ActionId)
		-- Ensure this click only configures and never fires
		WindowGameAction = blockedWindowGameAction
		return
	end

	-- Block firing when GCDsaver says the ability should be blocked.
	if self.m_ActionId ~= 0
		and GCDsaver.Settings.Abilities[self.m_ActionId]
		and isAbilityBlocked(self.m_ActionId) then
		WindowGameAction = blockedWindowGameAction
	else
		WindowGameAction = orgWindowGameAction
	end

	-- Call original OnLButtonDown last so other logic still runs
	if orgActionButtonOnLButtonDown then
		orgActionButtonOnLButtonDown(self, flags, x, y)
	end
end

-- Extends the default enabled/disabled logic to gray out
-- configured abilities when the target is immune or already affected
local orgActionBarsUpdateSlotEnabledState = ActionBars.UpdateSlotEnabledState
function ActionBars.UpdateSlotEnabledState(slot, isSlotEnabled, isTargetValid, isSlotBlocked)
	local hbar, buttonid = ActionBars:BarAndButtonIdFromSlot(slot)
	if hbar and buttonid then
		local button = hbar.m_Buttons[buttonid]
		local check = GCDsaver.Settings.Abilities[button.m_ActionId]
		if check then
			local abilityData = getAbilityDataCached(button.m_ActionId)
			if abilityData then
				if check == IMMOVABLE and GCDsaver.TargetImmovable then
					isSlotEnabled = false
				elseif check == UNSTOPPABLE and GCDsaver.TargetUnstoppable then
					isSlotEnabled = false
				elseif check >= 1 and check <= 3 and hasBuff(getTargetType(abilityData.targetType), abilityData, check) then
					isSlotEnabled = false
				end
			end
		end
	end
	orgActionBarsUpdateSlotEnabledState(slot, isSlotEnabled, isTargetValid, isSlotBlocked)
end

-- Suppresses the default item stack-count text on configured
-- actions so the GCDsaver overlay can use the same label
local orgActionButtonUpdateInventory = ActionButton.UpdateInventory
function ActionButton.UpdateInventory(self)
	if not GCDsaver.Settings.Abilities[self.m_ActionId] then
		orgActionButtonUpdateInventory(self)
	end
end