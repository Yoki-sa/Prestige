--[[
	Prestige loader
	  • In a supported game: loads that game's script straight away (full menu with the local Configs tab).
	  • Anywhere else: opens the hub (Games, Theme and Settings). The Games tab shows what every script does;
	    universal scripts can be loaded from there in any game, game scripts only inside their own game.
	  • Theme and all settings are saved to workspace/PrestigeClient and come back on the next run.

	Host PrestigeLib.lua, this file and your game scripts somewhere raw (GitHub raw, etc.) and fill in the URLs.
	Run with:  loadstring(game:HttpGet(LOADER_URL))()

	Shrimp build: the Games table only lists the two ported Shrimp games.
	Game scripts live as plain files in the Potassium workspace (readfile),
	with an HttpGet fallback (relative names resolve against BASE).
]]

local BASE = "https://raw.githubusercontent.com/Yoki-sa/Prestige/refs/heads/main/"
local LIB_URL = BASE .. "PrestigeLib.lua"

-- Script may be a URL, a file name (workspace readfile, else fetched from BASE),
-- or a function(Library, entry)
-- Features: strings or { "Name", "Short description" }
local Games = {
	{ Name = "Universal", Universal = true, Icon = "games", Script = BASE .. "Example.lua",
		Description = "General tools that work in any experience: movement, visuals and quality-of-life.",
		Features = { { "Speed", "Raises your walk speed" }, { "Flight", "Free flight with noclip" }, { "ESP", "Players through walls" },
			{ "Fullbright", "Removes darkness and fog" }, { "Anti AFK", "Stops the idle kick" }, { "Server Hop", "Joins a different server" } } },
	{ Name = "Cold War", PlaceId = 13687899540, Script = "ColdWar.lua",
		Description = "Ballistics shooter. Pellet-cone silent aim and player ESP.",
		Features = { { "Silent Aim", "Rotates the whole pellet cone onto the target" },
			{ "Aim Part", "Head or Torso" }, { "Prediction", "Leads moving targets" },
			{ "Redirect Tracer", "Muzzle-to-target beam on redirected shots" },
			{ "ESP", "Boxes, names, distance and health" },
			{ "Visibility Colors", "Green when seen, red when blocked" } } },
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

local function resolveScript(entry)
	local fn = entry.Script
	if type(fn) == "string" then
		local src
		if isfile and isfile(fn) then
			src = readfile(fn)
		else
			local url = fn:match("^https?://") and fn or (BASE .. fn)
			local ok, res = pcall(game.HttpGet, game, url)
			if not ok then
				warn("[Prestige] failed to fetch " .. entry.Name .. " from " .. url .. ": " .. tostring(res))
				return nil
			end
			src = res
		end
		local chunk, err = loadstring(src)
		if not chunk then warn("[Prestige] failed to compile " .. entry.Name .. ": " .. tostring(err)) return nil end
		fn = chunk
	end
	return fn
end

local function runGame(entry)
	local fn = resolveScript(entry)
	if not fn then return end
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
