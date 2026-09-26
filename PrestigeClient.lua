--[[
	Prestige Client — menu recreation (Roblox / Luau)
	Neon glows are UIShadow instances tinted with the theme accent.
	Toggle key: RightShift. Click the crown to collapse the sidebar.
	Uses sUNC helpers when available (gethui / cloneref / getgenv); falls back to PlayerGui.
]]

local cloneref = cloneref or function(x) return x end
local Players = cloneref(game:GetService("Players"))
local TweenService = cloneref(game:GetService("TweenService"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local RunService = cloneref(game:GetService("RunService"))
local Lighting = cloneref(game:GetService("Lighting"))
local ContextActionService = cloneref(game:GetService("ContextActionService"))

local LocalPlayer = Players.LocalPlayer

--------------------------------------------------------------------------- constants
local FONT_SANS = "rbxasset://fonts/families/BuilderSans.json"
local FONT_SERIF = "rbxasset://fonts/families/Merriweather.json"
local W = Enum.FontWeight
-- Builder Sans renders noticeably smaller and lighter than the reference font, so every sans label is
-- bumped one weight step and ~18% in size (see TS below)
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
local CONTENT_X = 259
local CONTENT_W = 810

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
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

local function derive(t)
	local acc = hex(t.Accent)
	local base = hex(t.Base):Lerp(acc, 0.04)
	return {
		Name = t.Name,
		Base = base,
		Accent = acc,
		Panel = base:Lerp(WHITE, 0.025):Lerp(acc, 0.03),
		Card = base:Lerp(WHITE, 0.035):Lerp(acc, 0.05),
		CardHover = base:Lerp(WHITE, 0.06):Lerp(acc, 0.08),
		Field = base:Lerp(WHITE, 0.045):Lerp(acc, 0.07),
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

local State = {
	Theme = "Aurora",
	Page = "Modules",
	Category = "Combat",
	View = "list",
	OpenModule = nil,
	Collapsed = false,
	MainColor = hex("5EEAD4"),
	MenuKey = Enum.KeyCode.RightShift,
	Search = "",
	Open = true,
}
local P = derive(ThemeByName[State.Theme])

--------------------------------------------------------------------------- data
local function M(name, desc, settings) return { Name = name, Desc = desc, Enabled = false, Bind = nil, BindMode = "Toggle", Settings = settings } end

local Categories = {
	{ Name = "Combat", Icon = "combat", Modules = {
		M("Aim Assist", "Aims at targets"),
		M("Anchor Exploder", "Automatically explodes respawn anchors for you"),
		M("Anchor Macro", "Explodes and places anchors automatically"),
		M("Anchor Pearl Catch", "Pre-places and detonates a respawn anchor where enemy pearls land"),
		M("Anchor Placer", "Automatically places respawn anchors for you"),
		M("Anti Action", "Prevents certain bad actions from interrupting your pvp", {
			{ Type = "toggle", Name = "Double Glowstone", Desc = "Blocks double-filling an anchor with glowstone.", Value = true },
			{ Type = "toggle", Name = "Open E-Chest", Desc = "Blocks opening an ender chest while holding combat items.", Value = true },
			{ Type = "toggle", Name = "Place Glowstone", Desc = "Blocks placing glowstone anywhere but an anchor.", Value = true },
			{ Type = "toggle", Name = "Ground Firework", Desc = "Blocks firing a firework rocket while not gliding on elytra. Skipped if a crossbow is in your offhand.", Value = true },
			{ Type = "toggle", Name = "Sword Shield", Desc = "Blocks hitting a shield with a sword.", Value = true },
		}),
		M("Anti Bot", "Filters out server-side bots from targeting"),
		M("Auto Clicker", "Clicks for you with a humanized pattern"),
		M("Auto Crystal", "Places and breaks end crystals automatically"),
		M("Auto Double Hand", "Swaps to a totem when you are about to pop"),
		M("Auto Hit Crystal", "Hit-crystals on obsidian when looking at a player"),
		M("Auto Inventory Totem", "Moves totems into your offhand from inventory"),
		M("Auto Pot", "Throws healing potions when low"),
		M("Auto Refill", "Refills your hotbar from your inventory"),
		M("Auto Totem", "Keeps a totem in your offhand"),
		M("Auto Weapon", "Switches to your best weapon on attack"),
		M("Backtrack", "Delays enemy positions for extra reach"),
		M("Block Hit", "Blocks with your sword between hits"),
		M("Xbow Cart", "Places and fires TNT minecarts with a crossbow"),
		M("Cobweb Placer", "Places cobwebs on the block your looking at", {
			{ Type = "toggle", Name = "Airborne Only", Desc = "Only fires while the target is airborne and falling.", Value = true },
			{ Type = "slider", Name = "Max Webs Per Fall", Desc = "Caps how many webs get placed per fall so it doesn't spam a stack; resets once the target lands.", Min = 1, Max = 8, Value = 5 },
			{ Type = "toggle", Name = "Silent", Desc = "Swaps between items server-side.", Value = false },
			{ Type = "dropdown", Name = "Switch Back", Desc = "Switches to a chosen slot or your original after placing.", Options = { "Original", "Slot", "Off" }, Value = "Slot" },
			{ Type = "slider", Name = "Switch Slot", Desc = "Switches to this hotbar slot after placing.", Min = 1, Max = 9, Value = 1 },
			{ Type = "dropdown", Name = "Swap", Desc = "None places only with cobweb in hand; Swap visibly switches to it.", Options = { "None", "Swap", "Silent" }, Value = "None" },
			{ Type = "toggle", Name = "From Inventory", Desc = "If no cobweb is in the hotbar, pulls one from the main inventory with a silent swap.", Value = true },
			{ Type = "toggle", Name = "Head Trap", Desc = "Also tries the head-level block; the best candidate wins.", Value = false },
			{ Type = "toggle", Name = "Render", Desc = "Outlines the predicted placement position.", Value = true },
			{ Type = "color", Name = "Render Color", Desc = "Sets the prediction outline color.", Value = hex("8F3FA4") },
		}),
		M("Criticals", "Lands a critical hit on every swing"),
		M("Crystal Optimizer", "Removes the client delay when breaking crystals"),
		M("Hitboxes", "Expands enemy hitboxes"),
		M("Hit Fix", "Fixes the 1.9+ attack registration delay"),
		M("Hover Totem", "Swaps to a totem when you hover it in inventory"),
		M("Jump Reset", "Jumps on hit to reduce knockback"),
		M("Key Pearl", "Throws a pearl with a single key"),
		M("Legit Totem", "Human-like offhand totem swaps"),
		M("Mace Swap", "Swaps to your mace mid-fall"),
		M("Offhand", "Manages what is in your offhand"),
		M("Pearl Catch", "Catches your own pearls with wind charges"),
		M("Pot Refill", "Refills potions into your hotbar"),
		M("Reach", "Extends your attack range"),
		M("Shield Breaker", "Switches to an axe to disable shields"),
		M("Silent Aim", "Redirects hits without moving your camera"),
		M("Sprint Reset", "Resets sprint between hits for more knockback"),
		M("Sticky Aim", "Locks onto the last target you hit"),
		M("Target HUD", "Shows info about your current target"),
		M("Totem Refill", "Refills your offhand totem instantly"),
		M("Trigger Bot", "Attacks when your crosshair is on a target"),
		M("W Tap", "Taps W between hits to reset sprint"),
	} },
	{ Name = "Mace", Icon = "mace", Modules = {
		M("Auto Mace", "Switches to mace when falling onto a target"),
		M("Breach Swap", "Swaps to a breach mace against armor"),
		M("Density Swap", "Swaps to a density mace on high falls"),
		M("Elytra Swap", "Swaps chestplate and elytra on demand"),
		M("Fall Predictor", "Shows where you will land"),
		M("Mace Aura", "Hits nearby targets while falling"),
		M("Mace Combo", "Chains mace hits with wind charges"),
		M("Mace Damage Indicator", "Shows the damage your smash will deal"),
		M("Mace Macro", "Runs a full mace combo on one key"),
		M("Pearl Mace", "Pearls up and smashes in one motion"),
		M("Stun Slam", "Stuns shields before slamming"),
		M("Wind Burst", "Uses wind burst to stay airborne"),
		M("Wind Charge Jump", "Launches you with a wind charge"),
		M("Smash Timer", "Shows the best moment to smash"),
	} },
	{ Name = "Misc", Icon = "misc", Modules = {
		M("Auto Armor", "Equips the best armor in your inventory"), M("Auto Eat", "Eats food when hungry"),
		M("Auto Pickaxe", "Swaps to the best pickaxe when mining"), M("Auto Text", "Sends preset chat messages on a key"),
		M("Auto Reconnect", "Reconnects when kicked"), M("Auto Respawn", "Respawns instantly"),
		M("Auto Tool", "Switches to the best tool for a block"), M("Chat Filter", "Hides unwanted chat messages"),
		M("Chest Stealer", "Takes all items from chests"), M("Discord RPC", "Shows your game in Discord"),
		M("Fake Player", "Spawns a client-side dummy"), M("Fast EXP", "Throws experience bottles faster"),
		M("Friends", "Prevents targeting your friends"), M("Inventory Cleaner", "Drops junk items"),
		M("Inventory Move", "Lets you move while in inventories"), M("Middle Click Friend", "Adds friends with middle click"),
		M("Name Protect", "Hides your name client-side"), M("No Break Delay", "Removes the block break delay"),
		M("No Rotate", "Stops the server from rotating you"), M("Notifier", "Alerts you about events"),
		M("Packet Mine", "Mines blocks with packets"), M("Panic", "Disables every module"),
		M("Scaffold", "Places blocks under you"), M("Spammer", "Sends messages on an interval"),
		M("Timer", "Changes the game speed"), M("Totem Pop Notifier", "Announces totem pops"),
		M("XCarry", "Stores items in the crafting grid"),
	} },
	{ Name = "Movement", Icon = "movement", Modules = {
		M("Auto Sprint", "Keeps you sprinting"), M("Auto Walk", "Walks forward for you"),
		M("Elytra Fly", "Improves elytra flight"), M("Fast Stop", "Stops momentum instantly"),
		M("Flight", "Lets you fly"), M("Jesus", "Walk on water"), M("No Fall", "Removes fall damage"),
		M("No Slow", "Removes item slowdown"), M("Safe Walk", "Stops you walking off edges"),
		M("Speed", "Moves you faster"), M("Step", "Steps up full blocks"),
	} },
	{ Name = "Spear", Icon = "spear", Modules = {
		M("Spear Damage Indicator", "Shows how much damage you have accumulated for the spear"),
		M("Spear Lunge", "Times your lunge for max damage"),
		M("Spear Swap", "Swaps to the spear when charging"),
		M("Auto Spear", "Throws and recalls automatically"),
	} },
	{ Name = "Visual", Icon = "visual", Modules = {
		M("Ambience", "Changes the ambience of the game"), M("Animations", "Renders custom smooth swing animations"),
		M("Anti Resource Pack", "Prevents servers from forcing a resource pack"), M("ESP", "Renders various things through walls"),
		M("Free Look", "Allows you to look around without rotating"), M("Health Indicators", "Shows health on players"),
		M("Hit Effects", "Adds effects when you hit a player"), M("Hitbox Render", "Draws entity hitboxes"),
		M("Item Physics", "Dropped items fall with physics"), M("Nametags", "Better nametags with armor and health"),
		M("No Hurt Cam", "Removes the hurt camera shake"), M("No Overlay", "Removes fire and water overlays"),
		M("Particles", "Changes hit particles"), M("Block Outline", "Customises the block outline"),
		M("Chams", "Renders players through walls"), M("Crosshair", "Custom crosshair"),
		M("Fullbright", "Makes everything bright"), M("Time Changer", "Changes the client time"),
		M("Trajectories", "Shows where projectiles will land"), M("Tracers", "Draws lines to players"),
		M("Totem Pop Counter", "Counts enemy totem pops"), M("View Model", "Moves your held item"),
		M("Weather", "Changes the client weather"), M("Zoom", "Zooms in like OptiFine"),
	} },
}
local CategoryByName = {}
for _, c in ipairs(Categories) do table.sort(c.Modules, function(a, b) return a.Name:lower() < b.Name:lower() end) end
for _, c in ipairs(Categories) do CategoryByName[c.Name] = c end

local Configs = {
	{ "Crystal Pvp Config", "My personal crystal pvp config, pretty unlegit", "Prestige", "2026-07-06 11:44:45", {}, 9730 },
	{ "lt3 ht3 Legit Sword", "RMB WTAP, LMB TBOT, AUTO JUMP RESET GOT ME LT3", "AlyssaXoXo", "2025-09-14 19:02:53", { "Sword", "Legit" }, 9356 },
	{ "MACE LT2", "MACE LT2", "sixsven", "2025-11-05 11:53:43", { "Legit", "Blatant" }, 6862 },
	{ "Donut SMP", "This config I use for donut SMP, be careful.", "Prestige", "2025-05-28 13:54:49", { "Crystal", "Legit" }, 5615 },
	{ "crystal", "maybe legit anchor", "Ediee", "2026-08-25 14:31:48", { "Crystal", "Legit" }, 5251 },
	{ "Best Legit Config", "Its Updated for new version dc @ansterq", "ansterq", "2026-03-28 09:36:12", { "Crystal", "Sword", "Legit" }, 4407 },
	{ "HT2", "leggit", "Filipchicken", "2026-04-09 21:27:15", { "Crystal", "Sword", "Legit" }, 4130 },
	{ "Possible ht3 crystal", "closet auto crystal, anchor mace, semicloset atot", "plutorawr", "2025-05-21 18:16:49", {}, 3931 },
	{ "MaceConfig", "pressharming", "EatMyMace", "2026-01-21 20:51:32", {}, 3834 },
	{ "Sword Only", "clean sword config, nothing blatant", "kiwi", "2026-02-11 10:12:05", { "Sword" }, 3120 },
	{ "Anchor God", "anchor macro + pearl catch", "zyph", "2025-12-02 16:40:22", { "Crystal" }, 2988 },
	{ "Closet", "closet everything", "Prestige", "2026-06-30 08:01:10", { "Legit" }, 2710 },
}

--------------------------------------------------------------------------- helpers
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
	return New("UIStroke", { Color = color, Thickness = thick or 1, Transparency = transp or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = parent })
end
local function Pad(parent, l, r, t, b)
	return New("UIPadding", { PaddingLeft = UDim.new(0, l or 0), PaddingRight = UDim.new(0, r or l or 0),
		PaddingTop = UDim.new(0, t or 0), PaddingBottom = UDim.new(0, b or t or 0), Parent = parent })
end
local function Glow(parent, color, blur, transp, spread)
	-- neon glow: a UIShadow with no offset, tinted with the accent
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
		if p.inst.Parent ~= nil then
			p.fn(animate)
			keep[#keep + 1] = p
		end
	end
	Painters = keep
end

--------------------------------------------------------------------------- icons (Lucide icon sprite sheets already uploaded to Roblox by lucide-roblox, 48px cells)
-- { spritesheet asset id, x, y } ; each icon is a 48x48 white glyph so ImageColor3 tints it
local ICONS = {
	combat = { 16898613777, 967, 759 },   -- swords
	mace = { 16898613509, 306, 820 },     -- hammer
	misc = { 16898613869, 820, 906 },     -- wrench
	movement = { 16898613699, 563, 771 }, -- person-standing
	spear = { 16898612629, 918, 147 },    -- arrow-up-right
	visual = { 16898613353, 771, 563 },   -- eye
	settings = { 16898613613, 49, 820 },  -- menu
	theme = { 16898613613, 453, 918 },    -- palette
	configs = { 16898613353, 404, 967 },  -- folder
	socials = { 16898613869, 967, 98 },   -- users
	keybinds = { 16898613509, 453, 820 }, -- keyboard
	search = { 16898613699, 918, 857 },
	crown = { 16898613044, 404, 918 },
	chevron = { 16898612819, 869, 759 },  -- chevron-right
	chevronLeft = { 16898612819, 404, 967 },
	chevronDown = { 16898612819, 196, 918 },
	check = { 16898612819, 710, 869 },
	list = { 16898613509, 869, 808 },
	grid = { 16898613509, 918, 404 },     -- layout-grid
}

-- Filled glyphs matching the reference (icons8 "ios-filled", white, 100px). Downloaded once through the
-- executor (request / HttpGet), cached with writefile and loaded with getcustomasset. If any of those sUNC
-- functions is missing, the Lucide asset above is used instead.
local FILLED = {
	combat = "wrestling", mace = "hammer", misc = "wrench", movement = "running", spear = "up-right-arrow",
	visual = "visible", settings = "menu", theme = "paint-palette", configs = "opened-folder", socials = "groups",
	keybinds = "keyboard", search = "search", crown = "crown",
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

-- Icon(parent, name, props, colorFn) -> ImageLabel, setColor(color, animate)
local function Icon(parent, name, props, colorFn)
	local def = ICONS[name]
	local custom = filledAsset(name)
	local img = New("ImageLabel", { Parent = parent, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromOffset(16, 16),
		ScaleType = Enum.ScaleType.Fit })
	if custom then
		img.Image = custom
	else
		img.Image = "rbxassetid://" .. def[1]
		img.ImageRectOffset = Vector2.new(def[2], def[3])
		img.ImageRectSize = Vector2.new(48, 48)
	end
	for k, v in pairs(props or {}) do img[k] = v end
	local function color(c, animate) Set(img, { ImageColor3 = c }, animate) end
	if colorFn then Paint(img, function(a) color(colorFn(), a) end) end
	return img, color
end

--------------------------------------------------------------------------- root
local function guiParent()
	local ok, h = pcall(function() return gethui and gethui() end)
	if ok and h then return h end
	return LocalPlayer:WaitForChild("PlayerGui")
end

local old = guiParent():FindFirstChild("PrestigeClient")
if old then old:Destroy() end

local Screen = New("ScreenGui", { Name = "PrestigeClient", ResetOnSpawn = false, IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999 })
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
local WindowGrad = New("UIGradient", { Rotation = 40, Parent = Window,
	Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(160, 160, 160)) }) })

local function fitScale()
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
	return math.clamp(math.min(vp.X / 1920, vp.Y / 1010), 0.5, 1.4)
end
WindowScale.Scale = fitScale()

-- ambient accent glow inside the window (UIShadow on tiny transparent blobs, clipped to the window body)
-- ambient blooms live in a rounded CanvasGroup the size of the window, so they fade out inside the glass
-- instead of stopping at a square clip
local GlowLayer = New("CanvasGroup", { Name = "GlowLayer", Parent = Window, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), ZIndex = 1 })
Corner(22, GlowLayer)
-- a radial bloom = several concentric UIShadows (moderate blur each) on a 2px dot
local BLOOM_ANCHOR = Vector2.new(-60, -60)
local function Bloom(pos, rings, step, blur, transp)
	-- The host must be opaque (UIShadow opacity is scaled by its parent's BackgroundTransparency), so it sits
	-- outside the rounded CanvasGroup where it is clipped away, and UIShadow.Offset moves the glow into place.
	-- Nothing but the glow itself is ever visible.
	local dot = Frame({ Parent = GlowLayer, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(BLOOM_ANCHOR.X, BLOOM_ANCHOR.Y),
		Size = UDim2.fromOffset(2, 2), BackgroundTransparency = 0, BackgroundColor3 = P.Base })
	Round(dot)
	local shadows = {}
	for i = 1, rings do
		shadows[i] = New("UIShadow", { Color = P.Accent, BlurRadius = UDim.new(0, blur), Transparency = transp,
			Offset = UDim2.fromOffset(pos.X.Offset - BLOOM_ANCHOR.X, pos.Y.Offset - BLOOM_ANCHOR.Y),
			Spread = UDim2.fromOffset(i * step, i * step), ZIndex = -i, Parent = dot })
	end
	return dot, shadows
end
local Blob1, Blob1Glow = Bloom(UDim2.fromOffset(620, 300), 1, 140, 240, 0.76)
local Blob2, Blob2Glow = Bloom(UDim2.fromOffset(470, 70), 1, 90, 170, 0.84)
local Blob3, Blob3Glow = Bloom(UDim2.fromOffset(850, 320), 1, 110, 200, 0.78)

-- where the ambient bloom sits on each page (GlowLayer space)
local GlowSpots = {
	Modules = Vector2.new(560, 330), Theme = Vector2.new(600, 250), Settings = Vector2.new(610, 440),
	Configs = Vector2.new(660, 60), Socials = Vector2.new(640, 260), Keybinds = Vector2.new(640, 250),
}
local function PlaceGlow(page, instant)
	local p = GlowSpots[page] or Vector2.new(620, 300)
	local t = instant and 0 or 0.6
	Tween(Blob1Glow[1], { Offset = UDim2.fromOffset(p.X - BLOOM_ANCHOR.X, p.Y - BLOOM_ANCHOR.Y) }, t, Enum.EasingStyle.Sine)
	Tween(Blob3Glow[1], { Offset = UDim2.fromOffset(p.X + 230 - BLOOM_ANCHOR.X, p.Y + 20 - BLOOM_ANCHOR.Y) }, t, Enum.EasingStyle.Sine)
end

Paint(Window, function(a)
	Set(Window, { BackgroundColor3 = P.Base }, a)
	Set(WindowStroke, { Color = P.Stroke:Lerp(WHITE, 0.2) }, a)
	Set(WindowGlow, { Color = P.Accent }, a)

	for _, list in ipairs({ Blob1Glow, Blob2Glow, Blob3Glow }) do
		for _, s in ipairs(list) do Set(s, { Color = P.Accent }, a) end
	end
end)

-- overlay layer for dropdowns / popups / toasts (window space)
local Overlay = Frame({ Name = "Overlay", Parent = Window, Size = UDim2.fromScale(1, 1), ZIndex = 50 })

local function toWindowSpace(guiObj)
	local s = WindowScale.Scale
	local rel = guiObj.AbsolutePosition - Window.AbsolutePosition
	return Vector2.new(rel.X / s, rel.Y / s), Vector2.new(guiObj.AbsoluteSize.X / s, guiObj.AbsoluteSize.Y / s)
end

--------------------------------------------------------------------------- generic controls
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
		Set(track, { BackgroundColor3 = on and (hovered and P.Accent:Lerp(WHITE, 0.1) or P.Accent) or P.Track, BackgroundTransparency = on and 0 or 0.35 }, a)
		Set(stroke, { Color = on and P.Accent or P.StrokeSoft, Transparency = on and 0.5 or 0.35 }, a)
		Set(glow, { Color = P.Accent, Transparency = on and (hovered and 0.15 or 0.3) or 1 }, a)
		Set(knob, { Position = on and UDim2.new(1, -20, 0.5, 0) or UDim2.new(0, 4, 0.5, 0), BackgroundColor3 = on and Color3.fromRGB(245, 255, 253):Lerp(P.Accent, 0.08) or WHITE }, a)
	end
	Paint(track, refresh)
	track.MouseButton1Click:Connect(function()
		onToggle()
		refresh(true)
	end)
	track.MouseEnter:Connect(function() hovered = true; refresh(true) end)
	track.MouseLeave:Connect(function() hovered = false; refresh(true) end)
	return track, refresh
end

local function Chip(parent, text, props)
	local b = Button({ Parent = parent, Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 0.4,
		Text = text, TextSize = 13, FontFace = Sans(W.Medium) })
	for k, v in pairs(props or {}) do b[k] = v end
	Round(b)
	Pad(b, 14, 14, 0, 0)
	local s = Stroke(b, P.StrokeSoft, 1, 0.15)
	Paint(b, function(a)
		Set(b, { BackgroundColor3 = P.Field, TextColor3 = P.Label }, a)
		Set(s, { Color = P.StrokeSoft }, a)
	end)
	b.MouseEnter:Connect(function() Tween(s, { Color = P.Accent:Lerp(P.Base, 0.5) }, 0.15) end)
	b.MouseLeave:Connect(function() Tween(s, { Color = P.StrokeSoft }, 0.15) end)
	return b
end

local function SearchBox(parent, placeholder, props, onChanged)
	local box = Frame({ Parent = parent, BackgroundTransparency = 0, Size = UDim2.fromOffset(308, 36) })
	for k, v in pairs(props or {}) do box[k] = v end
	Corner(9, box)
	local s = Stroke(box, P.StrokeSoft, 1, 0.1)
	local _, colorIcon = Icon(box, "search", { Position = UDim2.new(0, 13, 0.5, -7), Size = UDim2.fromOffset(14, 14) }, function() return P.Sub end)
	local tb = New("TextBox", { Parent = box, BackgroundTransparency = 1, Position = UDim2.fromOffset(38, 0), Size = UDim2.new(1, -46, 1, 0),
		Text = "", PlaceholderText = placeholder, FontFace = Sans(), TextSize = TS(13), TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false })
	Paint(box, function(a)
		Set(box, { BackgroundColor3 = P.Base:Lerp(P.Field, 0.55) }, a)
		Set(s, { Color = P.StrokeSoft }, a)
		tb.TextColor3 = P.Text
		tb.PlaceholderColor3 = P.Sub
	end)
	local focusGlow = Glow(box, P.Accent, 14, 1, 0)
	local function focusFx(on)
		focusGlow.Color = P.Accent
		Tween(s, { Color = on and P.Accent or P.StrokeSoft, Transparency = 0.1, Thickness = on and 1.5 or 1 }, 0.15)
		Tween(focusGlow, { Transparency = on and 0.6 or 1 }, 0.15)
	end
	tb.Focused:Connect(function() focusFx(true) end)
	tb.FocusLost:Connect(function() focusFx(false) end)
	if onChanged then tb:GetPropertyChangedSignal("Text"):Connect(function() onChanged(tb.Text) end) end
	return box, tb, focusFx
end

local function Tabs(parent, names, active, onSelect, x, y, w)
	local tabs = {}
	local function refresh(a)
		for i, t in ipairs(tabs) do
			local on = (names[i] == active)
			Set(t.btn, { BackgroundColor3 = on and P.Accent or P.Field, BackgroundTransparency = on and 0.05 or 0.45,
				TextColor3 = on and WHITE or P.Label }, a)
			Set(t.stroke, { Color = on and P.Accent or P.StrokeSoft, Transparency = on and 0.4 or 0.45 }, a)
			Set(t.glow, { Color = P.Accent, Transparency = on and 0.72 or 1 }, a)
		end
	end
	for i, n in ipairs(names) do
		local b = Button({ Parent = parent, Position = UDim2.fromOffset(x + (i - 1) * (w + 12), y), Size = UDim2.fromOffset(w, 36),
			Text = n, TextSize = 13, FontFace = Sans(W.Medium), BackgroundTransparency = 0 })
		Corner(7, b)
		local st = Stroke(b, P.StrokeSoft, 1, 0.3)
		local gl = Glow(b, P.Accent, 18, 1, 0)
		tabs[i] = { btn = b, stroke = st, glow = gl }
		b.MouseButton1Click:Connect(function()
			active = n
			refresh(true)
			if onSelect then onSelect(n) end
		end)
	end
	Paint(tabs[1].btn, refresh)
	return tabs
end

--------------------------------------------------------------------------- toast
local ToastHolder
local function Toast(text)
	if ToastHolder then ToastHolder:Destroy() end
	local t = Frame({ Parent = Overlay, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -22, 1, 22), Size = UDim2.fromOffset(0, 34),
		AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 0.05, BackgroundColor3 = P.Panel, ZIndex = 60 })
	ToastHolder = t
	Corner(9, t)
	Stroke(t, P.Stroke, 1, 0.1)
	DropShadow(t, 18, 0.5, 4)
	Pad(t, 12, 12, 0, 0)
	New("UIListLayout", { Parent = t, FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
	local dot = Frame({ Parent = t, Size = UDim2.fromOffset(9, 9), BackgroundTransparency = 0, BackgroundColor3 = P.Accent, LayoutOrder = 1, ZIndex = 61 })
	Round(dot); Glow(dot, P.Accent, 8, 0.3, 1)
	Label({ Parent = t, Size = UDim2.fromOffset(0, 34), AutomaticSize = Enum.AutomaticSize.X, Text = text, TextSize = 13, TextColor3 = P.Text, LayoutOrder = 2, ZIndex = 61 })
	Tween(t, { Position = UDim2.new(1, -22, 1, -24) }, 0.35, Enum.EasingStyle.Quint)
	task.delay(2.4, function()
		if ToastHolder == t then
			local tw = Tween(t, { Position = UDim2.new(1, -22, 1, 60) }, 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			tw.Completed:Connect(function() if ToastHolder == t then t:Destroy(); ToastHolder = nil end end)
		end
	end)
end

--------------------------------------------------------------------------- popups (dropdown / colour picker)
local ActivePopup
local function ClosePopup()
	if ActivePopup then ActivePopup:Destroy(); ActivePopup = nil end
end

local function Checker(parent, cols, rows, size)
	for y = 0, rows - 1 do
		for x = 0, cols - 1 do
			Frame({ Parent = parent, Position = UDim2.fromOffset(x * size, y * size), Size = UDim2.fromOffset(size, size), BackgroundTransparency = 0,
				BackgroundColor3 = ((x + y) % 2 == 0) and Color3.fromRGB(120, 120, 128) or Color3.fromRGB(70, 70, 76) })
		end
	end
end

-- builds an HSV colour picker into `parent`; returns a setter
local function ColorPicker(parent, pos, initial, onChange)
	local h, s, v = initial:ToHSV()
	local alpha = 1
	local root = Frame({ Parent = parent, Position = pos, Size = UDim2.fromOffset(206, 250) })

	local sv = Frame({ Parent = root, Size = UDim2.fromOffset(170, 170), BackgroundTransparency = 0 })
	Corner(4, sv)
	local white = Frame({ Parent = sv, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0, BackgroundColor3 = WHITE })
	Corner(4, white)
	New("UIGradient", { Parent = white, Transparency = NumberSequence.new(0, 1) })
	local black = Frame({ Parent = sv, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0, BackgroundColor3 = BLACK })
	Corner(4, black)
	New("UIGradient", { Parent = black, Rotation = 90, Transparency = NumberSequence.new(1, 0) })
	local cursor = Frame({ Parent = sv, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(11, 11), ZIndex = 3 })
	Round(cursor); Stroke(cursor, WHITE, 2, 0)
	DropShadow(cursor, 4, 0.4, 0)

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
	local alphaCursor = Frame({ Parent = root, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(196, 180), Size = UDim2.fromOffset(4, 16), BackgroundTransparency = 0, BackgroundColor3 = WHITE, ZIndex = 3 })
	Corner(2, alphaCursor); Stroke(alphaCursor, BLACK, 1, 0.5)

	local swatch = Frame({ Parent = root, Position = UDim2.fromOffset(0, 206), Size = UDim2.fromOffset(28, 28), BackgroundTransparency = 0 })
	Corner(5, swatch); Stroke(swatch, WHITE, 1, 0.85)
	local hexBox = New("TextBox", { Parent = root, Position = UDim2.fromOffset(38, 206), Size = UDim2.fromOffset(158, 28), BackgroundTransparency = 0.1,
		BorderSizePixel = 0, Text = "", FontFace = Sans(W.Medium), TextSize = TS(12), TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false })
	Corner(5, hexBox); Pad(hexBox, 9, 9, 0, 0)
	local hexStroke = Stroke(hexBox, P.StrokeSoft, 1, 0.2)
	Paint(hexBox, function(a)
		Set(hexBox, { BackgroundColor3 = P.Field, TextColor3 = P.Label }, a)
		Set(hexStroke, { Color = P.StrokeSoft }, a)
	end)

	local function update(fire)
		local c = Color3.fromHSV(h, s, v)
		sv.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
		cursor.Position = UDim2.fromScale(s, 1 - v)
		hueCursor.Position = UDim2.new(0.5, 0, h, 0)
		alphaFill.BackgroundColor3 = c
		alphaCursor.Position = UDim2.fromOffset(2 + alpha * 192, 180)
		swatch.BackgroundColor3 = c
		hexBox.Text = "#" .. c:ToHex():upper()
		if fire and onChange then onChange(c, alpha) end
	end
	update(false)

	local dragging
	local function drag(pos)
		if dragging == "sv" then
			local p, sz = sv.AbsolutePosition, sv.AbsoluteSize
			s = math.clamp((pos.X - p.X) / sz.X, 0, 1)
			v = 1 - math.clamp((pos.Y - p.Y) / sz.Y, 0, 1)
		elseif dragging == "hue" then
			local p, sz = hue.AbsolutePosition, hue.AbsoluteSize
			h = math.clamp((pos.Y - p.Y) / sz.Y, 0, 0.999)
		elseif dragging == "alpha" then
			local p, sz = alphaBar.AbsolutePosition, alphaBar.AbsoluteSize
			alpha = math.clamp((pos.X - p.X) / sz.X, 0, 1)
		end
		update(true)
	end
	local function hook(obj, name)
		obj.InputBegan:Connect(function(io)
			if io.UserInputType == Enum.UserInputType.MouseButton1 then dragging = name; drag(io.Position) end
		end)
	end
	hook(sv, "sv"); hook(hue, "hue"); hook(alphaBar, "alpha")
	local c1 = UserInputService.InputChanged:Connect(function(io)
		if dragging and io.UserInputType == Enum.UserInputType.MouseMovement then drag(io.Position) end
	end)
	local c2 = UserInputService.InputEnded:Connect(function(io)
		if io.UserInputType == Enum.UserInputType.MouseButton1 then dragging = nil end
	end)
	hexBox.FocusLost:Connect(function()
		local ok, c = pcall(Color3.fromHex, (hexBox.Text:gsub("#", "")))
		if ok and c then h, s, v = c:ToHSV() end
		update(true)
	end)
	return root, function() c1:Disconnect(); c2:Disconnect() end
end

local function OpenPopupAt(anchor, width, height, build)
	ClosePopup()
	local pos, size = toWindowSpace(anchor)
	local x = math.min(pos.X + size.X - width, WIN_W - width - 12)
	local y = pos.Y + size.Y + 6
	if y + height > WIN_H - 8 then y = pos.Y - height - 6 end
	local pop = Button({ Parent = Overlay, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(width, height), BackgroundTransparency = 0.02, ZIndex = 70 })
	Corner(9, pop)
	local st = Stroke(pop, P.Stroke, 1, 0.1)
	DropShadow(pop, 28, 0.45, 8)
	pop.BackgroundColor3 = P.Panel:Lerp(P.Base, 0.3)
	ActivePopup = pop
	build(pop)
	return pop
end

--------------------------------------------------------------------------- window skeleton: sidebar
local Sidebar = Frame({ Name = "Sidebar", Parent = Window, Position = UDim2.fromOffset(14, 14), Size = UDim2.new(0, SIDEBAR_W, 1, -28),
	BackgroundTransparency = 0.25, ClipsDescendants = true, ZIndex = 2 })
Corner(16, Sidebar)
local SidebarStroke = Stroke(Sidebar, P.StrokeSoft, 1, 0.1)
Paint(Sidebar, function(a)
	Set(Sidebar, { BackgroundColor3 = P.Panel:Lerp(BLACK, 0.12) }, a)
	Set(SidebarStroke, { Color = P.Stroke }, a)
end)

local CrownBtn = Button({ Parent = Sidebar, Position = UDim2.fromOffset(10, 12), Size = UDim2.fromOffset(40, 36), ZIndex = 3 })
local crown = Icon(CrownBtn, "crown", { Position = UDim2.new(0.5, -8, 0.5, -8) }, function() return P.Accent end)
local BrandTitle = Label({ Parent = Sidebar, Position = UDim2.fromOffset(49, 14), Size = UDim2.fromOffset(170, 20), TextSize = 15,
	FontFace = Serif(W.Bold), RichText = true, ZIndex = 3 })
local BrandVer = Label({ Parent = Sidebar, Position = UDim2.fromOffset(49, 33), Size = UDim2.fromOffset(170, 12), TextSize = 10, Text = "RELEASE 4.4.0", ZIndex = 3 })
Paint(BrandTitle, function(a)
	BrandTitle.Text = 'Prestige <i><font color="' .. toHex(P.AccentPale) .. '">Client</font></i>'
	Set(BrandTitle, { TextColor3 = P.Text }, a)
	Set(BrandVer, { TextColor3 = P.Muted }, a)
end)

local NavItems = {}
local Navigate -- forward

local function SectionLabel(text, y)
	local l = Label({ Parent = Sidebar, Position = UDim2.fromOffset(23, y), Size = UDim2.fromOffset(150, 14), Text = text, TextSize = 11, ZIndex = 3 })
	Paint(l, function(a) Set(l, { TextColor3 = P.Muted }, a) end)
	return l
end

local function NavItem(key, text, icon, y, count)
	local b = Button({ Parent = Sidebar, Position = UDim2.fromOffset(11, y), Size = UDim2.new(1, -22, 0, 40), BackgroundTransparency = 1, ZIndex = 3 })
	Corner(10, b)
	local st = Stroke(b, P.Accent, 1, 1)
	local ic, colorIcon = Icon(b, icon, { Position = UDim2.new(0, 11, 0.5, -9), Size = UDim2.fromOffset(18, 18), ZIndex = 4 })
	local lbl = Label({ Parent = b, Position = UDim2.fromOffset(38, 0), Size = UDim2.new(1, -80, 1, 0), Text = text, TextSize = 13, ZIndex = 4 })
	local cnt
	if count then
		cnt = Label({ Parent = b, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -13, 0, 0), Size = UDim2.fromOffset(30, 40),
			Text = tostring(count), TextSize = 11, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 4 })
	end
	local item = { key = key, btn = b, hover = false }
	function item.refresh(a)
		local sel = (State.Page == "Modules" and State.Category == key) or (State.Page == key)
		local bg = sel and P.AccentSoft or P.Card
		Set(b, { BackgroundColor3 = bg, BackgroundTransparency = sel and 0.08 or (item.hover and 0.45 or 1) }, a)
		Set(st, { Color = P.Accent, Transparency = sel and 0.72 or 1 }, a)
		colorIcon(sel and P.Accent or P.Label:Lerp(P.Base, 0.12), a)
		Set(lbl, { TextColor3 = sel and P.Text or P.Label, TextTransparency = State.Collapsed and 1 or 0 }, a)
		if cnt then Set(cnt, { TextColor3 = sel and P.Label or P.Muted, TextTransparency = State.Collapsed and 1 or 0 }, a) end
	end
	item.icon = ic
	Paint(b, item.refresh)
	b.MouseEnter:Connect(function() item.hover = true; item.refresh(true) end)
	b.MouseLeave:Connect(function() item.hover = false; item.refresh(true) end)
	b.MouseButton1Click:Connect(function()
		if count then Navigate("Modules", key) else Navigate(key) end
	end)
	NavItems[#NavItems + 1] = item
	return item
end

local SecModules = SectionLabel("MODULES", 81)
for i, c in ipairs(Categories) do NavItem(c.Name, c.Name, c.Icon, 115 + (i - 1) * 44, #c.Modules) end
local Divider = Frame({ Parent = Sidebar, Position = UDim2.fromOffset(23, 396), Size = UDim2.new(1, -46, 0, 1), BackgroundTransparency = 0, ZIndex = 3 })
local DividerGrad = New("UIGradient", { Parent = Divider, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.25), NumberSequenceKeypoint.new(1, 1) }) })
Paint(Divider, function(a) Set(Divider, { BackgroundColor3 = P.Stroke:Lerp(P.Accent, 0.35) }, a) end)
local SecGeneral = SectionLabel("GENERAL", 414)
local generalNav = { { "Settings", "settings" }, { "Theme", "theme" }, { "Configs", "configs" }, { "Socials", "socials" }, { "Keybinds", "keybinds" } }
for i, g in ipairs(generalNav) do NavItem(g[1], g[1], g[2], 443 + (i - 1) * 44) end

local function refreshNav(a) for _, n in ipairs(NavItems) do n.refresh(a) end end

--------------------------------------------------------------------------- content area
local Content = Frame({ Name = "Content", Parent = Window, Position = UDim2.fromOffset(CONTENT_X, 0), Size = UDim2.new(0, CONTENT_W, 1, 0), ZIndex = 2 })
local PageHolder
local Title = Label({ Parent = Content, Position = UDim2.fromOffset(0, 28), Size = UDim2.fromOffset(500, 34), TextSize = 23, FontFace = Serif(W.Bold), RichText = true, ZIndex = 3 })
local Subtitle = Label({ Parent = Content, Position = UDim2.fromOffset(0, 65), Size = UDim2.fromOffset(500, 16), TextSize = 12, ZIndex = 3 })
local TitleParts = { accent = nil, rest = "" }
local function SetTitle(accentWord, rest, sub)
	TitleParts.accent = accentWord; TitleParts.rest = rest
	Subtitle.Text = sub or ""
end
Paint(Title, function(a)
	if TitleParts.accent then
		Title.Text = '<i><font color="' .. toHex(P.AccentPale) .. '">' .. TitleParts.accent .. '</font></i> ' .. TitleParts.rest
	else
		Title.Text = TitleParts.rest
	end
	Set(Title, { TextColor3 = P.Text }, a)
	Set(Subtitle, { TextColor3 = P.Sub }, a)
end)
local function RefreshTitle() for _, p in ipairs(Painters) do if p.inst == Title then p.fn(false) end end end

--------------------------------------------------------------------------- module pages
local function enabledCount(cat)
	local n = 0
	for _, m in ipairs(cat.Modules) do if m.Enabled then n = n + 1 end end
	return n
end
local function moduleSub(cat) return #cat.Modules .. " modules · " .. enabledCount(cat) .. " enabled" end

local function KeyName(k)
	if not k then return "None" end
	local n = k.Name
	local map = { RightShift = "Right Shift", LeftShift = "Left Shift", RightControl = "Right Ctrl", LeftControl = "Left Ctrl",
		RightAlt = "Right Alt", LeftAlt = "Left Alt", Return = "Enter" }
	return map[n] or n
end

local ModuleCard -- forward
local OpenModulePage -- forward

local function BuildModuleList(page, cat)
	local list = New("ScrollingFrame", { Parent = page, Position = UDim2.fromOffset(-22, 144), Size = UDim2.new(1, 44, 1, -156), BackgroundTransparency = 1,
		BorderSizePixel = 0, ScrollBarThickness = 0, ScrollBarImageTransparency = 1, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 3 })
	Pad(list, 24, 24, 8, 12) -- side padding leaves room for the neon glows so they never clip
	if State.View == "grid" then
		New("UIGridLayout", { Parent = list, CellSize = UDim2.new(1 / 3, -8, 0, 112), CellPadding = UDim2.fromOffset(11, 11), SortOrder = Enum.SortOrder.LayoutOrder })
	else
		New("UIListLayout", { Parent = list, Padding = UDim.new(0, 11), SortOrder = Enum.SortOrder.LayoutOrder })
	end
	local q = "" -- the list is never filtered; search lives in the dropdown
	local shown = 0
	for i, m in ipairs(cat.Modules) do
		if q == "" or m.Name:lower():find(q, 1, true) then
			shown = shown + 1
			ModuleCard(list, cat, m, i, page)
		end
	end
	if shown == 0 then
		local l = Label({ Parent = list, Size = UDim2.new(1, 0, 0, 120), Text = "No modules match \"" .. State.Search .. "\"", TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center })
		Paint(l, function(a) Set(l, { TextColor3 = P.Sub }, a) end)
	end
	return list
end

function ModuleCard(parent, cat, m, order, page)
	local grid = State.View == "grid"
	local card = Button({ Parent = parent, Size = UDim2.new(1, 0, 0, 74), BackgroundTransparency = 0.3, LayoutOrder = order, ZIndex = 3 })
	Corner(10, card)
	local st = Stroke(card, P.StrokeSoft, 1, 0.2)
	local bar = Frame({ Parent = card, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0), Size = UDim2.new(0, 3, 1, -22), BackgroundTransparency = 1, ZIndex = 4 })
	Round(bar)
	local barGlow = Glow(bar, P.Accent, 12, 1, 2)
	local title = Label({ Parent = card, Position = UDim2.fromOffset(19, grid and 16 or 15), Size = UDim2.new(1, grid and -30 or -140, 0, 20), Text = m.Name, TextSize = 16,
		FontFace = Sans(W.Medium), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4 })
	local desc = Label({ Parent = card, Position = UDim2.fromOffset(19, grid and 40 or 39), Size = UDim2.new(1, grid and -34 or -140, 0, grid and 38 or 16), Text = m.Desc, TextSize = 12,
		TextWrapped = grid, TextYAlignment = Enum.TextYAlignment.Top, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4 })
	local chevronHolder, colorChevron = Icon(card, "chevron", { AnchorPoint = Vector2.new(0, 0.5), Position = grid and UDim2.new(0, 14, 1, -24) or UDim2.new(1, -92, 0.5, -3), Size = UDim2.fromOffset(14, 14), ZIndex = 4 })
	local hover = false
	local function refresh(a)
		Set(card, { BackgroundColor3 = (hover and P.CardHover or P.Card):Lerp(P.Accent, m.Enabled and 0.05 or 0) }, a)
		Set(st, { Color = m.Enabled and P.Stroke:Lerp(P.Accent, 0.12) or P.StrokeSoft }, a)
		Set(bar, { BackgroundColor3 = P.Accent, BackgroundTransparency = m.Enabled and 0 or 1 }, a)
		Set(barGlow, { Color = P.Accent, Transparency = m.Enabled and 0.12 or 1 }, a)
		Set(title, { TextColor3 = P.Text }, a)
		Set(desc, { TextColor3 = P.Sub }, a)
		colorChevron(hover and P.Label or P.Sub, a)
	end
	Paint(card, refresh)
	Toggle(card, { AnchorPoint = Vector2.new(1, 0.5), Position = grid and UDim2.new(1, -14, 1, -24) or UDim2.new(1, -15, 0.5, 0) },
		function() return m.Enabled end,
		function()
			m.Enabled = not m.Enabled
			refresh(true)
			SetTitle(cat.Name, "Modules", moduleSub(cat))
			RefreshTitle()
		end)
	card.MouseEnter:Connect(function() hover = true; refresh(true) end)
	card.MouseLeave:Connect(function() hover = false; refresh(true) end)
	card.MouseButton1Click:Connect(function() OpenModulePage(cat, m) end)
	return card
end

local function SettingRow(parent, order, name, desc, descRoom)
	local row = Frame({ Parent = parent, Size = UDim2.new(1, 0, 0, 54), LayoutOrder = order, ZIndex = 3 })
	local rail = Frame({ Parent = row, Position = UDim2.fromOffset(-5, 6), Size = UDim2.new(0, 2, 1, -12), BackgroundTransparency = 1, ZIndex = 4 })
	Round(rail)
	local railGlow = Glow(rail, P.Accent, 6, 1, 0)
	local sep = Frame({ Parent = row, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 1), BackgroundTransparency = 0.6, ZIndex = 3 })
	local t = Label({ Parent = row, Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, -300, 0, 20), Text = name, TextSize = 15, FontFace = Sans(W.Medium), ZIndex = 4 })
	local d = Label({ Parent = row, Position = UDim2.fromOffset(0, 29), Size = UDim2.new(1, -(descRoom or 280), 0, 16), Text = desc or "", TextSize = 11, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 4 })
	Paint(row, function(a)
		Set(t, { TextColor3 = P.Text }, a)
		Set(sep, { BackgroundColor3 = P.StrokeSoft }, a)
		Set(d, { TextColor3 = P.Sub }, a)
		rail.BackgroundColor3 = P.Accent; railGlow.Color = P.Accent
	end)
	row.MouseEnter:Connect(function() Tween(rail, { BackgroundTransparency = 0.1 }, 0.15); Tween(railGlow, { Transparency = 0.5 }, 0.15) end)
	row.MouseLeave:Connect(function() Tween(rail, { BackgroundTransparency = 1 }, 0.15); Tween(railGlow, { Transparency = 1 }, 0.15) end)
	return row
