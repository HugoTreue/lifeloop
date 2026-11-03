--========================================================
-- Test1Cafe: Clicky Panel v3 (client-side only)
-- Draggable (title bar), resizable (corner), RightShift hides/shows
-- "Kill UI" fully shuts everything down; running the script again
-- starts a clean new copy.
--========================================================
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

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
		maxTools = 0,        -- how many tools "Drop all tools" drops; 0 = all
	}
end
local cfg = defaultCfg()

local saved, hooked = {}, {}
local busy = false
local alive = true
local conns = {}
local setStatus = function() end   -- replaced once the GUI exists
local refreshDot = function() end  -- replaced once the GUI exists
local kill                         -- defined after the GUI exists

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

-- drops every tool you're holding or carrying, in front of you.
-- Client-side only: the server still thinks you own them.
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
-- STYLE
------------------------------------------------------------
local C = {
	bg      = Color3.fromRGB(22, 23, 29),
	title   = Color3.fromRGB(30, 31, 40),
	card    = Color3.fromRGB(33, 35, 45),
	cardHi  = Color3.fromRGB(40, 43, 55),
	stroke  = Color3.fromRGB(55, 58, 74),
	text    = Color3.fromRGB(236, 237, 243),
	dim     = Color3.fromRGB(135, 139, 156),
	accent  = Color3.fromRGB(88, 140, 255),
	accentHi = Color3.fromRGB(112, 160, 255),
	accent2 = Color3.fromRGB(160, 100, 255),
	on      = Color3.fromRGB(70, 200, 120),
	off     = Color3.fromRGB(70, 73, 90),
	err     = Color3.fromRGB(240, 100, 100),
	dangerBg = Color3.fromRGB(70, 34, 40),
	dangerHi = Color3.fromRGB(100, 42, 50),
}

local FAST = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function new(class, props, parent)
	local i = Instance.new(class)
	for k, v in pairs(props) do i[k] = v end
	i.Parent = parent
	return i
end

local function round(parent, r)
	return new("UICorner", { CornerRadius = UDim.new(0, r or 8) }, parent)
end

local function stroke(parent, color, thickness)
	return new("UIStroke", {
		Color = color or C.stroke,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

local function tween(obj, props)
	TweenService:Create(obj, FAST, props):Play()
end

local function hover(obj, prop, normal, over)
	obj.MouseEnter:Connect(function() tween(obj, { [prop] = over }) end)
	obj.MouseLeave:Connect(function() tween(obj, { [prop] = normal }) end)
end

------------------------------------------------------------
-- GUI: WINDOW
------------------------------------------------------------
local pg = player:WaitForChild("PlayerGui")
for _, n in ipairs({ "ClickyPanel", "ClickySwitch" }) do
	local old = pg:FindFirstChild(n)
	if old then old:Destroy() end
end

local gui = new("ScreenGui", { Name = "ClickyPanel", ResetOnSpawn = false }, pg)

local main = new("Frame", {
	Size = UDim2.new(0, 290, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Position = UDim2.new(0, 40, 0, 100),
	BackgroundColor3 = C.bg,
	BorderSizePixel = 0,
}, gui)
round(main, 12)
stroke(main, C.stroke, 1)
new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, main)

-- title bar --------------------------------------------------
local titleBar = new("Frame", {
	Size = UDim2.new(1, 0, 0, 44),
	BackgroundColor3 = C.title,
	BorderSizePixel = 0,
	LayoutOrder = 0,
}, main)
round(titleBar, 12)

local filler = new("Frame", {
	Size = UDim2.new(1, 0, 0, 12),
	Position = UDim2.new(0, 0, 1, -12),
	BackgroundColor3 = C.title,
	BorderSizePixel = 0,
}, titleBar)

local logo = new("Frame", {
	Size = UDim2.new(0, 26, 0, 26),
	Position = UDim2.new(0, 12, 0.5, -13),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BorderSizePixel = 0,
}, titleBar)
round(logo, 8)
new("UIGradient", {
	Color = ColorSequence.new(C.accent, C.accent2),
	Rotation = 45,
}, logo)
new("TextLabel", {
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundTransparency = 1,
	Text = "C",
	TextColor3 = Color3.new(1, 1, 1),
	Font = Enum.Font.GothamBold,
	TextSize = 15,
}, logo)

new("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.new(0, 46, 0, 6),
	Size = UDim2.new(1, -150, 0, 18),
	Text = "Test1Cafe",
	TextColor3 = C.text,
	Font = Enum.Font.GothamBold,
	TextSize = 15,
	TextXAlignment = Enum.TextXAlignment.Left,
}, titleBar)
new("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.new(0, 46, 0, 24),
	Size = UDim2.new(1, -150, 0, 14),
	Text = "client-side tools",
	TextColor3 = C.dim,
	Font = Enum.Font.Gotham,
	TextSize = 11,
	TextXAlignment = Enum.TextXAlignment.Left,
}, titleBar)

