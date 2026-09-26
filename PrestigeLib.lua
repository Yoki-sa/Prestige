--[[
	PrestigeLib — Prestige Client style UI library for Roblox (Luau)

	Quick start
	-----------
		local Library = loadstring(game:HttpGet(LIB_URL))()
		local Window = Library:CreateWindow({
			Title = "Prestige", Accent = "Client", Version = "RELEASE 4.4.0",
			Mode = "Full",            -- "Full" (modules + all tabs) or "Hub" (Games, Theme, Settings only)
			Theme = "Aurora",         -- any name in Library.Themes
			MenuKey = Enum.KeyCode.RightShift,
			Games = Library.Games,    -- list shown on the Games tab (see Game entries below)
		})

		local Combat = Window:AddCategory("Combat", "combat")          -- icon: built-in name or "rbxassetid://..."
		local Aim = Combat:AddModule({ Name = "Aim Assist", Description = "Aims at targets",
			Default = false, Keybind = Enum.KeyCode.R, Callback = function(on) end })

		Aim:AddToggle({ Name = "Visible Only", Description = "...", Default = true, Flag = "AimVisible", Callback = function(v) end })
		Aim:AddSlider({ Name = "FOV", Min = 10, Max = 360, Default = 90, Increment = 1, Suffix = "°", Callback = function(v) end })
		Aim:AddDropdown({ Name = "Part", Options = { "Head", "Torso" }, Default = "Head", Callback = function(v) end })
		Aim:AddDropdown({ Name = "Targets", Options = { "Players", "NPCs" }, Multi = true, Default = { "Players" }, Callback = function(list) end })
		Aim:AddColorPicker({ Name = "FOV Color", Default = Color3.fromRGB(0, 200, 255), Callback = function(color, alpha) end })
		Aim:AddButton({ Name = "Reset", Text = "Reset", Callback = function() end })
		Aim:AddTextbox({ Name = "Whitelist", Placeholder = "username", Callback = function(text) end })

		-- every element returns an object with :Set(value) and :Get(); modules have :SetEnabled(bool)
		-- Window:Notify(text), Window:SetTheme(name), Window:Navigate(page), Window:Unload()
		-- Window.Flags[flag] holds the current value of every element that was given a Flag

	Game entries (Games tab)
	------------------------
		{ Name = "Arsenal", PlaceId = 286090429, Script = "https://.../arsenal.lua" or function(Library, entry) end,
		  Description = "optional", Thumbnail = "optional custom image" }
		Thumbnails default to the place's own 16:9 thumbnail (rbxthumb Asset 768x432).
		"Teleport & Load" queues Library.TeleportScript (queue_on_teleport) and teleports; "Load Script" calls
		Library.LoadGame(entry) (set by the loader) when you are already in that game.

	Neon glows are UIShadow instances. sUNC helpers are used when present (gethui, cloneref, getgenv, protectgui,
	request/HttpGet + writefile + getcustomasset for the filled icon set, queue_on_teleport, setclipboard).
]]

