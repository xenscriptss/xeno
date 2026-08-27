local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local Camera = Workspace.CurrentCamera

local Config = {
	KillAura = false,
	KillAuraRange = 15,
	TeleportKillAll = false,
	AutoShootMurderer = false,
	AimAssist = false,
	AimSmoothness = 0.2,
	AutoGrabGun = false,
	PlayerESP = false,
	RoleESP = false,
	GunESP = false,
	SpeedBoost = false,
	WalkSpeedValue = 24,
	NoClip = false,
	AntiAFK = true
}

local ESP_Tags = {}
local Highlights = {}
local Connections = {}
local LastShotTime = 0

local Theme = {
	Background = Color3.fromRGB(11, 12, 16),
	CardBg = Color3.fromRGB(18, 20, 26),
	TopBarBg = Color3.fromRGB(15, 17, 23),
	SidebarBg = Color3.fromRGB(14, 15, 20),
	Accent = Color3.fromRGB(0, 229, 255),
	AccentGlow = Color3.fromRGB(0, 180, 216),
	TextBright = Color3.fromRGB(240, 245, 255),
	TextMuted = Color3.fromRGB(120, 130, 150),
	Border = Color3.fromRGB(28, 32, 45),
	ToggleOff = Color3.fromRGB(30, 34, 45)
}

local function GetPlayerRole(player)
	if not player or not player.Character then return "Innocent" end
	
	local char = player.Character
	local backpack = player:FindFirstChild("Backpack")

	if char:FindFirstChild("Knife") or (backpack and backpack:FindFirstChild("Knife")) then
		return "Murderer"
	elseif char:FindFirstChild("Gun") or (backpack and backpack:FindFirstChild("Gun")) then
		return "Sheriff"
	end

	return "Innocent"
end

local function GetRoleColor(role)
	if role == "Murderer" then
		return Color3.fromRGB(255, 65, 84)
	elseif role == "Sheriff" then
		return Color3.fromRGB(0, 150, 255)
	else
		return Color3.fromRGB(46, 204, 113)
	end
end

local function GetMurderer()
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and GetPlayerRole(player) == "Murderer" then
			return player
		end
	end
	return nil
end

local function GetDroppedGun()
	for _, obj in ipairs(Workspace:GetChildren()) do
		if obj.Name == "GunDrop" or (obj:IsA("Tool") and obj.Name == "Gun") then
			return obj:IsA("BasePart") and obj or obj:FindFirstChild("Handle")
		end
	end
	return nil
end

local function GetClosestTargetForAim()
	local closestPlayer = nil
	local shortestDistance = math.huge
	local myRole = GetPlayerRole(LocalPlayer)

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local targetRole = GetPlayerRole(player)
			
			local shouldTarget = false
			if myRole == "Sheriff" then
				shouldTarget = (targetRole == "Murderer")
			else
				shouldTarget = (targetRole ~= "Innocent")
			end

			if shouldTarget then
				local pos, onScreen = Camera:WorldToViewportPoint(player.Character.HumanoidRootPart.Position)
				if onScreen then
					local mouseDist = (Vector2.new(pos.X, pos.Y) - Vector2.new(Mouse.X, Mouse.Y)).Magnitude
					if mouseDist < shortestDistance then
						shortestDistance = mouseDist
						closestPlayer = player
					end
				end
			end
		end
	end

	return closestPlayer
end

