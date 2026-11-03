--========================================================
-- Test1Cafe: Clicky Panel (client-side only, draggable + resizable)
--========================================================
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

------------------------------------------------------------
-- STATE
------------------------------------------------------------
local cfg = {
	name = "Clickypart",
	interval = 3,
	clickAll = false,
	auto = false,
}
local saved, hooked = {}, {}
local busy = false
local setStatus = function() end

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

local function hook(d)
	if hooked[d] then return end
	hooked[d] = true
	d.MouseClick:Connect(function()
		if cfg.clickAll and d.Parent and d.Parent.Name == cfg.name then
			local n = fireAll(d)
			if n > 0 then setStatus(("Click one: also clicked %d more"):format(n)) end
		end
	end)
end

for _, o in ipairs(Workspace:GetDescendants()) do
	if o:IsA("ClickDetector") then hook(o) end
end
Workspace.DescendantAdded:Connect(function(o)
	if o:IsA("ClickDetector") then task.defer(hook, o) end
end)

------------------------------------------------------------
-- GUI HELPERS
------------------------------------------------------------
local C = {
	bg = Color3.fromRGB(28, 29, 36),
	title = Color3.fromRGB(40, 42, 54),
	row = Color3.fromRGB(40, 42, 52),
	text = Color3.fromRGB(235, 235, 240),
	dim = Color3.fromRGB(150, 153, 165),
	accent = Color3.fromRGB(70, 130, 240),
	on = Color3.fromRGB(60, 180, 100),
	off = Color3.fromRGB(80, 82, 95),
	err = Color3.fromRGB(240, 110, 110),
}

local function new(class, props, parent)
	local i = Instance.new(class)
	for k, v in pairs(props) do i[k] = v end
	i.Parent = parent
	return i
end

local function round(parent, r)
	new("UICorner", { CornerRadius = UDim.new(0, r or 8) }, parent)
end

------------------------------------------------------------
-- GUI
------------------------------------------------------------
local pg = player:WaitForChild("PlayerGui")
for _, n in ipairs({ "ClickyPanel", "ClickySwitch" }) do
	local old = pg:FindFirstChild(n)
	if old then old:Destroy() end
end

local gui = new("ScreenGui", { Name = "ClickyPanel", ResetOnSpawn = false }, pg)

local main = new("Frame", {
	Size = UDim2.new(0, 270, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	Position = UDim2.new(0, 40, 0, 100),
	BackgroundColor3 = C.bg,
	BorderSizePixel = 0,
}, gui)
round(main, 10)
new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, main)

local titleBar = new("Frame", {
	Size = UDim2.new(1, 0, 0, 34),
	BackgroundColor3 = C.title,
	BorderSizePixel = 0,
	LayoutOrder = 0,
}, main)
round(titleBar, 10)

new("TextLabel", {
	BackgroundTransparency = 1,
	Position = UDim2.new(0, 12, 0, 0),
	Size = UDim2.new(1, -80, 1, 0),
	Text = "Clicky Panel",
	TextColor3 = C.text,
	Font = Enum.Font.GothamBold,
	TextSize = 15,
	TextXAlignment = Enum.TextXAlignment.Left,
}, titleBar)

local content = new("Frame", {
	Size = UDim2.new(1, 0, 0, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	LayoutOrder = 1,
}, main)
new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, content)
new("UIPadding", {
	PaddingTop = UDim.new(0, 10), PaddingBottom = UDim.new(0, 10),
	PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10),
}, content)

local function titleButton(text, xOffset, color, callback)
	local b = new("TextButton", {
		Size = UDim2.new(0, 30, 1, 0),
		Position = UDim2.new(1, xOffset, 0, 0),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = color,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
	}, titleBar)
	b.MouseButton1Click:Connect(callback)
end
titleButton("X", -32, C.err, function() gui:Destroy() end)
titleButton("-", -62, C.dim, function() content.Visible = not content.Visible end)

local function header(text)
	new("TextLabel", {
		Size = UDim2.new(1, 0, 0, 14),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = C.dim,
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, content)
end

local function makeToggle(title, hint, callback)
	local row = new("Frame", {
		Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = C.row, BorderSizePixel = 0,
	}, content)
	round(row)
	new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0, 5),
		Size = UDim2.new(1, -70, 0, 18), Text = title, TextColor3 = C.text,
		Font = Enum.Font.GothamBold, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
	}, row)
	new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0, 24),
		Size = UDim2.new(1, -70, 0, 16), Text = hint, TextColor3 = C.dim,
		Font = Enum.Font.Gotham, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}, row)

	local pill = new("TextButton", {
		Text = "", AutoButtonColor = false, Size = UDim2.new(0, 40, 0, 22),
		Position = UDim2.new(1, -50, 0.5, -11), BackgroundColor3 = C.off, BorderSizePixel = 0,
	}, row)
	round(pill, 11)
	local knob = new("Frame", {
		Size = UDim2.new(0, 16, 0, 16), Position = UDim2.new(0, 3, 0.5, -8),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
	}, pill)
	round(knob, 8)

	local state = false
	pill.MouseButton1Click:Connect(function()
		state = not state
		local info = TweenInfo.new(0.12)
		TweenService:Create(pill, info, { BackgroundColor3 = state and C.on or C.off }):Play()
		TweenService:Create(knob, info, {
			Position = state and UDim2.new(0, 21, 0.5, -8) or UDim2.new(0, 3, 0.5, -8),
		}):Play()
		callback(state)
	end)
