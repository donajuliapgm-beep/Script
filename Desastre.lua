-- Natural Disaster Survival Hub v3 | Delta Executor
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")
local Stats = game:GetService("Stats")

local player = Players.LocalPlayer
local GUI_NAME = "NDS_Hub"
local env = (getgenv and getgenv()) or _G

-- Remove versão antiga (inclusive as conexões dela)
if env.NDS_Unload then pcall(env.NDS_Unload) end
pcall(function()
	if gethui and gethui():FindFirstChild(GUI_NAME) then gethui()[GUI_NAME]:Destroy() end
end)
pcall(function()
	if CoreGui:FindFirstChild(GUI_NAME) then CoreGui[GUI_NAME]:Destroy() end
end)
if player.PlayerGui:FindFirstChild(GUI_NAME) then player.PlayerGui[GUI_NAME]:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = GUI_NAME
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 999
local okParent = pcall(function() gui.Parent = (gethui and gethui()) or CoreGui end)
if not okParent or not gui.Parent then gui.Parent = player:WaitForChild("PlayerGui") end

---------------------------------------------------------------- IDIOMAS
local LANG = {
	pt = {
		subtitle = "Natural Disaster Survival",
		tab_player = "Jogador", tab_fly = "Voo", tab_fling = "Fling",
		tab_hammer = "Martelo", tab_safe = "Segurança", tab_config = "Config",
		speed = "Velocidade", speed_val = "Valor da velocidade",
		jump = "Pulo alto", jump_val = "Valor do pulo", infjump = "Pulo infinito",
		fly = "Voar", fly_speed = "Velocidade do voo",
		fly_still = "Pose parada ao voar (estilo R6)",
		noclip = "Atravessar paredes", noclip_hold = "Noclip: manter altura (não cai)",
		fly_info = "Olhe para cima/baixo para subir/descer. No PC: Espaço sobe e Shift desce. No noclip, o botão de pulo sobe.",
		fling = "Arremessar quem chegar perto", fling_range = "Alcance (studs)",
		fling_info = "Chegue perto de alguém para arremessar. Precisa encostar.",
		hammer = "Martelo de quebrar", hammer_radius = "Raio de quebra (0 = só a peça)",
		hammer_undo = "Desfazer último", hammer_restore = "Restaurar tudo",
		hammer_info = "Ligue, e o martelo vai para sua mão. Toque num objeto para quebrar. A quebra só aparece para você.",
		platform = "Plataforma segura no céu", antiafk = "Anti-AFK", hop = "Trocar de servidor",
		hud = "Mostrar FPS e Ping", unload = "Descarregar script",
		unload_confirm = "Toque de novo para confirmar",
		config_info = "O X só fecha o painel e os recursos continuam ligados. Para desligar tudo, use Descarregar. No PC, RightShift abre/fecha.",
		toast_closed = "Painel fechado. Toque no ⚡ para abrir.",
		toast_hop = "Procurando outro servidor...",
		toast_hop_fail = "Nenhum servidor achado. Reentrando...",
		toast_undo_none = "Nada para desfazer", toast_undo_ok = "Objetos restaurados",
	},
	en = {
		subtitle = "Natural Disaster Survival",
		tab_player = "Player", tab_fly = "Flight", tab_fling = "Fling",
		tab_hammer = "Hammer", tab_safe = "Safety", tab_config = "Settings",
		speed = "Speed", speed_val = "Speed value",
		jump = "High jump", jump_val = "Jump value", infjump = "Infinite jump",
		fly = "Fly", fly_speed = "Fly speed",
		fly_still = "Still pose while flying (R6 style)",
		noclip = "Noclip (walk through walls)", noclip_hold = "Noclip: hold height (no falling)",
		fly_info = "Look up/down to rise/descend. On PC: Space goes up, Shift goes down. In noclip, the jump button goes up.",
		fling = "Fling nearby players", fling_range = "Range (studs)",
		fling_info = "Get close to someone to fling them. You need to touch them.",
		hammer = "Breaker hammer", hammer_radius = "Break radius (0 = single part)",
		hammer_undo = "Undo last", hammer_restore = "Restore all",
		hammer_info = "Turn it on and the hammer goes to your hand. Tap an object to break it. Only you see the damage.",
		platform = "Safe sky platform", antiafk = "Anti-AFK", hop = "Switch server",
		hud = "Show FPS & Ping", unload = "Unload script",
		unload_confirm = "Tap again to confirm",
		config_info = "The X only closes the panel and features stay on. To turn everything off, use Unload. On PC, RightShift opens/closes.",
		toast_closed = "Panel closed. Tap the ⚡ to open.",
		toast_hop = "Looking for another server...",
		toast_hop_fail = "No server found. Rejoining...",
		toast_undo_none = "Nothing to undo", toast_undo_ok = "Objects restored",
	},
}