table.insert(Connections, RunService.Stepped:Connect(function()
	local char = LocalPlayer.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")

	if char and root and humanoid then
		if Config.SpeedBoost then
			humanoid.WalkSpeed = Config.WalkSpeedValue
		end

		if Config.NoClip or Config.TeleportKillAll then
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") and part.CanCollide then
					part.CanCollide = false
				end
			end
		end

		if Config.AutoGrabGun then
			local droppedGun = GetDroppedGun()
			if droppedGun then
				root.CFrame = droppedGun.CFrame
			end
		end

		if Config.TeleportKillAll and GetPlayerRole(LocalPlayer) == "Murderer" then
			local knife = char:FindFirstChild("Knife") or (LocalPlayer.Backpack and LocalPlayer.Backpack:FindFirstChild("Knife"))
			if knife then
				if knife.Parent ~= char then knife.Parent = char end

				for _, target in ipairs(Players:GetPlayers()) do
					if target ~= LocalPlayer and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
						local tHum = target.Character:FindFirstChildOfClass("Humanoid")
						local tRoot = target.Character.HumanoidRootPart

						if tHum and tHum.Health > 0 then
							root.CFrame = tRoot.CFrame * CFrame.new(0, 0, 1.5)
							knife:Activate()
							firetouchinterest(knife.Handle, tRoot, 0)
							firetouchinterest(knife.Handle, tRoot, 1)
							task.wait(0.08)
						end
					end
				end
			end
		end

		if Config.KillAura and GetPlayerRole(LocalPlayer) == "Murderer" and not Config.TeleportKillAll then
			local knife = char:FindFirstChild("Knife") or (LocalPlayer.Backpack and LocalPlayer.Backpack:FindFirstChild("Knife"))
			if knife then
				if knife.Parent ~= char then knife.Parent = char end
				
				for _, target in ipairs(Players:GetPlayers()) do
					if target ~= LocalPlayer and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
						local tRoot = target.Character.HumanoidRootPart
						local dist = (root.Position - tRoot.Position).Magnitude

						if dist <= Config.KillAuraRange then
							knife:Activate()
							firetouchinterest(knife.Handle, tRoot, 0)
							firetouchinterest(knife.Handle, tRoot, 1)
						end
					end
				end
			end
		end

		if Config.AutoShootMurderer and GetPlayerRole(LocalPlayer) == "Sheriff" then
			local murderer = GetMurderer()
			if murderer and murderer.Character and murderer.Character:FindFirstChild("HumanoidRootPart") then
				local mHum = murderer.Character:FindFirstChildOfClass("Humanoid")
				local mRoot = murderer.Character.HumanoidRootPart

				if mHum and mHum.Health > 0 then
					local gun = char:FindFirstChild("Gun") or (LocalPlayer.Backpack and LocalPlayer.Backpack:FindFirstChild("Gun")) or char:FindFirstChildOfClass("Tool")
					
					if gun and (gun.Name == "Gun" or gun:FindFirstChild("GunScript")) then
						if gun.Parent ~= char then 
							gun.Parent = char 
						end
						
						Camera.CFrame = CFrame.new(Camera.CFrame.Position, mRoot.Position)
						
						if tick() - LastShotTime >= 0.3 then
							gun:Activate()
							LastShotTime = tick()
						end
					end
				end
			end
		end
	end
end))

table.insert(Connections, RunService.RenderStepped:Connect(function()
	if Config.AimAssist and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
		local target = GetClosestTargetForAim()
		if target and target.Character and target.Character:FindFirstChild("HumanoidRootPart") then
			local targetPos = target.Character.HumanoidRootPart.Position
			local currentCFrame = Camera.CFrame
			local targetCFrame = CFrame.new(currentCFrame.Position, targetPos)
			
			Camera.CFrame = currentCFrame:Lerp(targetCFrame, Config.AimSmoothness)
		end
	end
end))

table.insert(Connections, LocalPlayer.Idled:Connect(function()
	if Config.AntiAFK then
		local VirtualUser = game:GetService("VirtualUser")
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new())
	end
end))