end

local function FieldBox(parent, props)
	local b = Button({ Parent = parent, BackgroundTransparency = 0.35, TextSize = 12, FontFace = Sans(), ZIndex = 5 })
	for k, v in pairs(props) do b[k] = v end
	Corner(6, b)
	local st = Stroke(b, P.StrokeSoft, 1, 0.35)
	Paint(b, function(a)
		Set(b, { BackgroundColor3 = P.Field, TextColor3 = P.Text }, a)
		Set(st, { Color = P.StrokeSoft }, a)
	end)
	return b, st
end

local Binding -- module currently waiting for a key

local function BindRow(parent, order, m, header)
	local row = SettingRow(parent, order, "Bind", "Keybind for " .. m.Name)
	local seg = Frame({ Parent = row, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -132, 0.5, 0), Size = UDim2.fromOffset(112, 28), BackgroundTransparency = 0.45, ZIndex = 5 })
	Round(seg)
	local segStroke = Stroke(seg, P.StrokeSoft, 1, 0.3)
	local pills = {}
	for i, mode in ipairs({ "Hold", "Toggle" }) do
		local p = Button({ Parent = seg, Position = UDim2.fromOffset(2 + (i - 1) * 54, 2), Size = UDim2.fromOffset(54, 24), Text = mode, TextSize = 12, FontFace = Sans(W.Medium), ZIndex = 6 })
		Round(p)
		local g = Glow(p, P.Accent, 10, 1, 0)
		pills[mode] = { btn = p, glow = g }
		p.MouseButton1Click:Connect(function()
			-- the mode can be picked before a key is assigned
			m.BindMode = mode
			for k, v in pairs(pills) do
				local on = (m.BindMode == k)
				Tween(v.btn, { BackgroundTransparency = on and 0 or 1, TextColor3 = on and P.OnAccent or P.Muted }, 0.15)
				Tween(v.glow, { Transparency = on and 0.55 or 1 }, 0.15)
			end
		end)
	end
	local key, keyStroke = FieldBox(row, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(118, 28), Text = KeyName(m.Bind) })
	local tip
	local function paintPills(a)
		Set(seg, { BackgroundColor3 = P.Field }, a)
		Set(segStroke, { Color = P.StrokeSoft }, a)
		for k, v in pairs(pills) do
			local on = (m.BindMode == k)
			Set(v.btn, { BackgroundColor3 = P.Accent, BackgroundTransparency = on and 0 or 1, TextColor3 = on and P.OnAccent or P.Label:Lerp(P.Base, 0.3) }, a)
			Set(v.glow, { Color = P.Accent, Transparency = on and 0.55 or 1 }, a)
		end
	end
	Paint(seg, paintPills)
	local function finish()
		if tip then tip:Destroy(); tip = nil end
		key.Text = KeyName(m.Bind)
		Tween(keyStroke, { Color = P.StrokeSoft, Transparency = 0.15 }, 0.15)
		paintPills(true)
		if header then header() end
	end
	key.MouseButton1Click:Connect(function()
		key.Text = "Press a key"
		Tween(keyStroke, { Color = P.Accent, Transparency = 0.2 }, 0.15)
		tip = Label({ Parent = row, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 0, 2), Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X,
			Text = "Press a key (ESC to cancel)", TextSize = 11, BackgroundTransparency = 0.1, BackgroundColor3 = P.AccentFaint, TextColor3 = P.Accent, ZIndex = 8 })
		Corner(5, tip); Pad(tip, 8, 8, 0, 0); Stroke(tip, P.Accent, 1, 0.5)
		Binding = { module = m, done = finish }
	end)
	return row
