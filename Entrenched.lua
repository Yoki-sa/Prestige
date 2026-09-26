--[[
	Entrenched (3678761576) script for PrestigeLib. The loader calls it as fn(Library, entry).
	Ports the Shrimp modules (ESP + WeaponModule SilentAim) onto the Prestige UI.
]]
local Library, Game = ...
Library = Library or (getgenv and getgenv().PrestigeLib)

local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Debris           = game:GetService("Debris")

local LocalPlayer = Players.LocalPlayer

-- ============================ shared state ==========================
-- Lives on getgenv: the permanent-ish hook and any re-executed script
-- read the same Config; flags prevent stacking wrappers across re-executes.
-- Declared BEFORE the window so OnUnload captures the same table.
local Shrimp = getgenv().Shrimp or {}
getgenv().Shrimp = Shrimp
Shrimp.Cleanups = Shrimp.Cleanups or {}

--------------------------------------------------------------------- window
local Window = Library:CreateWindow({
	Title = "Prestige", Accent = "Client", Version = "RELEASE 4.4.0",
	Mode = "Full",
	Theme = "Aurora",
	MenuKey = Enum.KeyCode.RightShift,
	Games = Library.Games,
	Current = Game and Game.Name,
	ConfigKey = (Game and Library.IsCurrentGame(Game)) and Game.Name or nil,
	OnUnload = function()
		-- run cleanups but KEEP getgenv().Shrimp: the hook flags and Config must
		-- survive so a re-execute never stacks a second wrapper on the hook
		for _, fn in ipairs(Shrimp.Cleanups or {}) do pcall(fn) end
		Shrimp.Cleanups = {}
		print("[Prestige] unloaded")
	end,
})

local function log(name) return function(...) print("[Prestige]", name, ...) end end

--------------------------------------------------------------------- Combat
local Combat = Window:AddCategory("Combat", "combat")