table.insert(Connections, RunService.RenderStepped:Connect(function()
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			local char = player.Character
			local role = GetPlayerRole(player)
			local color = GetRoleColor(role)

			if Config.PlayerESP or Config.RoleESP then
				if not Highlights[player] or Highlights[player].Parent ~= char then
					if Highlights[player] then pcall(function() Highlights[player]:Destroy() end) end
					local hl = Instance.new("Highlight")
					hl.Name = "XenoHub_MM2_ESP"
					hl.FillTransparency = 0.6
					hl.OutlineTransparency = 0.1
					hl.Parent = char
					Highlights[player] = hl
				end

				Highlights[player].FillColor = color
				Highlights[player].OutlineColor = color
			else
				if Highlights[player] then
					pcall(function() Highlights[player]:Destroy() end)
					Highlights[player] = nil
				end
			end
		end
	end

	local droppedGun = GetDroppedGun()
	if droppedGun and Config.GunESP then
		if not ESP_Tags["DroppedGun"] then
			local bb = Instance.new("BillboardGui")
			bb.Name = "XenoGunESP"
			bb.Size = UDim2.fromOffset(120, 30)
			bb.StudsOffset = Vector3.new(0, 3, 0)
			bb.AlwaysOnTop = true

			local txt = Instance.new("TextLabel")
			txt.Size = UDim2.fromScale(1, 1)
			txt.BackgroundTransparency = 1
			txt.TextColor3 = Color3.fromRGB(255, 215, 0)
			txt.Font = Enum.Font.GothamBold
			txt.TextSize = 12
			txt.Text = "🔫 DROPPED GUN"
			txt.Parent = bb

			bb.Parent = droppedGun
			ESP_Tags["DroppedGun"] = bb
		end
	else
		if ESP_Tags["DroppedGun"] then
			pcall(function() ESP_Tags["DroppedGun"]:Destroy() end)
			ESP_Tags["DroppedGun"] = nil
		end
	end
end))

local GUI = Instance.new("ScreenGui")
GUI.Name = "XenoHubMM2_Clean"
GUI.ResetOnSpawn = false
GUI.IgnoreGuiInset = true
GUI.Parent = LocalPlayer:WaitForChild("PlayerGui")

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.fromOffset(520, 360)
Main.Position = UDim2.new(0.5, -260, 0.5, -180)
Main.BackgroundColor3 = Theme.Background
Main.BorderSizePixel = 0
Main.ClipsDescendants = true
Main.Parent = GUI

Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 12)
local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Theme.Border
MainStroke.Thickness = 1.2
MainStroke.Parent = Main

local TopBar = Instance.new("Frame")
TopBar.Size = UDim2.new(1, 0, 0, 48)
TopBar.BackgroundColor3 = Theme.TopBarBg
TopBar.BorderSizePixel = 0
TopBar.Parent = Main

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(0, 250, 1, 0)
Title.Position = UDim2.fromOffset(18, 0)
Title.BackgroundTransparency = 1
Title.Text = "<font color=\"#00E5FF\">XENO</font> HUB <font color=\"#788296\">| MM2</font>"
Title.RichText = true
Title.TextColor3 = Theme.TextBright
Title.TextSize = 15
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = TopBar

local TopControlContainer = Instance.new("Frame")
TopControlContainer.Size = UDim2.new(0, 70, 1, 0)
TopControlContainer.Position = UDim2.new(1, -78, 0, 0)
TopControlContainer.BackgroundTransparency = 1
TopControlContainer.Parent = TopBar

local TopControlLayout = Instance.new("UIListLayout")
TopControlLayout.FillDirection = Enum.FillDirection.Horizontal
TopControlLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
TopControlLayout.VerticalAlignment = Enum.VerticalAlignment.Center
TopControlLayout.Padding = UDim.new(0, 6)
TopControlLayout.Parent = TopControlContainer

local CollapseBtn = Instance.new("TextButton")
CollapseBtn.Size = UDim2.fromOffset(26, 26)
CollapseBtn.BackgroundColor3 = Theme.CardBg
CollapseBtn.Text = "-"
CollapseBtn.TextColor3 = Theme.TextBright
CollapseBtn.Font = Enum.Font.GothamBold
CollapseBtn.TextSize = 14
CollapseBtn.Parent = TopControlContainer
Instance.new("UICorner", CollapseBtn).CornerRadius = UDim.new(0, 6)

