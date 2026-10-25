-- A stand-in for the game's frame API, enough for UI code to run in tests.
-- Frames, textures and font strings record what is done with them; methods
-- the tests do not look at do nothing. Like the client, a frame is visible
-- only when it and all its parents are shown, and takes its parent's strata
-- when the parent changes. Loader.LoadAddon installs it; Loader.ui is the
-- last installed one.

local UI = {}

local function noop() end

local methods = {}

function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:SetShown(shown) self.shown = shown and true or false end
function methods:IsShown() return self.shown end
function methods:IsVisible() return self.shown and (self.parent == nil or self.parent:IsVisible()) end
function methods:SetAlpha(alpha) self.alpha = alpha end
function methods:SetScript(name, fn) self.scripts[name] = fn end
function methods:GetScript(name) return self.scripts[name] end
function methods:ClearAllPoints() self.points = {} end
function methods:SetPoint(...) self.points[#self.points + 1] = { ... } end
function methods:SetSize(width, height) self.width, self.height = width, height end
function methods:SetWidth(width) self.width = width end
function methods:SetHeight(height) self.height = height end
function methods:EnableMouseWheel(enabled) self.wheel = enabled end
function methods:IsMouseOver() return self.mouseOver == true end
function methods:SetParent(parent)
	self.parent = parent
	self.strata = parent.strata
end
function methods:GetParent() return self.parent end
function methods:SetFrameStrata(strata) self.strata = strata end
function methods:GetFrameStrata() return self.strata end
function methods:SetText(text) self.text = text end
function methods:SetFont(file, size, flags) self.font = { file, size, flags } end
-- About 7 pixels a letter (not a byte: "×" is two bytes in UTF-8).
function methods:GetUnboundedStringWidth() return select(2, (self.text or ""):gsub("[^\128-\191]", "")) * 7 end
function methods:SetGradient(orientation, from, to) self.gradient = { orientation, from, to } end
function methods:GetText() return self.text end
function methods:SetTextColor(r, g, b) self.color = { r, g, b } end
function methods:SetJustifyH(justify) self.justify = justify end
function methods:SetTexture(texture) self.texture = texture end
function methods:SetAtlas(atlas) self.atlas = atlas end
function methods:SetVertexColor(r, g, b) self.vertex = { r, g, b } end
function methods:GetEffectiveScale() return self.scale or 1 end
function methods:GetFrameLevel() return self.level or 0 end
function methods:SetChecked(checked) self.checked = checked end
function methods:GetChecked() return self.checked end
function methods:SetEnabled(enabled) self.enabled = enabled end
function methods:SetFontObject(font) self.fontObject = font end
function methods:HookScript(name, fn)
	self.hooks = self.hooks or {}
	self.hooks[name] = self.hooks[name] or {}
	table.insert(self.hooks[name], fn)
end
-- The options panel's controls (DefaultTooltipMixin).
function methods:SetTooltipFunc(fn) self.tooltipFunc = fn end
-- Slider: MinimalSliderWithSteppersTemplate.
function methods:Init(value, minValue, maxValue, steps) self.value, self.range = value, { minValue, maxValue, steps } end
function methods:RegisterCallback(event, fn, owner) self.callbacks = self.callbacks or {}; self.callbacks[event] = { fn, owner } end
-- Dropdown: WowStyle1DropdownTemplate and WowStyle2DropdownTemplate.
function methods:SetupMenu(generator) self.menu = generator end
function methods:GenerateMenu() self.generated = (self.generated or 0) + 1 end
function methods:CreateTexture() return UI.NewFake(self) end
function methods:CreateFontString() return UI.NewFake(self) end

-- A fake frame, texture or font string; shown by default, like a new frame.
function UI.NewFake(parent, strata)
	local fake = { parent = parent, shown = true, alpha = 1, scripts = {}, points = {}, strata = strata or "MEDIUM" }
	return setmetatable(fake, {
		-- Game API methods start with a capital letter; unset fields stay nil.
		__index = function(_, key)
			if methods[key] then
				return methods[key]
			end
			if type(key) == "string" and key:match("^%u") then
				return noop
			end
			return nil
		end,
	})
end

-- Blizzard's item quality colours (ITEM_QUALITY_COLORS), Poor to Legendary.
UI.QUALITY_COLORS = {
	[0] = { r = 0.62, g = 0.62, b = 0.62 },
	[1] = { r = 1, g = 1, b = 1 },
	[2] = { r = 0.12, g = 1, b = 0 },
	[3] = { r = 0, g = 0.44, b = 0.87 },
	[4] = { r = 0.64, g = 0.21, b = 0.93 },
	[5] = { r = 1, g = 0.5, b = 0 },
}

function UI.Install()
	local api = { frames = {} }

	api.UIParent = UI.NewFake()
	rawset(_G, "UIParent", api.UIParent)
	rawset(_G, "CreateFrame", function(_, _, parent)
		local frame = UI.NewFake(parent)
		api.frames[#api.frames + 1] = frame
		return frame
	end)

	local tooltip = { shown = false }
	function tooltip:SetOwner(owner) self.owner = owner end
	function tooltip:SetHyperlink(link) self.link = link end
	function tooltip:SetCurrencyByID(id) self.currency = id end
	function tooltip:Show() self.shown = true end
	function tooltip:Hide() self.shown = false end
	function tooltip:IsOwned(owner) return self.owner == owner end
	api.tooltip = tooltip
	rawset(_G, "GameTooltip", tooltip)

	rawset(_G, "GetMoneyString", function(copper) return copper .. " copper" end)
	rawset(_G, "ColorManager", {
		GetColorDataForItemQuality = function(quality)
			return UI.QUALITY_COLORS[quality]
		end,
		-- Like the client: no loot border for Poor items.
		GetAtlasDataForLootBorderItemQuality = function(quality)
			return quality and quality >= 1 and "loottoast-itemborder-" .. quality or nil
		end,
		GetAtlasDataForNewItemQuality = function(quality)
			return "bags-glow-" .. quality
		end,
	})
	rawset(_G, "CreateColor", function(r, g, b, a) return { r = r, g = g, b = b, a = a } end)
	api.cursor = { 0, 0 }
	rawset(_G, "GetCursorPosition", function() return api.cursor[1], api.cursor[2] end)
	api.escHandlers = {}
	rawset(_G, "GameMenuEscPriority", { AddOn = 8 })
	rawset(_G, "RegisterGameMenuEscHandler", function(_, handler) api.escHandlers[#api.escHandlers + 1] = handler end)
	rawset(_G, "MinimalSliderWithSteppersMixin", {
		Label = { Left = 1, Right = 2, Top = 3, Min = 4, Max = 5 },
		Event = { OnValueChanged = "OnValueChanged" },
	})
	rawset(_G, "CreateMinimalSliderFormatter", function(_, formatter) return formatter or tostring end)
	rawset(_G, "GameFontNormal", { GetFont = function() return "Fonts\\FRIZQT__.TTF", 12, "" end })
	rawset(_G, "NumberFontNormal", { GetFont = function() return "Fonts\\ARIALN.TTF", 14, "OUTLINE" end })
	return api
end

return UI