local dot = new("Frame", {
	Size = UDim2.new(0, 8, 0, 8),
	Position = UDim2.new(1, -96, 0.5, -4),
	BackgroundColor3 = C.off,
	BorderSizePixel = 0,
}, titleBar)
round(dot, 4)

refreshDot = function()
	tween(dot, { BackgroundColor3 = (cfg.auto or cfg.clickAll) and C.on or C.off })
end

local content = new("Frame", {
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	LayoutOrder = 1,
}, main)
new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, content)
new("UIPadding", {
	PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 14),
	PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12),
}, content)

local function titleButton(text, xOffset, color, hoverColor, callback)
	local b = new("TextButton", {
		Size = UDim2.new(0, 26, 0, 26),
		Position = UDim2.new(1, xOffset, 0.5, -13),
		BackgroundColor3 = C.card,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = text,
		TextColor3 = color,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		AutoButtonColor = false,
	}, titleBar)
	round(b, 7)
	b.MouseEnter:Connect(function()
		tween(b, { BackgroundTransparency = 0, TextColor3 = hoverColor })
	end)
	b.MouseLeave:Connect(function()
		tween(b, { BackgroundTransparency = 1, TextColor3 = color })
	end)
	b.MouseButton1Click:Connect(callback)
end
titleButton("X", -36, C.dim, C.err, function() kill() end)
titleButton("-", -66, C.dim, C.text, function()
	content.Visible = not content.Visible
	filler.Visible = content.Visible
end)

------------------------------------------------------------
-- GUI: BUILDING BLOCKS
------------------------------------------------------------
local function header(text)
	local row = new("Frame", {
		Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1,
	}, content)
	local bar = new("Frame", {
		Size = UDim2.new(0, 3, 0, 12), Position = UDim2.new(0, 0, 0.5, -6),
		BackgroundColor3 = C.accent, BorderSizePixel = 0,
	}, row)
	round(bar, 2)
	new("TextLabel", {
		Size = UDim2.new(1, -10, 1, 0), Position = UDim2.new(0, 10, 0, 0),
		BackgroundTransparency = 1, Text = text, TextColor3 = C.dim,
		Font = Enum.Font.GothamBold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
	}, row)
end

local function makeToggle(title, hint, callback)
	local row = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 50), BackgroundColor3 = C.card, BorderSizePixel = 0,
		Text = "", AutoButtonColor = false,
	}, content)
	round(row, 9)
	stroke(row)
	hover(row, "BackgroundColor3", C.card, C.cardHi)

	new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 7),
		Size = UDim2.new(1, -76, 0, 18), Text = title, TextColor3 = C.text,
		Font = Enum.Font.GothamBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
	}, row)
	new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 26),
		Size = UDim2.new(1, -76, 0, 16), Text = hint, TextColor3 = C.dim,
		Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, row)

	local pill = new("Frame", {
		Size = UDim2.new(0, 42, 0, 24), Position = UDim2.new(1, -54, 0.5, -12),
		BackgroundColor3 = C.off, BorderSizePixel = 0,
	}, row)
	round(pill, 12)
	local knob = new("Frame", {
		Size = UDim2.new(0, 18, 0, 18), Position = UDim2.new(0, 3, 0.5, -9),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
	}, pill)
	round(knob, 9)

	local state = false
	row.MouseButton1Click:Connect(function()
		state = not state
		tween(pill, { BackgroundColor3 = state and C.on or C.off })
		tween(knob, { Position = state and UDim2.new(0, 21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9) })
		callback(state)
		refreshDot()
	end)
end