end

local function SliderRow(parent, order, s)
	local row = SettingRow(parent, order, s.Name, s.Desc)
	local track = Button({ Parent = row, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -107, 0.5, 0), Size = UDim2.fromOffset(200, 4), BackgroundTransparency = 0, ZIndex = 5 })
	Round(track)
	local fill = Frame({ Parent = track, Size = UDim2.fromScale(0, 1), BackgroundTransparency = 0, ZIndex = 6 })
	Round(fill)
	local fillGlow = Glow(fill, P.Accent, 8, 0.6, 0)
	local knob = Frame({ Parent = track, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 0, ZIndex = 7 })
	Round(knob)
	local knobGlow = Glow(knob, P.Accent, 10, 0.4, 1)
	local box = FieldBox(row, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(95, 26), Text = tostring(s.Value) })
	local function update()
		local a = (s.Value - s.Min) / (s.Max - s.Min)
		fill.Size = UDim2.fromScale(a, 1)
		knob.Position = UDim2.fromScale(a, 0.5)
		box.Text = tostring(s.Value)
	end
	Paint(track, function(a)
		Set(track, { BackgroundColor3 = P.Track:Lerp(WHITE, 0.12) }, a)
		Set(fill, { BackgroundColor3 = P.Accent }, a)
		Set(knob, { BackgroundColor3 = P.Accent }, a)
		fillGlow.Color = P.Accent; knobGlow.Color = P.Accent
	end)
	update()
	local dragging = false
	local function setFrom(x)
		local p, sz = track.AbsolutePosition, track.AbsoluteSize
		local a = math.clamp((x - p.X) / sz.X, 0, 1)
		s.Value = math.floor(s.Min + (s.Max - s.Min) * a + 0.5)
		update()
	end
	track.InputBegan:Connect(function(io)
		if io.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; setFrom(io.Position.X) end
	end)
	UserInputService.InputChanged:Connect(function(io)
		if dragging and io.UserInputType == Enum.UserInputType.MouseMovement then setFrom(io.Position.X) end
	end)
	UserInputService.InputEnded:Connect(function(io)
		if io.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
	end)
	return row
