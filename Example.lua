--[[
	Example game script for PrestigeLib. The loader calls it as fn(Library, entry).
	Swap the callbacks for your own feature code.
]]
local Library, Game = ...
Library = Library or (getgenv and getgenv().PrestigeLib)

local Window = Library:CreateWindow({
	Title = "Prestige", Accent = "Client", Version = "RELEASE 4.4.0",
	Mode = "Full",
	Theme = "Aurora",                       -- default only; the saved theme wins
	MenuKey = Enum.KeyCode.RightShift,
	Games = Library.Games,
	Current = Game and Game.Name,
	-- local configs only when running inside the supported game itself
	ConfigKey = (Game and Library.IsCurrentGame(Game)) and Game.Name or nil,
	OnUnload = function() print("[Prestige] unloaded") end,
})

local function log(name) return function(...) print("[Prestige]", name, ...) end end

--------------------------------------------------------------------- Combat
local Combat = Window:AddCategory("Combat", "combat")
local names = {
	{ "Aim Assist", "Aims at targets" },
	{ "Anchor Exploder", "Automatically explodes respawn anchors for you" },
	{ "Anchor Macro", "Explodes and places anchors automatically" },
	{ "Anchor Pearl Catch", "Pre-places and detonates a respawn anchor where enemy pearls land" },
	{ "Anchor Placer", "Automatically places respawn anchors for you" },
}
for _, n in ipairs(names) do
	local m = Combat:AddModule({ Name = n[1], Description = n[2], Callback = log(n[1]) })
	m:AddSlider({ Name = "Range", Description = "Maximum distance in studs.", Min = 1, Max = 30, Default = 12, Increment = 0.5, Suffix = " st", Callback = log(n[1] .. " range") })
	m:AddDropdown({ Name = "Mode", Description = "How " .. n[1] .. " behaves.", Options = { "Legit", "Blatant", "Custom" }, Default = "Legit", Callback = log(n[1] .. " mode") })
end

local AntiAction = Combat:AddModule({ Name = "Anti Action", Description = "Prevents certain bad actions from interrupting your pvp", Keybind = Enum.KeyCode.C, Callback = log("Anti Action") })
AntiAction:AddToggle({ Name = "Double Glowstone", Description = "Blocks double-filling an anchor with glowstone.", Default = true })
AntiAction:AddToggle({ Name = "Open E-Chest", Description = "Blocks opening an ender chest while holding combat items.", Default = true })
AntiAction:AddToggle({ Name = "Place Glowstone", Description = "Blocks placing glowstone anywhere but an anchor.", Default = true })
AntiAction:AddToggle({ Name = "Ground Firework", Description = "Blocks firing a firework rocket while not gliding on elytra. Skipped if a crossbow is in your offhand.", Default = true })
AntiAction:AddToggle({ Name = "Sword Shield", Description = "Blocks hitting a shield with a sword.", Default = true })

for _, n in ipairs({ { "Anti Bot", "Filters out server-side bots from targeting" }, { "Auto Clicker", "Clicks for you with a humanized pattern" },
	{ "Auto Crystal", "Places and breaks end crystals automatically" }, { "Auto Totem", "Keeps a totem in your offhand" }, { "Hitboxes", "Expands enemy hitboxes" },
	{ "Hit Fix", "Fixes the attack registration delay" }, { "Trigger Bot", "Attacks when your crosshair is on a target" }, { "Xbow Cart", "Places and fires TNT minecarts with a crossbow" } }) do
	Combat:AddModule({ Name = n[1], Description = n[2], Callback = log(n[1]) })
end

--------------------------------------------------------------------- Movement
local Movement = Window:AddCategory("Movement", "movement")
local Speed = Movement:AddModule({ Name = "Speed", Description = "Moves you faster", Callback = function(on)
	local hum = game:GetService("Players").LocalPlayer.Character and game:GetService("Players").LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
	if hum then hum.WalkSpeed = on and (Window.Flags.SpeedValue or 24) or 16 end
end })
Speed:AddSlider({ Name = "Walk Speed", Description = "Humanoid walk speed while enabled.", Min = 16, Max = 100, Default = 24, Flag = "SpeedValue" })
Movement:AddModule({ Name = "Flight", Description = "Lets you fly", Callback = log("Flight") })
Movement:AddModule({ Name = "No Fall", Description = "Removes fall damage", Callback = log("No Fall") })
Movement:AddModule({ Name = "Step", Description = "Steps up full blocks", Callback = log("Step") })

--------------------------------------------------------------------- Visual
local Visual = Window:AddCategory("Visual", "visual")
Visual:AddModule({ Name = "Ambience", Description = "Changes the ambience of the game" })
Visual:AddModule({ Name = "Animations", Description = "Renders custom smooth swing animations" })
local ESP = Visual:AddModule({ Name = "ESP", Description = "Renders various things through walls", Callback = log("ESP") })
ESP:AddDropdown({ Name = "Mode", Description = "Selects the shader used to draw entity outlines/fills.", Options = { "Normal", "Glow", "Chams", "Box" }, Default = "Normal" })
ESP:AddDropdown({ Name = "Targets", Description = "Outlines these entity types.", Options = { "Players", "Crystals", "Items", "NPCs", "Vehicles" }, Multi = true, Default = { "Players", "Crystals" } })
ESP:AddToggle({ Name = "Menu Color", Description = "Follows the menu accent color instead of a custom one.", Default = true })
ESP:AddColorPicker({ Name = "Color", Description = "Custom outline color.", Default = Color3.fromRGB(0, 200, 255), Flag = "ESPColor", Callback = log("ESP color") })
ESP:AddSlider({ Name = "Quality", Description = "Raises outline shader quality. Default 3 balances smoothness and FPS; 6 is the safe maximum.", Min = 1, Max = 8, Default = 3 })
ESP:AddSlider({ Name = "Radius", Description = "Widens the outline glow (px).", Min = 1, Max = 20, Default = 15 })
ESP:AddToggle({ Name = "Fill", Description = "Fills the silhouette instead of outlining only.", Default = false })
ESP:AddButton({ Name = "Refresh", Description = "Rebuilds every highlight.", Text = "Refresh", Callback = function() Window:Notify("ESP refreshed") end })
Visual:AddModule({ Name = "Free Look", Description = "Allows you to look around without rotating" })
Visual:AddModule({ Name = "Health Indicators", Description = "Shows health on players" })
Visual:AddModule({ Name = "Fullbright", Description = "Makes everything bright", Callback = function(on) game:GetService("Lighting").Brightness = on and 3 or 1 end })

--------------------------------------------------------------------- Misc
local Misc = Window:AddCategory("Misc", "misc")
local Spammer = Misc:AddModule({ Name = "Spammer", Description = "Sends messages on an interval" })
Spammer:AddTextbox({ Name = "Message", Description = "Text to send.", Placeholder = "gg", Default = "gg" })
Spammer:AddSlider({ Name = "Delay", Description = "Seconds between messages.", Min = 1, Max = 30, Default = 5 })
Misc:AddModule({ Name = "Auto Pickaxe", Description = "Swaps to the best pickaxe when mining" })
Misc:AddModule({ Name = "Auto Text", Description = "Sends preset chat messages on a key" })
Misc:AddModule({ Name = "Fast EXP", Description = "Throws experience bottles faster" })

Window:Notify("Loaded · " .. ((Game and Game.Name) or "Prestige"))