local function makeButtons(a, b)
	local row = new("Frame", {
		Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1,
	}, content)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8),
	}, row)

	local primary = new("TextButton", {
		Size = UDim2.new(0.5, -4, 1, 0), BackgroundColor3 = C.accent, BorderSizePixel = 0,
		Text = a[1], TextColor3 = Color3.new(1, 1, 1), AutoButtonColor = false,
		Font = Enum.Font.GothamBold, TextSize = 13,
	}, row)
	round(primary, 9)
	hover(primary, "BackgroundColor3", C.accent, C.accentHi)
	primary.MouseButton1Click:Connect(a[2])

	local secondary = new("TextButton", {
		Size = UDim2.new(0.5, -4, 1, 0), BackgroundColor3 = C.card, BorderSizePixel = 0,
		Text = b[1], TextColor3 = C.text, AutoButtonColor = false,
		Font = Enum.Font.GothamBold, TextSize = 13,
	}, row)
	round(secondary, 9)
	stroke(secondary)
	hover(secondary, "BackgroundColor3", C.card, C.cardHi)
	secondary.MouseButton1Click:Connect(b[2])
end

-- full-width button; style = "normal" or "danger"
local function makeWide(text, style, callback)
	local danger = style == "danger"
	local base = danger and C.dangerBg or C.card
	local over = danger and C.dangerHi or C.cardHi
	local btn = new("TextButton", {
		Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = base, BorderSizePixel = 0,
		Text = text, TextColor3 = danger and C.err or C.text, AutoButtonColor = false,
		Font = Enum.Font.GothamBold, TextSize = 13,
	}, content)
	round(btn, 9)
	stroke(btn, danger and C.err or C.stroke)
	hover(btn, "BackgroundColor3", base, over)
	btn.MouseButton1Click:Connect(callback)
	return btn
end

local function makeInput(label, default, callback)
	local row = new("Frame", {
		Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = C.card, BorderSizePixel = 0,
	}, content)
	round(row, 9)
	stroke(row)
	new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 0),
		Size = UDim2.new(1, -140, 1, 0), Text = label, TextColor3 = C.text,
		Font = Enum.Font.GothamMedium, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
	}, row)
	local box = new("TextBox", {
		Size = UDim2.new(0, 112, 0, 26), Position = UDim2.new(1, -122, 0.5, -13),
		BackgroundColor3 = C.bg, BorderSizePixel = 0, Text = tostring(default),
		TextColor3 = C.text, Font = Enum.Font.Gotham, TextSize = 13, ClearTextOnFocus = false,
		PlaceholderText = "...", PlaceholderColor3 = C.dim,
	}, row)
	round(box, 7)
	local s = stroke(box, C.stroke, 1)
	box.Focused:Connect(function() tween(s, { Color = C.accent }) end)
	box.FocusLost:Connect(function()
		tween(s, { Color = C.stroke })
		box.Text = tostring(callback(box.Text))
	end)
end

------------------------------------------------------------
-- GUI: CONTENT
------------------------------------------------------------
header("AUTOMATION")
makeToggle("Auto gather", "Clicks every item for you", function(on)
	cfg.auto = on
	setStatus(on and "Auto gather is ON" or "Auto gather is OFF")
end)
makeToggle("Click one = get all", "Click one item, all fire", function(on)
	cfg.clickAll = on
	setStatus(on and "Click one = get all is ON" or "Click one = get all is OFF")
end)

header("MOVE ITEMS")
makeButtons({ "Bring all to me", bringAll }, { "Put them back", restoreAll })

header("TOOLS")
makeWide("Drop all tools", "normal", dropTools)
makeInput("Tools to drop (0 = all)", cfg.maxTools, function(text)
	local n = tonumber(text)
	if n then cfg.maxTools = math.max(0, math.floor(n)) end
	return cfg.maxTools
end)

header("SETTINGS")
makeInput("Item name", cfg.name, function(text)
	if text ~= "" then cfg.name = text end
	return cfg.name
end)
makeInput("Auto delay (sec)", cfg.interval, function(text)
	local n = tonumber(text)
	if n then cfg.interval = math.max(0.5, n) end
	return cfg.interval
end)

-- footer card: item counter + status line
local footer = new("Frame", {
	Size = UDim2.new(1, 0, 0, 64), BackgroundColor3 = C.card, BorderSizePixel = 0,
}, content)
round(footer, 9)
stroke(footer)

local countLabel = new("TextLabel", {
	BackgroundTransparency = 1, Position = UDim2.new(0, 12, 0, 7),
	Size = UDim2.new(1, -24, 0, 16), Text = "Found: ...", RichText = true,
	TextColor3 = C.text, Font = Enum.Font.GothamMedium, TextSize = 12,
	TextXAlignment = Enum.TextXAlignment.Left,
}, footer)