end

local function DropdownRow(parent, order, s)
	local row = SettingRow(parent, order, s.Name, s.Desc)
	local box = FieldBox(row, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(140, 26), Text = "" })
	local lbl = Label({ Parent = box, Position = UDim2.fromOffset(9, 0), Size = UDim2.new(1, -30, 1, 0), Text = s.Value, TextSize = 12, FontFace = Sans(), ZIndex = 6 })
	Icon(box, "chevronDown", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(12, 12), ZIndex = 6 }, function() return P.Sub end)
	Paint(lbl, function(a) Set(lbl, { TextColor3 = P.Text }, a) end)
	box.MouseButton1Click:Connect(function()
		OpenPopupAt(box, 140, 8 + #s.Options * 28, function(pop)
			for i, opt in ipairs(s.Options) do
				local o = Button({ Parent = pop, Position = UDim2.fromOffset(4, 4 + (i - 1) * 28), Size = UDim2.new(1, -8, 0, 26), Text = "", ZIndex = 71,
					BackgroundColor3 = P.AccentSoft, BackgroundTransparency = (opt == s.Value) and 0.2 or 1 })
				Corner(5, o)
				Label({ Parent = o, Position = UDim2.fromOffset(9, 0), Size = UDim2.new(1, -18, 1, 0), Text = opt, TextSize = 12, ZIndex = 72,
					TextColor3 = (opt == s.Value) and P.Accent or P.Label, FontFace = Sans(W.Medium) })
				o.MouseEnter:Connect(function() if opt ~= s.Value then Tween(o, { BackgroundTransparency = 0.6 }, 0.1) end end)
				o.MouseLeave:Connect(function() if opt ~= s.Value then Tween(o, { BackgroundTransparency = 1 }, 0.1) end end)
				o.MouseButton1Click:Connect(function()
					s.Value = opt
					lbl.Text = opt
					ClosePopup()
				end)
			end
		end)
	end)
	return row