local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.fromOffset(26, 26)
CloseBtn.BackgroundColor3 = Color3.fromRGB(255, 65, 84)
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 11
CloseBtn.Parent = TopControlContainer
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 130, 1, -48)
Sidebar.Position = UDim2.fromOffset(0, 48)
Sidebar.BackgroundColor3 = Theme.SidebarBg
Sidebar.BorderSizePixel = 0
Sidebar.Parent = Main

local SidebarList = Instance.new("UIListLayout")
SidebarList.Padding = UDim.new(0, 6)
SidebarList.HorizontalAlignment = Enum.HorizontalAlignment.Center
SidebarList.Parent = Sidebar

local SidebarPadding = Instance.new("UIPadding")
SidebarPadding.PaddingTop = UDim.new(0, 12)
SidebarPadding.Parent = Sidebar

local TabContainer = Instance.new("Frame")
TabContainer.Size = UDim2.new(1, -142, 1, -60)
TabContainer.Position = UDim2.fromOffset(136, 54)
TabContainer.BackgroundTransparency = 1
TabContainer.Parent = Main

local IsCollapsed = false

CollapseBtn.MouseButton1Click:Connect(function()
	IsCollapsed = not IsCollapsed
	if IsCollapsed then
		TweenService:Create(Main, TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(520, 48)
		}):Play()
		Sidebar.Visible = false
		TabContainer.Visible = false
		CollapseBtn.Text = "+"
	else
		TweenService:Create(Main, TweenInfo.new(0.3, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {
			Size = UDim2.fromOffset(520, 360)
		}):Play()
		task.delay(0.15, function()
			Sidebar.Visible = true
			TabContainer.Visible = true
		end)
		CollapseBtn.Text = "-"
	end
end)

CloseBtn.MouseButton1Click:Connect(function()
	for _, hl in pairs(Highlights) do pcall(function() hl:Destroy() end) end
	for _, esp in pairs(ESP_Tags) do pcall(function() esp:Destroy() end) end
	for _, conn in ipairs(Connections) do conn:Disconnect() end
	GUI:Destroy()
end)

local Tabs = {}
local TabButtons = {}

local function CreateTab(Name)
	local TabFrame = Instance.new("ScrollingFrame")
	TabFrame.Size = UDim2.new(1, 0, 1, 0)
	TabFrame.BackgroundTransparency = 1
	TabFrame.BorderSizePixel = 0
	TabFrame.ScrollBarThickness = 2
	TabFrame.ScrollBarImageColor3 = Theme.Accent
	TabFrame.Visible = false
	TabFrame.Parent = TabContainer

	local Layout = Instance.new("UIListLayout")
	Layout.Padding = UDim.new(0, 8)
	Layout.Parent = TabFrame

	local TabBtn = Instance.new("TextButton")
	TabBtn.Size = UDim2.new(1, -16, 0, 32)
	TabBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	TabBtn.BackgroundTransparency = 1
	TabBtn.Text = Name
	TabBtn.TextColor3 = Theme.TextMuted
	TabBtn.Font = Enum.Font.GothamMedium
	TabBtn.TextSize = 12
	TabBtn.Parent = Sidebar

	Instance.new("UICorner", TabBtn).CornerRadius = UDim.new(0, 6)

	TabBtn.MouseButton1Click:Connect(function()
		for _, t in pairs(Tabs) do t.Visible = false end
		for _, b in pairs(TabButtons) do 
			TweenService:Create(b, TweenInfo.new(0.2), {BackgroundTransparency = 1, TextColor3 = Theme.TextMuted}):Play()
		end
		TabFrame.Visible = true
		TweenService:Create(TabBtn, TweenInfo.new(0.2), {BackgroundTransparency = 0.8, TextColor3 = Theme.Accent}):Play()
	end)

	table.insert(Tabs, TabFrame)
	table.insert(TabButtons, TabBtn)
	return TabFrame