local statusDot = new("Frame", {
	Size = UDim2.new(0, 6, 0, 6), Position = UDim2.new(0, 12, 0, 33),
	BackgroundColor3 = C.on, BorderSizePixel = 0,
}, footer)
round(statusDot, 3)

local statusLabel = new("TextLabel", {
	BackgroundTransparency = 1, Position = UDim2.new(0, 24, 0, 28),
	Size = UDim2.new(1, -36, 0, 16), Text = "Ready",
	TextColor3 = C.dim, Font = Enum.Font.Gotham, TextSize = 12,
	TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
}, footer)

new("TextLabel", {
	BackgroundTransparency = 1, Position = UDim2.new(0, 12, 1, -18),
	Size = UDim2.new(1, -24, 0, 12),
	Text = "RightShift hides  |  drag corner to resize",
	TextColor3 = C.dim, Font = Enum.Font.Gotham, TextSize = 10,
	TextXAlignment = Enum.TextXAlignment.Left,
}, footer)

makeWide("Kill UI", "danger", function() kill() end)

setStatus = function(text, isErr)
	statusLabel.Text = text
	statusLabel.TextColor3 = isErr and C.err or C.text
	tween(statusDot, { BackgroundColor3 = isErr and C.err or C.on })
end

if not fireclickdetector then
	setStatus("No fireclickdetector: clicking is off", true)
end

------------------------------------------------------------
-- DRAGGING (title bar) and hotkey
------------------------------------------------------------
local dragging, dragStart, startPos
titleBar.InputBegan:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1
		or i.UserInputType == Enum.UserInputType.Touch then
		dragging, dragStart, startPos = true, i.Position, main.Position
	end
end)
track(UserInputService.InputChanged:Connect(function(i)
	if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
		or i.UserInputType == Enum.UserInputType.Touch) then
		local d = i.Position - dragStart
		main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
			startPos.Y.Scale, startPos.Y.Offset + d.Y)
	end
end))
track(UserInputService.InputEnded:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1
		or i.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end))
track(UserInputService.InputBegan:Connect(function(i, processed)
	if not processed and i.KeyCode == Enum.KeyCode.RightShift then
		main.Visible = not main.Visible
	end
end))

------------------------------------------------------------
-- RESIZE (drag the corner grip)
------------------------------------------------------------
local BASE_WIDTH = 290
local MIN_SCALE, MAX_SCALE = 0.6, 2.5

local uiScale = new("UIScale", { Scale = 1 }, main)

local handle = new("TextButton", {
	Size = UDim2.new(0, 22, 0, 22),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Text = "◢",
	TextColor3 = C.dim,
	TextSize = 13,
	Font = Enum.Font.GothamBold,
	AutoButtonColor = false,
	ZIndex = 10,
}, gui)
handle.MouseEnter:Connect(function() tween(handle, { TextColor3 = C.accent }) end)
handle.MouseLeave:Connect(function() tween(handle, { TextColor3 = C.dim }) end)

local function placeHandle()
	handle.Position = UDim2.fromOffset(
		main.AbsolutePosition.X + main.AbsoluteSize.X - 24,
		main.AbsolutePosition.Y + main.AbsoluteSize.Y - 24
	)
	handle.Visible = main.Visible
end
main:GetPropertyChangedSignal("AbsolutePosition"):Connect(placeHandle)
main:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeHandle)
main:GetPropertyChangedSignal("Visible"):Connect(placeHandle)
placeHandle()

local resizing, rStart, rScale
handle.InputBegan:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1
		or i.UserInputType == Enum.UserInputType.Touch then
		resizing, rStart, rScale = true, i.Position, uiScale.Scale
	end
end)
track(UserInputService.InputChanged:Connect(function(i)
	if resizing and (i.UserInputType == Enum.UserInputType.MouseMovement
		or i.UserInputType == Enum.UserInputType.Touch) then
		local dx = i.Position.X - rStart.X
		uiScale.Scale = math.clamp(rScale + dx / BASE_WIDTH, MIN_SCALE, MAX_SCALE)
	end
end))
track(UserInputService.InputEnded:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1
		or i.UserInputType == Enum.UserInputType.Touch then
		resizing = false
	end
end))

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

	if gui then gui:Destroy() end
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
		if content.Visible then
			countLabel.Text = ('Found <b>%d</b> item(s) named "%s"'):format(#findParts(), cfg.name)
		end
		task.wait(3)
	end
end)