end

local function ColorRow(parent, order, s)
	local row = SettingRow(parent, order, s.Name, s.Desc)
	local box = FieldBox(row, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(56, 28), Text = "" })
	local sw = Frame({ Parent = box, Position = UDim2.fromOffset(5, 5), Size = UDim2.fromOffset(18, 18), BackgroundTransparency = 0, BackgroundColor3 = s.Value, ZIndex = 6 })
	Corner(4, sw)
	Glow(sw, s.Value, 6, 0.6, 0)
	Icon(box, "chevronDown", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -7, 0.5, 0), Size = UDim2.fromOffset(12, 12), ZIndex = 6 }, function() return P.Sub end)
	box.MouseButton1Click:Connect(function()
		OpenPopupAt(box, 222, 256, function(pop)
			local _, cleanup = ColorPicker(pop, UDim2.fromOffset(12, 12), s.Value, function(c)
				s.Value = c
				sw.BackgroundColor3 = c
			end)
		end)
	end)
	return row
end

local function ToggleRow(parent, order, s)
	local row = SettingRow(parent, order, s.Name, s.Desc, 70)
	Toggle(row, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), ZIndex = 5 }, function() return s.Value end, function() s.Value = not s.Value end)
	return row
end

local function defaultSettings(m)
	return {
		{ Type = "toggle", Name = "Only While Holding Weapon", Desc = "Only runs while a weapon is in your main hand.", Value = false },
		{ Type = "slider", Name = "Delay", Desc = "Milliseconds between actions.", Min = 0, Max = 500, Value = 120 },
		{ Type = "dropdown", Name = "Mode", Desc = "How " .. m.Name .. " behaves.", Options = { "Legit", "Blatant", "Custom" }, Value = "Legit" },
	}
end

-- soft bottom edge for a scroll area: a strip in the container's own colour fading from transparent to solid
local function BottomFade(parent, height, bottomInset, z, colorFn, baseTransparency)
	local fade = Frame({ Parent = parent, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 1, 1, -(bottomInset or 1)),
		Size = UDim2.new(1, -2, 0, height or 24), BackgroundTransparency = baseTransparency or 0, ZIndex = z or 10 })
	New("UIGradient", { Parent = fade, Rotation = 90, Transparency = NumberSequence.new(1, 0) })
	Paint(fade, function(a) Set(fade, { BackgroundColor3 = colorFn() }, a) end)
	return fade
end

-- global module search: a results dropdown under the search box, grouped by category
local SearchPanel
local ActiveSearchBox
local function CloseSearch()
	if SearchPanel then SearchPanel:Destroy(); SearchPanel = nil end
end