-- ------------------------------------------------------------------ SilentAim
-- Built from the WeaponModule decompile. How shots work here:
--   shootEffect() computes the crosshair world point (Crosshair()), applies
--   mobile-only bulletMagnetism (returns nil on PC), spreads pellets around
--   the aim unit, raycasts each pellet locally, then fires:
--     ServerEvents.Shoot:FireServer(clientData, aimPoint, aiming, missCount, hitList, camPos)
--   (flamethrower/flaregun shape: FireServer(clientData, aimPoint) only)
-- The client REPORTS its own humanoid-hit list, and the game's own mobile
-- bulletMagnetism already replaces the aim point with an enemy part position
-- — so the server demonstrably accepts snap-to-target aim points. Silent aim:
-- intercept Shoot.FireServer and
--   • redirect aimPoint -> chosen target part
--   • optionally claim every pellet on that part (hitList rebuilt, miss 0)
-- payload shape stays exactly what a magnetized legit shot looks like.
--
-- Hook mechanics: direct hookfunction on Shoot.FireServer ONLY. A __namecall
-- layer was tried and REMOVED: it crashed the game ("AddItem is not a valid
-- member of RemoteEvent Shoot") — a namecall wrapper that makes nested method
-- calls pollutes the thread's namecall-method register, so the deferred
-- original resolved the WRONG method. The direct member hook has no such
-- register: it wraps the resolved FireServer closure and calls the original C
-- function directly (the Cobalt intercept pattern, proven on Potassium).
-- Flag on getgenv prevents stacking across re-executes; the wrapper reads
-- shared Config so a re-executed menu stays wired to the live hook.

local SAConfig = Shrimp.ShootSAConfig
if not SAConfig then
	SAConfig = {
		Enabled            = true,
		FOV                = 140,  -- pixels around the crosshair
		HitPart            = "Head", -- Head | Torso
		VisibleCheck       = true, -- only lock targets with line of sight
		TeamCheck          = true, -- skip teammates (Roblox Teams)
		ShowFOV            = true,
		RedirectTracer     = true, -- muzzle->target beam on redirected shots
		ClaimPellets       = true, -- rebuild the hit list so damage actually lands
		Prediction         = true, -- lead moving targets by their velocity
		PredictionStrength = 1,    -- seconds of travel time used for the lead
		FOVColor           = Color3.fromRGB(255, 255, 255),
	}
	Shrimp.ShootSAConfig = SAConfig
end

-- ============================ targeting =============================
local rayParams = RaycastParams.new()
rayParams.FilterType  = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

local function aimPartFor(char)
	if SAConfig.HitPart == "Torso" then
		return char:FindFirstChild("UpperTorso")
			or char:FindFirstChild("Torso")
			or char:FindFirstChild("HumanoidRootPart")
			or char:FindFirstChild("Head")
	end
	return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
end

local function pickTarget(cam)
	if not cam then return nil end
	local center   = cam.ViewportSize / 2
	local best     = nil
	local bestDist = SAConfig.FOV
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl ~= LocalPlayer
			and not (SAConfig.TeamCheck and LocalPlayer.Team and pl.Team == LocalPlayer.Team) then
			local char = pl.Character
			local hum  = char and char:FindFirstChildOfClass("Humanoid")
			local part = char and aimPartFor(char)
			if part and hum and hum.Health > 0 then
				local sp = cam:WorldToViewportPoint(part.Position)
				if sp.Z > 0.3 then
					local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
					if d <= bestDist then
						if SAConfig.VisibleCheck then
							local charL = LocalPlayer.Character
							rayParams.FilterDescendantsInstances = charL and { charL, cam } or { cam }
							local hit = workspace:Raycast(cam.CFrame.Position,
								part.Position - cam.CFrame.Position, rayParams)
							if hit and (hit.Instance == part or hit.Instance:IsDescendantOf(char)) then
								best, bestDist = part, d
							end
						else
							best, bestDist = part, d
						end
					end
				end
			end
		end
	end
	return best
end

-- Velocity lead: aiming at where the target WILL be. Predicted point is
-- clamped to a sphere around the current aim part (radius ~ hitbox size + 4
-- studs) so fast targets can't be led out of their own body.
local function predictPart(part)
	if not (SAConfig.Prediction and SAConfig.PredictionStrength > 0) then return part.Position end
	local ok, pos = pcall(function()
		local v = part.AssemblyLinearVelocity
		if typeof(v) ~= "Vector3" or v.Magnitude < 0.5 then return part.Position end
		local t   = SAConfig.PredictionStrength
		local p   = part.Position + v * t
		local rad = math.max(part.Size.Magnitude * 0.5, 4) + 4
		local off = p - part.Position
		if off.Magnitude > rad then p = part.Position + off.Unit * rad end
		return p
	end)
	return ok and pos or part.Position
end

-- ============================ fov circle ============================
local circle = nil
pcall(function()
	circle = Drawing.new("Circle")
	circle.Thickness = 1
	circle.Filled    = false
	circle.Visible   = false
	circle.Color     = SAConfig.FOVColor
end)

-- ========================= redirect tracer ==========================
-- Same beam spec as the ballistics module: red->yellow gradient, glow
-- texture, face-camera, quick fade. Anchor parts are CanQuery=false so the
-- beam never blocks our own raycasts.
local function spawnRedirectTracer(from, to)
	local len = (to - from).Magnitude
	if len < 0.1 then return end
	local holder = Instance.new("Folder")
	holder.Name = "ShrimpRedirectTracer"

	local function endPart(pos, name)
		local p = Instance.new("Part")
		p.Name         = name
		p.Size         = Vector3.one
		p.Position     = pos
		p.Anchored     = true
		p.CanCollide   = false
		p.CanTouch     = false
		p.CanQuery     = false
		p.CastShadow   = false
		p.Transparency = 1
		p.Parent       = holder
		return p
	end

	local p0 = endPart(from, "Origin")
	local p1 = endPart(to, "Target")
	local a0 = Instance.new("Attachment") a0.Parent = p0
	local a1 = Instance.new("Attachment") a1.Parent = p1

	local beam = Instance.new("Beam")
	beam.Attachment0    = a0
	beam.Attachment1    = a1
	beam.Color          = ColorSequence.new(Color3.new(1, 0, 0), Color3.new(1, 0.859, 0.063))
	beam.LightEmission  = 1
	beam.LightInfluence = 1
	beam.FaceCamera     = true
	beam.Segments       = 10
	beam.Texture        = "rbxassetid://1134824633"
	beam.TextureLength  = 1
	beam.TextureMode    = Enum.TextureMode.Stretch
	beam.TextureSpeed   = 1
	beam.Width0         = 2
	beam.Width1         = 2
	beam.Transparency   = NumberSequence.new(0.1, 0.7)
	beam.Parent         = p0

	holder.Parent = workspace
	task.delay(0.15, function()
		if beam.Parent then beam.Transparency = NumberSequence.new(0.55, 1) end
	end)
	Debris:AddItem(holder, 0.3)
end

-- ========================= fire interception =========================
-- args (after self): [1]=clientData [2]=aimPoint [3]=aiming [4]=missCount
-- [5]=hitList [6]=camPos — or the flamethrower shape ([1],[2] only).
-- Returns true if args were modified.
-- Cheap re-entry guard: if the executor's namecall dispatch AND the direct
-- member hook both reach us for one shot, this collapses it to one handling.
-- Real shots are never 5ms apart (fire rate floor ~0.05s), so legit fire is
-- never skipped.
local lastHandle = 0
local function handleFire(args)
	if os.clock() - lastHandle < 0.005 then return false end
	if not SAConfig.Enabled or args.n < 2 then return false end
	if typeof(args[2]) ~= "Vector3" then return false end

	lastHandle = os.clock() -- committed: mark this shot as handled

	local cam    = workspace.CurrentCamera
	local target = pickTarget(cam)
	if not target then return false end
	local tp = predictPart(target)

	args[2] = tp -- the aim point itself — what magnetism does on mobile

	-- claim the pellets: rebuild the client-reported hit list on the target
	if SAConfig.ClaimPellets and args.n >= 5 then
		local okP, pellets = pcall(function()
			local cd   = args[1]
			local tool = cd and cd.Tool
			return (tool and tool:GetAttribute("Projectiles")) or 1
		end)
		if okP and type(pellets) == "number" and pellets >= 1 then
			local normal = Vector3.new(0, 1, 0)
			if typeof(args[6]) == "Vector3" then
				local n = (args[6] - tp)
				if n.Magnitude > 0.001 then normal = n.Unit end
			end
			local hits = {}
			for i = 1, math.min(pellets, 32) do
				hits[i] = {
					Instance = target,
					Position = tp, -- predicted point, claimed on the target part
					Normal   = normal,
					Material = target.Material,
				}
			end
			args[4] = 0    -- zero misses claimed
			args[5] = hits
		end
	end

	if SAConfig.RedirectTracer then
		local char = LocalPlayer.Character
		local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
		local from = (head and head.Position)
			or (cam and cam.CFrame.Position)
			or tp
		pcall(spawnRedirectTracer, from, tp)
	end

	if not Shrimp.ShootSASeen then
		Shrimp.ShootSASeen = true
		print("[Prestige] WeaponModule SilentAim: shot redirected — active")
	end
	return true
end

-- ============================== hook ================================
local fovLoopStarted = false
local function startSilentAim()
	local okR, Shoot = pcall(function()
		return ReplicatedStorage:WaitForChild("ServerEvents", 10)
			and ReplicatedStorage.ServerEvents:WaitForChild("Shoot", 10)
	end)
	if not okR or typeof(Shoot) ~= "Instance" then
		warn("[Prestige] ServerEvents.Shoot not found — silent aim unavailable")
		return
	end

	if not Shrimp.ShootSAHooked then
		Shrimp.ShootSAHooked = true

		-- Direct member hook (Cobalt-proven pattern): wrap the resolved
		-- FireServer closure. NO namecall layer — a wrapper that makes nested
		-- method calls (targeting raycasts, tracer Debris) pollutes the
		-- thread's namecall-method register and the deferred original then
		-- resolves the WRONG method (the AddItem crash). Calling the original
		-- C closure directly has nothing to pollute.
		pcall(function()
			local orig = Shoot.FireServer
			hookfunction(Shoot.FireServer, function(self, ...)
				local args = table.pack(...)
				local okH, changed = pcall(handleFire, args)
				if okH and changed then
					return orig(self, table.unpack(args, 1, args.n))
				end
				return orig(self, ...)
			end)
		end)
	end

	if not fovLoopStarted then
		fovLoopStarted = true
		local conn = RunService.RenderStepped:Connect(function()
			if not circle then return end
			pcall(function()
				local cam = workspace.CurrentCamera
				if SAConfig.Enabled and SAConfig.ShowFOV and cam then
					circle.Radius   = SAConfig.FOV
					circle.Position = cam.ViewportSize / 2
					circle.Color    = SAConfig.FOVColor
					circle.Visible  = true
				else
					circle.Visible = false
				end
			end)
		end)
		table.insert(Shrimp.Cleanups, function()
			conn:Disconnect()
			if circle then pcall(function() circle:Remove() end) circle = nil end
		end)
	end

	print("[Prestige] WeaponModule SilentAim installed")
end

local SilentAim = Combat:AddModule({
	Name = "Silent Aim",
	Description = "Redirects the shot's aim point to the best crosshair target and claims the pellets.",
	Keybind = Enum.KeyCode.H,
	Callback = function(on)
		SAConfig.Enabled = on
		if on then startSilentAim() end
	end,
})
SilentAim:AddDropdown({ Name = "Aim Part", Description = "Where shots land.", Options = { "Head", "Torso" }, Default = "Head",
	Callback = function(v) SAConfig.HitPart = v end })
SilentAim:AddSlider({ Name = "FOV", Description = "Targeting circle radius in pixels.", Min = 30, Max = 500, Default = 140, Increment = 5, Suffix = " px",
	Callback = function(v) SAConfig.FOV = v end })
SilentAim:AddToggle({ Name = "FOV Circle", Description = "Draws the targeting circle.", Default = true,
	Callback = function(v) SAConfig.ShowFOV = v end })
SilentAim:AddToggle({ Name = "Redirect Tracer", Description = "Draws a muzzle-to-target beam on redirected shots.", Default = true,
	Callback = function(v) SAConfig.RedirectTracer = v end })
SilentAim:AddToggle({ Name = "Claim Pellets", Description = "Rebuilds the hit list so pellet damage lands.", Default = true,
	Callback = function(v) SAConfig.ClaimPellets = v end })
SilentAim:AddToggle({ Name = "Prediction", Description = "Leads moving targets by their velocity.", Default = true,
	Callback = function(v) SAConfig.Prediction = v end })
SilentAim:AddSlider({ Name = "Prediction Strength", Description = "Seconds of travel time used for the lead.", Min = 0.1, Max = 2, Default = 1, Increment = 0.1,
	Callback = function(v) SAConfig.PredictionStrength = v end })
SilentAim:AddToggle({ Name = "Visible Check", Description = "Only locks on to visible targets.", Default = true,
	Callback = function(v) SAConfig.VisibleCheck = v end })
SilentAim:AddToggle({ Name = "Team Check", Description = "Ignores teammates.", Default = true,
	Callback = function(v) SAConfig.TeamCheck = v end })

--------------------------------------------------------------------- Visual
local Visual = Window:AddCategory("Visual", "visual")

-- ------------------------------------------------------------------ ESP
-- Player ESP: box + health bar + name/distance, scaled by projected
-- geometry, behind-camera targets fully hidden (Z check).
--   Team Check ON -> teammates hidden entirely (this game demonstrably uses
--                    Roblox Teams: WeaponModule checks Player.Team)
--   Team Color ON -> box/text take the player's TeamColor
--   Visibility ON -> camera line of sight GREEN, blocked RED

local ESPConfig = {
	Enabled      = false,
	TeamCheck    = true,
	TeamColor    = true,
	VisColor     = true,
	ShowBox      = true,
	ShowHealth   = true,
	ShowNames    = true,
	MaxDistance  = 2000,
	BaseTextSize = 15,
	MinTextSize  = 9,
	MaxTextSize  = 26,
	TextColor    = Color3.fromRGB(240, 240, 240),
}

local VISIBLE = Color3.fromRGB(85, 255, 127) -- camera sees them
local BLOCKED = Color3.fromRGB(235, 65, 65)  -- wall between camera and them

local function sameTeam(pl)
	if not ESPConfig.TeamCheck then return false end
	local mine = LocalPlayer.Team
	if not mine then return false end -- no team info: can't filter
	return pl.Team == mine
end

local function colorFor(pl)
	if ESPConfig.TeamColor and pl.Team then
		return pl.Team.TeamColor.Color
	end
	return ESPConfig.TextColor
end

local seeParams = RaycastParams.new()
seeParams.FilterType  = Enum.RaycastFilterType.Exclude
seeParams.IgnoreWater = true

local function seenByCamera(char, camPos)
	local top = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
	if not top then return false end
	local cam = workspace.CurrentCamera
	seeParams.FilterDescendantsInstances = cam and { char, cam } or { char }
	local hit = workspace:Raycast(camPos, top.Position - camPos, seeParams)
	if not hit then return true end -- open sky
	return hit.Instance == top or hit.Instance:IsDescendantOf(char)
end

local function newText()
	local ok, t = pcall(function() return Drawing.new("Text") end)
	if not ok or not t then return nil end
	pcall(function()
		t.Center = false t.Outline = true t.OutlineColor = Color3.new(0, 0, 0)
		t.Visible = false
	end)
	return t
end

local function newBox(filled)
	local ok, b = pcall(function() return Drawing.new("Square") end)
	if not ok or not b then return nil end
	pcall(function()
		b.Thickness = 1 b.Filled = filled and true or false b.Visible = false
	end)
	return b
end

local function textScale(dist)
	local d = math.max(dist, 1)
	local s = ESPConfig.BaseTextSize * (40 / d)
	return math.clamp(math.floor(s + 0.5), ESPConfig.MinTextSize, ESPConfig.MaxTextSize)
end

local function shouldShow(dist)
	if ESPConfig.MaxDistance <= 0 then return true end
	return dist <= ESPConfig.MaxDistance
end

-- health: 1 = full green, 0 = red
local function healthColor(hp)
	local r = math.clamp(1.5 - hp * 1.5, 0, 1)
	local g = math.clamp(hp * 1.5, 0, 1)
	return Color3.fromRGB(math.floor(70 + 150 * r), math.floor(70 + 170 * g), 60)
end

local pool = {} -- player -> drawing set

local function acquire(pl)
	local set = pool[pl]
	if not set then
		set = {
			box    = newBox(false),
			text   = newText(),
			bar    = newBox(true),
			accent = newBox(true),
		}
		pool[pl] = set
	end
	return set
end

local function release(key)
	local set = pool[key]
	if not set then return end
	for _, d in pairs(set) do
		if d and d.Remove then pcall(d.Remove, d) end
	end
	pool[key] = nil
end

-- Box from real projected height: center + a point halfH above it; the
-- pixel gap IS the perspective scaling. Z <= 0.5 = behind camera -> hidden.
local function boxForCenter(worldPos, halfH, widthRatio)
	local cam = workspace.CurrentCamera
	if not cam then return nil end
	local c = cam:WorldToViewportPoint(worldPos)
	if c.Z <= 0.3 then return nil end
	local t = cam:WorldToViewportPoint(worldPos + Vector3.new(0, halfH, 0))
	if t.Z <= 0.3 then return nil end
	local px = math.abs(t.Y - c.Y)
	if px < 1 then return nil end
	local h = px * 2
	local w = h * widthRatio
	local x = math.floor(c.X - w / 2 + 0.5)
	local y = math.floor(t.Y + 0.5)
	local vp = cam.ViewportSize
	if x < -60 or y < -60 or x + w > vp.X + 60 or y + h > vp.Y + 60 then return nil end
	return { X = x, Y = y, W = math.floor(w + 0.5), H = math.floor(h + 0.5) }
end

local function renderSet(set, box, dist, label, color, hp)
	if set.box then
		pcall(function()
			if ESPConfig.ShowBox and box then
				set.box.Size = Vector2.new(box.W, box.H)
				set.box.Position = Vector2.new(box.X, box.Y)
				set.box.Color = color
				set.box.Visible = true
			else
				set.box.Visible = false
			end
		end)
	end

	if set.text then
		pcall(function()
			if not ESPConfig.ShowNames or not box then
				set.text.Visible = false
				return
			end
			local cam = workspace.CurrentCamera
			local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
			set.text.Text = label
			set.text.Size = textScale(dist)
			set.text.Color = color
			local tb = set.text.TextBounds
			if not tb or tb.X <= 0 or tb.Y <= 0 then return end
			set.text.Position = Vector2.new(
				math.clamp(box.X + box.W / 2 - tb.X / 2, 0, math.max(0, vp.X - tb.X)),
				math.clamp(box.Y - tb.Y - 3, 0, math.max(0, vp.Y - tb.Y)))
			set.text.Visible = true
		end)
	end

	if set.bar and set.accent then
		pcall(function()
			if ESPConfig.ShowHealth and box and hp then
				local t = 3
				local by = box.Y + box.H + 1
				set.accent.Size = Vector2.new(box.W, t)
				set.accent.Position = Vector2.new(box.X, by)
				set.accent.Color = Color3.fromRGB(20, 20, 20)
				set.accent.Visible = true
				local fw = math.floor(box.W * hp + 0.5)
				set.bar.Size = Vector2.new(fw, t)
				set.bar.Position = Vector2.new(box.X, by)
				set.bar.Color = healthColor(hp)
				set.bar.Visible = true
			else
				set.bar.Visible = false
				set.accent.Visible = false
			end
		end)
	end
end

local function hideSet(set)
	for _, d in pairs(set) do
		if d then pcall(function() d.Visible = false end) end
	end
end

local espRunning = false
local function startESP()
	if espRunning then return end
	espRunning = true

	local conn = RunService.RenderStepped:Connect(function()
		local cam = workspace.CurrentCamera
		if not cam then return end
		local camPos = cam.CFrame.Position

		if not ESPConfig.Enabled then
			for pl, set in pairs(pool) do
				hideSet(set)
				if pl.Parent == nil then release(pl) end
			end
			return
		end

		local drawn = {}
		for _, pl in ipairs(Players:GetPlayers()) do
			if pl ~= LocalPlayer and not sameTeam(pl) then
				local c = pl.Character
				local root = c and c:FindFirstChild("HumanoidRootPart")
				local hum  = c and c:FindFirstChildOfClass("Humanoid")
				if root and hum and hum.Health > 0 then
					local dist = (root.Position - camPos).Magnitude
					if shouldShow(dist) then
						-- ~6 stud tall character (root at center)
						local box = boxForCenter(root.Position, 3, 0.55)
						if box then
							local hp = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
							local color = colorFor(pl)
							if ESPConfig.VisColor then
								-- visibility beats team colors: red/green tells you
								-- who can actually shoot you this frame
								color = seenByCamera(c, camPos) and VISIBLE or BLOCKED
							end
							renderSet(acquire(pl), box, dist,
								("%s [%d]"):format(pl.Name, math.floor(dist + 0.5)),
								color, hp)
							drawn[pl] = true
						end
					end
				end
			end
		end

		for pl, set in pairs(pool) do
			if not drawn[pl] then
				hideSet(set)
				if pl.Parent == nil then release(pl) end
			end
		end
	end)
	table.insert(Shrimp.Cleanups, function()
		conn:Disconnect()
		for key in pairs(pool) do release(key) end
		espRunning = false
	end)

	print("[Prestige] ESP running — team check " .. (ESPConfig.TeamCheck and "ON" or "OFF"))
end

local ESP = Visual:AddModule({
	Name = "ESP",
	Description = "Boxes, names, distance and health bars through walls.",
	Keybind = Enum.KeyCode.G,
	Callback = function(on)
		ESPConfig.Enabled = on
		if on then startESP() end
	end,
})
ESP:AddToggle({ Name = "Team Check", Description = "Hides teammates entirely.", Default = true,
	Callback = function(v) ESPConfig.TeamCheck = v end })
ESP:AddToggle({ Name = "Team Colors", Description = "Boxes and text use the player's TeamColor.", Default = true,
	Callback = function(v) ESPConfig.TeamColor = v end })
ESP:AddToggle({ Name = "Visibility Colors", Description = "Green when the camera sees them, red when blocked.", Default = true,
	Callback = function(v) ESPConfig.VisColor = v end })
ESP:AddToggle({ Name = "Boxes", Description = "Draws the bounding box.", Default = true,
	Callback = function(v) ESPConfig.ShowBox = v end })
ESP:AddToggle({ Name = "Health Bars", Description = "Draws a health bar under the box.", Default = true,
	Callback = function(v) ESPConfig.ShowHealth = v end })
ESP:AddToggle({ Name = "Names", Description = "Draws name and distance above the box.", Default = true,
	Callback = function(v) ESPConfig.ShowNames = v end })
ESP:AddSlider({ Name = "Max Distance", Description = "Hides ESP beyond this range. 0 = unlimited.", Min = 0, Max = 5000, Default = 2000, Increment = 50, Suffix = " st",
	Callback = function(v) ESPConfig.MaxDistance = v end })
ESP:AddSlider({ Name = "Text Size", Description = "Base size of the name text.", Min = 9, Max = 26, Default = 15,
	Callback = function(v) ESPConfig.BaseTextSize = v end })

Window:Notify("Loaded · " .. ((Game and Game.Name) or "Entrenched"))
