--[[
	Prestige loader
	  • In a supported game: loads that game's script straight away (full menu with the local Configs tab).
	  • Anywhere else: opens the hub (Games, Theme and Settings). The Games tab shows what every script does;
	    universal scripts can be loaded from there in any game, game scripts only inside their own game.
	  • Theme and all settings are saved to workspace/PrestigeClient and come back on the next run.

	Host PrestigeLib.lua, this file and your game scripts somewhere raw (GitHub raw, etc.) and fill in the URLs.
	Run with:  loadstring(game:HttpGet(LOADER_URL))()
]]

local BASE = "https://raw.githubusercontent.com/Yoki-sa/Prestige/refs/heads/main/"
local LIB_URL = BASE .. "PrestigeLib.lua"

-- Script may be a URL (fetched + loadstring'd) or a function(Library, entry)
-- Features: strings or { "Name", "Short description" }
local Games = {
	{ Name = "Universal", Universal = true, Icon = "games", Script = BASE .. "Example.lua",
		Description = "General tools that work in any experience: movement, visuals and quality-of-life.",
		Features = { { "Speed", "Raises your walk speed" }, { "Flight", "Free flight with noclip" }, { "ESP", "Players through walls" },
			{ "Fullbright", "Removes darkness and fog" }, { "Anti AFK", "Stops the idle kick" }, { "Server Hop", "Joins a different server" } } },
	{ Name = "Universal Aim", Universal = true, Icon = "combat", Script = BASE .. "Example.lua",
		Description = "Camera aim assist and silent aim that adapt to most shooters.",
		Features = { { "Aim Assist", "Smoothly tracks the closest target" }, { "FOV Circle", "Configurable field of view" },
			{ "Team Check", "Ignores teammates" }, { "Visible Check", "Only locks on to visible players" } } },
	{ Name = "Arsenal", PlaceId = 286090429, Script = BASE .. "Example.lua",
		Description = "Fast-paced FPS. Aim assist, ESP and movement modules.",
		Features = { { "Aim Assist", "Target smoothing and FOV" }, { "Trigger Bot", "Fires when on target" }, { "ESP", "Boxes, names and health" },
			{ "Hitboxes", "Expands enemy hitboxes" }, { "Speed", "Movement boost" }, { "Gun Mods", "No recoil and spread" } } },
	{ Name = "Blox Fruits", PlaceId = 2753915549, PlaceIds = { 4442272183, 7449423635 }, Script = BASE .. "Example.lua",
		Description = "Farming, fruit notifier and teleports across all three seas.",
		Features = { { "Auto Farm", "Levels quests automatically" }, { "Fruit Notifier", "Alerts when a fruit spawns" }, { "Island Teleports", "Every island in all seas" }, { "Auto Stats", "Spends points for you" } } },
	{ Name = "Doors", PlaceId = 6516141723, Script = BASE .. "Example.lua",
		Description = "Entity ESP, key and lever finder, auto-hide.",
		Features = { { "Entity ESP", "Rush, Ambush, Figure and more" }, { "Key Finder", "Highlights keys and levers" }, { "Auto Hide", "Hides when entities spawn" }, { "Notifier", "Warns before entities" } } },
	{ Name = "Murder Mystery 2", PlaceId = 142823291, Script = BASE .. "Example.lua",
		Description = "Role reveal, gun ESP and coin collection.",
		Features = { { "Role Reveal", "Shows the murderer and sheriff" }, { "Gun ESP", "Tracks the dropped gun" }, { "Coin Farm", "Collects coins" } } },
	{ Name = "BedWars", PlaceId = 6872265039, Script = BASE .. "Example.lua",
		Description = "Kill aura, scaffold and bed ESP.",
		Features = { { "Kill Aura", "Hits nearby players" }, { "Scaffold", "Places blocks under you" }, { "Bed ESP", "Highlights beds" }, { "Velocity", "Reduces knockback" } } },
	{ Name = "Da Hood", PlaceId = 2788229376, Script = BASE .. "Example.lua",
		Description = "Lock-on, ESP and auto stomp.",
		Features = { { "Lock-On", "Camera lock with prediction" }, { "ESP", "Players and cash" }, { "Auto Stomp", "Stomps knocked players" } } },
	{ Name = "Jailbreak", PlaceId = 606849621, Script = BASE .. "Example.lua",
		Description = "Robbery helpers, car mods and teleports.",
		Features = { { "Robbery Status", "Which stores are open" }, { "Car Mods", "Speed and handling" }, { "Teleports", "Every location on the map" } } },
}

local env = (getgenv and getgenv()) or _G

-- reuse an already-loaded library (also lets you test locally with a PrestigeLib.lua in the workspace folder)
local Library = env.PrestigeLib
if not Library then
	local src = (isfile and isfile("PrestigeLib.lua") and readfile("PrestigeLib.lua")) or game:HttpGet(LIB_URL)
	Library = loadstring(src)()
	env.PrestigeLib = Library
end
Library.Games = Games

local function runGame(entry)
	local fn = entry.Script
	if type(fn) == "string" then
		local chunk, err = loadstring(game:HttpGet(fn))
		if not chunk then warn("[Prestige] failed to compile " .. entry.Name .. ": " .. tostring(err)) return end
		fn = chunk
	end
	task.spawn(function()
		local ok, err = pcall(fn, Library, entry)
		if not ok then warn("[Prestige] " .. entry.Name .. " script error: " .. tostring(err)) end
	end)
end

-- "Load Script" on a game page: only universal scripts, or the script of the game you are in
Library.LoadGame = function(entry, window)
	if not (entry.Universal or Library.IsCurrentGame(entry)) then return end
	if window then window:Unload() end
	runGame(entry)
end

local current
for _, g in ipairs(Games) do
	if Library.IsCurrentGame(g) then current = g break end
end

if current then
	runGame(current)
else
	Library:CreateWindow({ Mode = "Hub", Games = Games, Title = "Prestige", Accent = "Hub" })
end