local function ModuleSearch(page)
	local box, tb, focusFx = SearchBox(page, "Search modules", { Position = UDim2.fromOffset(501, 41) })
	ActiveSearchBox = tb
	local results, sel, rows = {}, 1, {}

	local function paintRows(a)
		for i, r in ipairs(rows) do
			local on = (i == sel)
			Set(r.btn, { BackgroundColor3 = on and P.AccentSoft or P.CardHover, BackgroundTransparency = on and 0.25 or 1 }, a)
			Set(r.stroke, { Color = P.Accent, Transparency = on and 0.45 or 1 }, a)
		end
	end

	local function openResult(i)
		local r = results[i]
		if not r then return end
		CloseSearch()
		tb.Text = ""
		Navigate("Modules", r.cat.Name)
		OpenModulePage(r.cat, r.m)
	end

	local function build(query)
		CloseSearch()
		rows = {}
		results = {}
		local q = query:lower():gsub("^%s+", ""):gsub("%s+$", "")
		if q == "" then return end
		focusFx(true) -- typing implies focus (also covers programmatic text)
		for _, cat in ipairs(Categories) do
			for _, m in ipairs(cat.Modules) do
				if m.Name:lower():find(q, 1, true) then results[#results + 1] = { cat = cat, m = m } end
			end
		end
		sel = 1
		local pos, size = toWindowSpace(box)
		local height = 0
		local panel = Frame({ Name = "SearchResults", Parent = Overlay, Position = UDim2.fromOffset(pos.X - 30, pos.Y + size.Y + 9),
			Size = UDim2.fromOffset(size.X + 50, 60), BackgroundTransparency = 0, BackgroundColor3 = P.Panel:Lerp(P.Base, 0.35), ZIndex = 80 })
		SearchPanel = panel
		Corner(10, panel)
		Stroke(panel, P.Stroke, 1, 0.2)
		DropShadow(panel, 34, 0.2, 12)
		local scroll = New("ScrollingFrame", { Parent = panel, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, ScrollBarImageTransparency = 1,
			CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 81 })
		Pad(scroll, 12, 12, 12, 10)
		New("UIListLayout", { Parent = scroll, Padding = UDim.new(0, 0), SortOrder = Enum.SortOrder.LayoutOrder })
		local order = 0
		local stops = {}
		local function add(inst, h) order = order + 1; inst.LayoutOrder = order; inst.Parent = scroll; height = height + h; stops[#stops + 1] = height end
		add(Label({ Size = UDim2.new(1, 0, 0, 22), Text = "MODULES", TextSize = 11, TextColor3 = P.Sub:Lerp(P.Accent, 0.3), ZIndex = 82 }), 22)
		if #results == 0 then
			add(Label({ Size = UDim2.new(1, 0, 0, 44), Text = "No modules match \"" .. query .. "\"", TextSize = 12, TextColor3 = P.Sub, ZIndex = 82 }), 44)
		end
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
			Icon(b, r.cat.Icon, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 11, 0.5, 0), Size = UDim2.fromOffset(22, 22), ImageColor3 = P.Label, ZIndex = 83 })
			Label({ Parent = b, Position = UDim2.fromOffset(46, 7), Size = UDim2.new(1, -130, 0, 18), Text = r.m.Name, TextSize = 14, FontFace = Sans(W.Medium), TextColor3 = P.Text,
				TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 83 })
			Label({ Parent = b, Position = UDim2.fromOffset(46, 25), Size = UDim2.new(1, -130, 0, 14), Text = r.cat.Name, TextSize = 11, TextColor3 = P.Sub, ZIndex = 83 })
			local tag = Label({ Parent = b, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(58, 20), Text = "Module", TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Center, BackgroundTransparency = 0, BackgroundColor3 = P.Base:Lerp(P.Accent, 0.2), TextColor3 = P.AccentPale, ZIndex = 83 })
			Corner(5, tag)
			rows[i] = { btn = b, stroke = st }
			b.MouseEnter:Connect(function() sel = i; paintRows(true) end)
			b.MouseButton1Click:Connect(function() openResult(i) end)
			add(b, 46)
		end
		-- show whole rows, plus a peek of the next row as a scroll cue (like the reference)
		local fit = height
		if height > 400 then
			fit = 0
			for _, s in ipairs(stops) do if s <= 400 then fit = s end end
			fit = fit + 18
		end
		panel.Size = UDim2.fromOffset(size.X + 50, fit + 28)
		if height > 400 then BottomFade(panel, 30, 1, 90, function() return P.Panel:Lerp(P.Base, 0.35) end, 0) end
		paintRows(false)
	end

	tb:GetPropertyChangedSignal("Text"):Connect(function()
		State.Search = tb.Text
		build(tb.Text)
	end)
	tb.Focused:Connect(function() if tb.Text ~= "" then build(tb.Text) end end)
	tb.FocusLost:Connect(function(enter)
		if enter and #results > 0 then openResult(sel) end
	end)
	-- arrow keys move the highlighted result while typing
	local conn
	conn = UserInputService.InputBegan:Connect(function(io)
		if not box.Parent then conn:Disconnect() return end
		if not SearchPanel or #rows == 0 then return end
		if io.KeyCode == Enum.KeyCode.Down then sel = math.min(sel + 1, #rows); paintRows(true)
		elseif io.KeyCode == Enum.KeyCode.Up then sel = math.max(sel - 1, 1); paintRows(true)
		elseif io.KeyCode == Enum.KeyCode.Escape then CloseSearch() end
	end)
	return box, tb
end

--------------------------------------------------------------------------- pages
local Pages = {}

-- Page transitions (matched to the recording): the old page fades out quickly while the new one fades in and
-- slides into place. Pages ride inside a temporary CanvasGroup only while animating; it is oversized so side
-- glows are not clipped, and the page is moved back out once settled so nothing stays clipped afterwards.
local FX_MARGIN = 40
local function fader(z)
	local g = New("CanvasGroup", { Parent = Content, BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = z or 3,
		Position = UDim2.fromOffset(-FX_MARGIN, -FX_MARGIN), Size = UDim2.new(1, FX_MARGIN * 2, 1, FX_MARGIN * 2) })
	return g
end
local function place(page, parent)
	page.Parent = parent
	if parent == Content then
		page.Position = UDim2.fromOffset(0, 0); page.Size = UDim2.fromScale(1, 1)
	else
		page.Position = UDim2.fromOffset(FX_MARGIN, FX_MARGIN); page.Size = UDim2.new(1, -FX_MARGIN * 2, 1, -FX_MARGIN * 2)
	end
end

local function NewPage(offset)
	ClosePopup()
	CloseSearch()
	local old = PageHolder
	if old then
		local out = fader(2)
		place(old, out)
		local tw = Tween(out, { GroupTransparency = 1 }, 0.12, Enum.EasingStyle.Quad)
		tw.Completed:Connect(function() out:Destroy() end)
	end
	offset = offset or Vector2.new(0, 12)
	local inn = fader(3)
	inn.GroupTransparency = 1
	inn.Position = UDim2.fromOffset(-FX_MARGIN + offset.X, -FX_MARGIN + offset.Y)
	local page = Frame({ Name = "Page", ZIndex = 3 })
	place(page, inn)
	PageHolder = page
	local tw = Tween(inn, { GroupTransparency = 0, Position = UDim2.fromOffset(-FX_MARGIN, -FX_MARGIN) }, 0.22, Enum.EasingStyle.Quint)
	tw.Completed:Connect(function()
		if page.Parent == inn then place(page, Content) end
		inn:Destroy()
	end)
	return page
end

function OpenModulePage(cat, m)
	State.OpenModule = m
	local page = NewPage(Vector2.new(22, 0))
	SetTitle(cat.Name, "Modules", moduleSub(cat))
	RefreshTitle()
	ModuleSearch(page)
	local back = Button({ Parent = page, Position = UDim2.fromOffset(4, 103), Size = UDim2.fromOffset(104, 26), BackgroundTransparency = 0.4, ZIndex = 4 })
	Round(back)
	local backStroke = Stroke(back, P.StrokeSoft, 1, 0.15)
	local backLbl = Label({ Parent = back, Position = UDim2.fromOffset(45, 0), Size = UDim2.new(1, -45, 1, 0), Text = "Back", TextSize = 13, FontFace = Sans(W.Medium), ZIndex = 5 })
	Icon(back, "chevronLeft", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 31, 0.5, 0), Size = UDim2.fromOffset(11, 11), ZIndex = 5 }, function() return P.Label end)
	Paint(backLbl, function(a)
		Set(back, { BackgroundColor3 = P.Field }, a); Set(backStroke, { Color = P.StrokeSoft }, a)
		Set(backLbl, { TextColor3 = P.Label }, a)
	end)
	back.MouseButton1Click:Connect(function() State.OpenModule = nil; Navigate("Modules", cat.Name) end)

	local panel = Frame({ Parent = page, Position = UDim2.fromOffset(0, 152), Size = UDim2.new(1, 0, 1, -168), BackgroundTransparency = 0.25, ZIndex = 3 })
	Corner(12, panel)
	local pst = Stroke(panel, P.StrokeSoft, 1, 0.15)
	Paint(panel, function(a) Set(panel, { BackgroundColor3 = P.Card }, a); Set(pst, { Color = P.StrokeSoft }, a) end)
	local nameLbl = Label({ Parent = panel, Position = UDim2.fromOffset(19, 18), Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, Text = m.Name, TextSize = 17, FontFace = Sans(W.Bold), ZIndex = 4 })
	local descLbl = Label({ Parent = panel, Position = UDim2.fromOffset(19, 48), Size = UDim2.new(1, -120, 0, 16), Text = m.Desc, TextSize = 12, ZIndex = 4 })
	local badge = Frame({ Parent = panel, Position = UDim2.fromOffset(19, 20), Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 0.2, ZIndex = 4 })
	Corner(4, badge); Pad(badge, 18, 5, 0, 0)
	local badgeIcon = Icon(badge, "keybinds", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, -14, 0.5, 0), Size = UDim2.fromOffset(11, 11), ZIndex = 5 }, function() return P.Sub end)
	local badgeText = Label({ Parent = badge, Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X, Text = "", TextSize = 11, ZIndex = 5 })
	local function header()
		badge.Visible = m.Bind ~= nil
		badgeText.Text = m.Bind and KeyName(m.Bind) or ""
		task.defer(function()
			local w = nameLbl.AbsoluteSize.X / WindowScale.Scale
			badge.Position = UDim2.fromOffset(19 + w + 10, 21)
		end)
	end
	Paint(nameLbl, function(a)
		Set(nameLbl, { TextColor3 = P.Text }, a)
		Set(descLbl, { TextColor3 = P.Sub }, a)
		Set(badge, { BackgroundColor3 = P.Field }, a)
		Set(badgeText, { TextColor3 = P.Sub }, a)
	end)
	header()
	Toggle(panel, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -19, 0, 20), ZIndex = 5 }, function() return m.Enabled end, function()
		m.Enabled = not m.Enabled
		SetTitle(cat.Name, "Modules", moduleSub(cat)); RefreshTitle()
	end)
	local div = Frame({ Parent = panel, Position = UDim2.fromOffset(19, 92), Size = UDim2.new(1, -38, 0, 1), BackgroundTransparency = 0.2, ZIndex = 4 })
	Paint(div, function(a) Set(div, { BackgroundColor3 = P.StrokeSoft }, a) end)

	local scroll = New("ScrollingFrame", { Parent = panel, Position = UDim2.fromOffset(13, 104), Size = UDim2.new(1, -8, 1, -118), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 0, ScrollBarImageTransparency = 1, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 4 })
	Pad(scroll, 12, 24, 6, 16)
	BottomFade(panel, 26, 1, 8, function() return P.Card end, 0.25)
	New("UIListLayout", { Parent = scroll, Padding = UDim.new(0, 0), SortOrder = Enum.SortOrder.LayoutOrder })
	BindRow(scroll, 0, m, header)
	m.Settings = m.Settings or defaultSettings(m)
	for i, s in ipairs(m.Settings) do
		if s.Type == "toggle" then ToggleRow(scroll, i, s)
		elseif s.Type == "slider" then SliderRow(scroll, i, s)
		elseif s.Type == "dropdown" then DropdownRow(scroll, i, s)
		elseif s.Type == "color" then ColorRow(scroll, i, s) end
	end
	refreshNav(true)
	PlaceGlow(State.Page)
end

Pages.Modules = function(catName, keepSearch)
	local cat = CategoryByName[catName] or Categories[1]
	State.Category = cat.Name
	if not keepSearch then State.Search = "" end
	local page = NewPage()
	SetTitle(cat.Name, "Modules", moduleSub(cat))
	RefreshTitle()
	ModuleSearch(page)
	local gm = Chip(page, "Gamemodes", { Position = UDim2.fromOffset(4, 103), ZIndex = 4 })
	-- list / grid switch
	local views = {}
	for i, v in ipairs({ "list", "grid" }) do
		local b = Button({ Parent = page, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, (i == 1) and -40 or -6, 0, 104), Size = UDim2.fromOffset(28, 24), BackgroundTransparency = 1, ZIndex = 4 })
		Corner(6, b)
		local st = Stroke(b, P.Accent, 1, 1)
		local _, colorIcon = Icon(b, v, { Position = UDim2.new(0.5, -7, 0.5, -7), Size = UDim2.fromOffset(14, 14), ZIndex = 5 })
		views[v] = { btn = b, st = st, color = colorIcon }
		b.MouseButton1Click:Connect(function()
			State.View = v
			Navigate("Modules", cat.Name, true)
		end)
	end
	Paint(page, function(a)
		for v, t in pairs(views) do
			local on = State.View == v
			Set(t.btn, { BackgroundColor3 = P.AccentSoft, BackgroundTransparency = on and 0.2 or 1 }, a)
			Set(t.st, { Color = P.Accent, Transparency = on and 0.7 or 1 }, a)
			t.color(on and P.Accent or P.Sub, a)
		end
	end)
	BuildModuleList(page, cat)
end

