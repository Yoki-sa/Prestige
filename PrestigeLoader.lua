--[[
	Prestige loader
	  • In a supported game: loads that game's script straight away (it builds the full menu with PrestigeLib).
	  • Anywhere else: opens the hub (Games, Theme and Settings only). Each game card can teleport you to a
	    server of that game; the loader is queued with queue_on_teleport so the game script loads on arrival.

	Host PrestigeLib.lua, this file and your game scripts somewhere raw (GitHub raw, etc.) and fill in the URLs.
	Run with:  loadstring(game:HttpGet(LOADER_URL))()
]]

local LIB_URL = "https://raw.githubusercontent.com/Yoki-sa/Prestige/refs/heads/main/PrestigeLib.lua"
local LOADER_URL = "https://raw.githubusercontent.com/YOUR_NAME/prestige/main/PrestigeLoader.lua"

-- Script may be a URL (fetched + loadstring'd) or a function(Library, entry)
local Games = {
	{ Name = "Arsenal", PlaceId = 286090429, Script = "https://raw.githubusercontent.com/YOUR_NAME/prestige/main/games/Example.lua",
		Description = "Fast-paced FPS. Aim assist, ESP and movement modules." },
	{ Name = "Blox Fruits", PlaceId = 2753915549, PlaceIds = { 4442272183, 7449423635 }, Script = "https://raw.githubusercontent.com/YOUR_NAME/prestige/main/games/Example.lua",
		Description = "Farming, fruit notifier and teleports across all three seas." },
	{ Name = "Doors", PlaceId = 6516141723, Script = "https://raw.githubusercontent.com/YOUR_NAME/prestige/main/games/Example.lua",
		Description = "Entity ESP, key and lever finder, auto-hide." },
	{ Name = "Murder Mystery 2", PlaceId = 142823291, Script = "https://raw.githubusercontent.com/YOUR_NAME/prestige/main/games/Example.lua",
		Description = "Role reveal, gun ESP and coin collection." },
	{ Name = "BedWars", PlaceId = 6872265039, Script = "https://raw.githubusercontent.com/YOUR_NAME/prestige/main/games/Example.lua",
		Description = "Kill aura, scaffold and bed ESP." },
	{ Name = "Brookhaven RP", PlaceId = 4924922222, Script = "https://raw.githubusercontent.com/YOUR_NAME/prestige/main/games/Example.lua",
		Description = "Roleplay utilities and house tools." },
	{ Name = "Pet Simulator 99", PlaceId = 8737899170, Script = "https://raw.githubusercontent.com/YOUR_NAME/prestige/main/games/Example.lua",
		Description = "Auto farm, egg hatcher and mailbox tools." },
	{ Name = "Da Hood", PlaceId = 2788229376, Script = "https://raw.githubusercontent.com/YOUR_NAME/prestige/main/games/Example.lua",
		Description = "Lock-on, ESP and auto stomp." },
	{ Name = "Jailbreak", PlaceId = 606849621, Script = "https://raw.githubusercontent.com/YOUR_NAME/prestige/main/games/Example.lua",
		Description = "Robbery helpers, car mods and teleports." },
}

local env = (getgenv and getgenv()) or _G
local function get(url) return game:HttpGet(url) end

-- reuse an already-loaded library (also lets you test locally with a PrestigeLib.lua in the workspace folder)
local Library = env.PrestigeLib
if not Library then
	local src = (isfile and isfile("PrestigeLib.lua") and readfile("PrestigeLib.lua")) or get(LIB_URL)
	Library = loadstring(src)()
	env.PrestigeLib = Library
end

Library.Games = Games
Library.TeleportScript = ('loadstring(game:HttpGet(%q))()'):format(LOADER_URL)

local function runGame(entry)
	local fn = entry.Script
	if type(fn) == "string" then
		local src = get(fn)
		local chunk, err = loadstring(src)
		if not chunk then warn("[Prestige] failed to compile " .. entry.Name .. ": " .. tostring(err)) return end
		fn = chunk
	end
	task.spawn(function()
		local ok, err = pcall(fn, Library, entry)
		if not ok then warn("[Prestige] " .. entry.Name .. " script error: " .. tostring(err)) end
	end)
end

-- "Load Script" on the Games page (you are already in that game): swap the hub for the game's menu
Library.LoadGame = function(entry, window)
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