end

local MurdererTab = CreateTab("Murderer")
local SheriffTab  = CreateTab("Sheriff")
local ESPTab      = CreateTab("Visuals / ESP")
local MovementTab = CreateTab("Movement")

Tabs[1].Visible = true
TabButtons[1].BackgroundTransparency = 0.8
TabButtons[1].TextColor3 = Theme.Accent

local function AddToggle(Parent, Name, Default, Callback)
	local Row = Instance.new("Frame")
	Row.Size = UDim2.new(1, -6, 0, 40)
	Row.BackgroundColor3 = Theme.CardBg
	Row.Parent = Parent

	Instance.new("UICorner", Row).CornerRadius = UDim.new(0, 8)
	local Stroke = Instance.new("UIStroke")
	Stroke.Color = Theme.Border
	Stroke.Thickness = 1
	Stroke.Parent = Row

	local Label = Instance.new("TextLabel")
	Label.Size = UDim2.new(1, -60, 1, 0)
	Label.Position = UDim2.fromOffset(12, 0)
	Label.BackgroundTransparency = 1
	Label.Text = Name
	Label.TextColor3 = Theme.TextBright
	Label.TextSize = 12
	Label.Font = Enum.Font.GothamMedium
	Label.TextXAlignment = Enum.TextXAlignment.Left
	Label.Parent = Row

	local ToggleBg = Instance.new("Frame")
	ToggleBg.Size = UDim2.fromOffset(36, 18)
	ToggleBg.Position = UDim2.new(1, -48, 0.5, -9)
	ToggleBg.BackgroundColor3 = Default and Theme.Accent or Theme.ToggleOff
	ToggleBg.Parent = Row
	Instance.new("UICorner", ToggleBg).CornerRadius = UDim.new(1, 0)

	local Indicator = Instance.new("Frame")
	Indicator.Size = UDim2.fromOffset(14, 14)
	Indicator.Position = Default and UDim2.fromOffset(19, 2) or UDim2.fromOffset(3, 2)
	Indicator.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	Indicator.Parent = ToggleBg
	Instance.new("UICorner", Indicator).CornerRadius = UDim.new(1, 0)

	local ClickArea = Instance.new("TextButton")
	ClickArea.Size = UDim2.fromScale(1, 1)
	ClickArea.BackgroundTransparency = 1
	ClickArea.Text = ""
	ClickArea.Parent = Row

	local State = Default
	ClickArea.MouseButton1Click:Connect(function()
		State = not State
		TweenService:Create(ToggleBg, TweenInfo.new(0.2), {BackgroundColor3 = State and Theme.Accent or Theme.ToggleOff}):Play()
		TweenService:Create(Indicator, TweenInfo.new(0.2), {Position = State and UDim2.fromOffset(19, 2) or UDim2.fromOffset(3, 2)}):Play()
		Callback(State)
	end)
end