Pages.Theme = function()
	local page = NewPage()
	SetTitle(nil, "Themes", "Menu accent and colors")
	RefreshTitle()
	local scroll = New("ScrollingFrame", { Parent = page, Position = UDim2.fromOffset(-22, 102), Size = UDim2.new(1, 44, 1, -110), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 0, ScrollBarImageTransparency = 1, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 3 })
	Pad(scroll, 24, 24, 8, 12)
	New("UIGridLayout", { Parent = scroll, CellSize = UDim2.fromOffset(238, 118), CellPadding = UDim2.fromOffset(22, 22), SortOrder = Enum.SortOrder.LayoutOrder })
	for i, t in ipairs(Themes) do
		local card = Button({ Parent = scroll, LayoutOrder = i, BackgroundTransparency = 0.3, ZIndex = 4 })
		Corner(10, card)
		local st = Stroke(card, P.StrokeSoft, 1, 0.2)
		local glow = Glow(card, hex(t.Accent), 20, 1, 0)
		local acc = hex(t.Accent)
	local base = hex(t.Base):Lerp(acc, 0.04)
		local sw = t.Swatches or { t.Base, base:Lerp(acc, 0.1):ToHex(), t.Accent, base:Lerp(acc, 0.13):Lerp(WHITE, 0.02):ToHex(), base:Lerp(WHITE, 0.07):Lerp(acc, 0.06):ToHex() }
		local strip = Frame({ Parent = card, Position = UDim2.fromOffset(12, 12), Size = UDim2.new(1, -24, 0, 35), ZIndex = 5 })
		for j = 1, 5 do
			local seg = Frame({ Parent = strip, Position = UDim2.new((j - 1) / 5, 0, 0, 0), Size = UDim2.new(0.2, (j < 5) and 1 or 0, 1, 0), BackgroundTransparency = 0,
				BackgroundColor3 = hex(sw[j]), ZIndex = 5 })
			if j == 1 or j == 5 then
				Corner(5, seg)
				Frame({ Parent = seg, Position = UDim2.new((j == 1) and 0.5 or 0, 0, 0, 0), Size = UDim2.fromScale(0.5, 1), BackgroundTransparency = 0, BackgroundColor3 = hex(sw[j]), ZIndex = 5 })
			end
		end
		if t.Glass then
			local g = Label({ Parent = strip, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(40, 17), Text = "GLASS",
				TextSize = 10, FontFace = Sans(W.Medium), TextXAlignment = Enum.TextXAlignment.Center, BackgroundTransparency = 0.72, BackgroundColor3 = acc,
				TextColor3 = acc:Lerp(WHITE, 0.25), ZIndex = 6 })
			Corner(4, g)
		end
		local name = Label({ Parent = card, Position = UDim2.fromOffset(12, 55), Size = UDim2.new(1, -60, 0, 18), Text = t.Name, TextSize = 14, FontFace = Sans(W.Medium), ZIndex = 5 })
		local desc = Label({ Parent = card, Position = UDim2.fromOffset(12, 76), Size = UDim2.new(1, -24, 0, 16), Text = t.Desc, TextSize = 12, ZIndex = 5 })
		local check = Frame({ Parent = card, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0, 63), Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 0, BackgroundColor3 = acc, ZIndex = 6 })
		Round(check)
		local checkGlow = Glow(check, acc, 10, 0.4, 0)
		Icon(check, "check", { Position = UDim2.new(0.5, -6, 0.5, -6), Size = UDim2.fromOffset(12, 12), ZIndex = 7 }, function() return WHITE end)
		local hover = false
		local function refresh(a)
			local sel = State.Theme == t.Name
			Set(card, { BackgroundColor3 = sel and P.Card:Lerp(acc, 0.1) or (hover and P.CardHover or P.Card), BackgroundTransparency = sel and 0.1 or 0.3 }, a)
			Set(st, { Color = sel and acc or P.StrokeSoft, Transparency = sel and 0.45 or 0.2, Thickness = sel and 1.2 or 1 }, a)
			Set(glow, { Transparency = sel and 0.62 or 1 }, a)
			Set(name, { TextColor3 = P.Text }, a)
			Set(desc, { TextColor3 = P.Sub }, a)
			check.Visible = sel
		end
		Paint(card, refresh)
		card.MouseEnter:Connect(function() hover = true; refresh(true) end)
		card.MouseLeave:Connect(function() hover = false; refresh(true) end)
		card.MouseButton1Click:Connect(function()
			if State.Theme ~= t.Name then
				State.Theme = t.Name
				P = derive(t)
				Repaint(true)
			end
			Toast("Theme · " .. t.Name)
		end)
	end
end

Pages.Settings = function()
	local page = NewPage()
	SetTitle(nil, "Settings", "Appearance and keybinds")
	RefreshTitle()
	local function Card(x, w, h, title, sub)
		local c = Frame({ Parent = page, Position = UDim2.fromOffset(x, 103), Size = w and UDim2.fromOffset(w, h) or UDim2.new(1, -x, 0, h), BackgroundTransparency = 0.25, ZIndex = 3 })
		Corner(12, c)
		local st = Stroke(c, P.StrokeSoft, 1, 0.15)
		local t = Label({ Parent = c, Position = UDim2.fromOffset(19, 17), Size = UDim2.new(1, -38, 0, 18), Text = title, TextSize = 14, FontFace = Sans(W.SemiBold), ZIndex = 4 })
		local s = Label({ Parent = c, Position = UDim2.fromOffset(19, 40), Size = UDim2.new(1, -38, 0, 14), Text = sub, TextSize = 11, ZIndex = 4 })
		Paint(c, function(a)
			Set(c, { BackgroundColor3 = P.Card }, a); Set(st, { Color = P.StrokeSoft }, a)
			Set(t, { TextColor3 = P.Text }, a); Set(s, { TextColor3 = P.Sub }, a)
		end)
		return c
	end
	local colorCard = Card(0, 258, 356, "Main color", "Accent for trails, effects and HUD")
	local inner = Frame({ Parent = colorCard, Position = UDim2.fromOffset(19, 80), Size = UDim2.fromOffset(220, 256), BackgroundTransparency = 0.3, ZIndex = 4 })
	Corner(8, inner)
	local ist = Stroke(inner, P.StrokeSoft, 1, 0.3)
	Paint(inner, function(a) Set(inner, { BackgroundColor3 = P.Field }, a); Set(ist, { Color = P.StrokeSoft }, a) end)
	ColorPicker(inner, UDim2.fromOffset(12, 12), State.MainColor, function(c) State.MainColor = c end)

	local bindCard = Card(284, nil, 146, "Menu Bind", "Key to open/close this menu")
	local row = Frame({ Parent = bindCard, Position = UDim2.fromOffset(19, 70), Size = UDim2.new(1, -38, 0, 56), BackgroundTransparency = 0.3, ZIndex = 4 })
	Corner(8, row)
	local rst = Stroke(row, P.StrokeSoft, 1, 0.3)
	local rl = Label({ Parent = row, Position = UDim2.fromOffset(14, 0), Size = UDim2.fromOffset(200, 56), Text = "Toggle menu", TextSize = 13, FontFace = Sans(W.Medium), ZIndex = 5 })
	local keyBtn = Button({ Parent = row, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(120, 30), Text = KeyName(State.MenuKey),
		TextSize = 12, FontFace = Sans(W.Medium), BackgroundTransparency = 0, ZIndex = 5 })
	Corner(6, keyBtn)
	local kst = Stroke(keyBtn, P.Accent, 1, 0.7)
	Paint(row, function(a)
		Set(row, { BackgroundColor3 = P.Field }, a); Set(rst, { Color = P.StrokeSoft }, a)
		Set(rl, { TextColor3 = P.Text }, a)
		Set(keyBtn, { BackgroundColor3 = P.AccentSoft, TextColor3 = P.Text }, a)
		Set(kst, { Color = P.Accent }, a)
	end)
	keyBtn.MouseButton1Click:Connect(function()
		keyBtn.Text = "Press a key"
		Binding = { menu = true, done = function() keyBtn.Text = KeyName(State.MenuKey) end }
	end)
end