---------------------------------------------------------------- ESTADO
local state = {
	speedOn = false, speed = 32,
	jumpOn = false, jump = 80,
	infJump = false,
	fly = false, flySpeed = 60, flyStill = true,
	noclip = false, noclipHold = true,
	fling = false, flingRange = 15,
	hammer = false, hammerRadius = 0,
	platform = false,
	antiAfk = true,
	hud = true,
	lang = "pt",
}

local connections = {}
local function track(c)
	connections[#connections + 1] = c
	return c
end

local flyBV, flyBG, holdBV
local platformPart, savedCFrame
local flingActive, savedVel, savedAng
local hammerTool
local brokenStack = {}
local noclipOrig, charParts = {}, {}
local descAdded
local PLATFORM_HEIGHT = 300
local updateHUD, toast -- definidos mais abaixo

local function getChar() return player.Character end
local function getHum() local c = getChar() return c and c:FindFirstChildOfClass("Humanoid") end
local function getRoot() local c = getChar() return c and c:FindFirstChild("HumanoidRootPart") end

---------------------------------------------------------------- NOCLIP MELHORADO
local function updateHold()
	local root = getRoot()
	local want = state.noclip and state.noclipHold and (not state.fly) and root ~= nil
	if want then
		if (not holdBV) or holdBV.Parent ~= root then
			if holdBV then holdBV:Destroy() end
			holdBV = Instance.new("BodyVelocity")
			holdBV.MaxForce = Vector3.new(0, 1e5, 0)
			holdBV.Velocity = Vector3.zero
			holdBV.Parent = root
		end
	elseif holdBV then
		holdBV:Destroy()
		holdBV = nil
	end
end

local function restoreNoclip()
	for p, v in pairs(noclipOrig) do
		if p.Parent then p.CanCollide = v end
	end
	table.clear(noclipOrig)
end

local function setNoclip(v)
	state.noclip = v
	if not v then restoreNoclip() end
	updateHold()
end

local function bindCharacter(c)
	if descAdded then descAdded:Disconnect() end
	table.clear(charParts)
	table.clear(noclipOrig)
	for _, p in ipairs(c:GetDescendants()) do
		if p:IsA("BasePart") then charParts[#charParts + 1] = p end
	end
	descAdded = c.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then charParts[#charParts + 1] = d end
	end)
end

---------------------------------------------------------------- VOO
local function applyStill(on)
	local c = getChar()
	if not c then return end
	local animate = c:FindFirstChild("Animate")
	if animate then pcall(function() animate.Disabled = on end) end
end

local function destroyFlyObjects()
	if flyBV then flyBV:Destroy() flyBV = nil end
	if flyBG then flyBG:Destroy() flyBG = nil end
end

local function stopFly()
	destroyFlyObjects()
	applyStill(false)
	local hum = getHum()
	if hum then hum.AutoRotate = true end
end

local function startFly()
	destroyFlyObjects()
	local root = getRoot()
	if not root then return end
	flyBV = Instance.new("BodyVelocity")
	flyBV.MaxForce = Vector3.new(1e5, 1e5, 1e5)
	flyBV.Velocity = Vector3.zero
	flyBV.Parent = root
	flyBG = Instance.new("BodyGyro")
	flyBG.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
	flyBG.P = 1e4
	flyBG.CFrame = root.CFrame
	flyBG.Parent = root
	local hum = getHum()
	if hum then hum.AutoRotate = false end
	if state.flyStill then applyStill(true) end
end

local function setFly(v)
	state.fly = v
	if v then startFly() else stopFly() end
	updateHold()
end

---------------------------------------------------------------- PLATAFORMA
local function disablePlatform()
	local root = getRoot()
	if root and savedCFrame then root.CFrame = savedCFrame end
	if platformPart then platformPart:Destroy() platformPart = nil end
	savedCFrame = nil
end

local function enablePlatform()
	local root = getRoot()
	if not root then return false end
	savedCFrame = root.CFrame
	platformPart = Instance.new("Part")
	platformPart.Name = "SafePlatform"
	platformPart.Size = Vector3.new(40, 2, 40)
	platformPart.Anchored = true
	platformPart.Material = Enum.Material.ForceField
	platformPart.Color = Color3.fromRGB(255, 170, 40)
	platformPart.Position = root.Position + Vector3.new(0, PLATFORM_HEIGHT, 0)
	platformPart.Parent = Workspace
	root.CFrame = CFrame.new(platformPart.Position + Vector3.new(0, 5, 0))
	return true
end

local function setPlatform(v)
	if v then
		state.platform = enablePlatform()
	else
		state.platform = false
		disablePlatform()
	end
end

---------------------------------------------------------------- FLING
local function nearestTarget(root)
	local best, bestDist
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and other.Character then
			local oRoot = other.Character:FindFirstChild("HumanoidRootPart")
			local oHum = other.Character:FindFirstChildOfClass("Humanoid")
			if oRoot and oHum and oHum.Health > 0 then
				local d = (oRoot.Position - root.Position).Magnitude
				if d <= state.flingRange and (not bestDist or d < bestDist) then
					best, bestDist = oRoot, d
				end
			end
		end
	end
	return best
end

---------------------------------------------------------------- MARTELO
local function isProtected(part)
	if part:IsA("Terrain") then return true end
	if part == platformPart then return true end
	for _, plr in ipairs(Players:GetPlayers()) do
		local ch = plr.Character
		if ch and part:IsDescendantOf(ch) then return true end
	end
	return false
end

local function breakAt(target, pos)
	if not target or isProtected(target) then return end
	local list = {target}
	if state.hammerRadius > 0 and pos then
		local params = OverlapParams.new()
		local ex = {}
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr.Character then ex[#ex + 1] = plr.Character end
		end
		params.FilterDescendantsInstances = ex
		params.FilterType = Enum.RaycastFilterType.Exclude
		local found = Workspace:GetPartBoundsInRadius(pos, state.hammerRadius, params)
		if #found > 0 then list = found end
	end
	local group, count = {}, 0
	for _, p in ipairs(list) do
		if count >= 80 then break end
		if p.Parent and not isProtected(p) then
			group[#group + 1] = {part = p, parent = p.Parent}
			p.Parent = nil
			count = count + 1
		end
	end
	if #group > 0 then
		brokenStack[#brokenStack + 1] = group
		if #brokenStack > 40 then table.remove(brokenStack, 1) end
		pcall(function()
			local e = Instance.new("Explosion")
			e.Position = pos or Vector3.zero
			e.BlastPressure = 0
			e.BlastRadius = 4
			e.DestroyJointRadiusPercent = 0
			e.ExplosionType = Enum.ExplosionType.NoCraters
			e.Parent = Workspace
		end)
	end
end

local function restoreGroup(g)
	for _, e in ipairs(g) do
		pcall(function() e.part.Parent = e.parent end)
	end
end

local function undoLast()
	local g = table.remove(brokenStack)
	if g then
		restoreGroup(g)
		if toast then toast(LANG[state.lang].toast_undo_ok) end
	elseif toast then
		toast(LANG[state.lang].toast_undo_none)
	end
end

local function restoreAllBroken()
	while #brokenStack > 0 do
		restoreGroup(table.remove(brokenStack))
	end
end

local function buildHammer()
	local tool = Instance.new("Tool")
	tool.Name = "Martelo"
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.GripPos = Vector3.new(0, 0, -1.2)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.5, 0.5, 3)
	handle.Material = Enum.Material.Wood
	handle.Color = Color3.fromRGB(120, 80, 45)
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(2.2, 1.2, 1.2)
	head.Material = Enum.Material.Metal
	head.Color = Color3.fromRGB(95, 100, 115)
	head.CanCollide = false
	head.Massless = true
	head.Parent = tool

	local weld = Instance.new("Weld")
	weld.Part0 = handle
	weld.Part1 = head
	weld.C0 = CFrame.new(0, 0, 1.5)
	weld.Parent = handle

	local mouse = player:GetMouse()
	tool.Activated:Connect(function()
		if not state.hammer then return end
		pcall(function() mouse.TargetFilter = getChar() end)
		local target, hit = mouse.Target, mouse.Hit
		if target and hit then breakAt(target, hit.Position) end
	end)
	return tool
end

local function removeHammer()
	if hammerTool then hammerTool:Destroy() hammerTool = nil end
end

local function giveHammer()
	local bp = player:FindFirstChildOfClass("Backpack")
	if not bp then return end
	removeHammer()
	hammerTool = buildHammer()
	hammerTool.Parent = bp
	local hum = getHum()
	if hum then pcall(function() hum:EquipTool(hammerTool) end) end
end

local function setHammer(v)
	state.hammer = v
	if v then giveHammer() else removeHammer() end
end

---------------------------------------------------------------- PING
local function getPing()
	local ok, v = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
	if ok and type(v) == "number" then return math.floor(v + 0.5) end
	local ok2, p = pcall(function() return player:GetNetworkPing() end)
	if ok2 and type(p) == "number" then return math.floor(p * 1000 + 0.5) end
	return 0
end

---------------------------------------------------------------- LOOPS
local acc, frames = 0, 0
track(RunService.Heartbeat:Connect(function(dt)
	local hum = getHum()
	local root = getRoot()

	if hum then
		if state.speedOn then hum.WalkSpeed = state.speed end
		if state.jumpOn then
			hum.UseJumpPower = true
			hum.JumpPower = state.jump
		end
	end

	-- Voo
	if state.fly and flyBV and flyBG and hum then
		local cam = Workspace.CurrentCamera
		local cf = cam.CFrame
		local md = hum.MoveDirection
		local vel = Vector3.zero
		if md.Magnitude > 0 then
			local flatLook = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z)
			local flatRight = Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z)
			if flatLook.Magnitude > 0 and flatRight.Magnitude > 0 then
				local fwd = md:Dot(flatLook.Unit)
				local rt = md:Dot(flatRight.Unit)
				vel = (cf.LookVector * fwd + cf.RightVector * rt) * state.flySpeed
			end
		end
		if hum.Jump or UIS:IsKeyDown(Enum.KeyCode.Space) then
			vel = vel + Vector3.new(0, state.flySpeed, 0)
		end
		if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then
			vel = vel - Vector3.new(0, state.flySpeed, 0)
		end
		flyBV.Velocity = vel
		flyBG.CFrame = cf

		-- Pose parada (todas as animações paradas)
		if state.flyStill then
			local animator = hum:FindFirstChildOfClass("Animator")
			if animator then
				for _, t in ipairs(animator:GetPlayingAnimationTracks()) do t:Stop(0) end
			end
		end
	end

	-- Noclip: segura a altura
	if holdBV and hum then
		local up = (hum.Jump and 40 or 0) - (UIS:IsKeyDown(Enum.KeyCode.LeftShift) and 40 or 0)
		holdBV.Velocity = Vector3.new(0, up, 0)
	end

	-- Fling
	if state.fling and root and hum and hum.Health > 0 then
		local target = nearestTarget(root)
		if target then
			savedVel = root.AssemblyLinearVelocity
			savedAng = root.AssemblyAngularVelocity
			flingActive = true
			if flyBV then flyBV.MaxForce = Vector3.zero end
			if holdBV then holdBV.MaxForce = Vector3.zero end
			local dir = target.Position - root.Position
			if dir.Magnitude > 0.01 then dir = dir.Unit else dir = Vector3.new(1, 0, 0) end
			root.AssemblyAngularVelocity = Vector3.new(0, 1e5, 0)
			root.AssemblyLinearVelocity = Vector3.new(dir.X * 5e4, 2e4, dir.Z * 5e4)
		end
	end

	-- FPS / Ping
	acc = acc + dt
	frames = frames + 1
	if acc >= 0.5 then
		local fps = frames / acc
		acc, frames = 0, 0
		if updateHUD then updateHUD(fps, getPing()) end
	end
end))

track(RunService.RenderStepped:Connect(function()
	if flingActive then
		flingActive = false
		local root = getRoot()
		if root then
			root.AssemblyLinearVelocity = savedVel or Vector3.zero
			root.AssemblyAngularVelocity = savedAng or Vector3.zero
		end
		if flyBV then flyBV.MaxForce = Vector3.new(1e5, 1e5, 1e5) end
		if holdBV then holdBV.MaxForce = Vector3.new(0, 1e5, 0) end
	end
end))

track(RunService.Stepped:Connect(function()
	if not state.noclip then return end
	for i = #charParts, 1, -1 do
		local p = charParts[i]
		if p.Parent then
			if noclipOrig[p] == nil then noclipOrig[p] = p.CanCollide end
			p.CanCollide = false
		else
			table.remove(charParts, i)
		end
	end
end))

track(UIS.JumpRequest:Connect(function()
	if state.infJump then
		local hum = getHum()
		if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
	end
end))

track(player.Idled:Connect(function()
	if state.antiAfk then
		pcall(function()
			local vu = game:GetService("VirtualUser")
			vu:CaptureController()
			vu:ClickButton2(Vector2.new())
		end)
	end
end))

track(player.CharacterAdded:Connect(function(char)
	bindCharacter(char)
	task.wait(1)
	if state.fly then startFly() end
	updateHold()
	if state.platform and platformPart then
		local root = getRoot()
		if root then root.CFrame = CFrame.new(platformPart.Position + Vector3.new(0, 5, 0)) end
	end
	if state.hammer then giveHammer() end
end))

if getChar() then bindCharacter(getChar()) end

---------------------------------------------------------------- DESCARREGAR TUDO
local function unload()
	state.speedOn, state.jumpOn, state.infJump, state.fling = false, false, false, false
	pcall(function() setFly(false) end)
	pcall(function() setNoclip(false) end)
	pcall(function() if state.platform then setPlatform(false) end end)
	pcall(removeHammer)
	pcall(restoreAllBroken)
	local h = getHum()
	if h then h.WalkSpeed = 16 h.JumpPower = 50 end
	for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
	if descAdded then pcall(function() descAdded:Disconnect() end) end
	env.NDS_Unload = nil
	gui:Destroy()
end
env.NDS_Unload = unload

---------------------------------------------------------------- TEMA E HELPERS
local THEME = {
	bg1 = Color3.fromRGB(22, 27, 40),
	bg2 = Color3.fromRGB(10, 12, 19),
	panel = Color3.fromRGB(18, 22, 33),
	item = Color3.fromRGB(30, 37, 54),
	item2 = Color3.fromRGB(44, 58, 86),
	accent = Color3.fromRGB(255, 170, 40),   -- alerta / raio
	blue = Color3.fromRGB(70, 130, 200),     -- tempestade
	danger = Color3.fromRGB(220, 65, 55),    -- vulcão
	good = Color3.fromRGB(80, 220, 130),
	warn = Color3.fromRGB(255, 200, 60),
	text = Color3.fromRGB(236, 240, 250),
	sub = Color3.fromRGB(140, 150, 175),
	off = Color3.fromRGB(62, 70, 92),
}

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end

local function corner(o, r) return new("UICorner", {CornerRadius = UDim.new(0, r or 8)}, o) end

local function stroke(o, color, th, tr)
	return new("UIStroke", {
		Color = color, Thickness = th or 1, Transparency = tr or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, o)
end

local function tween(o, t, props)
	TweenService:Create(o, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local function makeDraggable(handle, target)
	local dragging, dragStart, startPos, moved = false, nil, nil, false
	handle.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			moved = false
			dragStart = i.Position
			startPos = target.Position
			local c
			c = i.Changed:Connect(function()
				if i.UserInputState == Enum.UserInputState.End then
					dragging = false
					c:Disconnect()
				end
			end)
		end
	end)
	track(UIS.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - dragStart
			if d.Magnitude > 6 then moved = true end
			target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, st
