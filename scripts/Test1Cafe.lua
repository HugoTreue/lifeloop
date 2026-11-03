--========================================================
-- Test1Cafe (client-side) - Rayfield UI edition
-- RightShift hides/shows the window. "Kill UI" shuts everything
-- down; running the script again starts a clean new copy.
--========================================================
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

-- if an older copy is still running, shut it down first
local env = (getgenv and getgenv()) or _G
if env.Test1CafeKill then
	pcall(env.Test1CafeKill)
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
local function dropTools()
	-- if the game has a "DropAllTools" RemoteEvent (see the server Script),
	-- ask the server to do it so everyone sees it
	local remote = game:GetService("ReplicatedStorage"):FindFirstChild("DropAllTools")
	if remote and remote:IsA("RemoteEvent") then
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
		end
	end
	setStatus(("Dropped %d tool(s)"):format(n))
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
	warn("Test1Cafe: couldn't load Rayfield: " .. tostring(Rayfield))
	alive = false
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	return
end

local Window = Rayfield:CreateWindow({
	Name = "Test1Cafe",
	Icon = 0,
	LoadingTitle = "Test1Cafe",
	LoadingSubtitle = "client-side tools",
	ShowText = "Test1Cafe",
	Theme = "Default",
	ToggleUIKeybind = Enum.KeyCode.RightShift,
	DisableRayfieldPrompts = true,
	DisableBuildWarnings = true,
	ConfigurationSaving = { Enabled = false },
	KeySystem = false,
})

local Tab = Window:CreateTab("Main", "layout-dashboard")

-- automation ----------------------------------------------------
Tab:CreateSection("Automation")
Tab:CreateToggle({
	Name = "Auto gather",
	CurrentValue = false,
	Flag = "t1c_auto",
	Callback = function(on)
		cfg.auto = on
		setStatus(on and "Auto gather is ON" or "Auto gather is OFF")
	end,
})
Tab:CreateToggle({
	Name = "Click one = get all",
	CurrentValue = false,
	Flag = "t1c_clickall",
	Callback = function(on)
		cfg.clickAll = on
		setStatus(on and "Click one = get all is ON" or "Click one = get all is OFF")
	end,
})

-- move items ----------------------------------------------------
Tab:CreateSection("Move items")
Tab:CreateButton({ Name = "Bring all to me", Callback = bringAll })
Tab:CreateButton({ Name = "Put them back", Callback = restoreAll })

-- tools ---------------------------------------------------------
Tab:CreateSection("Tools")
local toolsInput
toolsInput = Tab:CreateInput({
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
Tab:CreateButton({ Name = "Drop tools", Callback = dropTools })

-- settings ------------------------------------------------------
Tab:CreateSection("Settings")
local nameInput
nameInput = Tab:CreateInput({
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
local delayInput
delayInput = Tab:CreateInput({
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

-- status --------------------------------------------------------
Tab:CreateSection("Status")
local countLabel = Tab:CreateLabel("Searching...", "search")
local statusLabel = Tab:CreateLabel("Ready", "activity")

setStatus = function(text, isErr)
	if not alive then return end
	statusLabel:Set(text, isErr and "triangle-alert" or "activity")
	if isErr then
		Rayfield:Notify({ Title = "Test1Cafe", Content = text, Duration = 4, Image = "triangle-alert" })
	end
end

if not fireclickdetector then
	setStatus("No fireclickdetector: clicking is off", true)
end

Tab:CreateSection("Danger zone")
Tab:CreateButton({ Name = "Kill UI", Callback = function() kill() end })

------------------------------------------------------------
-- KILL UI: stop everything, put things back, reset to defaults
------------------------------------------------------------
kill = function()
	if not alive then return end
	alive = false

	-- reset every function to its default
	cfg = defaultCfg()
	busy = false

	-- put moved items back where they were
	pcall(restoreAll)

	-- disconnect every listener this script made
	for _, c in ipairs(conns) do
		pcall(function() c:Disconnect() end)
	end
	conns = {}
	hooked = {}

	pcall(function() Rayfield:Destroy() end)
	if env.Test1CafeKill == kill then env.Test1CafeKill = nil end
end
env.Test1CafeKill = kill

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