Pages.Configs = function()
	local page = NewPage()
	SetTitle(nil, "Configs", "")
	RefreshTitle()
	Tabs(page, { "Public configs", "Personal configs", "Create config" }, "Public configs", nil, 0, 67, 150)
	SearchBox(page, "Search public configs", { Position = UDim2.fromOffset(498, 67), Size = UDim2.fromOffset(260, 36) })
	local scroll = New("ScrollingFrame", { Parent = page, Position = UDim2.fromOffset(-22, 118), Size = UDim2.new(1, 44, 1, -190), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 0, ScrollBarImageTransparency = 1, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 3 })
	Pad(scroll, 24, 24, 8, 8)
	New("UIGridLayout", { Parent = scroll, CellSize = UDim2.new(1 / 3, -14, 0, 180), CellPadding = UDim2.fromOffset(20, 20), SortOrder = Enum.SortOrder.LayoutOrder })
	for i, c in ipairs(Configs) do
		local card = Frame({ Parent = scroll, LayoutOrder = i, BackgroundTransparency = 0.3, ZIndex = 4 })
		Corner(10, card)
		local st = Stroke(card, P.StrokeSoft, 1, 0.2)
		local t = Label({ Parent = card, Position = UDim2.fromOffset(15, 14), Size = UDim2.new(1, -90, 0, 18), Text = c[1], TextSize = 14, FontFace = Sans(W.Medium), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 5 })
		local cnt = Label({ Parent = card, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -15, 0, 14), Size = UDim2.fromOffset(48, 20), Text = tostring(c[6]), TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Center, BackgroundTransparency = 0.2, ZIndex = 5 })
		Corner(4, cnt)
		local d = Label({ Parent = card, Position = UDim2.fromOffset(15, 40), Size = UDim2.new(1, -30, 0, 32), Text = c[2], TextSize = 11, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 5 })
		local by = Label({ Parent = card, Position = UDim2.fromOffset(15, 86), Size = UDim2.new(0.5, -15, 0, 14), Text = "by " .. c[3], TextSize = 11, ZIndex = 5 })
		local date = Label({ Parent = card, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -15, 0, 86), Size = UDim2.new(0.5, 0, 0, 14), Text = c[4], TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 5 })
		local tags = Frame({ Parent = card, Position = UDim2.fromOffset(15, 105), Size = UDim2.new(1, -30, 0, 18), ZIndex = 5 })
		New("UIListLayout", { Parent = tags, FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
		local tagList = (#c[5] > 0) and c[5] or { "No tags" }
		local tagLabels = {}
		for j, tg in ipairs(tagList) do
			local tl = Label({ Parent = tags, LayoutOrder = j, Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X, Text = tg, TextSize = 10, BackgroundTransparency = 0.2, ZIndex = 6 })
			Corner(4, tl); Pad(tl, 7, 7, 0, 0)
			local tst = Stroke(tl, P.Accent, 1, 0.6)
			tagLabels[#tagLabels + 1] = { tl, #c[5] == 0, tst }
		end
		local dl = Button({ Parent = card, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.new(1, -30, 0, 32), Text = "Download",
			TextSize = 12, FontFace = Sans(W.Medium), BackgroundTransparency = 0.12, ZIndex = 5 })
		Corner(6, dl)
		local dlGlow = Glow(dl, P.Accent, 14, 1, 0)
		Paint(card, function(a)
			Set(card, { BackgroundColor3 = P.Card }, a); Set(st, { Color = P.StrokeSoft }, a)
			Set(t, { TextColor3 = P.Text }, a); Set(d, { TextColor3 = P.Sub }, a)
			Set(by, { TextColor3 = P.Sub }, a); Set(date, { TextColor3 = P.Sub }, a)
			Set(cnt, { BackgroundColor3 = P.Base:Lerp(P.Accent, 0.26), TextColor3 = P.Text }, a)
			for _, tl in ipairs(tagLabels) do
				Set(tl[1], { BackgroundColor3 = tl[2] and P.Field:Lerp(WHITE, 0.03) or P.Base:Lerp(P.Accent, 0.2), TextColor3 = tl[2] and P.Sub or P.AccentPale }, a)
				Set(tl[3], { Color = tl[2] and P.StrokeSoft or P.Accent, Transparency = tl[2] and 0.3 or 0.6 }, a)
			end
			Set(dl, { BackgroundColor3 = P.Accent:Lerp(P.Base, 0.18), TextColor3 = P.OnAccent }, a)
			dlGlow.Color = P.Accent
		end)
		dl.MouseEnter:Connect(function() Tween(dl, { BackgroundColor3 = P.Accent }, 0.15); Tween(dlGlow, { Transparency = 0.55 }, 0.15) end)
		dl.MouseLeave:Connect(function() Tween(dl, { BackgroundColor3 = P.Accent:Lerp(P.Base, 0.18) }, 0.15); Tween(dlGlow, { Transparency = 1 }, 0.15) end)
		dl.MouseButton1Click:Connect(function() Toast("Downloaded · " .. c[1]) end)
		card.MouseEnter:Connect(function() Tween(card, { BackgroundColor3 = P.CardHover }, 0.15); Tween(st, { Color = P.Stroke:Lerp(P.Accent, 0.25) }, 0.15) end)
		card.MouseLeave:Connect(function() Tween(card, { BackgroundColor3 = P.Card }, 0.15); Tween(st, { Color = P.StrokeSoft }, 0.15) end)
	end
	local pager = Label({ Parent = page, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, -45), Size = UDim2.fromOffset(80, 20), Text = "0/765", TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4 })
	local nextBtn = Button({ Parent = page, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 66, 1, -45), Size = UDim2.fromOffset(30, 28), BackgroundTransparency = 0.3, ZIndex = 4 })
	Corner(6, nextBtn)
	local nst = Stroke(nextBtn, P.StrokeSoft, 1, 0.2)
	Icon(nextBtn, "chevron", { Position = UDim2.new(0.5, -7, 0.5, -7), Size = UDim2.fromOffset(14, 14), ZIndex = 5 }, function() return P.Label end)
	Paint(pager, function(a)
		Set(pager, { TextColor3 = P.Label }, a)
		Set(nextBtn, { BackgroundColor3 = P.Field }, a); Set(nst, { Color = P.StrokeSoft }, a)
	end)
end

Pages.Socials = function()
	local page = NewPage()
	SetTitle(nil, "Socials", "Friends and requests")
	RefreshTitle()
	local list
	local function fill(tab)
		if list then list:Destroy() end
		list = New("ScrollingFrame", { Parent = page, Position = UDim2.fromOffset(-22, 146), Size = UDim2.new(1, 44, 1, -156), BackgroundTransparency = 1, BorderSizePixel = 0,
			ScrollBarThickness = 0, ScrollBarImageTransparency = 1, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 3 })
		Pad(list, 24, 24, 12, 12)
		New("UIListLayout", { Parent = list, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder })
		local others = {}
		for _, plr in ipairs(Players:GetPlayers()) do if plr ~= LocalPlayer then others[#others + 1] = plr end end
		if tab == "Friends" or #others == 0 then
			local l = Label({ Parent = list, Size = UDim2.new(1, 0, 0, 220), Text = (tab == "Friends") and "No friends added" or "No players in server",
				TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4 })
			Paint(l, function(a) Set(l, { TextColor3 = P.Sub }, a) end)
			return
		end
		for i, plr in ipairs(others) do
			local r = Frame({ Parent = list, LayoutOrder = i, Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 0.3, ZIndex = 4 })
			Corner(10, r)
			local st = Stroke(r, P.StrokeSoft, 1, 0.2)
			local n = Label({ Parent = r, Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -150, 1, 0), Text = "", RichText = true, TextSize = 14, FontFace = Sans(W.Medium), ZIndex = 5 })
			local add = Button({ Parent = r, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(100, 30), Text = "Add friend", TextSize = 12, BackgroundTransparency = 0.1, ZIndex = 5 })
			Corner(6, add)
			Paint(r, function(a)
				Set(r, { BackgroundColor3 = P.Card }, a); Set(st, { Color = P.StrokeSoft }, a)
				n.Text = plr.DisplayName .. '  <font color="' .. toHex(P.Sub) .. '">@' .. plr.Name .. '</font>'
				Set(n, { TextColor3 = P.Text }, a); Set(add, { BackgroundColor3 = P.Accent, TextColor3 = P.OnAccent }, a)
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
	RefreshTitle()
	local scroll = New("ScrollingFrame", { Parent = page, Position = UDim2.fromOffset(-22, 102), Size = UDim2.new(1, 44, 1, -110), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 0, ScrollBarImageTransparency = 1, CanvasSize = UDim2.new(0, 0, 0, 0), AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 3 })
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
				Paint(r, function(a)
					Set(r, { BackgroundColor3 = P.Card }, a); Set(st, { Color = P.StrokeSoft }, a)
					Set(t, { TextColor3 = P.Text }, a); Set(c, { TextColor3 = P.Sub }, a)
					Set(k, { BackgroundColor3 = P.Field, TextColor3 = P.Text }, a); Set(kst, { Color = P.StrokeSoft }, a)
				end)
				r.MouseButton1Click:Connect(function() Navigate("Modules", cat.Name); OpenModulePage(cat, m) end)
			end
		end
	end
	if n == 0 then
		local l = Label({ Parent = scroll, Size = UDim2.new(1, 0, 0, 220), Text = "No keybinds yet — open a module and click its Bind box", TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4 })
		Paint(l, function(a) Set(l, { TextColor3 = P.Label }, a) end)
	end
end

function Navigate(page, arg, keepSearch)
	if page == "Modules" then
		State.Page = "Modules"
		State.OpenModule = nil
		Pages.Modules(arg or State.Category, keepSearch)
	else
		State.Page = page
		Pages[page]()
	end
	refreshNav(true)
	PlaceGlow(State.Page)
end

--------------------------------------------------------------------------- sidebar collapse
local function SetCollapsed(c, instant)
	State.Collapsed = c
	local sw = c and SIDEBAR_COLLAPSED_W or SIDEBAR_W
	local cx = c and 91 or CONTENT_X
	local cw = c and (WIN_W - 91 - 28) or CONTENT_W
	local t = instant and 0 or 0.2
	Tween(Sidebar, { Size = UDim2.new(0, sw, 1, -28) }, t, Enum.EasingStyle.Quint)
	Tween(Content, { Position = UDim2.fromOffset(cx, 0), Size = UDim2.new(0, cw, 1, 0) }, t, Enum.EasingStyle.Quint)
	Tween(CrownBtn, { Position = UDim2.fromOffset(c and 11 or 10, 12) }, t, Enum.EasingStyle.Quint)
	Tween(BrandTitle, { TextTransparency = c and 1 or 0 }, t * 0.6)
	Tween(BrandVer, { TextTransparency = c and 1 or 0 }, t * 0.6)
	Tween(SecModules, { TextTransparency = c and 1 or 0 }, t * 0.6)
	Tween(SecGeneral, { TextTransparency = c and 1 or 0 }, t * 0.6)
	Tween(Divider, { Size = c and UDim2.new(1, -30, 0, 1) or UDim2.new(1, -46, 0, 1), Position = UDim2.fromOffset(c and 15 or 23, 396) }, t, Enum.EasingStyle.Quint)
	for _, n in ipairs(NavItems) do
		Tween(n.btn, { Size = c and UDim2.fromOffset(40, 40) or UDim2.new(1, -22, 0, 40) }, t, Enum.EasingStyle.Quint)
		n.refresh(not instant)
	end
end
CrownBtn.MouseButton1Click:Connect(function() SetCollapsed(not State.Collapsed) end)

--------------------------------------------------------------------------- dragging (grab the header strip)
local DragZone = Frame({ Name = "DragZone", Parent = Window, Position = UDim2.fromOffset(CONTENT_X, 0), Size = UDim2.new(0, 480, 0, 26), ZIndex = 10 })
do
	local dragging, startPos, startMouse
	DragZone.InputBegan:Connect(function(io)
		if io.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			startPos = Window.Position
			startMouse = Vector2.new(io.Position.X, io.Position.Y)
		end
	end)
	UserInputService.InputChanged:Connect(function(io)
		if dragging and io.UserInputType == Enum.UserInputType.MouseMovement then
			local d = Vector2.new(io.Position.X, io.Position.Y) - startMouse
			Window.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
	UserInputService.InputEnded:Connect(function(io)
		if io.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
	end)
end

--------------------------------------------------------------------------- open / close + key handling
-- while the menu is open every game-bound input (movement, camera, tools, clicks) is sunk at a
-- priority above the default PlayerModule / tool bindings; GUI and TextBoxes still receive input first
local BLOCK_ACTION = "PrestigeClientBlockInput"
local function BlockGameInput(on)
	if on then
		ContextActionService:BindActionAtPriority(BLOCK_ACTION, function()
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value + 1000,
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
		Window.Visible = true
		Dim.Visible = true
		WindowScale.Scale = fitScale() * 0.94
		Tween(WindowScale, { Scale = fitScale() }, 0.35, Enum.EasingStyle.Quint)
		Tween(Dim, { BackgroundTransparency = 0.45 }, 0.3)
		Tween(Blur, { Size = 18 }, 0.3)
	else
		ClosePopup()
		local tw = Tween(WindowScale, { Scale = fitScale() * 0.94 }, 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		Tween(Dim, { BackgroundTransparency = 1 }, 0.2)
		Tween(Blur, { Size = 0 }, 0.2)
		tw.Completed:Connect(function()
			if not State.Open then Window.Visible = false; Dim.Visible = false end
		end)
	end
end

UserInputService.InputBegan:Connect(function(io, gp)
	if io.UserInputType == Enum.UserInputType.MouseButton1 and SearchPanel then
		local p, s = SearchPanel.AbsolutePosition, SearchPanel.AbsoluteSize
		local x, y = io.Position.X, io.Position.Y
		if x < p.X or y < p.Y - 60 or x > p.X + s.X or y > p.Y + s.Y then task.defer(CloseSearch) end
	end
	if io.UserInputType == Enum.UserInputType.MouseButton1 and ActivePopup then
		local p, s = ActivePopup.AbsolutePosition, ActivePopup.AbsoluteSize
		local x, y = io.Position.X, io.Position.Y
		if x < p.X or y < p.Y or x > p.X + s.X or y > p.Y + s.Y then
			task.defer(ClosePopup)
		end
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
	if UserInputService:GetFocusedTextBox() then return end -- typing in a box, not a hotkey
	if io.KeyCode == State.MenuKey then SetOpen(not State.Open) return end
	for _, cat in ipairs(Categories) do
		for _, m in ipairs(cat.Modules) do
			if m.Bind == io.KeyCode then
				if m.BindMode == "Hold" then m.Enabled = true else m.Enabled = not m.Enabled end
			end
		end
	end
end)
UserInputService.InputEnded:Connect(function(io)
	if io.UserInputType ~= Enum.UserInputType.Keyboard then return end
	for _, cat in ipairs(Categories) do
		for _, m in ipairs(cat.Modules) do
			if m.Bind == io.KeyCode and m.BindMode == "Hold" then m.Enabled = false end
		end
	end
end)

if workspace.CurrentCamera and workspace.CurrentCamera.GetPropertyChangedSignal then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		if State.Open then WindowScale.Scale = fitScale() end
	end)
end

--------------------------------------------------------------------------- boot
-- a few defaults so the list shows the enabled / glow state out of the box
CategoryByName.Combat.Modules[6].Bind = Enum.KeyCode.C
Navigate("Modules", "Combat")
SetOpen(true)

-- public handle (sUNC getgenv when available)
local api = {
	Navigate = Navigate,
	OpenModule = function(catName, modName)
		local cat = CategoryByName[catName]
		for _, m in ipairs(cat.Modules) do if m.Name == modName then Navigate("Modules", catName); OpenModulePage(cat, m) end end
	end,
	SetTheme = function(name)
		State.Theme = name
		P = derive(ThemeByName[name])
		Repaint(false)
	end,
	SetEnabled = function(catName, modName, on)
		for _, m in ipairs(CategoryByName[catName].Modules) do if m.Name == modName then m.Enabled = on end end
	end,
	SetView = function(v) State.View = v end,
	Collapse = SetCollapsed,
	Toast = Toast,
	Search = function(text) if ActiveSearchBox then ActiveSearchBox:CaptureFocus(); ActiveSearchBox.Text = text end end,
	Toggle = function() SetOpen(not State.Open) end,
	Destroy = function() BlockGameInput(false); Screen:Destroy(); Blur:Destroy() end,
}
if getgenv then getgenv().PrestigeUI = api end
return api