local cloneref = cloneref or function(x) return x end
local Players = cloneref(game:GetService("Players"))
local TweenService = cloneref(game:GetService("TweenService"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local Lighting = cloneref(game:GetService("Lighting"))
local ContextActionService = cloneref(game:GetService("ContextActionService"))
local TeleportService = cloneref(game:GetService("TeleportService"))
local LocalPlayer = Players.LocalPlayer

local Library = { Version = "4.4.0", Games = {} }

--------------------------------------------------------------------------- fonts / constants
local FONT_SANS = "rbxasset://fonts/families/BuilderSans.json"
local FONT_SERIF = "rbxasset://fonts/families/Merriweather.json"
local W = Enum.FontWeight
-- Builder Sans renders smaller and lighter than the reference font: every sans label is bumped one weight
-- step and ~18% in size
local WEIGHT_UP = { Regular = W.Medium, Medium = W.SemiBold, SemiBold = W.Bold, Bold = W.Bold }
local function Sans(weight)
	weight = weight or W.Regular
	return Font.new(FONT_SANS, WEIGHT_UP[weight.Name] or weight, Enum.FontStyle.Normal)
end
local function TS(size, font)
	if font and font.Family ~= FONT_SANS then return size end
	return math.floor(size * 1.18 + 0.5)
end
local function Serif(weight, italic)
	return Font.new(FONT_SERIF, weight or W.Regular, italic and Enum.FontStyle.Italic or Enum.FontStyle.Normal)
end

local WIN_W, WIN_H = 1100, 700
local SIDEBAR_W, SIDEBAR_COLLAPSED_W = 230, 62
local CONTENT_X, CONTENT_W = 259, 810
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
local DANGER = Color3.fromRGB(240, 82, 74)
local function hex(h) return Color3.fromHex(h) end

--------------------------------------------------------------------------- themes
local Themes = {
	{ Name = "Vault", Desc = "Glass + violet, Prestige Client theme", Base = "0B0A1A", Accent = "7C7CFF", Glass = true },
	{ Name = "Nova", Desc = "Dark indigo + cyan", Base = "07101F", Accent = "1EC8F0", Glass = true },
	{ Name = "Rose", Desc = "Black plum + pink", Base = "1E0A15", Accent = "F2609A", Glass = true },
	{ Name = "Ember", Desc = "Charcoal + orange", Base = "150D08", Accent = "FF7A1A", Glass = true },
	{ Name = "Forest", Desc = "Deep moss + green", Base = "06120E", Accent = "10A880", Glass = true },
	{ Name = "Indigo", Desc = "Dark navy + indigo", Base = "0A0D22", Accent = "6366F1", Glass = true },
	{ Name = "Magenta", Desc = "Dark plum + magenta", Base = "1A0A20", Accent = "E35CE8", Glass = true },
	{ Name = "Ocean", Desc = "Deep navy + blue", Base = "061022", Accent = "3B82F6", Glass = true },
	{ Name = "Crimson", Desc = "Near-black + red", Base = "150808", Accent = "F0503C", Glass = true },
	{ Name = "Lime", Desc = "Dark olive + lime", Base = "0C1108", Accent = "84CC16", Glass = true },
	{ Name = "Gold", Desc = "Dark brown + gold", Base = "130F07", Accent = "FBBF24", Glass = true },
	{ Name = "Aurora", Desc = "Deep teal + mint", Base = "07191A", Accent = "5EEAD4", Glass = true },
	{ Name = "Carbon", Desc = "Pure neutral dark", Base = "111113", Accent = "EDEDED", Swatches = { "121212", "1C1C1E", "EDEDED", "8A8A8A", "26262A" } },
	{ Name = "Slate", Desc = "Cool gray + electric blue", Base = "13161D", Accent = "3B82F6", Swatches = { "1A1D24", "232833", "3B82F6", "1E4A99", "2F3644" } },
	{ Name = "Mocha", Desc = "Espresso brown + peach", Base = "17100C", Accent = "FDBA8C", Swatches = { "1E1612", "2B1F18", "FDBA8C", "9A6B4C", "3A2A20" } },
	{ Name = "Cobalt", Desc = "Uniform deep blue", Base = "0C1426", Accent = "3B7BE6", Swatches = { "0F1628", "17213A", "3B7BE6", "1F4A9A", "16203A" } },
	{ Name = "Mauve", Desc = "Dusty muted purple", Base = "17111A", Accent = "D8A7E8", Swatches = { "1E1520", "2A1E2D", "D8A7E8", "7A5A86", "3A2C40" } },
	{ Name = "Sage", Desc = "Soft muted green", Base = "0F1512", Accent = "86C497", Swatches = { "111814", "1A241D", "86C497", "4A6E53", "27322A" } },
	{ Name = "Brick", Desc = "Burnt clay + orange", Base = "170E0B", Accent = "E0703F", Swatches = { "1A100C", "2A1911", "E0703F", "8E4526", "3A2219" } },
	{ Name = "Abyss", Desc = "Pitch black + cyan", Base = "05080B", Accent = "0EA5C9", Swatches = { "06090C", "0C1318", "0EA5C9", "0B5F75", "121A20" } },
	{ Name = "Copper", Desc = "Smoked copper + amber", Base = "140E0A", Accent = "F08A4B", Swatches = { "1A120D", "281B13", "F08A4B", "B8683A", "34241A" } },
}
local ThemeByName = {}
for _, t in ipairs(Themes) do ThemeByName[t.Name] = t end
Library.Themes = Themes

local function derive(t)
	local acc = hex(t.Accent)
	local base = hex(t.Base):Lerp(acc, 0.04)
	return {
		Name = t.Name, Base = base, Accent = acc,
		Panel = base:Lerp(WHITE, 0.025):Lerp(acc, 0.03),
		Card = base:Lerp(WHITE, 0.035):Lerp(acc, 0.05),
		CardHover = base:Lerp(WHITE, 0.06):Lerp(acc, 0.08),
		Field = base:Lerp(WHITE, 0.045):Lerp(acc, 0.07),
		FieldHover = base:Lerp(WHITE, 0.08):Lerp(acc, 0.1),
		Stroke = base:Lerp(WHITE, 0.1):Lerp(acc, 0.14),
		StrokeSoft = base:Lerp(WHITE, 0.08):Lerp(acc, 0.08),
		AccentSoft = base:Lerp(acc, 0.24),
		AccentPale = acc:Lerp(WHITE, 0.42),
		AccentFaint = base:Lerp(acc, 0.1),
		OnAccent = acc:Lerp(BLACK, 0.82),
		Text = Color3.fromRGB(240, 242, 245),
		Label = Color3.fromRGB(205, 211, 218):Lerp(acc, 0.04),
		Sub = base:Lerp(Color3.fromRGB(200, 207, 214), 0.7),
		Muted = base:Lerp(Color3.fromRGB(200, 207, 214), 0.55),
		Track = base:Lerp(WHITE, 0.07),
	}
end

--------------------------------------------------------------------------- instance helpers
local P = derive(ThemeByName.Aurora) -- active palette (one window at a time)

local function New(class, props, children)
	local inst = Instance.new(class)
	local parent
	if props then
		for k, v in pairs(props) do
			if k == "Parent" then parent = v else inst[k] = v end
		end
	end
	if children then for _, c in ipairs(children) do c.Parent = inst end end
	if parent then inst.Parent = parent end
	return inst
end
local function Tween(inst, props, t, style, dir)
	local tw = TweenService:Create(inst, TweenInfo.new(t or 0.2, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end
local function Set(inst, props, animate)
	if animate then Tween(inst, props, 0.18) else for k, v in pairs(props) do inst[k] = v end end
end
local function Corner(r, parent) return New("UICorner", { CornerRadius = UDim.new(0, r), Parent = parent }) end
local function Round(parent) return New("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = parent }) end
local function Stroke(parent, color, thick, transp)
	return New("UIStroke", { Color = color, Thickness = thick or 1, Transparency = transp or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = parent })
end
local function Pad(parent, l, r, t, b)
	return New("UIPadding", { PaddingLeft = UDim.new(0, l or 0), PaddingRight = UDim.new(0, r or l or 0),
		PaddingTop = UDim.new(0, t or 0), PaddingBottom = UDim.new(0, b or t or 0), Parent = parent })
end
-- neon glow: a UIShadow with no offset tinted with the accent (its parent must be fairly opaque)
local function Glow(parent, color, blur, transp, spread)
	return New("UIShadow", { Color = color, BlurRadius = UDim.new(0, blur or 12), Transparency = transp or 0.4,
		Offset = UDim2.new(0, 0, 0, 0), Spread = UDim2.fromOffset(spread or 0, spread or 0), ZIndex = -1, Parent = parent })
end
local function DropShadow(parent, blur, transp, oy)
	return New("UIShadow", { Color = BLACK, BlurRadius = UDim.new(0, blur or 24), Transparency = transp or 0.55,
		Offset = UDim2.fromOffset(0, oy or 6), Spread = UDim2.fromOffset(0, 0), ZIndex = -2, Parent = parent })
end
local function Frame(props)
	props.BorderSizePixel = 0
	if props.BackgroundTransparency == nil then props.BackgroundTransparency = 1 end
	return New("Frame", props)
end
local function Label(props)
	props.BorderSizePixel = 0
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.FontFace = props.FontFace or Sans()
	props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
	props.TextSize = TS(props.TextSize or 14, props.FontFace)
	return New("TextLabel", props)
end
local function Button(props)
	props.BorderSizePixel = 0
	props.AutoButtonColor = false
	props.Text = props.Text or ""
	props.FontFace = props.FontFace or Sans(W.Medium)
	props.TextSize = TS(props.TextSize or 14, props.FontFace)
	if props.BackgroundTransparency == nil then props.BackgroundTransparency = 1 end
	return New("TextButton", props)
end
local function Scroller(props)
	props.BackgroundTransparency = 1
	props.BorderSizePixel = 0
	props.ScrollBarThickness = 0
	props.ScrollBarImageTransparency = 1
	props.CanvasSize = UDim2.new(0, 0, 0, 0)
	props.AutomaticCanvasSize = Enum.AutomaticSize.Y
	return New("ScrollingFrame", props)
end
local function Hover(inst, enter, leave)
	inst.MouseEnter:Connect(enter)
	inst.MouseLeave:Connect(leave)
end
local function toHex(c) return "#" .. c:ToHex():upper() end

-- theme painters: every themed element registers a function that recolours it
local Painters = {}
local function Paint(inst, fn)
	Painters[#Painters + 1] = { inst = inst, fn = fn }
	fn(false)
	return fn
end
local function Repaint(animate)
	local keep = {}
	for _, p in ipairs(Painters) do
		if p.inst.Parent ~= nil then p.fn(animate); keep[#keep + 1] = p end
	end
	Painters = keep
end

--------------------------------------------------------------------------- icons
-- Lucide sprite sheets uploaded to Roblox by lucide-roblox (48px cells) — fallback when sUNC file APIs are missing
local ICONS = {
	combat = { 16898613777, 967, 759 }, mace = { 16898613509, 306, 820 }, misc = { 16898613869, 820, 906 },
	movement = { 16898613699, 563, 771 }, spear = { 16898612629, 918, 147 }, visual = { 16898613353, 771, 563 },
	settings = { 16898613613, 49, 820 }, theme = { 16898613613, 453, 918 }, games = { 16898613353, 710, 967 },
	socials = { 16898613869, 967, 98 }, keybinds = { 16898613509, 453, 820 }, search = { 16898613699, 918, 857 },
	crown = { 16898613044, 404, 918 }, chevron = { 16898612819, 869, 759 }, chevronLeft = { 16898612819, 404, 967 },
	chevronDown = { 16898612819, 196, 918 }, check = { 16898612819, 710, 869 }, list = { 16898613509, 869, 808 },
	grid = { 16898613509, 918, 404 }, player = { 16898613699, 918, 257 }, unload = { 16898613699, 820, 147 },
}
-- filled glyphs matching the reference (icons8 "ios-filled", white). Downloaded once through the executor,
-- cached with writefile and loaded with getcustomasset.
local FILLED = {
	combat = "wrestling", mace = "hammer", misc = "wrench", movement = "running", spear = "up-right-arrow",
	visual = "visible", settings = "menu", theme = "paint-palette", games = "controller", socials = "groups",
	keybinds = "keyboard", search = "search", crown = "crown", player = "play", unload = "shutdown",
}
local FILLED_URL = "https://img.icons8.com/ios-filled/100/ffffff/%s.png"
local ICON_DIR = "PrestigeClient/icons"
local filledCache = {}

local function httpGet(url)
	local req = request or http_request or (syn and syn.request) or (http and http.request)
	if req then
		local ok, res = pcall(req, { Url = url, Method = "GET" })
		if ok and res and (res.StatusCode == nil or res.StatusCode == 200) and res.Body and #res.Body > 0 then return res.Body end
	end
	local ok, body = pcall(function() return game:HttpGet(url) end)
	if ok and body and #body > 0 then return body end
end
Library.HttpGet = httpGet

local function filledAsset(name)
	local file = FILLED[name]
	if not file or not (getcustomasset and writefile and isfile) then return nil end
	if filledCache[name] ~= nil then return filledCache[name] or nil end
	local path = ICON_DIR .. "/" .. file .. ".png"
	local ok, id = pcall(function()
		if not isfile(path) then
			if makefolder and isfolder then
				if not isfolder("PrestigeClient") then makefolder("PrestigeClient") end
				if not isfolder(ICON_DIR) then makefolder(ICON_DIR) end
			end
			local body = httpGet(FILLED_URL:format(file))
			if not body or body:sub(2, 4) ~= "PNG" then error("download failed") end
			writefile(path, body)
		end
		return getcustomasset(path)
	end)
	filledCache[name] = (ok and id) or false
	return filledCache[name] or nil
end

-- Icon(parent, name, props, colorFn) -> ImageLabel, setColor(color, animate). name may also be a raw image id.
local function Icon(parent, name, props, colorFn)
	local img = New("ImageLabel", { Parent = parent, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromOffset(16, 16), ScaleType = Enum.ScaleType.Fit })
	local def = ICONS[name]
	local custom = def and filledAsset(name)
	if custom then
		img.Image = custom
	elseif def then
		img.Image = "rbxassetid://" .. def[1]
		img.ImageRectOffset = Vector2.new(def[2], def[3])
		img.ImageRectSize = Vector2.new(48, 48)
	else
		img.Image = tostring(name)
	end
	for k, v in pairs(props or {}) do img[k] = v end
	local function color(c, animate) Set(img, { ImageColor3 = c }, animate) end
	if colorFn then Paint(img, function(a) color(colorFn(), a) end) end
	return img, color
end

local function guiParent()
	local ok, h = pcall(function() return gethui and gethui() end)
	if ok and h then return h end
	return LocalPlayer:WaitForChild("PlayerGui")
end

local function KeyName(k)
	if not k then return "None" end
	local map = { RightShift = "Right Shift", LeftShift = "Left Shift", RightControl = "Right Ctrl", LeftControl = "Left Ctrl",
		RightAlt = "Right Alt", LeftAlt = "Left Alt", Return = "Enter" }
	return map[k.Name] or k.Name
end

local function thumbFor(entry)
	return entry.Thumbnail or ("rbxthumb://type=Asset&id=" .. string.format("%d", entry.PlaceId) .. "&w=768&h=432")
end

local function isCurrentGame(entry)
	if entry.PlaceId == game.PlaceId then return true end
	if entry.PlaceIds then for _, id in ipairs(entry.PlaceIds) do if id == game.PlaceId then return true end end end
	return false
end
Library.IsCurrentGame = isCurrentGame

--========================================================================= window
function Library:CreateWindow(opts)
	opts = opts or {}
	if Library._window then Library._window:Unload() end
	Painters = {}
	local Hub = (opts.Mode == "Hub")
	local Games = opts.Games or Library.Games or {}

	local State = {
		Theme = ThemeByName[opts.Theme or ""] and opts.Theme or "Aurora",
		Page = nil, Category = nil, View = "list", OpenModule = nil, Collapsed = false,
		MainColor = opts.MainColor or hex("5EEAD4"), MenuKey = opts.MenuKey or Enum.KeyCode.RightShift, Open = true,
	}
	P = derive(ThemeByName[State.Theme])

	local Win = { Flags = {}, Categories = {}, Mode = Hub and "Hub" or "Full" }
	local Categories = Win.Categories
	local CategoryByName = {}
	local Conns = {}
	local Unloaded = false
	-- global-signal connection that is dropped on unload (and lazily when `owner` is gone)
	local function Listen(signal, fn, owner)
		local c
		c = signal:Connect(function(...)
			if owner and owner.Parent == nil then c:Disconnect() return end
			fn(...)
		end)
		Conns[#Conns + 1] = c
		return c
	end

	-------------------------------------------------------------------- root
	local old = guiParent():FindFirstChild("PrestigeClient")
	if old then old:Destroy() end
	local Screen = New("ScreenGui", { Name = "PrestigeClient", ResetOnSpawn = false, IgnoreGuiInset = true, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999 })
	if protectgui then pcall(protectgui, Screen) end
	Screen.Parent = guiParent()
	local Blur = Lighting:FindFirstChild("PrestigeBlur") or New("BlurEffect", { Name = "PrestigeBlur", Size = 0, Parent = Lighting })

	-- full-screen click sink: a Modal button eats clicks meant for the world and frees the mouse in first person
	local Dim = New("TextButton", { Name = "InputSink", Parent = Screen, Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 0.45,
		BorderSizePixel = 0, Text = "", AutoButtonColor = false, Modal = true, Active = true, Selectable = false, ZIndex = 0 })

	local Window = Frame({ Name = "Window", Parent = Screen, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(WIN_W, WIN_H), BackgroundTransparency = 0.06, ZIndex = 1 })
	Corner(22, Window)
	local WindowStroke = Stroke(Window, P.Stroke:Lerp(WHITE, 0.2), 1, 0.42)
	DropShadow(Window, 60, 0.35, 12)
	local WindowGlow = Glow(Window, P.Accent, 40, 0.93, 0)
	local WindowScale = New("UIScale", { Parent = Window })
	New("UIGradient", { Rotation = 40, Parent = Window,
		Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(160, 160, 160)) }) })
	local function fitScale()
		local cam = workspace.CurrentCamera
		local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
		return math.clamp(math.min(vp.X / 1920, vp.Y / 1010), 0.5, 1.4)
	end
	WindowScale.Scale = fitScale()

	-- ambient blooms: a rounded CanvasGroup the size of the window, so they fade out inside the glass. Each bloom
	-- host is opaque (UIShadow opacity follows its parent's transparency) and parked outside the canvas where it
	-- is clipped away; UIShadow.Offset moves the glow into place, so only the glow is ever visible.
	local GlowLayer = New("CanvasGroup", { Name = "GlowLayer", Parent = Window, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 1 })
	Corner(22, GlowLayer)
	local ANCHOR = Vector2.new(-60, -60)
	local function Bloom(x, y, spread, blur, transp)
		local dot = Frame({ Parent = GlowLayer, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(ANCHOR.X, ANCHOR.Y),
			Size = UDim2.fromOffset(2, 2), BackgroundTransparency = 0, BackgroundColor3 = P.Base })
		Round(dot)
		return New("UIShadow", { Color = P.Accent, BlurRadius = UDim.new(0, blur), Transparency = transp,
			Offset = UDim2.fromOffset(x - ANCHOR.X, y - ANCHOR.Y), Spread = UDim2.fromOffset(spread, spread), ZIndex = -1, Parent = dot })
	end
	local Bloom1 = Bloom(620, 300, 140, 240, 0.76)
	local Bloom2 = Bloom(470, 70, 90, 170, 0.84)
	local Bloom3 = Bloom(850, 320, 110, 200, 0.78)
	local GlowSpots = { Modules = Vector2.new(560, 330), Theme = Vector2.new(600, 250), Settings = Vector2.new(610, 440),
		Games = Vector2.new(600, 330), Game = Vector2.new(520, 300), Socials = Vector2.new(640, 260), Keybinds = Vector2.new(640, 250) }
	local function PlaceGlow(page, instant)
		local p = GlowSpots[page] or Vector2.new(620, 300)
		local t = instant and 0 or 0.6
		Tween(Bloom1, { Offset = UDim2.fromOffset(p.X - ANCHOR.X, p.Y - ANCHOR.Y) }, t, Enum.EasingStyle.Sine)
		Tween(Bloom3, { Offset = UDim2.fromOffset(p.X + 230 - ANCHOR.X, p.Y + 20 - ANCHOR.Y) }, t, Enum.EasingStyle.Sine)
	end
	Paint(Window, function(a)
		Set(Window, { BackgroundColor3 = P.Base }, a)
		Set(WindowStroke, { Color = P.Stroke:Lerp(WHITE, 0.2) }, a)
		Set(WindowGlow, { Color = P.Accent }, a)
		for _, b in ipairs({ Bloom1, Bloom2, Bloom3 }) do Set(b, { Color = P.Accent }, a) end
	end)

	local Overlay = Frame({ Name = "Overlay", Parent = Window, Size = UDim2.fromScale(1, 1), ZIndex = 50 })
	local function toWindowSpace(guiObj)
		local s = WindowScale.Scale
		local rel = guiObj.AbsolutePosition - Window.AbsolutePosition
		return Vector2.new(rel.X / s, rel.Y / s), Vector2.new(guiObj.AbsoluteSize.X / s, guiObj.AbsoluteSize.Y / s)
	end

	-------------------------------------------------------------------- generic controls
	local function Toggle(parent, props, getState, onToggle)
		local track = Button({ Parent = parent, Size = UDim2.fromOffset(44, 24), BackgroundTransparency = 0, ZIndex = 3 })
		for k, v in pairs(props or {}) do track[k] = v end
		Round(track)
		local stroke = Stroke(track, P.StrokeSoft, 1, 0.2)
		local glow = Glow(track, P.Accent, 18, 1, 2)
		local knob = Frame({ Parent = track, AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(16, 16), BackgroundTransparency = 0, BackgroundColor3 = WHITE, ZIndex = 4 })
		Round(knob)
		local hovered = false
		local function refresh(a)
			local on = getState()
			Set(track, { BackgroundColor3 = on and (hovered and P.Accent:Lerp(WHITE, 0.1) or P.Accent) or (hovered and P.Track:Lerp(WHITE, 0.06) or P.Track),
				BackgroundTransparency = on and 0 or 0.35 }, a)
			Set(stroke, { Color = on and P.Accent or (hovered and P.Stroke or P.StrokeSoft), Transparency = on and 0.5 or 0.35 }, a)
			Set(glow, { Color = P.Accent, Transparency = on and (hovered and 0.15 or 0.3) or 1 }, a)
			Set(knob, { Position = on and UDim2.new(1, -20, 0.5, 0) or UDim2.new(0, 4, 0.5, 0), Size = hovered and UDim2.fromOffset(17, 17) or UDim2.fromOffset(16, 16),
				BackgroundColor3 = on and Color3.fromRGB(245, 255, 253):Lerp(P.Accent, 0.08) or WHITE }, a)
		end
		Paint(track, refresh)
		track.MouseButton1Click:Connect(function() onToggle(); refresh(true) end)
		Hover(track, function() hovered = true; refresh(true) end, function() hovered = false; refresh(true) end)
		return track, refresh
	end

	local function Chip(parent, text, props)
		local b = Button({ Parent = parent, Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 0.4, Text = text, TextSize = 13, FontFace = Sans(W.Medium) })
		for k, v in pairs(props or {}) do b[k] = v end
		Round(b); Pad(b, 14, 14, 0, 0)
		local s = Stroke(b, P.StrokeSoft, 1, 0.15)
		Paint(b, function(a) Set(b, { BackgroundColor3 = P.Field, TextColor3 = P.Label }, a); Set(s, { Color = P.StrokeSoft }, a) end)
		Hover(b, function() Tween(s, { Color = P.Accent:Lerp(P.Base, 0.4) }, 0.15); Tween(b, { BackgroundColor3 = P.FieldHover, TextColor3 = P.Text }, 0.15) end,
			function() Tween(s, { Color = P.StrokeSoft }, 0.15); Tween(b, { BackgroundColor3 = P.Field, TextColor3 = P.Label }, 0.15) end)
		return b
	end

	-- small pill button with a leading icon (Back, etc.)
	local function PillButton(parent, text, icon, props)
		local b = Button({ Parent = parent, Size = UDim2.fromOffset(104, 26), BackgroundTransparency = 0.4, ZIndex = 4 })
		for k, v in pairs(props or {}) do b[k] = v end
		Round(b)
		local st = Stroke(b, P.StrokeSoft, 1, 0.15)
		local lbl = Label({ Parent = b, Position = UDim2.fromOffset(45, 0), Size = UDim2.new(1, -45, 1, 0), Text = text, TextSize = 13, FontFace = Sans(W.Medium), ZIndex = 5 })
		local _, col = Icon(b, icon, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 31, 0.5, 0), Size = UDim2.fromOffset(11, 11), ZIndex = 5 })
		local function paint(a, h)
			Set(b, { BackgroundColor3 = h and P.FieldHover or P.Field }, a)
			Set(st, { Color = h and P.Accent:Lerp(P.Base, 0.4) or P.StrokeSoft }, a)
			Set(lbl, { TextColor3 = h and P.Text or P.Label }, a)
			col(h and P.Text or P.Label, a)
		end
		Paint(b, function(a) paint(a, false) end)
		Hover(b, function() paint(true, true) end, function() paint(true, false) end)
		return b
	end

	local function SearchBox(parent, placeholder, props)
		local box = Frame({ Parent = parent, BackgroundTransparency = 0, Size = UDim2.fromOffset(308, 36) })
		for k, v in pairs(props or {}) do box[k] = v end
		Corner(9, box)
		local s = Stroke(box, P.StrokeSoft, 1, 0.1)
		local _, colorIcon = Icon(box, "search", { Position = UDim2.new(0, 13, 0.5, -7), Size = UDim2.fromOffset(14, 14) })
		local tb = New("TextBox", { Parent = box, BackgroundTransparency = 1, Position = UDim2.fromOffset(38, 0), Size = UDim2.new(1, -46, 1, 0),
			Text = "", PlaceholderText = placeholder, FontFace = Sans(), TextSize = TS(13), TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false })
		local focused, hovered = false, false
		Paint(box, function(a)
			Set(box, { BackgroundColor3 = P.Base:Lerp(P.Field, 0.55) }, a)
			Set(s, { Color = P.StrokeSoft }, a)
			colorIcon(P.Sub, a)
			tb.TextColor3 = P.Text; tb.PlaceholderColor3 = P.Sub
		end)
		local focusGlow = Glow(box, P.Accent, 14, 1, 0)
		local function fx()
			focusGlow.Color = P.Accent
			Tween(s, { Color = focused and P.Accent or (hovered and P.Stroke:Lerp(P.Accent, 0.3) or P.StrokeSoft), Transparency = 0.1, Thickness = focused and 1.5 or 1 }, 0.15)
			Tween(focusGlow, { Transparency = focused and 0.6 or 1 }, 0.15)
			colorIcon((focused or hovered) and P.Label or P.Sub, true)
		end
		tb.Focused:Connect(function() focused = true; fx() end)
		tb.FocusLost:Connect(function() focused = false; fx() end)
		Hover(box, function() hovered = true; fx() end, function() hovered = false; fx() end)
		local function setFocus(on) focused = on; fx() end
		return box, tb, setFocus
	end

	local function Tabs(parent, names, active, onSelect, x, y, w)
		local tabs = {}
		local function refresh(a)
			for i, t in ipairs(tabs) do
				local on = (names[i] == active)
				Set(t.btn, { BackgroundColor3 = on and P.Accent or (t.hover and P.FieldHover or P.Field), BackgroundTransparency = on and 0.05 or 0.45,
					TextColor3 = on and WHITE or (t.hover and P.Text or P.Label) }, a)
				Set(t.stroke, { Color = on and P.Accent or (t.hover and P.Stroke:Lerp(P.Accent, 0.3) or P.StrokeSoft), Transparency = on and 0.4 or 0.45 }, a)
				Set(t.glow, { Color = P.Accent, Transparency = on and (t.hover and 0.55 or 0.72) or 1 }, a)
			end
		end
		for i, n in ipairs(names) do
			local b = Button({ Parent = parent, Position = UDim2.fromOffset(x + (i - 1) * (w + 12), y), Size = UDim2.fromOffset(w, 36), Text = n, TextSize = 13, FontFace = Sans(W.Medium), BackgroundTransparency = 0 })
			Corner(7, b)
			local t = { btn = b, stroke = Stroke(b, P.StrokeSoft, 1, 0.3), glow = Glow(b, P.Accent, 18, 1, 0), hover = false }
			tabs[i] = t
			b.MouseButton1Click:Connect(function() active = n; refresh(true); if onSelect then onSelect(n) end end)
			Hover(b, function() t.hover = true; refresh(true) end, function() t.hover = false; refresh(true) end)
		end
		Paint(tabs[1].btn, refresh)
		return tabs
	end

	-- solid accent button (primary) / outlined (secondary) / danger
	local function ActionButton(parent, text, icon, kind, props)
		local b = Button({ Parent = parent, Size = UDim2.fromOffset(180, 38), Text = "", BackgroundTransparency = 0, ZIndex = 5 })
		for k, v in pairs(props or {}) do b[k] = v end
		Corner(8, b)
		local st = Stroke(b, P.Accent, 1, 0.5)
		local glow = Glow(b, P.Accent, 16, 1, 0)
		local holder = Frame({ Parent = b, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 6 })
		New("UIListLayout", { Parent = holder, FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
		local col, _ic
		if icon then _ic, col = Icon(holder, icon, { Size = UDim2.fromOffset(15, 15), LayoutOrder = 1, ZIndex = 6 }) end
		local lbl = Label({ Parent = holder, Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, Text = text, TextSize = 13, FontFace = Sans(W.SemiBold), LayoutOrder = 2, ZIndex = 6 })
		local hovered, pressed = false, false
		local obj = { btn = b, label = lbl }
		local function paint(a)
			local accent = (kind == "danger") and DANGER or P.Accent
			local fg
			if kind == "primary" then
				Set(b, { BackgroundColor3 = hovered and accent:Lerp(WHITE, 0.12) or accent:Lerp(P.Base, 0.12), BackgroundTransparency = 0 }, a)
				Set(st, { Color = accent, Transparency = 0.4 }, a)
				fg = P.OnAccent
			else
				Set(b, { BackgroundColor3 = hovered and P.Base:Lerp(accent, 0.28) or P.Base:Lerp(accent, (kind == "danger") and 0.16 or 0.1), BackgroundTransparency = 0 }, a)
				Set(st, { Color = hovered and accent or accent:Lerp(P.Base, 0.45), Transparency = hovered and 0.2 or 0.45 }, a)
				fg = hovered and WHITE or accent:Lerp(WHITE, 0.35)
			end
			Set(glow, { Color = accent, Transparency = hovered and 0.45 or ((kind == "primary") and 0.75 or 1) }, a)
			Set(lbl, { TextColor3 = fg }, a)
			if col then col(fg, a) end
		end
		obj.paint = paint
		Paint(b, paint)
		Hover(b, function() hovered = true; paint(true) end, function() hovered = false; paint(true) end)
		b.MouseButton1Down:Connect(function() Tween(b, { Size = b.Size - UDim2.fromOffset(4, 2) }, 0.08) end)
		b.MouseButton1Up:Connect(function() Tween(b, { Size = (props and props.Size) or UDim2.fromOffset(180, 38) }, 0.12) end)
		return obj
	end

	-------------------------------------------------------------------- toast
	local ToastHolder
	local function Toast(text, color)
		if ToastHolder then ToastHolder:Destroy() end
		local t = Frame({ Parent = Overlay, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -22, 1, 22), Size = UDim2.fromOffset(0, 34),
			AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 0.05, BackgroundColor3 = P.Panel, ZIndex = 60 })
		ToastHolder = t
		Corner(9, t); Stroke(t, P.Stroke, 1, 0.1); DropShadow(t, 18, 0.5, 4); Pad(t, 12, 12, 0, 0)
		New("UIListLayout", { Parent = t, FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
		local dot = Frame({ Parent = t, Size = UDim2.fromOffset(9, 9), BackgroundTransparency = 0, BackgroundColor3 = color or P.Accent, LayoutOrder = 1, ZIndex = 61 })
		Round(dot); Glow(dot, color or P.Accent, 8, 0.3, 1)
		Label({ Parent = t, Size = UDim2.fromOffset(0, 34), AutomaticSize = Enum.AutomaticSize.X, Text = text, TextSize = 13, TextColor3 = P.Text, LayoutOrder = 2, ZIndex = 61 })
		Tween(t, { Position = UDim2.new(1, -22, 1, -24) }, 0.35, Enum.EasingStyle.Quint)
		task.delay(2.6, function()
			if ToastHolder == t then
				local tw = Tween(t, { Position = UDim2.new(1, -22, 1, 60) }, 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				tw.Completed:Connect(function() if ToastHolder == t then t:Destroy(); ToastHolder = nil end end)
			end
		end)
	end

	-------------------------------------------------------------------- popups (dropdown / colour picker)
	local ActivePopup
	local function ClosePopup() if ActivePopup then ActivePopup:Destroy(); ActivePopup = nil end end

	local function Checker(parent, cols, rows, size)
		for y = 0, rows - 1 do
			for x = 0, cols - 1 do
				Frame({ Parent = parent, Position = UDim2.fromOffset(x * size, y * size), Size = UDim2.fromOffset(size, size), BackgroundTransparency = 0,
					BackgroundColor3 = ((x + y) % 2 == 0) and Color3.fromRGB(120, 120, 128) or Color3.fromRGB(70, 70, 76) })
			end
		end
	end

	-- HSV colour picker with alpha + hex field
	local function ColorPicker(parent, pos, initial, initialAlpha, onChange)
		local h, s, v = initial:ToHSV()
		local alpha = initialAlpha or 1
		local root = Frame({ Parent = parent, Position = pos, Size = UDim2.fromOffset(206, 250) })
		local sv = Frame({ Parent = root, Size = UDim2.fromOffset(170, 170), BackgroundTransparency = 0 })
		Corner(4, sv)
		local white = Frame({ Parent = sv, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0, BackgroundColor3 = WHITE })
		Corner(4, white); New("UIGradient", { Parent = white, Transparency = NumberSequence.new(0, 1) })
		local black = Frame({ Parent = sv, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0, BackgroundColor3 = BLACK })
		Corner(4, black); New("UIGradient", { Parent = black, Rotation = 90, Transparency = NumberSequence.new(1, 0) })
		local cursor = Frame({ Parent = sv, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(11, 11), ZIndex = 3 })
		Round(cursor); local cursorStroke = Stroke(cursor, WHITE, 2, 0); DropShadow(cursor, 4, 0.4, 0)
		local hue = Frame({ Parent = root, Position = UDim2.fromOffset(180, 0), Size = UDim2.fromOffset(12, 170), BackgroundTransparency = 0, BackgroundColor3 = WHITE })
		Corner(3, hue)
		local keys = {}
		for i = 0, 6 do keys[#keys + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV((i / 6) % 1, 1, 1)) end
		New("UIGradient", { Parent = hue, Rotation = 90, Color = ColorSequence.new(keys) })
		local hueCursor = Frame({ Parent = hue, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(18, 5), BackgroundTransparency = 0, BackgroundColor3 = WHITE, ZIndex = 3 })
		Corner(2, hueCursor); Stroke(hueCursor, BLACK, 1, 0.5)
		local alphaBar = Frame({ Parent = root, Position = UDim2.fromOffset(0, 182), Size = UDim2.fromOffset(196, 12), ClipsDescendants = true })
		Checker(alphaBar, 33, 2, 6)
		local alphaFill = Frame({ Parent = alphaBar, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0, BackgroundColor3 = WHITE })
		New("UIGradient", { Parent = alphaFill, Transparency = NumberSequence.new(1, 0) })
		local alphaCursor = Frame({ Parent = root, AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(4, 16), BackgroundTransparency = 0, BackgroundColor3 = WHITE, ZIndex = 3 })
		Corner(2, alphaCursor); Stroke(alphaCursor, BLACK, 1, 0.5)
		local swatch = Frame({ Parent = root, Position = UDim2.fromOffset(0, 206), Size = UDim2.fromOffset(28, 28), BackgroundTransparency = 0 })
		Corner(5, swatch); Stroke(swatch, WHITE, 1, 0.85)
		local hexBox = New("TextBox", { Parent = root, Position = UDim2.fromOffset(38, 206), Size = UDim2.fromOffset(158, 28), BackgroundTransparency = 0.1,
			BorderSizePixel = 0, Text = "", FontFace = Sans(W.Medium), TextSize = TS(12), TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false })
		Corner(5, hexBox); Pad(hexBox, 9, 9, 0, 0)
		local hexStroke = Stroke(hexBox, P.StrokeSoft, 1, 0.2)
		local hexHover = false
		local function paintHex(a)
			Set(hexBox, { BackgroundColor3 = hexHover and P.FieldHover or P.Field, TextColor3 = hexHover and P.Text or P.Label }, a)
			Set(hexStroke, { Color = hexHover and P.Stroke:Lerp(P.Accent, 0.35) or P.StrokeSoft }, a)
		end
		Paint(hexBox, paintHex)
		Hover(hexBox, function() hexHover = true; paintHex(true) end, function() hexHover = false; paintHex(true) end)
		-- hover feedback on the picking surfaces
		Hover(sv, function() Tween(cursor, { Size = UDim2.fromOffset(14, 14) }, 0.12) end, function() Tween(cursor, { Size = UDim2.fromOffset(11, 11) }, 0.12) end)
		Hover(hue, function() Tween(hueCursor, { Size = UDim2.fromOffset(20, 6) }, 0.12) end, function() Tween(hueCursor, { Size = UDim2.fromOffset(18, 5) }, 0.12) end)
		Hover(alphaBar, function() Tween(alphaCursor, { Size = UDim2.fromOffset(6, 18) }, 0.12) end, function() Tween(alphaCursor, { Size = UDim2.fromOffset(4, 16) }, 0.12) end)

		local function update(fire)
			local c = Color3.fromHSV(h, s, v)
			sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
			cursor.Position = UDim2.fromScale(s, 1 - v)
			cursorStroke.Color = (v > 0.6 and s < 0.4) and Color3.fromRGB(30, 30, 30) or WHITE
			hueCursor.Position = UDim2.new(0.5, 0, h, 0)
			alphaFill.BackgroundColor3 = c
			alphaCursor.Position = UDim2.fromOffset(2 + alpha * 192, 180)
			swatch.BackgroundColor3 = c
			hexBox.Text = toHex(c)
			if fire and onChange then onChange(c, alpha) end
		end
		update(false)
		local dragging
		local function drag(p)
			if dragging == "sv" then
				local o, sz = sv.AbsolutePosition, sv.AbsoluteSize
				s = math.clamp((p.X - o.X) / sz.X, 0, 1); v = 1 - math.clamp((p.Y - o.Y) / sz.Y, 0, 1)
			elseif dragging == "hue" then
				local o, sz = hue.AbsolutePosition, hue.AbsoluteSize
				h = math.clamp((p.Y - o.Y) / sz.Y, 0, 0.999)
			elseif dragging == "alpha" then
				local o, sz = alphaBar.AbsolutePosition, alphaBar.AbsoluteSize
				alpha = math.clamp((p.X - o.X) / sz.X, 0, 1)
			end
			update(true)
		end
		local function hook(obj, name)
			obj.InputBegan:Connect(function(io)
				if io.UserInputType == Enum.UserInputType.MouseButton1 then dragging = name; drag(io.Position) end
			end)
		end
		hook(sv, "sv"); hook(hue, "hue"); hook(alphaBar, "alpha")
		Listen(UserInputService.InputChanged, function(io)
			if dragging and io.UserInputType == Enum.UserInputType.MouseMovement then drag(io.Position) end
		end, root)
		Listen(UserInputService.InputEnded, function(io)
			if io.UserInputType == Enum.UserInputType.MouseButton1 then dragging = nil end
		end, root)
		hexBox.FocusLost:Connect(function()
			local ok, c = pcall(Color3.fromHex, (hexBox.Text:gsub("#", "")))
			if ok and c then h, s, v = c:ToHSV() end
			update(true)
		end)
		return root
	end

	local function OpenPopupAt(anchor, width, height, build)
		ClosePopup()
		local pos, size = toWindowSpace(anchor)
		local x = math.min(pos.X + size.X - width, WIN_W - width - 12)
		local y = pos.Y + size.Y + 6
		if y + height > WIN_H - 8 then y = pos.Y - height - 6 end
		local pop = Button({ Parent = Overlay, Position = UDim2.fromOffset(x, y + 6), Size = UDim2.fromOffset(width, height), BackgroundTransparency = 0.02, ZIndex = 70 })
		Corner(9, pop); Stroke(pop, P.Stroke, 1, 0.1); DropShadow(pop, 28, 0.35, 8)
		pop.BackgroundColor3 = P.Panel:Lerp(P.Base, 0.3)
		ActivePopup = pop
		Tween(pop, { Position = UDim2.fromOffset(x, y) }, 0.16, Enum.EasingStyle.Quint)
		build(pop)
		return pop
	end

	-------------------------------------------------------------------- sidebar
	local Sidebar = Frame({ Name = "Sidebar", Parent = Window, Position = UDim2.fromOffset(14, 14), Size = UDim2.new(0, SIDEBAR_W, 1, -28), BackgroundTransparency = 0.25, ClipsDescendants = true, ZIndex = 2 })
	Corner(16, Sidebar)
	local SidebarStroke = Stroke(Sidebar, P.StrokeSoft, 1, 0.1)
	Paint(Sidebar, function(a) Set(Sidebar, { BackgroundColor3 = P.Panel:Lerp(BLACK, 0.12) }, a); Set(SidebarStroke, { Color = P.Stroke }, a) end)

	local CrownBtn = Button({ Parent = Sidebar, Position = UDim2.fromOffset(10, 12), Size = UDim2.fromOffset(40, 36), ZIndex = 3 })
	local crownImg, crownColor = Icon(CrownBtn, "crown", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) }, function() return P.Accent end)
	local crownGlow = Glow(CrownBtn, P.Accent, 14, 1, 0)
	Hover(CrownBtn, function() Tween(crownImg, { Size = UDim2.fromOffset(19, 19), Rotation = -8 }, 0.15); crownColor(P.AccentPale, true) end,
		function() Tween(crownImg, { Size = UDim2.fromOffset(16, 16), Rotation = 0 }, 0.15); crownColor(P.Accent, true) end)
	local BrandTitle = Label({ Parent = Sidebar, Position = UDim2.fromOffset(49, 14), Size = UDim2.fromOffset(170, 20), TextSize = 15, FontFace = Serif(W.Bold), RichText = true, ZIndex = 3 })
	local BrandVer = Label({ Parent = Sidebar, Position = UDim2.fromOffset(49, 33), Size = UDim2.fromOffset(170, 12), TextSize = 10, Text = opts.Version or ("RELEASE " .. Library.Version), ZIndex = 3 })
	Paint(BrandTitle, function(a)
		BrandTitle.Text = (opts.Title or "Prestige") .. ' <i><font color="' .. toHex(P.AccentPale) .. '">' .. (opts.Accent or "Client") .. '</font></i>'
		Set(BrandTitle, { TextColor3 = P.Text }, a)
		Set(BrandVer, { TextColor3 = P.Muted }, a)
	end)

	-- nav list (dynamic): section label, category items, divider, general items
	local NavList = Frame({ Parent = Sidebar, Position = UDim2.fromOffset(0, 70), Size = UDim2.new(1, 0, 1, -74), ZIndex = 3 })
	Pad(NavList, 11, 11, 0, 0)
	New("UIListLayout", { Parent = NavList, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder })
	local NavItems, SectionLabels = {}, {}
	local Navigate -- forward
	local function SectionLabel(text, order)
		local f = Frame({ Parent = NavList, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = order, ZIndex = 3 })
		local l = Label({ Parent = f, Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -12, 0, 14), Text = text, TextSize = 11, ZIndex = 3 })
		Paint(l, function(a) Set(l, { TextColor3 = P.Muted }, a) end)
		SectionLabels[#SectionLabels + 1] = l
		return f
	end
	local function NavItem(key, text, icon, order, isCategory)
		local b = Button({ Parent = NavList, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = order, BackgroundTransparency = 1, ZIndex = 3 })
		Corner(10, b)
		local st = Stroke(b, P.Accent, 1, 1)
		local ic, colorIcon = Icon(b, icon, { Position = UDim2.new(0, 11, 0.5, -9), Size = UDim2.fromOffset(18, 18), ZIndex = 4 })
		local lbl = Label({ Parent = b, Position = UDim2.fromOffset(38, 0), Size = UDim2.new(1, -80, 1, 0), Text = text, TextSize = 13, ZIndex = 4 })
		local cnt
		if isCategory then
			cnt = Label({ Parent = b, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -13, 0, 0), Size = UDim2.fromOffset(30, 40), Text = "0", TextSize = 11, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 4 })
		end
		local item = { key = key, btn = b, hover = false, count = cnt, isCategory = isCategory }
		function item.refresh(a)
			local sel = (isCategory and State.Page == "Modules" and State.Category == key) or ((not isCategory) and (State.Page == key or (key == "Games" and State.Page == "Game")))
			Set(b, { BackgroundColor3 = sel and P.AccentSoft or P.Card, BackgroundTransparency = sel and 0.08 or (item.hover and 0.45 or 1) }, a)
			Set(st, { Color = P.Accent, Transparency = sel and 0.72 or (item.hover and 0.88 or 1) }, a)
			colorIcon(sel and P.Accent or (item.hover and P.Text or P.Label:Lerp(P.Base, 0.12)), a)
			Set(ic, { Size = item.hover and UDim2.fromOffset(19, 19) or UDim2.fromOffset(18, 18) }, a)
			Set(lbl, { TextColor3 = (sel or item.hover) and P.Text or P.Label, TextTransparency = State.Collapsed and 1 or 0 }, a)
			if cnt then Set(cnt, { TextColor3 = sel and P.Label or P.Muted, TextTransparency = State.Collapsed and 1 or 0 }, a) end
		end
		Paint(b, item.refresh)
		Hover(b, function() item.hover = true; item.refresh(true) end, function() item.hover = false; item.refresh(true) end)
		b.MouseButton1Click:Connect(function() if isCategory then Navigate("Modules", key) else Navigate(key) end end)
		NavItems[#NavItems + 1] = item
		return item
	end
	local function refreshNav(a) for _, n in ipairs(NavItems) do n.refresh(a) end end

	local DividerHolder = Frame({ Parent = NavList, Size = UDim2.new(1, 0, 0, 26), LayoutOrder = 500, ZIndex = 3 })
	local Divider = Frame({ Parent = DividerHolder, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -24, 0, 1), BackgroundTransparency = 0, ZIndex = 3 })
	New("UIGradient", { Parent = Divider, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.25), NumberSequenceKeypoint.new(1, 1) }) })
	Paint(Divider, function(a) Set(Divider, { BackgroundColor3 = P.Stroke:Lerp(P.Accent, 0.35) }, a) end)
	if Hub then
		SectionLabel("HUB", 1)
		NavItem("Games", "Games", "games", 2, false)
		SectionLabel("GENERAL", 501)
		NavItem("Theme", "Theme", "theme", 502, false)
		NavItem("Settings", "Settings", "settings", 503, false)
	else
		SectionLabel("MODULES", 1)
		SectionLabel("GENERAL", 501)
		local general = { { "Settings", "settings" }, { "Theme", "theme" }, { "Games", "games" }, { "Socials", "socials" }, { "Keybinds", "keybinds" } }
		for i, g in ipairs(general) do NavItem(g[1], g[1], g[2], 501 + i, false) end
	end

	-------------------------------------------------------------------- content + title
	local Content = Frame({ Name = "Content", Parent = Window, Position = UDim2.fromOffset(CONTENT_X, 0), Size = UDim2.new(0, CONTENT_W, 1, 0), ZIndex = 2 })
	local PageHolder
	local Title = Label({ Parent = Content, Position = UDim2.fromOffset(0, 28), Size = UDim2.fromOffset(560, 34), TextSize = 23, FontFace = Serif(W.Bold), RichText = true, ZIndex = 3 })
	local Subtitle = Label({ Parent = Content, Position = UDim2.fromOffset(0, 65), Size = UDim2.fromOffset(560, 16), TextSize = 12, ZIndex = 3 })
	local TitleParts = { accent = nil, rest = "" }
	local function paintTitle(a)
		if TitleParts.accent then
			Title.Text = '<i><font color="' .. toHex(P.AccentPale) .. '">' .. TitleParts.accent .. '</font></i> ' .. TitleParts.rest
		else
			Title.Text = TitleParts.rest
		end
		Set(Title, { TextColor3 = P.Text }, a)
		Set(Subtitle, { TextColor3 = P.Sub }, a)
	end
	Paint(Title, paintTitle)
	local function SetTitle(accentWord, rest, sub)
		TitleParts.accent = accentWord; TitleParts.rest = rest
		Subtitle.Text = sub or ""
		paintTitle(false)
	end

	-------------------------------------------------------------------- module state
	local function enabledCount(cat)
		local n = 0
		for _, m in ipairs(cat.Modules) do if m.Enabled then n = n + 1 end end
		return n
	end
	local function moduleSub(cat) return #cat.Modules .. " modules · " .. enabledCount(cat) .. " enabled" end
	local function fire(fn, ...)
		if fn then
			local args = table.pack(...)
			task.spawn(function()
				local ok, err = pcall(fn, table.unpack(args, 1, args.n))
				if not ok then warn("[PrestigeLib] callback error: " .. tostring(err)) end
			end)
		end
	end
	local function refreshViews(obj)
		local keep = {}
		for _, v in ipairs(obj._views) do
			if v.inst.Parent ~= nil then v.fn(true); keep[#keep + 1] = v end
		end
		obj._views = keep
	end
	local function addView(obj, inst, fn) obj._views[#obj._views + 1] = { inst = inst, fn = fn } end
	local function setEnabled(m, on)
		on = on and true or false
		if m.Enabled == on then return end
		m.Enabled = on
		refreshViews(m)
		if State.Page == "Modules" and State.Category == m.Category.Name then SetTitle(m.Category.Name, "Modules", moduleSub(m.Category)) end
		fire(m.Callback, on)
	end

	-------------------------------------------------------------------- setting rows
	local function SettingRow(parent, order, name, desc, descRoom)
		local row = Frame({ Parent = parent, Size = UDim2.new(1, 0, 0, 54), LayoutOrder = order, ZIndex = 3 })
		local rail = Frame({ Parent = row, Position = UDim2.fromOffset(-5, 6), Size = UDim2.new(0, 2, 1, -12), BackgroundTransparency = 1, ZIndex = 4 })
		Round(rail)
		local railGlow = Glow(rail, P.Accent, 6, 1, 0)
		local sep = Frame({ Parent = row, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 1), BackgroundTransparency = 0.6, ZIndex = 3 })
		local t = Label({ Parent = row, Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, -300, 0, 20), Text = name, TextSize = 15, FontFace = Sans(W.Medium), ZIndex = 4 })
		local d = Label({ Parent = row, Position = UDim2.fromOffset(0, 29), Size = UDim2.new(1, -(descRoom or 280), 0, 16), Text = desc or "", TextSize = 11, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4 })
		local hovered = false
		Paint(row, function(a)
			Set(t, { TextColor3 = P.Text }, a); Set(sep, { BackgroundColor3 = P.StrokeSoft }, a); Set(d, { TextColor3 = hovered and P.Label or P.Sub }, a)
			rail.BackgroundColor3 = P.Accent; railGlow.Color = P.Accent
		end)
		Hover(row, function() hovered = true; Tween(rail, { BackgroundTransparency = 0.1 }, 0.15); Tween(railGlow, { Transparency = 0.5 }, 0.15); Tween(d, { TextColor3 = P.Label }, 0.15) end,
			function() hovered = false; Tween(rail, { BackgroundTransparency = 1 }, 0.15); Tween(railGlow, { Transparency = 1 }, 0.15); Tween(d, { TextColor3 = P.Sub }, 0.15) end)
		return row
	end

	-- dark input-like box used by dropdowns, key boxes and colour boxes; brightens on hover
	local function FieldBox(parent, props)
		local b = Button({ Parent = parent, BackgroundTransparency = 0.35, TextSize = 12, FontFace = Sans(), ZIndex = 5 })
		for k, v in pairs(props) do b[k] = v end
		Corner(6, b)
		local st = Stroke(b, P.StrokeSoft, 1, 0.35)
		local obj = { hover = false, active = false }
		function obj.paint(a)
			Set(b, { BackgroundColor3 = obj.hover and P.FieldHover or P.Field, TextColor3 = P.Text }, a)
			Set(st, { Color = obj.active and P.Accent or (obj.hover and P.Stroke:Lerp(P.Accent, 0.35) or P.StrokeSoft), Transparency = obj.active and 0.15 or (obj.hover and 0.15 or 0.35) }, a)
		end
		Paint(b, obj.paint)
		Hover(b, function() obj.hover = true; obj.paint(true) end, function() obj.hover = false; obj.paint(true) end)
		return b, st, obj
	end

	local Binding -- module or menu waiting for a key

	local function BindRow(parent, order, m, header)
		local row = SettingRow(parent, order, "Bind", "Keybind for " .. m.Name)
		local seg = Frame({ Parent = row, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -132, 0.5, 0), Size = UDim2.fromOffset(112, 28), BackgroundTransparency = 0.45, ZIndex = 5 })
		Round(seg)
		local segStroke = Stroke(seg, P.StrokeSoft, 1, 0.3)
		local pills = {}
		local function paintPills(a)
			Set(seg, { BackgroundColor3 = P.Field }, a); Set(segStroke, { Color = P.StrokeSoft }, a)
			for k, v in pairs(pills) do
				local on = (m.BindMode == k)
				Set(v.btn, { BackgroundColor3 = on and P.Accent or P.FieldHover, BackgroundTransparency = on and 0 or (v.hover and 0.2 or 1),
					TextColor3 = on and P.OnAccent or (v.hover and P.Text or P.Label:Lerp(P.Base, 0.3)) }, a)
				Set(v.glow, { Color = P.Accent, Transparency = on and 0.55 or 1 }, a)
			end
		end
		for i, mode in ipairs({ "Hold", "Toggle" }) do
			local p = Button({ Parent = seg, Position = UDim2.fromOffset(2 + (i - 1) * 54, 2), Size = UDim2.fromOffset(54, 24), Text = mode, TextSize = 12, FontFace = Sans(W.Medium), ZIndex = 6 })
			Round(p)
			local pill = { btn = p, glow = Glow(p, P.Accent, 10, 1, 0), hover = false }
			pills[mode] = pill
			p.MouseButton1Click:Connect(function() m.BindMode = mode; paintPills(true) end)
			Hover(p, function() pill.hover = true; paintPills(true) end, function() pill.hover = false; paintPills(true) end)
		end
		Paint(seg, paintPills)
		local key, _, keyObj = FieldBox(row, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(118, 28), Text = KeyName(m.Bind) })
		local tip
		local function finish()
			if tip then tip:Destroy(); tip = nil end
			key.Text = KeyName(m.Bind)
			keyObj.active = false; keyObj.paint(true)
			paintPills(true)
			if header then header() end
		end
		key.MouseButton1Click:Connect(function()
			key.Text = "Press a key"
			keyObj.active = true; keyObj.paint(true)
			tip = Label({ Parent = row, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 0, 2), Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X,
				Text = "Press a key (ESC to cancel, Backspace to clear)", TextSize = 11, BackgroundTransparency = 0.1, BackgroundColor3 = P.AccentFaint, TextColor3 = P.Accent, ZIndex = 8 })
			Corner(5, tip); Pad(tip, 8, 8, 0, 0); Stroke(tip, P.Accent, 1, 0.5)
			Binding = { module = m, done = finish }
		end)
		return row
	end

	local function fmtNumber(s, n)
		local inc = s.Increment or 1
		local txt
		if inc >= 1 then txt = tostring(math.floor(n + 0.5)) else
			local dec = math.max(0, math.min(4, math.ceil(-math.log(inc, 10) - 1e-9)))
			txt = string.format("%." .. dec .. "f", n)
		end
		return txt .. (s.Suffix or "")
	end

	local function SliderRow(parent, order, s)
		local row = SettingRow(parent, order, s.Name, s.Desc)
		local track = Button({ Parent = row, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -107, 0.5, 0), Size = UDim2.fromOffset(200, 4), BackgroundTransparency = 0, ZIndex = 5 })
		Round(track)
		local hit = Button({ Parent = track, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 20), ZIndex = 8 })
		local fill = Frame({ Parent = track, Size = UDim2.fromScale(0, 1), BackgroundTransparency = 0, ZIndex = 6 })
		Round(fill)
		local fillGlow = Glow(fill, P.Accent, 8, 0.6, 0)
		local knob = Frame({ Parent = track, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 0, ZIndex = 7 })
		Round(knob)
		local knobGlow = Glow(knob, P.Accent, 10, 0.4, 1)
		local box = New("TextBox", { Parent = row, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(95, 26), BackgroundTransparency = 0.35,
			BorderSizePixel = 0, Text = "", FontFace = Sans(), TextSize = TS(12), ClearTextOnFocus = false, ZIndex = 5 })
		Corner(6, box)
		local boxStroke = Stroke(box, P.StrokeSoft, 1, 0.35)
		local hovered, dragging, boxHover, boxFocus = false, false, false, false
		local function paintBox(a)
			Set(box, { BackgroundColor3 = (boxHover or boxFocus) and P.FieldHover or P.Field, TextColor3 = P.Text }, a)
			Set(boxStroke, { Color = boxFocus and P.Accent or (boxHover and P.Stroke:Lerp(P.Accent, 0.35) or P.StrokeSoft), Transparency = (boxHover or boxFocus) and 0.15 or 0.35 }, a)
		end
		local function update()
			local a = (s.Value - s.Min) / (s.Max - s.Min)
			fill.Size = UDim2.fromScale(a, 1)
			knob.Position = UDim2.fromScale(a, 0.5)
			if not boxFocus then box.Text = fmtNumber(s, s.Value) end
		end
		local function paintKnob(a)
			local big = hovered or dragging
			Set(knob, { Size = big and UDim2.fromOffset(16, 16) or UDim2.fromOffset(12, 12), BackgroundColor3 = big and P.Accent:Lerp(WHITE, 0.15) or P.Accent }, a)
			Set(knobGlow, { Color = P.Accent, Transparency = big and 0.15 or 0.4 }, a)
			Set(track, { BackgroundColor3 = big and P.Track:Lerp(WHITE, 0.18) or P.Track:Lerp(WHITE, 0.12) }, a)
		end
		Paint(track, function(a)
			Set(fill, { BackgroundColor3 = P.Accent }, a)
			fillGlow.Color = P.Accent
			paintKnob(a); paintBox(a)
		end)
		s._refresh = update
		update()
		local function setValue(raw)
			local inc = s.Increment or 1
			local val = math.clamp(math.floor((raw - s.Min) / inc + 0.5) * inc + s.Min, s.Min, s.Max)
			if val ~= s.Value then s.Value = val; update(); if s.Flag then Win.Flags[s.Flag] = val end; fire(s.Callback, val) else update() end
		end
		local function setFrom(x)
			local p, sz = track.AbsolutePosition, track.AbsoluteSize
			setValue(s.Min + (s.Max - s.Min) * math.clamp((x - p.X) / sz.X, 0, 1))
		end
		hit.InputBegan:Connect(function(io)
			if io.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; paintKnob(true); setFrom(io.Position.X) end
		end)
		Hover(hit, function() hovered = true; paintKnob(true) end, function() hovered = false; paintKnob(true) end)
		Listen(UserInputService.InputChanged, function(io)
			if dragging and io.UserInputType == Enum.UserInputType.MouseMovement then setFrom(io.Position.X) end
		end, row)
		Listen(UserInputService.InputEnded, function(io)
			if dragging and io.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false; paintKnob(true) end
		end, row)
		Hover(box, function() boxHover = true; paintBox(true) end, function() boxHover = false; paintBox(true) end)
		box.Focused:Connect(function() boxFocus = true; box.Text = tostring(s.Value); paintBox(true) end)
		box.FocusLost:Connect(function()
			boxFocus = false
			local n = tonumber((box.Text:gsub("[^%d%.%-]", "")))
			if n then setValue(n) end
			update(); paintBox(true)
		end)
		return row
	end

	local function dropdownText(s)
		if s.Multi then
			if #s.Value == 0 then return "None" end
			return table.concat(s.Value, ", ")
		end
		return tostring(s.Value)
	end
	local function has(list, v) for i, x in ipairs(list) do if x == v then return i end end end

	local function DropdownRow(parent, order, s)
		local row = SettingRow(parent, order, s.Name, s.Desc)
		local box, _, boxObj = FieldBox(row, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(140, 26), Text = "" })
		local lbl = Label({ Parent = box, Position = UDim2.fromOffset(9, 0), Size = UDim2.new(1, -30, 1, 0), Text = dropdownText(s), TextSize = 12, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 6 })
		local chevron = Icon(box, "chevronDown", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(12, 12), ZIndex = 6 }, function() return P.Sub end)
		Paint(lbl, function(a) Set(lbl, { TextColor3 = P.Text }, a) end)
		s._refresh = function() lbl.Text = dropdownText(s) end
		local function open()
			local n = #s.Options
			local h = math.min(8 + n * 28, 8 + 7 * 28)
			boxObj.active = true; boxObj.paint(true)
			Tween(chevron, { Rotation = 180 }, 0.15)
			local pop = OpenPopupAt(box, math.max(140, 160), h, function(pop)
				local list = Scroller({ Parent = pop, Size = UDim2.fromScale(1, 1), ZIndex = 71 })
				Pad(list, 4, 4, 4, 4)
				New("UIListLayout", { Parent = list, Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder })
				local optRows = {}
				local function isOn(opt) if s.Multi then return has(s.Value, opt) ~= nil end return opt == s.Value end
				local function paintOpts(a)
					for _, r in ipairs(optRows) do
						local on = isOn(r.opt)
						Set(r.btn, { BackgroundColor3 = on and P.AccentSoft or P.FieldHover, BackgroundTransparency = on and 0.2 or (r.hover and 0.3 or 1) }, a)
						Set(r.lbl, { TextColor3 = on and P.AccentPale or (r.hover and P.Text or P.Label) }, a)
						if r.check then r.check.Visible = on end
					end
				end
				for i, opt in ipairs(s.Options) do
					local o = Button({ Parent = list, LayoutOrder = i, Size = UDim2.new(1, 0, 0, 26), ZIndex = 72 })
					Corner(5, o)
					local r = { opt = opt, btn = o, hover = false }
					r.lbl = Label({ Parent = o, Position = UDim2.fromOffset(9, 0), Size = UDim2.new(1, -34, 1, 0), Text = tostring(opt), TextSize = 12, FontFace = Sans(W.Medium), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 73 })
					if s.Multi then r.check = Icon(o, "check", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(12, 12), ImageColor3 = P.Accent, ZIndex = 73 }) end
					optRows[#optRows + 1] = r
					Hover(o, function() r.hover = true; paintOpts(true) end, function() r.hover = false; paintOpts(true) end)
					o.MouseButton1Click:Connect(function()
						if s.Multi then
							local idx = has(s.Value, opt)
							if idx then table.remove(s.Value, idx) else s.Value[#s.Value + 1] = opt end
							paintOpts(true)
						else
							s.Value = opt
							ClosePopup()
						end
						lbl.Text = dropdownText(s)
						if s.Flag then Win.Flags[s.Flag] = s.Value end
						fire(s.Callback, s.Value)
					end)
				end
				paintOpts(false)
			end)
			pop.Destroying:Connect(function()
				boxObj.active = false
				if box.Parent then boxObj.paint(true); Tween(chevron, { Rotation = 0 }, 0.15) end
			end)
		end
		box.MouseButton1Click:Connect(open)
		s._open = open
		return row
	end

	local function ColorRow(parent, order, s)
		local row = SettingRow(parent, order, s.Name, s.Desc)
		local box, _, boxObj = FieldBox(row, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(56, 28), Text = "" })
		local sw = Frame({ Parent = box, Position = UDim2.fromOffset(5, 5), Size = UDim2.fromOffset(18, 18), BackgroundTransparency = 0, BackgroundColor3 = s.Value, ZIndex = 6 })
		Corner(4, sw)
		local swGlow = Glow(sw, s.Value, 6, 0.6, 0)
		local chevron = Icon(box, "chevronDown", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -7, 0.5, 0), Size = UDim2.fromOffset(12, 12), ZIndex = 6 }, function() return P.Sub end)
		s._refresh = function() sw.BackgroundColor3 = s.Value; swGlow.Color = s.Value end
		Hover(box, function() Tween(swGlow, { Transparency = 0.25 }, 0.15) end, function() Tween(swGlow, { Transparency = 0.6 }, 0.15) end)
		local function open()
			boxObj.active = true; boxObj.paint(true)
			Tween(chevron, { Rotation = 180 }, 0.15)
			local pop = OpenPopupAt(box, 222, 256, function(pop)
				ColorPicker(pop, UDim2.fromOffset(12, 12), s.Value, s.Alpha, function(c, alpha)
					s.Value = c; s.Alpha = alpha
					s._refresh()
					if s.Flag then Win.Flags[s.Flag] = c end
					fire(s.Callback, c, alpha)
				end)
			end)
			pop.Destroying:Connect(function()
				boxObj.active = false
				if box.Parent then boxObj.paint(true); Tween(chevron, { Rotation = 0 }, 0.15) end
			end)
		end
		box.MouseButton1Click:Connect(open)
		s._open = open
		return row
	end

	local function ToggleRow(parent, order, s)
		local row = SettingRow(parent, order, s.Name, s.Desc, 70)
		local _, refresh = Toggle(row, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), ZIndex = 5 }, function() return s.Value end, function()
			s.Value = not s.Value
			if s.Flag then Win.Flags[s.Flag] = s.Value end
			fire(s.Callback, s.Value)
		end)
		s._refresh = function() refresh(true) end
		return row
	end

	local function ButtonRow(parent, order, s)
		local row = SettingRow(parent, order, s.Name, s.Desc)
		local b = ActionButton(row, s.Text or "Run", nil, "secondary", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(118, 28) })
		b.btn.MouseButton1Click:Connect(function() fire(s.Callback) end)
		return row
	end

	local function TextboxRow(parent, order, s)
		local row = SettingRow(parent, order, s.Name, s.Desc)
		local box = New("TextBox", { Parent = row, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(180, 28), BackgroundTransparency = 0.35,
			BorderSizePixel = 0, Text = s.Value or "", PlaceholderText = s.Placeholder or "", FontFace = Sans(), TextSize = TS(12), ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 5 })
		Corner(6, box); Pad(box, 9, 9, 0, 0)
		local st = Stroke(box, P.StrokeSoft, 1, 0.35)
		local hovered, focused = false, false
		local function paint(a)
			Set(box, { BackgroundColor3 = (hovered or focused) and P.FieldHover or P.Field, TextColor3 = P.Text }, a)
			Set(st, { Color = focused and P.Accent or (hovered and P.Stroke:Lerp(P.Accent, 0.35) or P.StrokeSoft), Transparency = (hovered or focused) and 0.15 or 0.35 }, a)
			box.PlaceholderColor3 = P.Sub
		end
		Paint(box, paint)
		Hover(box, function() hovered = true; paint(true) end, function() hovered = false; paint(true) end)
		box.Focused:Connect(function() focused = true; paint(true) end)
		box.FocusLost:Connect(function(enter)
			focused = false; paint(true)
			s.Value = box.Text
			if s.Flag then Win.Flags[s.Flag] = s.Value end
			fire(s.Callback, s.Value, enter)
		end)
		s._refresh = function() box.Text = s.Value end
		return row
	end

	local RowBuilders = { toggle = ToggleRow, slider = SliderRow, dropdown = DropdownRow, color = ColorRow, button = ButtonRow, textbox = TextboxRow }

	-- soft bottom edge for a scroll area: a strip in the container's own colour fading to solid
	local function BottomFade(parent, height, z, colorFn, baseTransparency)
		local fade = Frame({ Parent = parent, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 1, 1, -1), Size = UDim2.new(1, -2, 0, height or 24), BackgroundTransparency = baseTransparency or 0, ZIndex = z or 10 })
		New("UIGradient", { Parent = fade, Rotation = 90, Transparency = NumberSequence.new(1, 0) })
		Paint(fade, function(a) Set(fade, { BackgroundColor3 = colorFn() }, a) end)
		return fade
	end

	-------------------------------------------------------------------- page transitions
	-- the old page fades out while the new one fades in and slides into place; pages ride in an oversized
	-- temporary CanvasGroup only while animating so nothing stays clipped afterwards
	local FX = 40
	local function fader(z)
		return New("CanvasGroup", { Parent = Content, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = z or 3,
			Position = UDim2.fromOffset(-FX, -FX), Size = UDim2.new(1, FX * 2, 1, FX * 2) })
	end
	local function place(page, parent)
		page.Parent = parent
		if parent == Content then page.Position = UDim2.fromOffset(0, 0); page.Size = UDim2.fromScale(1, 1)
		else page.Position = UDim2.fromOffset(FX, FX); page.Size = UDim2.new(1, -FX * 2, 1, -FX * 2) end
	end
	local SearchPanel, ActiveSearchBox
	local function CloseSearch() if SearchPanel then SearchPanel:Destroy(); SearchPanel = nil end end
	local function NewPage(offset)
		ClosePopup(); CloseSearch()
		local old = PageHolder
		if old then
			local out = fader(2)
			place(old, out)
			Tween(out, { GroupTransparency = 1 }, 0.12).Completed:Connect(function() out:Destroy() end)
		end
		offset = offset or Vector2.new(0, 12)
		local inn = fader(3)
		inn.GroupTransparency = 1
		inn.Position = UDim2.fromOffset(-FX + offset.X, -FX + offset.Y)
		local page = Frame({ Name = "Page", ZIndex = 3 })
		place(page, inn)
		PageHolder = page
		Tween(inn, { GroupTransparency = 0, Position = UDim2.fromOffset(-FX, -FX) }, 0.22, Enum.EasingStyle.Quint).Completed:Connect(function()
			if page.Parent == inn then place(page, Content) end
			inn:Destroy()
		end)
		return page
	end

	-------------------------------------------------------------------- module search (global dropdown)
	local OpenModulePage -- forward
	local function ModuleSearch(page)
		local box, tb, setFocus = SearchBox(page, "Search modules", { Position = UDim2.fromOffset(501, 41) })
		ActiveSearchBox = tb
		local results, sel, rows = {}, 1, {}
		local function paintRows(a)
			for i, r in ipairs(rows) do
				local on = (i == sel)
				Set(r.btn, { BackgroundColor3 = on and P.AccentSoft or P.CardHover, BackgroundTransparency = on and 0.25 or 1 }, a)
				Set(r.stroke, { Color = P.Accent, Transparency = on and 0.45 or 1 }, a)
				Set(r.icon, { ImageColor3 = on and P.Accent or P.Label }, a)
			end
		end
		local function openResult(i)
			local r = results[i]
			if not r then return end
			CloseSearch(); tb.Text = ""
			OpenModulePage(r.cat, r.m)
		end
		local function build(query)
			CloseSearch()
			rows, results = {}, {}
			local q = query:lower():gsub("^%s+", ""):gsub("%s+$", "")
			if q == "" then return end
			setFocus(true)
			for _, cat in ipairs(Categories) do
				for _, m in ipairs(cat.Modules) do
					if m.Name:lower():find(q, 1, true) then results[#results + 1] = { cat = cat, m = m } end
				end
			end
			sel = 1
			local pos, size = toWindowSpace(box)
			local height = 0
			local panel = Frame({ Name = "SearchResults", Parent = Overlay, Position = UDim2.fromOffset(pos.X - 30, pos.Y + size.Y + 9), Size = UDim2.fromOffset(size.X + 50, 60),
				BackgroundTransparency = 0, BackgroundColor3 = P.Panel:Lerp(P.Base, 0.35), ZIndex = 80 })
			SearchPanel = panel
			Corner(10, panel); Stroke(panel, P.Stroke, 1, 0.2); DropShadow(panel, 34, 0.2, 12)
			local scroll = Scroller({ Parent = panel, Size = UDim2.fromScale(1, 1), ZIndex = 81 })
			Pad(scroll, 12, 12, 12, 10)
			New("UIListLayout", { Parent = scroll, Padding = UDim.new(0, 0), SortOrder = Enum.SortOrder.LayoutOrder })
			local order, stops = 0, {}
			local function add(inst, h) order = order + 1; inst.LayoutOrder = order; inst.Parent = scroll; height = height + h; stops[#stops + 1] = height end
			add(Label({ Size = UDim2.new(1, 0, 0, 22), Text = "MODULES", TextSize = 11, TextColor3 = P.Sub:Lerp(P.Accent, 0.3), ZIndex = 82 }), 22)
			if #results == 0 then add(Label({ Size = UDim2.new(1, 0, 0, 44), Text = "No modules match \"" .. query .. "\"", TextSize = 12, TextColor3 = P.Sub, ZIndex = 82 }), 44) end
			local lastCat
			for i, r in ipairs(results) do
				if r.cat ~= lastCat then
					lastCat = r.cat
					local head = Frame({ Size = UDim2.new(1, 0, 0, 24), ZIndex = 82 })
					Label({ Parent = head, Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 0, 16), Text = r.cat.Name, TextSize = 11, TextColor3 = P.Label:Lerp(P.Base, 0.3), ZIndex = 82 })
					Frame({ Parent = head, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 4, 1, 0), Size = UDim2.new(1, -8, 0, 1), BackgroundTransparency = 0.5, BackgroundColor3 = P.StrokeSoft, ZIndex = 82 })
					add(head, 24)
				end
				local b = Button({ Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1, ZIndex = 82 })
				Corner(8, b)
				local st = Stroke(b, P.Accent, 1, 1)
				local ic = Icon(b, r.cat.Icon, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 11, 0.5, 0), Size = UDim2.fromOffset(22, 22), ImageColor3 = P.Label, ZIndex = 83 })
				Label({ Parent = b, Position = UDim2.fromOffset(46, 7), Size = UDim2.new(1, -130, 0, 18), Text = r.m.Name, TextSize = 14, FontFace = Sans(W.Medium), TextColor3 = P.Text, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 83 })
				Label({ Parent = b, Position = UDim2.fromOffset(46, 25), Size = UDim2.new(1, -130, 0, 14), Text = r.cat.Name, TextSize = 11, TextColor3 = P.Sub, ZIndex = 83 })
				local tag = Label({ Parent = b, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(58, 20), Text = "Module", TextSize = 11,
					TextXAlignment = Enum.TextXAlignment.Center, BackgroundTransparency = 0, BackgroundColor3 = P.Base:Lerp(P.Accent, 0.2), TextColor3 = P.AccentPale, ZIndex = 83 })
				Corner(5, tag)
				rows[i] = { btn = b, stroke = st, icon = ic }
				b.MouseEnter:Connect(function() sel = i; paintRows(true) end)
				b.MouseButton1Click:Connect(function() openResult(i) end)
				add(b, 46)
			end
			local fit = height
			if height > 400 then
				fit = 0
				for _, v in ipairs(stops) do if v <= 400 then fit = v end end
				fit = fit + 18
			end
			panel.Size = UDim2.fromOffset(size.X + 50, fit + 28)
			if height > 400 then BottomFade(panel, 30, 90, function() return P.Panel:Lerp(P.Base, 0.35) end, 0) end
			paintRows(false)
		end
		tb:GetPropertyChangedSignal("Text"):Connect(function() build(tb.Text) end)
		tb.Focused:Connect(function() if tb.Text ~= "" then build(tb.Text) end end)
		tb.FocusLost:Connect(function(enter) if enter and #results > 0 then openResult(sel) end end)
		Listen(UserInputService.InputBegan, function(io)
			if not SearchPanel or #rows == 0 then return end
			if io.KeyCode == Enum.KeyCode.Down then sel = math.min(sel + 1, #rows); paintRows(true)
			elseif io.KeyCode == Enum.KeyCode.Up then sel = math.max(sel - 1, 1); paintRows(true)
			elseif io.KeyCode == Enum.KeyCode.Escape then CloseSearch() end
		end, box)
		return box, tb
	end

	-------------------------------------------------------------------- module list + cards
	local function ModuleCard(parent, cat, m, order)
		local grid = State.View == "grid"
		local card = Button({ Parent = parent, Size = UDim2.new(1, 0, 0, 74), BackgroundTransparency = 0.3, LayoutOrder = order, ZIndex = 3 })
		Corner(10, card)
		local st = Stroke(card, P.StrokeSoft, 1, 0.2)
		local bar = Frame({ Parent = card, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0), Size = UDim2.new(0, 3, 1, -22), BackgroundTransparency = 1, ZIndex = 4 })
		Round(bar)
		local barGlow = Glow(bar, P.Accent, 12, 1, 2)
		local title = Label({ Parent = card, Position = UDim2.fromOffset(19, grid and 16 or 15), Size = UDim2.new(1, grid and -30 or -140, 0, 20), Text = m.Name, TextSize = 16, FontFace = Sans(W.Medium), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4 })
		local desc = Label({ Parent = card, Position = UDim2.fromOffset(19, grid and 40 or 39), Size = UDim2.new(1, grid and -34 or -140, 0, grid and 38 or 16), Text = m.Desc, TextSize = 12,
			TextWrapped = grid, TextYAlignment = Enum.TextYAlignment.Top, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4 })
		local chev, colorChevron = Icon(card, "chevron", { AnchorPoint = Vector2.new(0, 0.5), Position = grid and UDim2.new(0, 14, 1, -24) or UDim2.new(1, -92, 0.5, -3), Size = UDim2.fromOffset(14, 14), ZIndex = 4 })
		local chevHome = chev.Position
		local hover = false
		local function refresh(a)
			Set(card, { BackgroundColor3 = (hover and P.CardHover or P.Card):Lerp(P.Accent, m.Enabled and 0.05 or 0) }, a)
			Set(st, { Color = m.Enabled and P.Stroke:Lerp(P.Accent, 0.12) or (hover and P.Stroke or P.StrokeSoft) }, a)
			Set(bar, { BackgroundColor3 = P.Accent, BackgroundTransparency = m.Enabled and 0 or 1 }, a)
			Set(barGlow, { Color = P.Accent, Transparency = m.Enabled and 0.12 or 1 }, a)
			Set(title, { TextColor3 = P.Text }, a)
			Set(desc, { TextColor3 = hover and P.Label or P.Sub }, a)
			colorChevron(hover and P.Accent or P.Sub, a)
			Set(chev, { Position = hover and (chevHome + UDim2.fromOffset(3, 0)) or chevHome }, a)
		end
		Paint(card, refresh)
		addView(m, card, refresh)
		Toggle(card, { AnchorPoint = Vector2.new(1, 0.5), Position = grid and UDim2.new(1, -14, 1, -24) or UDim2.new(1, -15, 0.5, 0) },
			function() return m.Enabled end, function() setEnabled(m, not m.Enabled) end)
		Hover(card, function() hover = true; refresh(true) end, function() hover = false; refresh(true) end)
		card.MouseButton1Click:Connect(function() OpenModulePage(cat, m) end)
		return card
	end

	local function BuildModuleList(page, cat)
		local list = Scroller({ Parent = page, Position = UDim2.fromOffset(-22, 144), Size = UDim2.new(1, 44, 1, -156), ZIndex = 3 })
		Pad(list, 24, 24, 8, 12) -- side padding leaves room for the neon glows so they never clip
		if State.View == "grid" then
			New("UIGridLayout", { Parent = list, CellSize = UDim2.new(1 / 3, -8, 0, 112), CellPadding = UDim2.fromOffset(11, 11), SortOrder = Enum.SortOrder.LayoutOrder })
		else
			New("UIListLayout", { Parent = list, Padding = UDim.new(0, 11), SortOrder = Enum.SortOrder.LayoutOrder })
		end
		for i, m in ipairs(cat.Modules) do ModuleCard(list, cat, m, i) end
		if #cat.Modules == 0 then
			local l = Label({ Parent = list, Size = UDim2.new(1, 0, 0, 120), Text = "No modules in this category yet", TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center })
			Paint(l, function(a) Set(l, { TextColor3 = P.Sub }, a) end)
		end
		return list
	end

	local Pages = {}

	function OpenModulePage(cat, m)
		State.Page = "Modules"; State.Category = cat.Name; State.OpenModule = m
		local page = NewPage(Vector2.new(22, 0))
		SetTitle(cat.Name, "Modules", moduleSub(cat))
		ModuleSearch(page)
		local back = PillButton(page, "Back", "chevronLeft", { Position = UDim2.fromOffset(4, 103) })
		back.MouseButton1Click:Connect(function() State.OpenModule = nil; Navigate("Modules", cat.Name) end)
		local panel = Frame({ Parent = page, Position = UDim2.fromOffset(0, 152), Size = UDim2.new(1, 0, 1, -168), BackgroundTransparency = 0.25, ZIndex = 3 })
		Corner(12, panel)
		local pst = Stroke(panel, P.StrokeSoft, 1, 0.15)
		Paint(panel, function(a) Set(panel, { BackgroundColor3 = P.Card }, a); Set(pst, { Color = m.Enabled and P.Stroke:Lerp(P.Accent, 0.15) or P.StrokeSoft }, a) end)
		addView(m, panel, function(a) Set(pst, { Color = m.Enabled and P.Stroke:Lerp(P.Accent, 0.15) or P.StrokeSoft }, a) end)
		local nameLbl = Label({ Parent = panel, Position = UDim2.fromOffset(19, 18), Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, Text = m.Name, TextSize = 17, FontFace = Sans(W.Bold), ZIndex = 4 })
		local descLbl = Label({ Parent = panel, Position = UDim2.fromOffset(19, 48), Size = UDim2.new(1, -120, 0, 16), Text = m.Desc, TextSize = 12, ZIndex = 4 })
		local badge = Frame({ Parent = panel, Position = UDim2.fromOffset(19, 20), Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 0.2, ZIndex = 4 })
		Corner(4, badge); Pad(badge, 18, 5, 0, 0)
		Icon(badge, "keybinds", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -14, 0.5, 0), Size = UDim2.fromOffset(11, 11), ZIndex = 5 }, function() return P.Sub end)
		local badgeText = Label({ Parent = badge, Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X, Text = "", TextSize = 11, ZIndex = 5 })
		local function header()
			badge.Visible = m.Bind ~= nil
			badgeText.Text = m.Bind and KeyName(m.Bind) or ""
			task.defer(function()
				if not nameLbl.Parent then return end
				badge.Position = UDim2.fromOffset(19 + nameLbl.AbsoluteSize.X / WindowScale.Scale + 10, 21)
			end)
		end
		Paint(nameLbl, function(a)
			Set(nameLbl, { TextColor3 = P.Text }, a); Set(descLbl, { TextColor3 = P.Sub }, a)
			Set(badge, { BackgroundColor3 = P.Field }, a); Set(badgeText, { TextColor3 = P.Sub }, a)
		end)
		header()
		local _, refreshMain = Toggle(panel, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -19, 0, 20), ZIndex = 5 }, function() return m.Enabled end, function() setEnabled(m, not m.Enabled) end)
		addView(m, panel, refreshMain)
		local div = Frame({ Parent = panel, Position = UDim2.fromOffset(19, 92), Size = UDim2.new(1, -38, 0, 1), BackgroundTransparency = 0.2, ZIndex = 4 })
		Paint(div, function(a) Set(div, { BackgroundColor3 = P.StrokeSoft }, a) end)
		local scroll = Scroller({ Parent = panel, Position = UDim2.fromOffset(13, 104), Size = UDim2.new(1, -8, 1, -118), ZIndex = 4 })
		Pad(scroll, 12, 24, 6, 16)
		BottomFade(panel, 26, 8, function() return P.Card end, 0.25)
		New("UIListLayout", { Parent = scroll, Padding = UDim.new(0, 0), SortOrder = Enum.SortOrder.LayoutOrder })
		BindRow(scroll, 0, m, header)
		for i, s in ipairs(m.Settings) do
			local b = RowBuilders[s.Type]
			if b then b(scroll, i, s) end
		end
		refreshNav(true)
		PlaceGlow("Modules")
	end

	Pages.Modules = function(catName)
		local cat = CategoryByName[catName] or Categories[1]
		if not cat then return end
		State.Category = cat.Name
		local page = NewPage()
		SetTitle(cat.Name, "Modules", moduleSub(cat))
		ModuleSearch(page)
		Chip(page, "Gamemodes", { Position = UDim2.fromOffset(4, 103), ZIndex = 4 })
		local views = {}
		local function paintViews(a)
			for v, t in pairs(views) do
				local on = State.View == v
				Set(t.btn, { BackgroundColor3 = on and P.AccentSoft or P.FieldHover, BackgroundTransparency = on and 0.2 or (t.hover and 0.4 or 1) }, a)
				Set(t.st, { Color = P.Accent, Transparency = on and 0.7 or (t.hover and 0.85 or 1) }, a)
				t.color(on and P.Accent or (t.hover and P.Text or P.Sub), a)
			end
		end
		for i, v in ipairs({ "list", "grid" }) do
			local b = Button({ Parent = page, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, (i == 1) and -40 or -6, 0, 104), Size = UDim2.fromOffset(28, 24), BackgroundTransparency = 1, ZIndex = 4 })
			Corner(6, b)
			local st = Stroke(b, P.Accent, 1, 1)
			local _, colorIcon = Icon(b, v, { Position = UDim2.new(0.5, -7, 0.5, -7), Size = UDim2.fromOffset(14, 14), ZIndex = 5 })
			local t = { btn = b, st = st, color = colorIcon, hover = false }
			views[v] = t
			Hover(b, function() t.hover = true; paintViews(true) end, function() t.hover = false; paintViews(true) end)
			b.MouseButton1Click:Connect(function() State.View = v; Navigate("Modules", cat.Name) end)
		end
		Paint(page, paintViews)
		BuildModuleList(page, cat)
	end

	Pages.Theme = function()
		local page = NewPage()
		SetTitle(nil, "Themes", "Menu accent and colors")
		local scroll = Scroller({ Parent = page, Position = UDim2.fromOffset(-22, 102), Size = UDim2.new(1, 44, 1, -110), ZIndex = 3 })
		Pad(scroll, 24, 24, 8, 12)
		New("UIGridLayout", { Parent = scroll, CellSize = UDim2.fromOffset(238, 118), CellPadding = UDim2.fromOffset(22, 22), SortOrder = Enum.SortOrder.LayoutOrder })
		for i, t in ipairs(Themes) do
			local card = Button({ Parent = scroll, LayoutOrder = i, BackgroundTransparency = 0.3, ZIndex = 4 })
			Corner(10, card)
			local st = Stroke(card, P.StrokeSoft, 1, 0.2)
			local acc = hex(t.Accent)
			local glow = Glow(card, acc, 20, 1, 0)
			local base = hex(t.Base):Lerp(acc, 0.04)
			local sw = t.Swatches or { t.Base, base:Lerp(acc, 0.1):ToHex(), t.Accent, base:Lerp(acc, 0.13):Lerp(WHITE, 0.02):ToHex(), base:Lerp(WHITE, 0.07):Lerp(acc, 0.06):ToHex() }
			local strip = Frame({ Parent = card, Position = UDim2.fromOffset(12, 12), Size = UDim2.new(1, -24, 0, 35), ZIndex = 5 })
			for j = 1, 5 do
				local seg = Frame({ Parent = strip, Position = UDim2.new((j - 1) / 5, 0, 0, 0), Size = UDim2.new(0.2, (j < 5) and 1 or 0, 1, 0), BackgroundTransparency = 0, BackgroundColor3 = hex(sw[j]), ZIndex = 5 })
				if j == 1 or j == 5 then
					Corner(5, seg)
					Frame({ Parent = seg, Position = UDim2.new((j == 1) and 0.5 or 0, 0, 0, 0), Size = UDim2.fromScale(0.5, 1), BackgroundTransparency = 0, BackgroundColor3 = hex(sw[j]), ZIndex = 5 })
				end
			end
			if t.Glass then
				local g = Label({ Parent = strip, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(40, 17), Text = "GLASS", TextSize = 10, FontFace = Sans(W.Medium),
					TextXAlignment = Enum.TextXAlignment.Center, BackgroundTransparency = 0.72, BackgroundColor3 = acc, TextColor3 = acc:Lerp(WHITE, 0.25), ZIndex = 6 })
				Corner(4, g)
			end
			local name = Label({ Parent = card, Position = UDim2.fromOffset(12, 55), Size = UDim2.new(1, -60, 0, 18), Text = t.Name, TextSize = 14, FontFace = Sans(W.Medium), ZIndex = 5 })
			local desc = Label({ Parent = card, Position = UDim2.fromOffset(12, 76), Size = UDim2.new(1, -24, 0, 16), Text = t.Desc, TextSize = 12, ZIndex = 5 })
			local check = Frame({ Parent = card, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0, 63), Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 0, BackgroundColor3 = acc, ZIndex = 6 })
			Round(check); Glow(check, acc, 10, 0.4, 0)
			Icon(check, "check", { Position = UDim2.new(0.5, -6, 0.5, -6), Size = UDim2.fromOffset(12, 12), ZIndex = 7 }, function() return WHITE end)
			local hover = false
			local function refresh(a)
				local sel = State.Theme == t.Name
				Set(card, { BackgroundColor3 = sel and P.Card:Lerp(acc, 0.1) or (hover and P.CardHover:Lerp(acc, 0.05) or P.Card), BackgroundTransparency = sel and 0.1 or 0.3 }, a)
				Set(st, { Color = (sel or hover) and acc or P.StrokeSoft, Transparency = sel and 0.45 or (hover and 0.6 or 0.2), Thickness = sel and 1.2 or 1 }, a)
				Set(glow, { Transparency = sel and 0.62 or (hover and 0.82 or 1) }, a)
				Set(name, { TextColor3 = P.Text }, a); Set(desc, { TextColor3 = hover and P.Label or P.Sub }, a)
				Set(strip, { Position = hover and UDim2.fromOffset(12, 10) or UDim2.fromOffset(12, 12) }, a)
				check.Visible = sel
			end
			Paint(card, refresh)
			Hover(card, function() hover = true; refresh(true) end, function() hover = false; refresh(true) end)
			card.MouseButton1Click:Connect(function() Win:SetTheme(t.Name); Toast("Theme · " .. t.Name) end)
		end
	end

	-------------------------------------------------------------------- games
	local GameCards = {}
	local function GameThumb(parent, entry, props, radius)
		-- CanvasGroup gives the thumbnail rounded corners and lets it zoom inside them on hover
		local holder = New("CanvasGroup", { Parent = parent, BackgroundTransparency = 0, BorderSizePixel = 0, BackgroundColor3 = P.Field, ZIndex = 5 })
		for k, v in pairs(props) do holder[k] = v end
		Corner(radius or 8, holder)
		local img = New("ImageLabel", { Parent = holder, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1, Image = thumbFor(entry), ScaleType = Enum.ScaleType.Crop, ZIndex = 5 })
		local scale = New("UIScale", { Parent = img, Scale = 1 })
		local shade = Frame({ Parent = holder, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0, BackgroundColor3 = BLACK, ZIndex = 6 })
		New("UIGradient", { Parent = shade, Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.55, 1), NumberSequenceKeypoint.new(1, 0.45) }) })
		New("UIAspectRatioConstraint", { Parent = holder, AspectRatio = 16 / 9 })
		return holder, img, scale
	end

	Pages.Games = function()
		local page = NewPage()
		local here = 0
		for _, g in ipairs(Games) do if isCurrentGame(g) then here = here + 1 end end
		SetTitle(nil, "Games", #Games .. " supported games" .. ((here > 0) and " · you are in one" or ""))
		local _, tb = SearchBox(page, "Search games", { Position = UDim2.fromOffset(501, 41) })
		local scroll
		local function fill(q)
			if scroll then scroll:Destroy() end
			scroll = Scroller({ Parent = page, Position = UDim2.fromOffset(-22, 102), Size = UDim2.new(1, 44, 1, -110), ZIndex = 3 })
			Pad(scroll, 24, 24, 8, 16)
			New("UIGridLayout", { Parent = scroll, CellSize = UDim2.new(1 / 3, -14, 0, 190), CellPadding = UDim2.fromOffset(20, 20), SortOrder = Enum.SortOrder.LayoutOrder })
			q = (q or ""):lower()
			local shown = 0
			for i, entry in ipairs(Games) do
				if q == "" or entry.Name:lower():find(q, 1, true) then
					shown = shown + 1
					local current = isCurrentGame(entry)
					local card = Button({ Parent = scroll, LayoutOrder = current and 0 or i, BackgroundTransparency = 0.3, ZIndex = 4 })
					Corner(12, card)
					local st = Stroke(card, P.StrokeSoft, 1, 0.2)
					local glow = Glow(card, P.Accent, 22, 1, 0)
					local name = Label({ Parent = card, Position = UDim2.fromOffset(14, 13), Size = UDim2.new(1, current and -118 or -28, 0, 20), Text = entry.Name, TextSize = 15, FontFace = Sans(W.SemiBold), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 5 })
					local badge
					if current then
						badge = Label({ Parent = card, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 13), Size = UDim2.fromOffset(84, 20), Text = "You're here", TextSize = 11,
							TextXAlignment = Enum.TextXAlignment.Center, BackgroundTransparency = 0, ZIndex = 5 })
						Corner(5, badge)
					end
					local thumb, _, zoom = GameThumb(card, entry, { Position = UDim2.fromOffset(12, 44), Size = UDim2.new(1, -24, 0, 132) })
					local play = Frame({ Parent = thumb, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(44, 44), BackgroundTransparency = 1, ZIndex = 7 })
					Round(play)
					local playGlow = Glow(play, P.Accent, 16, 1, 0)
					local playIcon = Icon(play, "player", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 2, 0.5, 0), Size = UDim2.fromOffset(18, 18), ImageTransparency = 1, ZIndex = 8 })
					local hover = false
					local function refresh(a)
						Set(card, { BackgroundColor3 = hover and P.CardHover or (current and P.Card:Lerp(P.Accent, 0.06) or P.Card) }, a)
						Set(st, { Color = (hover or current) and P.Accent or P.StrokeSoft, Transparency = hover and 0.35 or (current and 0.55 or 0.2) }, a)
						Set(glow, { Color = P.Accent, Transparency = hover and 0.7 or (current and 0.85 or 1) }, a)
						Set(name, { TextColor3 = hover and WHITE or P.Text }, a)
						Set(zoom, { Scale = hover and 1.07 or 1 }, a)
						Set(play, { BackgroundColor3 = P.Accent, BackgroundTransparency = hover and 0.1 or 1, Size = hover and UDim2.fromOffset(44, 44) or UDim2.fromOffset(34, 34) }, a)
						Set(playGlow, { Color = P.Accent, Transparency = hover and 0.35 or 1 }, a)
						Set(playIcon, { ImageTransparency = hover and 0 or 1, ImageColor3 = P.OnAccent }, a)
						if badge then Set(badge, { BackgroundColor3 = P.Base:Lerp(P.Accent, 0.24), TextColor3 = P.AccentPale }, a) end
					end
					Paint(card, refresh)
					Hover(card, function() hover = true; refresh(true) end, function() hover = false; refresh(true) end)
					card.MouseButton1Click:Connect(function() Navigate("Game", entry) end)
				end
			end
			if shown == 0 then
				local l = Label({ Parent = scroll, Size = UDim2.new(1, 0, 0, 120), Text = (#Games == 0) and "No games registered" or ("No games match \"" .. q .. "\""), TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center })
				Paint(l, function(a) Set(l, { TextColor3 = P.Sub }, a) end)
			end
		end
		tb:GetPropertyChangedSignal("Text"):Connect(function() fill(tb.Text) end)
		fill("")
	end

	Pages.Game = function(entry)
		local page = NewPage(Vector2.new(22, 0))
		local current = isCurrentGame(entry)
		SetTitle(nil, entry.Name, "Place " .. string.format("%d", entry.PlaceId))
		local back = PillButton(page, "Games", "chevronLeft", { Position = UDim2.fromOffset(4, 103) })
		back.MouseButton1Click:Connect(function() Navigate("Games") end)
		local panel = Frame({ Parent = page, Position = UDim2.fromOffset(0, 152), Size = UDim2.new(1, 0, 1, -168), BackgroundTransparency = 0.25, ZIndex = 3 })
		Corner(12, panel)
		local pst = Stroke(panel, P.StrokeSoft, 1, 0.15)
		Paint(panel, function(a) Set(panel, { BackgroundColor3 = P.Card }, a); Set(pst, { Color = P.StrokeSoft }, a) end)
		local thumb, _, zoom = GameThumb(panel, entry, { Position = UDim2.fromOffset(20, 20), Size = UDim2.fromOffset(448, 252) }, 10)
		local thumbGlow = Glow(thumb, P.Accent, 26, 0.8, 0)
		Hover(thumb, function() Tween(zoom, { Scale = 1.04 }, 0.3) end, function() Tween(zoom, { Scale = 1 }, 0.3) end)
		local x = 488
		local name = Label({ Parent = panel, Position = UDim2.fromOffset(x, 22), Size = UDim2.new(1, -x - 20, 0, 26), Text = entry.Name, TextSize = 20, FontFace = Sans(W.Bold), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4 })
		local status = Label({ Parent = panel, Position = UDim2.fromOffset(x, 58), Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, Text = current and "You're in this game" or "Not in this game",
			TextSize = 11, BackgroundTransparency = 0, ZIndex = 4 })
		Corner(6, status); Pad(status, 9, 9, 0, 0)
		local statusStroke = Stroke(status, P.Accent, 1, 0.6)
		local desc = Label({ Parent = panel, Position = UDim2.fromOffset(x, 94), Size = UDim2.new(1, -x - 20, 0, 88), Text = entry.Description or "Teleports you to a server of this game and loads its script automatically once you arrive.",
			TextSize = 12, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 4 })
		Paint(name, function(a)
			Set(name, { TextColor3 = P.Text }, a); Set(desc, { TextColor3 = P.Sub }, a)
			Set(status, { BackgroundColor3 = current and P.Base:Lerp(P.Accent, 0.22) or P.Field, TextColor3 = current and P.AccentPale or P.Sub }, a)
			Set(statusStroke, { Color = current and P.Accent or P.StrokeSoft, Transparency = current and 0.55 or 0.3 }, a)
		end)
		local primary = ActionButton(panel, current and "Load Script" or "Teleport & Load", "player", "primary", { Position = UDim2.fromOffset(x, 190), Size = UDim2.fromOffset(200, 40) })
		local copy = ActionButton(panel, "Copy Place ID", nil, "secondary", { Position = UDim2.fromOffset(x + 212, 190), Size = UDim2.fromOffset(98, 40) })
		copy.label.Text = "Copy ID"
		primary.btn.MouseButton1Click:Connect(function()
			if current then
				Toast("Loading · " .. entry.Name)
				local loader = opts.OnLoadGame or Library.LoadGame
				if loader then task.defer(loader, entry, Win) else warn("[PrestigeLib] no LoadGame handler set") end
			else
				Toast("Teleporting · " .. entry.Name)
				local script = opts.TeleportScript or Library.TeleportScript
				local queue = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
				if script and queue then pcall(queue, script) end
				task.delay(0.4, function()
					local ok, err = pcall(function() TeleportService:Teleport(entry.PlaceId, LocalPlayer) end)
					if not ok then Toast("Teleport failed", DANGER); warn(err) end
				end)
			end
		end)
		copy.btn.MouseButton1Click:Connect(function()
			local set = setclipboard or toclipboard or (syn and syn.write_clipboard)
			if set then pcall(set, string.format("%d", entry.PlaceId)); Toast("Copied · " .. string.format("%d", entry.PlaceId)) else Toast("Clipboard unavailable", DANGER) end
		end)
		-- info rows under the thumbnail
		local info = Frame({ Parent = panel, Position = UDim2.fromOffset(20, 290), Size = UDim2.new(1, -40, 0, 60), ZIndex = 4 })
		New("UIListLayout", { Parent = info, FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder })
		local facts = { { "Place ID", string.format("%d", entry.PlaceId) }, { "Script", type(entry.Script) == "string" and "Remote" or "Bundled" }, { "Auto-load", "On arrival" } }
		for i, f in ipairs(facts) do
			local c = Frame({ Parent = info, LayoutOrder = i, Size = UDim2.new(1 / 3, -8, 1, 0), BackgroundTransparency = 0.3, ZIndex = 4 })
			Corner(9, c)
			local cst = Stroke(c, P.StrokeSoft, 1, 0.3)
			local k = Label({ Parent = c, Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -28, 0, 14), Text = f[1], TextSize = 11, ZIndex = 5 })
			local v = Label({ Parent = c, Position = UDim2.fromOffset(14, 28), Size = UDim2.new(1, -28, 0, 20), Text = f[2], TextSize = 14, FontFace = Sans(W.SemiBold), ZIndex = 5 })
			local h = false
			local function paint(a)
				Set(c, { BackgroundColor3 = h and P.FieldHover or P.Field }, a); Set(cst, { Color = h and P.Stroke:Lerp(P.Accent, 0.35) or P.StrokeSoft }, a)
				Set(k, { TextColor3 = P.Sub }, a); Set(v, { TextColor3 = h and P.AccentPale or P.Text }, a)
			end
			Paint(c, paint)
			Hover(c, function() h = true; paint(true) end, function() h = false; paint(true) end)
		end
		Paint(thumb, function(a) Set(thumbGlow, { Color = P.Accent }, a) end)
	end

	-------------------------------------------------------------------- settings
	Pages.Settings = function()
		local page = NewPage()
		SetTitle(nil, "Settings", "Appearance, keybinds and session")
		local function Card(x, y, w, h, title, sub)
			local c = Frame({ Parent = page, Position = UDim2.fromOffset(x, y), Size = w and UDim2.fromOffset(w, h) or UDim2.new(1, -x, 0, h), BackgroundTransparency = 0.25, ZIndex = 3 })
			Corner(12, c)
			local st = Stroke(c, P.StrokeSoft, 1, 0.15)
			local t = Label({ Parent = c, Position = UDim2.fromOffset(19, 17), Size = UDim2.new(1, -38, 0, 18), Text = title, TextSize = 14, FontFace = Sans(W.SemiBold), ZIndex = 4 })
			local s = Label({ Parent = c, Position = UDim2.fromOffset(19, 40), Size = UDim2.new(1, -38, 0, 14), Text = sub, TextSize = 11, ZIndex = 4 })
			local h = false
			local function paint(a)
				Set(c, { BackgroundColor3 = P.Card }, a); Set(st, { Color = h and P.Stroke or P.StrokeSoft }, a)
				Set(t, { TextColor3 = P.Text }, a); Set(s, { TextColor3 = P.Sub }, a)
			end
			Paint(c, paint)
			Hover(c, function() h = true; paint(true) end, function() h = false; paint(true) end)
			return c
		end
		local colorCard = Card(0, 103, 258, 356, "Main color", "Accent for trails, effects and HUD")
		local inner = Frame({ Parent = colorCard, Position = UDim2.fromOffset(19, 80), Size = UDim2.fromOffset(220, 256), BackgroundTransparency = 0.3, ZIndex = 4 })
		Corner(8, inner)
		local ist = Stroke(inner, P.StrokeSoft, 1, 0.3)
		Paint(inner, function(a) Set(inner, { BackgroundColor3 = P.Field }, a); Set(ist, { Color = P.StrokeSoft }, a) end)
		ColorPicker(inner, UDim2.fromOffset(12, 12), State.MainColor, 1, function(c, alpha)
			State.MainColor = c
			Win.Flags.MainColor = c
			fire(opts.OnMainColor, c, alpha)
		end)

		local bindCard = Card(284, 103, nil, 146, "Menu Bind", "Key to open/close this menu")
		local row = Frame({ Parent = bindCard, Position = UDim2.fromOffset(19, 70), Size = UDim2.new(1, -38, 0, 56), BackgroundTransparency = 0.3, ZIndex = 4 })
		Corner(8, row)
		local rst = Stroke(row, P.StrokeSoft, 1, 0.3)
		local rl = Label({ Parent = row, Position = UDim2.fromOffset(14, 0), Size = UDim2.fromOffset(200, 56), Text = "Toggle menu", TextSize = 13, FontFace = Sans(W.Medium), ZIndex = 5 })
		local keyBtn = Button({ Parent = row, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(120, 30), Text = KeyName(State.MenuKey), TextSize = 12, FontFace = Sans(W.Medium), BackgroundTransparency = 0, ZIndex = 5 })
		Corner(6, keyBtn)
		local kst = Stroke(keyBtn, P.Accent, 1, 0.7)
		local kh, waiting = false, false
		local function paintKey(a)
			Set(row, { BackgroundColor3 = P.Field }, a); Set(rst, { Color = P.StrokeSoft }, a); Set(rl, { TextColor3 = P.Text }, a)
			Set(keyBtn, { BackgroundColor3 = (kh or waiting) and P.Base:Lerp(P.Accent, 0.34) or P.AccentSoft, TextColor3 = P.Text }, a)
			Set(kst, { Color = P.Accent, Transparency = (kh or waiting) and 0.25 or 0.7 }, a)
		end
		Paint(row, paintKey)
		Hover(keyBtn, function() kh = true; paintKey(true) end, function() kh = false; paintKey(true) end)
		keyBtn.MouseButton1Click:Connect(function()
			keyBtn.Text = "Press a key"; waiting = true; paintKey(true)
			Binding = { menu = true, done = function() waiting = false; keyBtn.Text = KeyName(State.MenuKey); paintKey(true) end }
		end)

		local unloadCard = Card(284, 267, nil, 136, "Unload", "Disables every module, removes the menu and restores input")
		local confirm = false
		local ub = ActionButton(unloadCard, "Unload", "unload", "danger", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -19, 1, -18), Size = UDim2.fromOffset(150, 38) })
		local hint = Label({ Parent = unloadCard, Position = UDim2.fromOffset(19, 82), Size = UDim2.new(1, -200, 0, 30), Text = "Everything you enabled is turned off first, so the game is left clean.", TextSize = 11, TextWrapped = true, ZIndex = 4 })
		Paint(hint, function(a) Set(hint, { TextColor3 = P.Muted }, a) end)
		ub.btn.MouseButton1Click:Connect(function()
			if not confirm then
				confirm = true
				ub.label.Text = "Click to confirm"
				task.delay(2.5, function() if ub.btn.Parent and confirm then confirm = false; ub.label.Text = "Unload" end end)
				return
			end
			Win:Unload()
		end)
	end

	-------------------------------------------------------------------- socials / keybinds
	Pages.Socials = function()
		local page = NewPage()
		SetTitle(nil, "Socials", "Friends and requests")
		local list
		local function fill(tab)
			if list then list:Destroy() end
			list = Scroller({ Parent = page, Position = UDim2.fromOffset(-22, 146), Size = UDim2.new(1, 44, 1, -156), ZIndex = 3 })
			Pad(list, 24, 24, 12, 12)
			New("UIListLayout", { Parent = list, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
			local others = {}
			for _, plr in ipairs(Players:GetPlayers()) do if plr ~= LocalPlayer then others[#others + 1] = plr end end
			if tab == "Friends" or #others == 0 then
				local l = Label({ Parent = list, Size = UDim2.new(1, 0, 0, 220), Text = (tab == "Friends") and "No friends added" or "No players in server", TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4 })
				Paint(l, function(a) Set(l, { TextColor3 = P.Sub }, a) end)
				return
			end
			for i, plr in ipairs(others) do
				local r = Frame({ Parent = list, LayoutOrder = i, Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 0.3, ZIndex = 4 })
				Corner(10, r)
				local st = Stroke(r, P.StrokeSoft, 1, 0.2)
				local n = Label({ Parent = r, Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -150, 1, 0), Text = "", RichText = true, TextSize = 14, FontFace = Sans(W.Medium), ZIndex = 5 })
				local add = ActionButton(r, "Add friend", nil, "secondary", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(110, 30) })
				local h = false
				local function paint(a)
					Set(r, { BackgroundColor3 = h and P.CardHover or P.Card }, a); Set(st, { Color = h and P.Stroke or P.StrokeSoft }, a)
					n.Text = plr.DisplayName .. '  <font color="' .. toHex(P.Sub) .. '">@' .. plr.Name .. '</font>'
					Set(n, { TextColor3 = P.Text }, a)
				end
				Paint(r, paint)
				Hover(r, function() h = true; paint(true) end, function() h = false; paint(true) end)
				add.btn.MouseButton1Click:Connect(function()
					pcall(function() LocalPlayer:RequestFriendship(plr) end)
					Toast("Friend request · " .. plr.DisplayName)
				end)
			end
		end
		Tabs(page, { "All Players", "Friends" }, "All Players", fill, 0, 99, 150)
		SearchBox(page, "Search", { Position = UDim2.fromOffset(330, 99), Size = UDim2.fromOffset(250, 36) })
		fill("All Players")
	end

	Pages.Keybinds = function()
		local page = NewPage()
		SetTitle(nil, "Keybinds", "Every module with a key assigned")
		local scroll = Scroller({ Parent = page, Position = UDim2.fromOffset(-22, 102), Size = UDim2.new(1, 44, 1, -110), ZIndex = 3 })
		Pad(scroll, 24, 24, 8, 10)
		New("UIListLayout", { Parent = scroll, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
		local n = 0
		for _, cat in ipairs(Categories) do
			for _, m in ipairs(cat.Modules) do
				if m.Bind then
					n = n + 1
					local r = Button({ Parent = scroll, LayoutOrder = n, Size = UDim2.new(1, 0, 0, 56), BackgroundTransparency = 0.3, ZIndex = 4 })
					Corner(10, r)
					local st = Stroke(r, P.StrokeSoft, 1, 0.2)
					local t = Label({ Parent = r, Position = UDim2.fromOffset(18, 10), Size = UDim2.fromOffset(400, 18), Text = m.Name, TextSize = 15, FontFace = Sans(W.SemiBold), ZIndex = 5 })
					local c = Label({ Parent = r, Position = UDim2.fromOffset(18, 30), Size = UDim2.fromOffset(400, 14), Text = cat.Name .. " · " .. m.BindMode, TextSize = 11, ZIndex = 5 })
					local k = Label({ Parent = r, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Size = UDim2.fromOffset(110, 28), Text = KeyName(m.Bind), TextSize = 12,
						TextXAlignment = Enum.TextXAlignment.Center, BackgroundTransparency = 0.1, FontFace = Sans(W.Medium), ZIndex = 5 })
					Corner(6, k)
					local kst = Stroke(k, P.StrokeSoft, 1, 0.2)
					local h = false
					local function paint(a)
						Set(r, { BackgroundColor3 = h and P.CardHover or P.Card }, a); Set(st, { Color = h and P.Stroke:Lerp(P.Accent, 0.25) or P.StrokeSoft }, a)
						Set(t, { TextColor3 = P.Text }, a); Set(c, { TextColor3 = P.Sub }, a)
						Set(k, { BackgroundColor3 = h and P.Base:Lerp(P.Accent, 0.2) or P.Field, TextColor3 = h and P.AccentPale or P.Text }, a)
						Set(kst, { Color = h and P.Accent or P.StrokeSoft, Transparency = h and 0.5 or 0.2 }, a)
					end
					Paint(r, paint)
					Hover(r, function() h = true; paint(true) end, function() h = false; paint(true) end)
					r.MouseButton1Click:Connect(function() OpenModulePage(cat, m) end)
				end
			end
		end
		if n == 0 then
			local l = Label({ Parent = scroll, Size = UDim2.new(1, 0, 0, 220), Text = "No keybinds yet — open a module and click its Bind box", TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4 })
			Paint(l, function(a) Set(l, { TextColor3 = P.Label }, a) end)
		end
	end

	function Navigate(page, arg)
		if Unloaded then return end
		if page == "Modules" then
			if #Categories == 0 then return end
			State.Page = "Modules"; State.OpenModule = nil
			Pages.Modules(arg or State.Category)
		elseif Pages[page] then
			State.Page = page
			Pages[page](arg)
		end
		refreshNav(true)
		PlaceGlow(State.Page)
	end

	-------------------------------------------------------------------- collapse / drag / open-close / input
	local function SetCollapsed(c, instant)
		State.Collapsed = c
		local t = instant and 0 or 0.2
		Tween(Sidebar, { Size = UDim2.new(0, c and SIDEBAR_COLLAPSED_W or SIDEBAR_W, 1, -28) }, t, Enum.EasingStyle.Quint)
		Tween(Content, { Position = UDim2.fromOffset(c and 91 or CONTENT_X, 0), Size = UDim2.new(0, c and (WIN_W - 91 - 28) or CONTENT_W, 1, 0) }, t, Enum.EasingStyle.Quint)
		Tween(CrownBtn, { Position = UDim2.fromOffset(c and 11 or 10, 12) }, t, Enum.EasingStyle.Quint)
		for _, l in ipairs({ BrandTitle, BrandVer }) do Tween(l, { TextTransparency = c and 1 or 0 }, t * 0.6) end
		for _, l in ipairs(SectionLabels) do Tween(l, { TextTransparency = c and 1 or 0 }, t * 0.6) end
		Tween(Divider, { Size = c and UDim2.new(1, -8, 0, 1) or UDim2.new(1, -24, 0, 1) }, t, Enum.EasingStyle.Quint)
		for _, n in ipairs(NavItems) do
			Tween(n.btn, { Size = c and UDim2.fromOffset(40, 40) or UDim2.new(1, 0, 0, 40) }, t, Enum.EasingStyle.Quint)
			n.refresh(not instant)
		end
	end
	CrownBtn.MouseButton1Click:Connect(function() SetCollapsed(not State.Collapsed) end)

	local DragZone = Frame({ Name = "DragZone", Parent = Window, Position = UDim2.fromOffset(CONTENT_X, 0), Size = UDim2.new(0, 480, 0, 26), ZIndex = 10 })
	do
		local dragging, startPos, startMouse
		DragZone.InputBegan:Connect(function(io)
			if io.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; startPos = Window.Position; startMouse = Vector2.new(io.Position.X, io.Position.Y) end
		end)
		Listen(UserInputService.InputChanged, function(io)
			if dragging and io.UserInputType == Enum.UserInputType.MouseMovement then
				local d = Vector2.new(io.Position.X, io.Position.Y) - startMouse
				Window.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
			end
		end)
		Listen(UserInputService.InputEnded, function(io) if io.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
	end

	-- while open, every game-bound input is sunk above the PlayerModule / tool bindings; GUI and TextBoxes still get input first
	local BLOCK_ACTION = "PrestigeClientBlockInput"
	local function BlockGameInput(on)
		if on then
			ContextActionService:BindActionAtPriority(BLOCK_ACTION, function() return Enum.ContextActionResult.Sink end, false, Enum.ContextActionPriority.High.Value + 1000,
				Enum.UserInputType.Keyboard, Enum.UserInputType.MouseButton1, Enum.UserInputType.MouseButton2, Enum.UserInputType.MouseButton3,
				Enum.UserInputType.MouseWheel, Enum.UserInputType.MouseMovement, Enum.UserInputType.Touch, Enum.UserInputType.Gamepad1)
		else
			ContextActionService:UnbindAction(BLOCK_ACTION)
		end
	end

	local function SetOpen(open)
		State.Open = open
		BlockGameInput(open)
		if open then
			Window.Visible = true; Dim.Visible = true
			WindowScale.Scale = fitScale() * 0.94
			Tween(WindowScale, { Scale = fitScale() }, 0.35, Enum.EasingStyle.Quint)
			Tween(Dim, { BackgroundTransparency = 0.45 }, 0.3)
			Tween(Blur, { Size = 18 }, 0.3)
		else
			ClosePopup(); CloseSearch()
			local tw = Tween(WindowScale, { Scale = fitScale() * 0.94 }, 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			Tween(Dim, { BackgroundTransparency = 1 }, 0.2)
			Tween(Blur, { Size = 0 }, 0.2)
			tw.Completed:Connect(function() if not State.Open then Window.Visible = false; Dim.Visible = false end end)
		end
	end

	local function outside(frame, io, slack)
		local p, s = frame.AbsolutePosition, frame.AbsoluteSize
		local x, y = io.Position.X, io.Position.Y
		return x < p.X or y < p.Y - (slack or 0) or x > p.X + s.X or y > p.Y + s.Y
	end
	Listen(UserInputService.InputBegan, function(io)
		if io.UserInputType == Enum.UserInputType.MouseButton1 then
			if SearchPanel and outside(SearchPanel, io, 60) then task.defer(CloseSearch) end
			if ActivePopup and outside(ActivePopup, io) then task.defer(ClosePopup) end
			return
		end
		if io.UserInputType ~= Enum.UserInputType.Keyboard then return end
		if Binding then
			local b = Binding
			Binding = nil
			if io.KeyCode ~= Enum.KeyCode.Escape then
				if b.menu then State.MenuKey = io.KeyCode
				elseif io.KeyCode == Enum.KeyCode.Backspace then b.module.Bind = nil
				else b.module.Bind = io.KeyCode end
			end
			b.done()
			return
		end
		if UserInputService:GetFocusedTextBox() then return end
		if io.KeyCode == State.MenuKey then SetOpen(not State.Open) return end
		for _, cat in ipairs(Categories) do
			for _, m in ipairs(cat.Modules) do
				if m.Bind == io.KeyCode then
					if m.BindMode == "Hold" then setEnabled(m, true) else setEnabled(m, not m.Enabled) end
				end
			end
		end
	end)
	Listen(UserInputService.InputEnded, function(io)
		if io.UserInputType ~= Enum.UserInputType.Keyboard then return end
		for _, cat in ipairs(Categories) do
			for _, m in ipairs(cat.Modules) do
				if m.Bind == io.KeyCode and m.BindMode == "Hold" then setEnabled(m, false) end
			end
		end
	end)
	if workspace.CurrentCamera and workspace.CurrentCamera.GetPropertyChangedSignal then
		Listen(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), function() if State.Open then WindowScale.Scale = fitScale() end end)
	end

	--===================================================================== public API
	local ModuleMT = {}
	ModuleMT.__index = ModuleMT
	local function element(m, kind, o, value)
		local s = { Type = kind, Name = o.Name or kind, Desc = o.Description or o.Desc or "", Value = value, Callback = o.Callback, Flag = o.Flag }
		for k, v in pairs(o) do if s[k] == nil then s[k] = v end end
		function s:Set(v, silent)
			if kind == "dropdown" and s.Multi and type(v) ~= "table" then v = { v } end
			s.Value = v
			if s.Flag then Win.Flags[s.Flag] = v end
			if s._refresh then pcall(s._refresh) end
			if not silent then fire(s.Callback, v, s.Alpha) end
		end
		function s:Get() return s.Value end
		function s:SetOptions(list) s.Options = list end
		m.Settings[#m.Settings + 1] = s
		if s.Flag then Win.Flags[s.Flag] = value end
		return s
	end
	function ModuleMT:AddToggle(o) return element(self, "toggle", o, o.Default and true or false) end
	function ModuleMT:AddSlider(o)
		local s = element(self, "slider", o, math.clamp(o.Default or o.Min or 0, o.Min or 0, o.Max or 100))
		s.Min = o.Min or 0; s.Max = o.Max or 100; s.Increment = o.Increment or 1
		return s
	end
	function ModuleMT:AddDropdown(o)
		local def = o.Default
		if o.Multi then
			local list = {}
			if type(def) == "table" then for _, v in ipairs(def) do list[#list + 1] = v end elseif def ~= nil then list[1] = def end
			def = list
		elseif def == nil then def = (o.Options or {})[1] end
		local s = element(self, "dropdown", o, def)
		s.Options = o.Options or {}
		return s
	end
	function ModuleMT:AddColorPicker(o)
		local s = element(self, "color", o, o.Default or Color3.fromRGB(255, 255, 255))
		s.Alpha = o.Alpha or 1
		return s
	end
	ModuleMT.AddColorpicker = ModuleMT.AddColorPicker
	function ModuleMT:AddButton(o) return element(self, "button", o, nil) end
	function ModuleMT:AddTextbox(o) return element(self, "textbox", o, o.Default or "") end
	ModuleMT.AddTextBox = ModuleMT.AddTextbox
	function ModuleMT:SetEnabled(v) setEnabled(self, v) end
	function ModuleMT:Toggle() setEnabled(self, not self.Enabled) end
	function ModuleMT:SetKeybind(k, mode) self.Bind = k; if mode then self.BindMode = mode end end

	local CategoryMT = {}
	CategoryMT.__index = CategoryMT
	function CategoryMT:AddModule(o)
		o = o or {}
		local m = setmetatable({ Name = o.Name or "Module", Desc = o.Description or o.Desc or "", Enabled = false, Bind = o.Keybind, BindMode = o.BindMode or "Toggle",
			Settings = {}, Callback = o.Callback, Category = self, _views = {} }, ModuleMT)
		self.Modules[#self.Modules + 1] = m
		if self._nav and self._nav.count then self._nav.count.Text = tostring(#self.Modules) end
		if o.Default then task.defer(setEnabled, m, true) end
		return m
	end

	function Win:AddCategory(name, icon)
		if Hub then error("[PrestigeLib] categories are not available in Hub mode") end
		local cat = setmetatable({ Name = name, Icon = icon or "misc", Modules = {} }, CategoryMT)
		Categories[#Categories + 1] = cat
		CategoryByName[name] = cat
		cat._nav = NavItem(name, name, cat.Icon, 1 + #Categories, true)
		cat._nav.refresh(false)
		return cat
	end
	Win.AddTab = Win.AddCategory

	function Win:Notify(text, color) Toast(text, color) end
	function Win:SetTheme(name)
		local t = ThemeByName[name]
		if not t then return end
		State.Theme = name
		P = derive(t)
		Repaint(true)
	end
	function Win:Navigate(page, arg)
		if page == "Game" and type(arg) == "string" then
			for _, g in ipairs(Games) do if g.Name == arg then arg = g end end
		end
		Navigate(page, arg)
	end
	function Win:OpenModule(catName, modName)
		local cat = CategoryByName[catName]
		if not cat then return end
		for _, m in ipairs(cat.Modules) do if m.Name == modName then OpenModulePage(cat, m) end end
	end
	function Win:SetView(v) State.View = v end
	function Win:Collapse(c) SetCollapsed(c) end
	function Win:Toggle() SetOpen(not State.Open) end
	function Win:Search(text) if ActiveSearchBox then ActiveSearchBox:CaptureFocus(); ActiveSearchBox.Text = text end end
	function Win:Unload()
		if Unloaded then return end
		for _, cat in ipairs(Categories) do for _, m in ipairs(cat.Modules) do if m.Enabled then setEnabled(m, false) end end end
		Unloaded = true
		fire(opts.OnUnload)
		BlockGameInput(false)
		for _, c in ipairs(Conns) do pcall(function() c:Disconnect() end) end
		pcall(function() Blur:Destroy() end)
		pcall(function() Screen:Destroy() end)
		if Library._window == Win then Library._window = nil end
		if getgenv and getgenv().PrestigeUI == Win then getgenv().PrestigeUI = nil end
	end

	Library._window = Win
	if getgenv then getgenv().PrestigeUI = Win end
	SetOpen(true)
	-- first page once the caller has added its categories
	task.defer(function()
		if State.Page == nil and not Unloaded then
			if Hub or #Categories == 0 then Navigate("Games") else Navigate("Modules", Categories[1].Name) end
		end
	end)
	return Win
end

return Library
