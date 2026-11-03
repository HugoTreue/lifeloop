--========================================================
-- RiTW Unboxed (client-side) - Rayfield UI edition
-- RightShift hides/shows the window. "Kill UI" shuts everything
-- down; running the script again starts a clean new copy.
--========================================================
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

-- if an older copy is still running, shut it down first
local env = (getgenv and getgenv()) or _G
if env.RiTWUnboxedKill then
	pcall(env.RiTWUnboxedKill)
end

------------------------------------------------------------
-- STATE
------------------------------------------------------------
local function defaultCfg()
	return {
		name = "Clickypart", -- name of the parts to work with
		interval = 3,        -- seconds between automatic clicks
		clickAll = false,    -- "click one = get all"
		auto = false,        -- "auto gather"
		maxTools = 0,        -- how many tools "Drop tools" drops; 0 = all
		speedOn = false, speed = 50,  -- custom walk speed
		jumpOn = false, jump = 100,   -- custom jump power
		infJump = false,     -- infinite jump
		noclip = false,      -- walk through walls
		antiAfk = false,     -- stop the idle kick
		notifyAll = false,   -- pop-up for every status message
	}
end
local cfg = defaultCfg()

local saved, hooked = {}, {}
local busy = false
local alive = true
local conns = {}
local setStatus = function() end -- replaced once the GUI exists
local kill                       -- defined after the GUI exists