local function AddSlider(Parent, Name, Min, Max, Default, Callback)
	local Row = Instance.new("Frame")
	Row.Size = UDim2.new(1, -6, 0, 52)
	Row.BackgroundColor3 = Theme.CardBg
	Row.Parent = Parent

	Instance.new("UICorner", Row).CornerRadius = UDim.new(0, 8)
	local Stroke = Instance.new("UIStroke")
	Stroke.Color = Theme.Border
	Stroke.Thickness = 1
	Stroke.Parent = Row

	local Label = Instance.new("TextLabel")
	Label.Size = UDim2.new(1, -70, 0, 24)
	Label.Position = UDim2.fromOffset(12, 4)
	Label.BackgroundTransparency = 1
	Label.Text = Name
	Label.TextColor3 = Theme.TextBright
	Label.TextSize = 12
	Label.Font = Enum.Font.GothamMedium
	Label.TextXAlignment = Enum.TextXAlignment.Left
	Label.Parent = Row

	local ValueLabel = Instance.new("TextLabel")
	ValueLabel.Size = UDim2.new(0, 50, 0, 24)
	ValueLabel.Position = UDim2.new(1, -62, 0, 4)
	ValueLabel.BackgroundTransparency = 1
	ValueLabel.Text = tostring(Default)
	ValueLabel.TextColor3 = Theme.Accent
	ValueLabel.TextSize = 12
	ValueLabel.Font = Enum.Font.GothamBold
	ValueLabel.TextXAlignment = Enum.TextXAlignment.Right
	ValueLabel.Parent = Row

	local Track = Instance.new("Frame")
	Track.Size = UDim2.new(1, -24, 0, 4)
	Track.Position = UDim2.fromOffset(12, 34)
	Track.BackgroundColor3 = Theme.ToggleOff
	Track.Parent = Row
	Instance.new("UICorner", Track).CornerRadius = UDim.new(1, 0)

	local Fill = Instance.new("Frame")
	local startScale = (Default - Min) / (Max - Min)
	Fill.Size = UDim2.new(startScale, 0, 1, 0)
	Fill.BackgroundColor3 = Theme.Accent
	Fill.Parent = Track
	Instance.new("UICorner", Fill).CornerRadius = UDim.new(1, 0)

	local Sliding = false
	local function UpdateInput(input)
		local scale = math.clamp((input.Position.X - Track.AbsolutePosition.X) / Track.AbsoluteSize.X, 0, 1)
		local val = math.floor(Min + (Max - Min) * scale)
		Fill.Size = UDim2.new(scale, 0, 1, 0)
		ValueLabel.Text = tostring(val)
		Callback(val)
	end

	Track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then Sliding = true; UpdateInput(input) end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if Sliding and input.UserInputType == Enum.UserInputType.MouseMovement then UpdateInput(input) end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then Sliding = false end
	end)
end

AddToggle(MurdererTab, "Teleport Kill All", Config.TeleportKillAll, function(v) Config.TeleportKillAll = v end)
AddToggle(MurdererTab, "Knife Kill Aura", Config.KillAura, function(v) Config.KillAura = v end)
AddSlider(MurdererTab, "Kill Aura Range", 5, 30, Config.KillAuraRange, function(v) Config.KillAuraRange = v end)

AddToggle(SheriffTab, "Auto Shoot Murderer", Config.AutoShootMurderer, function(v) Config.AutoShootMurderer = v end)
AddToggle(SheriffTab, "Gun Aim Assist (Hold RMB)", Config.AimAssist, function(v) Config.AimAssist = v end)
AddToggle(SheriffTab, "Auto Grab Dropped Gun", Config.AutoGrabGun, function(v) Config.AutoGrabGun = v end)

AddToggle(ESPTab, "Role ESP (Murderer/Sheriff)", Config.RoleESP, function(v) Config.RoleESP = v end)
AddToggle(ESPTab, "Player ESP", Config.PlayerESP, function(v) Config.PlayerESP = v end)
AddToggle(ESPTab, "Dropped Gun ESP", Config.GunESP, function(v) Config.GunESP = v end)

AddToggle(MovementTab, "Speed Boost", Config.SpeedBoost, function(v) Config.SpeedBoost = v end)
AddSlider(MovementTab, "Walk Speed", 16, 60, Config.WalkSpeedValue, function(v) Config.WalkSpeedValue = v end)
AddToggle(MovementTab, "Noclip", Config.NoClip, function(v) Config.NoClip = v end)

local Dragging, DragStart, StartPos
TopBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		Dragging = true
		DragStart = input.Position
		StartPos = Main.Position
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if Dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = input.Position - DragStart
		Main.Position = UDim2.new(StartPos.X.Scale, StartPos.X.Offset + delta.X, StartPos.Y.Scale, StartPos.Y.Offset + delta.Y)
	end
end)

TopBar.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then Dragging = false end
end)

table.insert(Connections, UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.RightShift then
		Main.Visible = not Main.Visible
	end
end))