end

local function makeButtons(a, b)
	local row = new("Frame", {
		Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1,
	}, content)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8),
	}, row)
	for _, def in ipairs({ a, b }) do
		local btn = new("TextButton", {
			Size = UDim2.new(0.5, -4, 1, 0), BackgroundColor3 = C.accent, BorderSizePixel = 0,
			Text = def[1], TextColor3 = Color3.new(1, 1, 1),
			Font = Enum.Font.GothamBold, TextSize = 13,
		}, row)
		round(btn, 8)
		btn.MouseButton1Click:Connect(def[2])
	end
end

local function makeInput(label, default, callback)
	local row = new("Frame", {
		Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = C.row, BorderSizePixel = 0,
	}, content)
	round(row)
	new("TextLabel", {
		BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0, 0),
		Size = UDim2.new(1, -130, 1, 0), Text = label, TextColor3 = C.text,
		Font = Enum.Font.Gotham, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left,
	}, row)
	local box = new("TextBox", {
		Size = UDim2.new(0, 110, 0, 24), Position = UDim2.new(1, -120, 0.5, -12),
		BackgroundColor3 = C.bg, BorderSizePixel = 0, Text = tostring(default),
		TextColor3 = C.text, Font = Enum.Font.Gotham, TextSize = 13, ClearTextOnFocus = false,
	}, row)
	round(box, 6)
	box.FocusLost:Connect(function()
		box.Text = tostring(callback(box.Text))
	end)
end

------------------------------------------------------------
-- PANEL CONTENT
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

local countLabel = new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Text = "Found: ...",
	TextColor3 = C.text, Font = Enum.Font.GothamBold, TextSize = 12,
	TextXAlignment = Enum.TextXAlignment.Left,
}, content)

local statusLabel = new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Text = "Ready",
	TextColor3 = C.dim, Font = Enum.Font.Gotham, TextSize = 12, TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
}, content)

setStatus = function(text, isErr)
	statusLabel.Text = text
	statusLabel.TextColor3 = isErr and C.err or C.dim
end

if not fireclickdetector then
	setStatus("Warning: no fireclickdetector. Auto gather and click-all can't click.", true)
end

------------------------------------------------------------
-- DRAGGING (title bar) and hotkey (RightShift hides/shows)
------------------------------------------------------------
local dragging, dragStart, startPos
titleBar.InputBegan:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1
		or i.UserInputType == Enum.UserInputType.Touch then
		dragging, dragStart, startPos = true, i.Position, main.Position
	end
end)
UserInputService.InputChanged:Connect(function(i)
	if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement
		or i.UserInputType == Enum.UserInputType.Touch) then
		local d = i.Position - dragStart
		main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
			startPos.Y.Scale, startPos.Y.Offset + d.Y)
	end
end)
UserInputService.InputEnded:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1
		or i.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end)
UserInputService.InputBegan:Connect(function(i, processed)
	if not processed and i.KeyCode == Enum.KeyCode.RightShift then
		main.Visible = not main.Visible
	end
end)

------------------------------------------------------------
-- RESIZE (drag the corner handle)
------------------------------------------------------------
local BASE_WIDTH = 270
local MIN_SCALE, MAX_SCALE = 0.6, 2.5

local uiScale = new("UIScale", { Scale = 1 }, main)

local handle = new("TextButton", {
	Size = UDim2.new(0, 22, 0, 22),
	BackgroundColor3 = C.accent,
	BackgroundTransparency = 0.3,
	BorderSizePixel = 0,
	Text = "◢",
	TextColor3 = Color3.new(1, 1, 1),
	TextSize = 12,
	Font = Enum.Font.GothamBold,
	AutoButtonColor = false,
	ZIndex = 10,
}, gui)
round(handle, 6)

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
UserInputService.InputChanged:Connect(function(i)
	if resizing and (i.UserInputType == Enum.UserInputType.MouseMovement
		or i.UserInputType == Enum.UserInputType.Touch) then
		local dx = i.Position.X - rStart.X
		uiScale.Scale = math.clamp(rScale + dx / BASE_WIDTH, MIN_SCALE, MAX_SCALE)
	end
end)
UserInputService.InputEnded:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1
		or i.UserInputType == Enum.UserInputType.Touch then
		resizing = false
	end
end)

------------------------------------------------------------
-- BACKGROUND LOOPS (stop when the panel is closed)
------------------------------------------------------------
task.spawn(function()
	while gui.Parent do
		task.wait(cfg.interval)
		if cfg.auto and gui.Parent then
			local n = fireAll()
			if n > 0 then setStatus(("Auto gather: clicked %d item(s)"):format(n)) end
		end
	end
end)

task.spawn(function()
	while gui.Parent do
		if content.Visible then
			countLabel.Text = ("Found: %d item(s) named \"%s\""):format(#findParts(), cfg.name)
		end
		task.wait(3)
	end
end)