local function track(c)
	conns[#conns + 1] = c
	return c
end

------------------------------------------------------------
-- LOGIC
------------------------------------------------------------
local function findParts()
	local t = {}
	for _, o in ipairs(Workspace:GetDescendants()) do
		if o:IsA("BasePart") and o.Name == cfg.name then t[#t + 1] = o end
	end
	return t
end

local function findDetectors()
	local t = {}
	for _, o in ipairs(Workspace:GetDescendants()) do
		if o:IsA("ClickDetector") and o.Parent and o.Parent.Name == cfg.name then
			t[#t + 1] = o
		end
	end
	return t
end

local function fireAll(except)
	if busy then return 0 end
	if not fireclickdetector then
		setStatus("Your mod menu has no fireclickdetector, so clicking is off", true)
		return 0
	end
	busy = true
	local n = 0
	for _, d in ipairs(findDetectors()) do
		if not alive then break end
		if d ~= except then
			fireclickdetector(d)
			n += 1
			task.wait()
		end
	end
	busy = false
	return n
end

local function bringAll()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not root then setStatus("No character yet", true) return end
	local n = 0
	for _, p in ipairs(findParts()) do
		if not saved[p] then
			saved[p] = { CFrame = p.CFrame, CanCollide = p.CanCollide, Anchored = p.Anchored }
		end
		p.CanCollide = false
		p.Anchored = true
		p.CFrame = root.CFrame
		n += 1
	end
	setStatus(("Brought %d item(s) to you"):format(n))
end

local function restoreAll()
	local n = 0
	for p, s in pairs(saved) do
		if p.Parent then
			p.CFrame, p.CanCollide, p.Anchored = s.CFrame, s.CanCollide, s.Anchored
			n += 1
		end
	end
	saved = {}
	setStatus(("Put %d item(s) back"):format(n))
end

-- drops the tools you're holding or carrying (up to cfg.maxTools, 0 = all)
-- dest (optional CFrame): drop them there instead of where you stand
local function dropTools(dest)
	-- if the game has a "DropAllTools" RemoteEvent (see the server Script),
	-- ask the server to do it so everyone sees it (only for a normal drop;
	-- the server event has no way to receive a chosen spot)
	local remote = game:GetService("ReplicatedStorage"):FindFirstChild("DropAllTools")
	if not dest and remote and remote:IsA("RemoteEvent") then
		remote:FireServer(cfg.maxTools)
		setStatus("Asked the server to drop your tools")
		return
	end

	-- otherwise fall back to the local drop (same method as Infinite Yield's droptools):
	-- equip everything first, wait a frame, then drop it from the character
	local char = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not (char and backpack and root) then setStatus("No character yet", true) return end

	-- pick the tools: equipped first, then backpack, capped at cfg.maxTools (0 = all)
	local selected = {}
	for _, container in ipairs({ char, backpack }) do
		for _, t in ipairs(container:GetChildren()) do
			if t:IsA("Tool") and (cfg.maxTools <= 0 or #selected < cfg.maxTools) then
				selected[#selected + 1] = t
			end
		end
	end

	-- step 1: backpack -> character (equips them so their handles are at you)
	for _, t in ipairs(selected) do
		if t.Parent == backpack then t.Parent = char end
	end

	task.wait() -- let them finish equipping / welding

	-- step 2: character -> workspace (removes the grip weld, they fall where you stand)
	local n = 0
	for _, t in ipairs(selected) do
		if t.Parent == char then
			t.Parent = Workspace
			n += 1
			-- chosen spot: move the handle there, fanned out so tools don't stack
			local handle = t:FindFirstChild("Handle")
			if dest and handle and handle:IsA("BasePart") then
				handle.CFrame = dest * CFrame.new((n - 1) * 1.5, 0, 0)
				handle.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			end
		end
	end
	setStatus(dest and ("Dropped %d tool(s) at your spot"):format(n) or ("Dropped %d tool(s)"):format(n))
end

local function hook(d)
	if hooked[d] then return end
	hooked[d] = true
	track(d.MouseClick:Connect(function()
		if alive and cfg.clickAll and d.Parent and d.Parent.Name == cfg.name then
			local n = fireAll(d)
			if n > 0 then setStatus(("Click one: also clicked %d more"):format(n)) end
		end
	end))
end

for _, o in ipairs(Workspace:GetDescendants()) do
	if o:IsA("ClickDetector") then hook(o) end
end
track(Workspace.DescendantAdded:Connect(function(o)
	if o:IsA("ClickDetector") then task.defer(hook, o) end
end))

------------------------------------------------------------
-- GUI (Rayfield)
------------------------------------------------------------
-- Rayfield is pinned to one exact commit so a library update can't change how the
-- panel looks or behaves. To upgrade on purpose, replace the commit hash below.
local RAYFIELD_COMMIT = "ae2eec9ac0a4f337b8437374e744958e619e6a49"
env.RAYFIELD_ANALYTICS = false -- opt out of Rayfield's anonymous usage counts
local okLoad, Rayfield = pcall(function()
	return loadstring(game:HttpGet(
		"https://raw.githubusercontent.com/SiriusSoftwareLtd/Rayfield/" .. RAYFIELD_COMMIT .. "/source.lua"
	))()
end)
if not okLoad or not Rayfield then
	warn("RiTW Unboxed: couldn't load Rayfield: " .. tostring(Rayfield))
	alive = false
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	return
end

-- Rayfield's "Default" theme, with a clearer hover highlight on every element.
-- (A custom theme must list every key, so the rest are Default's own values.)
local theme = {
	TextColor = Color3.fromRGB(240, 240, 240),

	Background = Color3.fromRGB(25, 25, 25),
	Topbar = Color3.fromRGB(34, 34, 34),
	Shadow = Color3.fromRGB(20, 20, 20),

	NotificationBackground = Color3.fromRGB(20, 20, 20),
	NotificationActionsBackground = Color3.fromRGB(230, 230, 230),

	TabBackground = Color3.fromRGB(80, 80, 80),
	TabStroke = Color3.fromRGB(85, 85, 85),
	TabBackgroundSelected = Color3.fromRGB(210, 210, 210),
	TabTextColor = Color3.fromRGB(240, 240, 240),
	SelectedTabTextColor = Color3.fromRGB(50, 50, 50),

	ElementBackground = Color3.fromRGB(35, 35, 35),
	ElementBackgroundHover = Color3.fromRGB(58, 62, 74), -- Default is (40, 40, 40); raise to taste
	SecondaryElementBackground = Color3.fromRGB(25, 25, 25),
	ElementStroke = Color3.fromRGB(50, 50, 50),
	SecondaryElementStroke = Color3.fromRGB(40, 40, 40),

	SliderBackground = Color3.fromRGB(50, 138, 220),
	SliderProgress = Color3.fromRGB(50, 138, 220),
	SliderStroke = Color3.fromRGB(58, 163, 255),

	ToggleBackground = Color3.fromRGB(30, 30, 30),
	ToggleEnabled = Color3.fromRGB(0, 146, 214),
	ToggleDisabled = Color3.fromRGB(100, 100, 100),
	ToggleEnabledStroke = Color3.fromRGB(0, 170, 255),
	ToggleDisabledStroke = Color3.fromRGB(125, 125, 125),
	ToggleEnabledOuterStroke = Color3.fromRGB(100, 100, 100),
	ToggleDisabledOuterStroke = Color3.fromRGB(65, 65, 65),

	DropdownSelected = Color3.fromRGB(40, 40, 40),
	DropdownUnselected = Color3.fromRGB(30, 30, 30),

	InputBackground = Color3.fromRGB(30, 30, 30),
	InputStroke = Color3.fromRGB(65, 65, 65),
	PlaceholderColor = Color3.fromRGB(178, 178, 178),
}

local Window = Rayfield:CreateWindow({
	Name = "RiTW Unboxed",
	Icon = 0,
	LoadingTitle = "RiTW Unboxed",
	LoadingSubtitle = "client-side tools",
	ShowText = "RiTW Unboxed",
	Theme = theme,
	ToggleUIKeybind = Enum.KeyCode.RightShift,
	DisableRayfieldPrompts = true,
	DisableBuildWarnings = true,
	ConfigurationSaving = { Enabled = false },
	KeySystem = false,
})

------------------------------------------------------------
-- PLAYER (speed / jump / noclip helpers)
------------------------------------------------------------
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local origSpeed, origJump, origUseJP -- game's own values, restored when a toggle goes off

local function getHumanoid()
	local c = player.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

local function applyMovement()
	local h = getHumanoid()
	if not h then return end

	if cfg.speedOn then
		if not origSpeed then origSpeed = h.WalkSpeed end
		h.WalkSpeed = cfg.speed
	elseif origSpeed then
		h.WalkSpeed = origSpeed
		origSpeed = nil
	end

	if cfg.jumpOn then
		if not origJump then origJump, origUseJP = h.JumpPower, h.UseJumpPower end
		h.UseJumpPower = true
		h.JumpPower = cfg.jump
	elseif origJump then
		h.JumpPower = origJump
		h.UseJumpPower = origUseJP
		origJump, origUseJP = nil, nil
	end
end

-- infinite jump: every jump press while airborne becomes a new jump
track(UserInputService.JumpRequest:Connect(function()
	if cfg.infJump then
		local h = getHumanoid()
		if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
	end
end))

-- noclip: keep every part of your character non-solid
track(RunService.Stepped:Connect(function()
	if cfg.noclip and player.Character then
		for _, p in ipairs(player.Character:GetDescendants()) do
			if p:IsA("BasePart") then p.CanCollide = false end
		end
	end
end))

-- anti-AFK: a tiny fake click whenever Roblox thinks you're idle
track(player.Idled:Connect(function()
	if cfg.antiAfk then
		local vu = game:GetService("VirtualUser")
		vu:CaptureController()
		vu:ClickButton2(Vector2.new())
	end
end))

task.spawn(function() -- keeps speed/jump applied (games often reset them)
	while alive do
		applyMovement()
		task.wait(0.2)
	end
end)

------------------------------------------------------------
-- GUI TABS
------------------------------------------------------------
local ItemsTab = Window:CreateTab("Items", "package")
local ToolsTab = Window:CreateTab("Tools", "wrench")
local PlayerTab = Window:CreateTab("Player", "user")
local ConfigTab = Window:CreateTab("Config", "settings")

-- every tab gets a status line; setStatus updates them all
local statusLabels = {}
local function addStatus(tab)
	tab:CreateSection("Status")
	statusLabels[#statusLabels + 1] = tab:CreateLabel("Ready", "activity")
end

-- element handles, kept so "Reset all" can put them back to defaults
local autoToggle, clickToggle, nameInput, delayInput
local toolsInput, speedToggle, speedSlider, jumpToggle, jumpSlider
local infToggle, noclipToggle, afkToggle

-- ITEMS ---------------------------------------------------------
ItemsTab:CreateSection("Automation")
autoToggle = ItemsTab:CreateToggle({
	Name = "Auto gather",
	CurrentValue = false,
	Flag = "t1c_auto",
	Callback = function(on)
		cfg.auto = on
		setStatus(on and "Auto gather is ON" or "Auto gather is OFF")
	end,
})
clickToggle = ItemsTab:CreateToggle({
	Name = "Click one = get all",
	CurrentValue = false,
	Flag = "t1c_clickall",
	Callback = function(on)
		cfg.clickAll = on
		setStatus(on and "Click one = get all is ON" or "Click one = get all is OFF")
	end,
})

ItemsTab:CreateSection("Move items")
ItemsTab:CreateButton({ Name = "Bring all to me", Callback = bringAll })
ItemsTab:CreateButton({ Name = "Put them back", Callback = restoreAll })

ItemsTab:CreateSection("Item settings")
nameInput = ItemsTab:CreateInput({
	Name = "Item name",
	CurrentValue = cfg.name,
	PlaceholderText = "Clickypart",
	RemoveTextAfterFocusLost = false,
	Flag = "t1c_itemname",
	Callback = function(text)
		if text ~= "" then cfg.name = text end
		if nameInput then nameInput:Set(cfg.name) end
	end,
})
delayInput = ItemsTab:CreateInput({
	Name = "Auto delay (sec)",
	CurrentValue = tostring(cfg.interval),
	PlaceholderText = "3",
	RemoveTextAfterFocusLost = false,
	Flag = "t1c_delay",
	Callback = function(text)
		local n = tonumber(text)
		if n then cfg.interval = math.max(0.5, n) end
		if delayInput then delayInput:Set(tostring(cfg.interval)) end
	end,
})

ItemsTab:CreateSection("Found")
local countLabel = ItemsTab:CreateLabel("Searching...", "search")
addStatus(ItemsTab)

-- TOOLS ---------------------------------------------------------
ToolsTab:CreateSection("Drop tools")
toolsInput = ToolsTab:CreateInput({
	Name = "Tools to drop (0 = all)",
	CurrentValue = tostring(cfg.maxTools),
	PlaceholderText = "0",
	RemoveTextAfterFocusLost = false,
	Flag = "t1c_maxtools",
	Callback = function(text)
		local n = tonumber(text)
		if n then cfg.maxTools = math.max(0, math.floor(n)) end
		if toolsInput then toolsInput:Set(tostring(cfg.maxTools)) end
	end,
})
ToolsTab:CreateButton({ Name = "Drop tools", Callback = function() dropTools() end })

-- drop at a chosen spot
ToolsTab:CreateSection("Drop at a spot")
local dropPoint, picking
local spotLabel = ToolsTab:CreateLabel("Spot: not set", "map-pin")

local function setSpot(cf)
	dropPoint = cf
	local p = cf.Position
	spotLabel:Set(("Spot: %d, %d, %d"):format(math.floor(p.X), math.floor(p.Y), math.floor(p.Z)), "map-pin")
	setStatus("Drop spot saved")
end

ToolsTab:CreateButton({
	Name = "Pick spot (then click in the world)",
	Callback = function()
		picking = true
		setStatus("Click anywhere in the world to set the spot")
	end,
})
ToolsTab:CreateButton({
	Name = "Use my position as the spot",
	Callback = function()
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root then setStatus("No character yet", true) return end
		picking = false
		setSpot(root.CFrame)
	end,
})
ToolsTab:CreateButton({
	Name = "Drop tools at the spot",
	Callback = function()
		if not dropPoint then setStatus("Set a spot first", true) return end
		dropTools(dropPoint)
	end,
})

-- the click that finishes "Pick spot" (clicks on the panel itself are ignored)
track(UserInputService.InputBegan:Connect(function(input, processed)
	if picking and not processed and input.UserInputType == Enum.UserInputType.MouseButton1 then
		picking = false
		local hit = player:GetMouse().Hit
		if hit then setSpot(CFrame.new(hit.Position + Vector3.new(0, 3, 0))) end
	end
end))
addStatus(ToolsTab)

-- PLAYER --------------------------------------------------------
PlayerTab:CreateSection("Movement")
speedToggle = PlayerTab:CreateToggle({
	Name = "Custom walk speed",
	CurrentValue = false,
	Flag = "t1c_speedon",
	Callback = function(on)
		cfg.speedOn = on
		applyMovement()
		setStatus(on and ("Walk speed set to " .. cfg.speed) or "Walk speed back to normal")
	end,
})
speedSlider = PlayerTab:CreateSlider({
	Name = "Walk speed",
	Range = { 16, 250 },
	Increment = 1,
	Suffix = "studs/s",
	CurrentValue = cfg.speed,
	Flag = "t1c_speed",
	Callback = function(v)
		cfg.speed = v
		applyMovement()
	end,
})
jumpToggle = PlayerTab:CreateToggle({
	Name = "Custom jump power",
	CurrentValue = false,
	Flag = "t1c_jumpon",
	Callback = function(on)
		cfg.jumpOn = on
		applyMovement()
		setStatus(on and ("Jump power set to " .. cfg.jump) or "Jump power back to normal")
	end,
})
jumpSlider = PlayerTab:CreateSlider({
	Name = "Jump power",
	Range = { 50, 400 },
	Increment = 1,
	Suffix = "power",
	CurrentValue = cfg.jump,
	Flag = "t1c_jump",
	Callback = function(v)
		cfg.jump = v
		applyMovement()
	end,
})

PlayerTab:CreateSection("Abilities")
infToggle = PlayerTab:CreateToggle({
	Name = "Infinite jump",
	CurrentValue = false,
	Flag = "t1c_infjump",
	Callback = function(on)
		cfg.infJump = on
		setStatus(on and "Infinite jump is ON" or "Infinite jump is OFF")
	end,
})
noclipToggle = PlayerTab:CreateToggle({
	Name = "Noclip",
	CurrentValue = false,
	Flag = "t1c_noclip",
	Callback = function(on)
		cfg.noclip = on
		setStatus(on and "Noclip is ON" or "Noclip is OFF")
	end,
})
afkToggle = PlayerTab:CreateToggle({
	Name = "Anti-AFK",
	CurrentValue = false,
	Flag = "t1c_afk",
	Callback = function(on)
		cfg.antiAfk = on
		setStatus(on and "Anti-AFK is ON" or "Anti-AFK is OFF")
	end,
})

PlayerTab:CreateSection("Quick actions")
PlayerTab:CreateButton({
	Name = "Reset speed and jump",
	Callback = function()
		speedToggle:Set(false)
		jumpToggle:Set(false)
		setStatus("Speed and jump reset")
	end,
})
addStatus(PlayerTab)

-- CONFIG --------------------------------------------------------
ConfigTab:CreateSection("Interface")
ConfigTab:CreateDropdown({
	Name = "Theme",
	Options = { "Default", "Ocean", "AmberGlow", "Light", "Amethyst", "Green", "Bloom", "DarkBlue", "Serenity" },
	CurrentOption = { "Default" },
	MultipleOptions = false,
	Flag = "t1c_theme",
	Callback = function(opt)
		local name = type(opt) == "table" and opt[1] or opt
		-- "Default" is the custom theme with the clearer hover highlight
		Window.ModifyTheme(name == "Default" and theme or name)
	end,
})
ConfigTab:CreateToggle({
	Name = "Pop-up for every action",
	CurrentValue = false,
	Flag = "t1c_notifyall",
	Callback = function(on)
		cfg.notifyAll = on
		setStatus(on and "Pop-ups are ON" or "Pop-ups are OFF")
	end,
})

ConfigTab:CreateSection("Defaults")
ConfigTab:CreateButton({
	Name = "Reset all settings",
	Callback = function()
		-- flip every control back; each one's callback updates cfg to match
		for _, t in ipairs({ autoToggle, clickToggle, speedToggle, jumpToggle, infToggle, noclipToggle, afkToggle }) do
			t:Set(false)
		end
		local d = defaultCfg()
		nameInput:Set(d.name)
		delayInput:Set(tostring(d.interval))
		toolsInput:Set(tostring(d.maxTools))
		speedSlider:Set(d.speed)
		jumpSlider:Set(d.jump)
		setStatus("All settings reset")
	end,
})

ConfigTab:CreateSection("Game")
ConfigTab:CreateButton({
	Name = "Rejoin this server",
	Callback = function()
		setStatus("Rejoining...")
		local ts = game:GetService("TeleportService")
		if #Players:GetPlayers() <= 1 then
			ts:Teleport(game.PlaceId, player)
		else
			ts:TeleportToPlaceInstance(game.PlaceId, game.JobId, player)
		end
	end,
})

ConfigTab:CreateSection("Danger zone")
ConfigTab:CreateButton({ Name = "Kill UI", Callback = function() kill() end })
addStatus(ConfigTab)

setStatus = function(text, isErr)
	if not alive then return end
	for _, l in ipairs(statusLabels) do
		l:Set(text, isErr and "triangle-alert" or "activity")
	end
	if isErr or cfg.notifyAll then
		Rayfield:Notify({
			Title = "RiTW Unboxed", Content = text, Duration = 4,
			Image = isErr and "triangle-alert" or "info",
		})
	end
end

if not fireclickdetector then
	setStatus("No fireclickdetector: clicking is off", true)
end

------------------------------------------------------------
-- KILL UI: stop everything, put things back, reset to defaults
------------------------------------------------------------
kill = function()
	if not alive then return end
	alive = false

	-- reset every function to its default (and give speed/jump back to the game)
	cfg = defaultCfg()
	busy = false
	pcall(applyMovement)

	-- put moved items back where they were
	pcall(restoreAll)

	-- disconnect every listener this script made
	for _, c in ipairs(conns) do
		pcall(function() c:Disconnect() end)
	end
	conns = {}
	hooked = {}

	pcall(function() Rayfield:Destroy() end)
	if env.RiTWUnboxedKill == kill then env.RiTWUnboxedKill = nil end
end
env.RiTWUnboxedKill = kill

------------------------------------------------------------
-- BACKGROUND LOOPS (stop when the panel is killed)
------------------------------------------------------------
task.spawn(function() -- auto gather
	while alive do
		task.wait(cfg.interval)
		if alive and cfg.auto then
			local n = fireAll()
			if n > 0 then setStatus(("Auto gather: clicked %d item(s)"):format(n)) end
		end
	end
end)

task.spawn(function() -- item counter
	while alive do
		countLabel:Set(('%d item(s) named "%s"'):format(#findParts(), cfg.name), "search")
		task.wait(3)
	end
end)
