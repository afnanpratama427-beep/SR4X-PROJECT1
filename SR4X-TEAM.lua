
--[[
    SR4X TEAM — v25 — by NanzzzProject
    v25 changes:
      * ESP Line: fixed + 2 styles (Bottom/Top)
      * ESP Counter: ENEMY N top-center
      * ESP Box: full char bounding box (R6 leg names fixed)
      * Skeleton: merged + head outline (decoupled from skeleton toggle)
      * Hologram: 4 modes (Solid / RGB / Pulse / Flicker)
      * Bug fixes: head outline independent, R6 foot detection, skeleton color unified, headLines memory leak on rig change
]]

print("[SR4X] v25 booting...")
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local Tween      = game:GetService("TweenService")
local PhysicsService = game:GetService("PhysicsService")
local TeleportSvc = game:GetService("TeleportService")
local LP         = Players.LocalPlayer

local atan2 = math.atan2 or function(y, x)
    if math.atan then
        local ok, r = pcall(function() return math.atan(y, x) end)
        if ok and r then return r end
    end
    if x > 0 then return math.atan(y/x)
    elseif x < 0 then return (y >= 0) and (math.atan(y/x)+math.pi) or (math.atan(y/x)-math.pi)
    elseif y > 0 then return math.pi/2
    elseif y < 0 then return -math.pi/2
    else return 0 end
end

print("[SR4X] STEP 1: wait char")
if not LP.Character then pcall(function() LP.CharacterAdded:Wait() end) end
task.wait(0.5)

local Camera = workspace.CurrentCamera
if not Camera then
    for _ = 1, 30 do task.wait(0.1); Camera = workspace.CurrentCamera; if Camera then break end end
end
if Camera then
    pcall(function()
        workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
            if workspace.CurrentCamera then Camera = workspace.CurrentCamera end
        end)
    end)
end

local HITBOX_GROUP = "SR4X_Hitbox"
local PLAYER_GROUP = "SR4X_Player"
pcall(function() PhysicsService:RegisterCollisionGroup(HITBOX_GROUP) end)
pcall(function() PhysicsService:RegisterCollisionGroup(PLAYER_GROUP) end)
pcall(function() PhysicsService:CollisionGroupSetCollidable(HITBOX_GROUP, "Default", false) end)
pcall(function() PhysicsService:CollisionGroupSetCollidable(HITBOX_GROUP, HITBOX_GROUP, false) end)
pcall(function() PhysicsService:CollisionGroupSetCollidable(PLAYER_GROUP, HITBOX_GROUP, false) end)
pcall(function() PhysicsService:CollisionGroupSetCollidable(PLAYER_GROUP, PLAYER_GROUP, false) end)

local Config = {
    FreezeEnabled = false, FreezeActive = false,
    Aimbot = false, AimbotFOV = 180, AimbotSmooth = 0.25, AimbotPart = "Head",
    POV_X = 0, POV_Y = 0,
    TargetPlayers = true, TargetNPCs = false, TeamCheck = true, ShowFOV = true, WallCheck = true,
    ESP_Enabled = false, ESP_Box = true, ESP_Line = true, ESP_Name = true,
    ESP_Skeleton = true, ESP_HeadOutline = true, ESP_Counter = true,
    ESP_LineStyle = "Bottom",
    ESP_Color = Color3.fromRGB(255, 50, 50),
    ESP_OutlineColor = Color3.fromRGB(255, 255, 255),
    ESP_OutlineRGB = false,
    SkeletonColor = Color3.fromRGB(200, 200, 255),
    HologramOn = false,
    HologramMode = "RGB",
    HologramColor = Color3.fromRGB(255, 0, 255),
    HologramFillColor = Color3.fromRGB(255, 0, 255),
    HologramOutlineTrans = 0,
    HologramFillTrans = 50,
    HologramDepth = "AlwaysOnTop",
    Theme = "Gradient", AccentA = Color3.fromRGB(0, 200, 255), AccentB = Color3.fromRGB(180, 0, 255),
    BoxColor = Color3.fromRGB(30, 30, 45), BoxTransp = 0.35, OrbSize = 64, OrbThick = 60,
    FreezeOrbSize = 64, FreezeOrbThick = 60,
    FreezeInactiveColor = Color3.fromRGB(10, 10, 10),
    FreezeInactiveRGB = false,
    AutoMagnet = false, AimMagnetManual = false, AimMagnetPro = false, MagnetTarget = "Head",
    AutoShoot = false, AutoShootTarget = "Head", AutoShootSpeed = 0.15,
    FastReload = false, AntiKick = true, NoReload = true,
    NoclipEnabled = false, NoclipAuto = true, NoclipActive = false, AntiFlingEnabled = true,
    SilentAim = false, SilentAimHeadSize = 25, SilentAimRange = 500,
    SilentAimTeam = true, SilentAimNPCs = false,
    NinjaFire = false, NinjaFireDist = 4, NinjaFireReturnDelay = 0.05, NinjaFireMaxRange = 500,
    AntiBanEnabled = true,
}

local _targetsDirty = true
local _cachedTargets = {}
local _lastTargetUpdate = 0
local npcCache, lastScan = {}, 0

local function invalidateTargets() _targetsDirty = true end
Players.PlayerAdded:Connect(invalidateTargets)
Players.PlayerRemoving:Connect(invalidateTargets)

local function refreshNPCs()
    if os.clock() - lastScan < 0.5 then return end
    lastScan = os.clock()
    npcCache = {}
    for _, m in ipairs(workspace:GetDescendants()) do
        if m:IsA("Model") and m:FindFirstChild("HumanoidRootPart") then
            local hum = m:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 and not Players:GetPlayerFromCharacter(m) then
                npcCache[#npcCache+1] = m
            end
        end
    end
end

local function collectTargets()
    local out = {}
    local myTeam = LP.Team
    if Config.TargetPlayers then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and p.Character then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 and not (Config.TeamCheck and myTeam and p.Team == myTeam) then
                    out[#out+1] = p.Character
                end
            end
        end
    end
    if Config.TargetNPCs then
        refreshNPCs()
        for _, m in ipairs(npcCache) do if m.Parent then out[#out+1] = m end end
    end
    return out
end

local function getCachedTargets()
    local now = os.clock()
    if _targetsDirty or now - _lastTargetUpdate > 0.5 then
        _cachedTargets = collectTargets()
        _lastTargetUpdate = now
        _targetsDirty = false
    end
    return _cachedTargets
end

local function getCharTeam(model)
    local plr = Players:GetPlayerFromCharacter(model)
    return plr and plr.Team or nil
end

local _guiParentForRay = nil
local function isVisible(targetModel, targetPosition)
    if not Config.WallCheck or not Camera then return true end
    local origin = Camera.CFrame.Position
    local direction = targetPosition - origin
    local params = RaycastParams.new()
    pcall(function() params.FilterType = Enum.RaycastFilterType.Exclude end)
    local ignoreList = {LP.Character, Camera}
    if _guiParentForRay then table.insert(ignoreList, _guiParentForRay) end
    params.FilterDescendantsInstances = ignoreList
    local result = workspace:Raycast(origin, direction, params)
    if result then return result.Instance:IsDescendantOf(targetModel) end
    return true
end

-- BIG HEAD (unchanged)
local frozenData = {}
local bigHeadState = {}

local function collectBigHeadTargets()
    local out = {}
    local myTeam = LP.Team
    local range = Config.SilentAimRange or 500
    local camPos = Camera and Camera.CFrame.Position or Vector3.zero
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character and not frozenData[p.Character] then
            local hum = p.Character:FindFirstChildOfClass("Humanoid")
            local hrp = p.Character:FindFirstChild("HumanoidRootPart")
            if hum and hum.Health > 0 and hrp then
                local teamOk = not (Config.SilentAimTeam and myTeam and p.Team == myTeam)
                local rangeOk = (camPos - hrp.Position).Magnitude <= range
                if teamOk and rangeOk then out[#out+1] = p.Character end
            end
        end
    end
    if Config.SilentAimNPCs then
        refreshNPCs()
        for _, m in ipairs(npcCache) do
            if m.Parent and not frozenData[m] then
                local hrp = m:FindFirstChild("HumanoidRootPart")
                if hrp and (camPos - hrp.Position).Magnitude <= range then out[#out+1] = m end
            end
        end
    end
    return out
end

local function applyBigHead(model)
    if not model or not model.Parent or bigHeadState[model] then return end
    local head = model:FindFirstChild("Head")
    if not head or not head:IsA("BasePart") then return end
    bigHeadState[model] = {
        head = head, origSize = head.Size, origTrans = head.Transparency,
        origCanQuery = head.CanQuery, origCastShadow = head.CastShadow,
        origCanCollide = head.CanCollide, origMassless = head.Massless,
    }
    local s = Config.SilentAimHeadSize
    pcall(function()
        head.Size = head.Size + Vector3.new(s, s, s)
        head.Transparency = 0
        head.CanQuery = true
        head.CastShadow = false
        head.CanCollide = false
        head.Massless = true
    end)
end

local function clearBigHead(model)
    local d = bigHeadState[model]
    if not d then return end
    if d.head and d.head.Parent then
        pcall(function()
            d.head.Size = d.origSize
            d.head.Transparency = d.origTrans
            d.head.CanQuery = d.origCanQuery
            d.head.CastShadow = d.origCastShadow
            d.head.CanCollide = d.origCanCollide
            d.head.Massless = d.origMassless
        end)
    end
    bigHeadState[model] = nil
end

local function clearAllBigHeads()
    local keys = {}
    for m in pairs(bigHeadState) do table.insert(keys, m) end
    for _, m in ipairs(keys) do clearBigHead(m) end
end

task.spawn(function()
    while task.wait(0.1) do
        pcall(function()
            if Config.SilentAim then
                local targets = collectBigHeadTargets()
                local targetSet = {}
                for _, m in ipairs(targets) do targetSet[m] = true end
                for _, model in ipairs(targets) do
                    local st = bigHeadState[model]
                    if st and st.head ~= model:FindFirstChild("Head") then clearBigHead(model) end
                    if not bigHeadState[model] then applyBigHead(model) end
                end
                local keys = {}
                for m in pairs(bigHeadState) do table.insert(keys, m) end
                for _, m in ipairs(keys) do
                    if not targetSet[m] or not m.Parent then clearBigHead(m) end
                end
            else
                if next(bigHeadState) ~= nil then clearAllBigHeads() end
            end
        end)
    end
end)

RunService.Heartbeat:Connect(function()
    if not Config.SilentAim then return end
    local s = Config.SilentAimHeadSize
    local offset = Vector3.new(s, s, s)
    for _, st in pairs(bigHeadState) do
        local h = st.head
        if h and h.Parent then
            local targetSize = st.origSize + offset
            if h.Size ~= targetSize then pcall(function() h.Size = targetSize end) end
            if h.Transparency ~= 0 then pcall(function() h.Transparency = 0 end) end
            if h.CanQuery ~= true then pcall(function() h.CanQuery = true end) end
            if h.CanCollide ~= false then pcall(function() h.CanCollide = false end) end
        end
    end
end)

-- NINJA FIRE
local function findNearestNinjaTarget()
    if not Camera then return nil end
    local vs = Camera.ViewportSize
    if not vs or vs.X <= 0 then return nil end
    local center = Vector2.new(vs.X/2, vs.Y/2)
    local myTeam = LP.Team
    local best, bestDist = nil, Config.NinjaFireMaxRange or 500
    for _, model in ipairs(getCachedTargets()) do
        local hrp = model:FindFirstChild("HumanoidRootPart")
        if hrp then
            local team = getCharTeam(model)
            if not (Config.SilentAimTeam and myTeam and team == myTeam) then
                if isVisible(model, hrp.Position) then
                    local ok, sp = pcall(function() return Camera:WorldToViewportPoint(hrp.Position) end)
                    if ok and sp and sp.Z > 0 then
                        local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                        local worldD = (Camera.CFrame.Position - hrp.Position).Magnitude
                        if d < 400 and worldD < bestDist then best = model; bestDist = worldD end
                    end
                end
            end
        end
    end
    return best
end

local function getWeaponTool()
    local char = LP.Character
    if char then return char:FindFirstChildOfClass("Tool") end
end

local function ninjaFire()
    local char = LP.Character
    local myHRP = char and char:FindFirstChild("HumanoidRootPart")
    if not myHRP then return end
    local targetModel = findNearestNinjaTarget()
    if not targetModel then return end
    local targetHRP = targetModel:FindFirstChild("HumanoidRootPart")
    if not targetHRP then return end
    local origCF = myHRP.CFrame
    pcall(function() myHRP.CFrame = targetHRP.CFrame * CFrame.new(0, 0, Config.NinjaFireDist) end)
    task.wait(Config.NinjaFireReturnDelay)
    local tool = getWeaponTool()
    if tool then pcall(function() tool:Activate() end) end
    task.wait(Config.NinjaFireReturnDelay)
    pcall(function() myHRP.CFrame = origCF end)
end

-- ANTI-BAN
do
    local installed = false
    pcall(function()
        local oldNamecall
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local method = getnamecallmethod()
            if Config.AntiBanEnabled then
                if method == "Kick" or method == "kick" then return nil end
                if (method == "Disconnect" or method == "disconnect") and (self == game or self == LP) then return nil end
                if self == TeleportSvc and (method == "Teleport" or method == "TeleportAsync" or method == "TeleportToPlaceInstance") then
                    local placeId = select(1, ...)
                    if typeof(placeId) == "number" and placeId ~= game.PlaceId then return nil end
                end
            end
            return oldNamecall(self, ...)
        end)
        installed = true
    end)
    print("[SR4X] Anti-Ban: " .. (installed and "ACTIVE" or "FAILED"))
end

-- NOCLIP + ANTI-FLING
local ourPartsCache = {}
local function rebuildOurParts()
    ourPartsCache = {}
    local char = LP.Character
    if not char then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then table.insert(ourPartsCache, p) end
    end
end
rebuildOurParts()
LP.CharacterAdded:Connect(function() task.wait(0.15); rebuildOurParts() end)

task.spawn(function()
    while task.wait(0.15) do
        Config.NoclipActive = Config.NoclipEnabled or (Config.NoclipAuto and Config.SilentAim)
    end
end)

local lastFallAssistTime = 0
RunService.Heartbeat:Connect(function()
    local char = LP.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local now = os.clock()
    if Config.NoclipActive then
        for _, p in ipairs(ourPartsCache) do
            if p.Parent and p.CollisionGroup ~= PLAYER_GROUP then
                pcall(function() p.CollisionGroup = PLAYER_GROUP end)
            end
        end
        if hum and hrp and now - lastFallAssistTime > 0.3 then
            local state = hum:GetState()
            local vel = hrp.AssemblyLinearVelocity
            if (state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Landed) and vel.Magnitude < 8 then
                local params = RaycastParams.new()
                pcall(function() params.FilterType = Enum.RaycastFilterType.Exclude end)
                params.FilterDescendantsInstances = {char}
                local hit = workspace:Raycast(hrp.Position, Vector3.new(0, -4, 0), params)
                if hit and hit.Instance.CollisionGroup == HITBOX_GROUP then
                    lastFallAssistTime = now
                    pcall(function()
                        hum:ChangeState(Enum.HumanoidStateType.Freefall)
                        hrp.AssemblyLinearVelocity = Vector3.new(vel.X, -30, vel.Z)
                    end)
                end
            end
        end
    elseif hrp and Config.AntiFlingEnabled then
        local vel = hrp.AssemblyLinearVelocity
        if vel.Magnitude > 600 then
            pcall(function()
                hrp.AssemblyLinearVelocity = Vector3.new(0, vel.Y, 0)
                hrp.AssemblyAngularVelocity = Vector3.zero
            end)
        end
    end
end)

-- GUI PARENT with render test
local function testRender(container)
    local ok, result = pcall(function()
        local t = Instance.new("ScreenGui")
        t.ResetOnSpawn = false; t.IgnoreGuiInset = true; t.DisplayOrder = 10000; t.Enabled = true
        local f = Instance.new("Frame")
        f.Size = UDim2.fromOffset(100, 100); f.Position = UDim2.fromOffset(50, 50)
        f.BackgroundColor3 = Color3.fromRGB(255, 0, 0); f.BorderSizePixel = 0; f.Parent = t
        t.Parent = container
        task.wait(0.15)
        local v = t.Parent ~= nil and f.AbsoluteSize.X > 50 and f.AbsoluteSize.Y > 50
        pcall(function() t:Destroy() end)
        return v
    end)
    return ok and result == true
end

local candidates = {}
local pg = LP:FindFirstChild("PlayerGui")
if not pg then pcall(function() pg = LP:WaitForChild("PlayerGui", 3) end) end
if pg then table.insert(candidates, {name="PlayerGui", c=pg}) end
if gethui then
    local ok, h = pcall(gethui)
    if ok and h then table.insert(candidates, {name="gethui", c=h}) end
end
local okcg, cg = pcall(function() return game:GetService("CoreGui") end)
if okcg and cg then table.insert(candidates, {name="CoreGui", c=cg}) end

local guiParent = nil
for _, x in ipairs(candidates) do
    if testRender(x.c) then guiParent = x.c; print("[SR4X] Parent: " .. x.name); break end
end
if not guiParent then
    guiParent = LP:WaitForChild("PlayerGui")
    warn("[SR4X] Forced PlayerGui")
end
_guiParentForRay = guiParent

local ESP_Colors = {
    {name="Red", color=Color3.fromRGB(255, 50, 50)}, {name="Green", color=Color3.fromRGB(50, 255, 50)},
    {name="Blue", color=Color3.fromRGB(50, 150, 255)}, {name="Yellow", color=Color3.fromRGB(255, 255, 50)},
    {name="White", color=Color3.fromRGB(255, 255, 255)},
}
local ESP_OutlineColors = {
    {name="White",   color=Color3.fromRGB(255, 255, 255)},
    {name="Red",     color=Color3.fromRGB(255, 50, 50)},
    {name="Green",   color=Color3.fromRGB(50, 255, 50)},
    {name="Blue",    color=Color3.fromRGB(50, 150, 255)},
    {name="Yellow",  color=Color3.fromRGB(255, 255, 50)},
    {name="Cyan",    color=Color3.fromRGB(50, 255, 255)},
    {name="Magenta", color=Color3.fromRGB(255, 50, 255)},
    {name="Orange",  color=Color3.fromRGB(255, 150, 50)},
    {name="Purple",  color=Color3.fromRGB(170, 80, 255)},
    {name="Lime",    color=Color3.fromRGB(180, 255, 80)},
}
local ThemePresets = {
    {name="Aqua-Violet", box=Color3.fromRGB(30,30,45),  a=Color3.fromRGB(0,200,255),   b=Color3.fromRGB(180,0,255)},
    {name="Red-Orange",  box=Color3.fromRGB(45,20,20),  a=Color3.fromRGB(255,60,60),   b=Color3.fromRGB(255,160,0)},
    {name="Green-Cyan",  box=Color3.fromRGB(20,40,30),  a=Color3.fromRGB(60,255,120),  b=Color3.fromRGB(0,200,255)},
    {name="Pink-Yellow", box=Color3.fromRGB(40,20,35),  a=Color3.fromRGB(255,80,180),  b=Color3.fromRGB(255,240,80)},
    {name="Pure White",  box=Color3.fromRGB(25,25,25),  a=Color3.fromRGB(255,255,255), b=Color3.fromRGB(200,200,255)},
}
local FreezeInactiveColors = {{name="Hitam", color=Color3.fromRGB(10, 10, 10)},{name="Putih", color=Color3.fromRGB(240, 240, 240)},{name="Merah", color=Color3.fromRGB(200, 40, 40)},{name="Biru", color=Color3.fromRGB(30, 90, 255)},{name="RGB", color=Color3.fromRGB(255, 255, 255)}}
local LineStyles = {{name="Bottom"}, {name="Top"}}
local HologramModes = {{name="Solid"}, {name="RGB"}, {name="Pulse"}, {name="Flicker"}}
local DepthModes = {{name="AlwaysOnTop"}, {name="Occluded"}}

local BASE_DO = 10000

local espGui = Instance.new("ScreenGui")
espGui.Name = "SR4X_ESP"
espGui.ResetOnSpawn = false
espGui.IgnoreGuiInset = true
espGui.Enabled = true
espGui.DisplayOrder = BASE_DO + 0
espGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
if guiParent then espGui.Parent = guiParent end

local espObjects = {}
local skeletonObjs = {}
local highlightObjs = {}

local SKEL_R15 = {
    {"Head", "UpperTorso"}, {"UpperTorso", "LowerTorso"},
    {"UpperTorso", "LeftUpperArm"}, {"LeftUpperArm", "LeftLowerArm"}, {"LeftLowerArm", "LeftHand"},
    {"UpperTorso", "RightUpperArm"}, {"RightUpperArm", "RightLowerArm"}, {"RightLowerArm", "RightHand"},
    {"LowerTorso", "LeftUpperLeg"}, {"LeftUpperLeg", "LeftLowerLeg"}, {"LeftLowerLeg", "LeftFoot"},
    {"LowerTorso", "RightUpperLeg"}, {"RightUpperLeg", "RightLowerLeg"}, {"RightLowerLeg", "RightFoot"},
}
local SKEL_R6 = {
    {"Head", "Torso"}, {"Torso", "Left Arm"}, {"Torso", "Right Arm"},
    {"Torso", "Left Leg"}, {"Torso", "Right Leg"},
}

-- ESP COUNTER (top center)
local counterFrame = Instance.new("Frame")
counterFrame.Name = "SR4X_Counter"
counterFrame.Size = UDim2.fromOffset(220, 40)
counterFrame.AnchorPoint = Vector2.new(0.5, 0)
counterFrame.Position = UDim2.new(0.5, 0, 0, 20)
counterFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
counterFrame.BackgroundTransparency = 0.35
counterFrame.BorderSizePixel = 0
counterFrame.Visible = false
counterFrame.ZIndex = 10
counterFrame.Parent = espGui
Instance.new("UICorner", counterFrame).CornerRadius = UDim.new(0, 10)
local counterStroke = Instance.new("UIStroke", counterFrame)
counterStroke.Thickness = 2
counterStroke.Color = Color3.fromRGB(255, 50, 50)
counterStroke.Transparency = 0.2
local counterLabel = Instance.new("TextLabel", counterFrame)
counterLabel.Size = UDim2.new(1, 0, 1, 0)
counterLabel.BackgroundTransparency = 1
counterLabel.Text = "ENEMY 0"
counterLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
counterLabel.Font = Enum.Font.GothamBlack
counterLabel.TextSize = 20
counterLabel.TextStrokeTransparency = 0
counterLabel.ZIndex = 11

local function getESPObject(plr)
    if espObjects[plr] then return espObjects[plr] end
    local box = Instance.new("Frame")
    box.AnchorPoint = Vector2.new(0.5, 0.5)
    box.BackgroundTransparency = 1; box.BorderSizePixel = 0
    box.Visible = false; box.ZIndex = 1; box.Parent = espGui
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1.5; stroke.Color = Config.ESP_OutlineColor; stroke.Parent = box
    local line = Instance.new("Frame")
    line.AnchorPoint = Vector2.new(0, 0.5); line.BorderSizePixel = 0
    line.BackgroundColor3 = Config.ESP_Color; line.Visible = false
    line.ZIndex = 1; line.Parent = espGui
    local nameLbl = Instance.new("TextLabel")
    nameLbl.AnchorPoint = Vector2.new(0.5, 1); nameLbl.BackgroundTransparency = 1
    nameLbl.Font = Enum.Font.Code; nameLbl.TextSize = 14
    nameLbl.TextColor3 = Config.ESP_Color; nameLbl.TextStrokeTransparency = 0
    nameLbl.Visible = false; nameLbl.ZIndex = 2; nameLbl.Parent = espGui
    espObjects[plr] = { box = box, stroke = stroke, line = line, name = nameLbl }
    return espObjects[plr]
end

local function hideESPObject(plr)
    local o = espObjects[plr]
    if not o then return end
    o.box.Visible = false; o.line.Visible = false; o.name.Visible = false
end

-- CHAR BOUNDS (accurate box) — BUG 2 FIX: Added "Left Leg" and "Right Leg" for R6
local function getCharBounds(char)
    local head = char:FindFirstChild("Head")
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not head or not hrp then return nil end
    local topY = head.Position.Y + head.Size.Y/2
    local bottomY = hrp.Position.Y - 3
    for _, name in ipairs({"LeftFoot", "RightFoot", "Foot", "LeftLeg", "RightLeg", "Left Leg", "Right Leg"}) do
        local p = char:FindFirstChild(name)
        if p and p:IsA("BasePart") then
            bottomY = math.min(bottomY, p.Position.Y - p.Size.Y/2)
        end
    end
    local width = 2
    local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
    if torso then width = torso.Size.X + 0.5 end
    return {
        cx = hrp.Position.X, cz = hrp.Position.Z,
        topY = topY, bottomY = bottomY,
        width = width, depth = width,
    }
end

local function getScreenBox(bounds)
    local hw, hd = bounds.width/2, bounds.depth/2
    local corners = {}
    for _, y in ipairs({bounds.topY, bounds.bottomY}) do
        for _, dx in ipairs({-hw, hw}) do
            for _, dz in ipairs({-hd, hd}) do
                local sp, onScr = Camera:WorldToViewportPoint(Vector3.new(bounds.cx + dx, y, bounds.cz + dz))
                if sp.Z > 0 then
                    table.insert(corners, {x=sp.X, y=sp.Y})
                end
            end
        end
    end
    if #corners < 2 then return nil end
    local minX, maxX = corners[1].x, corners[1].x
    local minY, maxY = corners[1].y, corners[1].y
    for _, c in ipairs(corners) do
        if c.x < minX then minX = c.x end
        if c.x > maxX then maxX = c.x end
        if c.y < minY then minY = c.y end
        if c.y > maxY then maxY = c.y end
    end
    local w = maxX - minX
    local h = maxY - minY
    if w < 5 or h < 5 or w > 3000 or h > 3000 then return nil end
    return {x = minX, y = minY, w = w, h = h, cx = minX + w/2, cy = minY + h/2}
end

-- SKELETON (merged into ESP) — BUG 1 & 3 FIXES APPLIED
local function ensureSkeleton(plr)
    local char = plr.Character
    if not char then return nil end
    local rig = char:FindFirstChild("UpperTorso") and "R15" or "R6"
    local data = skeletonObjs[plr]
    -- NEW BUG FIX: Destroy headLines on rig change to prevent memory leak
    if data and data.rig ~= rig then
        for _, l in ipairs(data.lines) do pcall(function() l:Destroy() end) end
        for _, l in ipairs(data.headLines) do pcall(function() l:Destroy() end) end
        skeletonObjs[plr] = nil; data = nil
    end
    if data then return data end
    local boneList = rig == "R15" and SKEL_R15 or SKEL_R6
    local lines = {}
    for i = 1, #boneList do
        local l = Instance.new("Frame")
        l.AnchorPoint = Vector2.new(0, 0.5); l.BorderSizePixel = 0
        -- BUG 3 FIX: Use ESP_OutlineColor instead of SkeletonColor
        l.BackgroundColor3 = Config.ESP_OutlineColor
        l.Visible = false; l.ZIndex = 3; l.Parent = espGui
        lines[i] = l
    end
    -- Head outline: 4 lines (edges of head box)
    local headLines = {}
    for i = 1, 4 do
        local l = Instance.new("Frame")
        l.AnchorPoint = Vector2.new(0, 0.5); l.BorderSizePixel = 0
        -- BUG 3 FIX: Use ESP_OutlineColor instead of SkeletonColor
        l.BackgroundColor3 = Config.ESP_OutlineColor
        l.Visible = false; l.ZIndex = 4; l.Parent = espGui
        headLines[i] = l
    end
    data = {lines = lines, boneList = boneList, rig = rig, headLines = headLines}
    skeletonObjs[plr] = data
    return data
end

local function hideSkeleton(plr)
    local d = skeletonObjs[plr]
    if not d then return end
    for _, l in ipairs(d.lines) do l.Visible = false end
    for _, l in ipairs(d.headLines) do l.Visible = false end
end

local function drawLineSeg(obj, x1, y1, x2, y2, color)
    local dx = x2 - x1
    local dy = y2 - y1
    local len = math.sqrt(dx*dx + dy*dy)
    if len < 0.5 or len > 5000 then obj.Visible = false; return end
    local ang = math.deg(atan2(dy, dx))
    if ang ~= ang then obj.Visible = false; return end
    obj.Size = UDim2.fromOffset(len, 1.5)
    obj.Position = UDim2.fromOffset(x1, y1)
    obj.Rotation = ang
    obj.BackgroundColor3 = color
    obj.Visible = true
end

-- BUG 1 FIX: Decoupled head outline from skeleton toggle
local function updateSkeleton(plr, char)
    local data = ensureSkeleton(plr)
    if not data then return end

    if Config.ESP_Skeleton then
        for i, bone in ipairs(data.boneList) do
            local p1 = char:FindFirstChild(bone[1])
            local p2 = char:FindFirstChild(bone[2])
            local line = data.lines[i]
            if p1 and p2 and line then
                local ok, sp1 = pcall(function() return Camera:WorldToViewportPoint(p1.Position) end)
                local ok2, sp2 = pcall(function() return Camera:WorldToViewportPoint(p2.Position) end)
                if ok and ok2 and sp1.Z > 0 and sp2.Z > 0 then
                    -- BUG 3 FIX: Use ESP_OutlineColor
                    drawLineSeg(line, sp1.X, sp1.Y, sp2.X, sp2.Y, Config.ESP_OutlineColor)
                else line.Visible = false end
            elseif line then line.Visible = false end
        end
    else
        -- Hide skeleton lines when skeleton is OFF but head outline may still be ON
        for _, l in ipairs(data.lines) do l.Visible = false end
    end

    -- Head outline (independent of skeleton toggle)
    if Config.ESP_HeadOutline then
        local head = char:FindFirstChild("Head")
        if head then
            local hp = head.Position
            local hs = head.Size / 2
            local corners = {}
            for _, dx in ipairs({-hs.X, hs.X}) do
                for _, dy in ipairs({-hs.Y, hs.Y}) do
                    for _, dz in ipairs({-hs.Z, hs.Z}) do
                        local sp, onScr = Camera:WorldToViewportPoint(hp + Vector3.new(dx, dy, dz))
                        if sp.Z > 0 then table.insert(corners, {x=sp.X, y=sp.Y}) end
                    end
                end
            end
            if #corners >= 2 then
                local minX, maxX = corners[1].x, corners[1].x
                local minY, maxY = corners[1].y, corners[1].y
                for _, c in ipairs(corners) do
                    if c.x < minX then minX = c.x end
                    if c.x > maxX then maxX = c.x end
                    if c.y < minY then minY = c.y end
                    if c.y > maxY then maxY = c.y end
                end
                local w = maxX - minX; local h = maxY - minY
                if w > 2 and w < 2000 and h > 2 and h < 2000 then
                    -- BUG 3 FIX: Use ESP_OutlineColor for all 4 head outline segments
                    drawLineSeg(data.headLines[1], minX, minY, maxX, minY, Config.ESP_OutlineColor)
                    drawLineSeg(data.headLines[2], maxX, minY, maxX, maxY, Config.ESP_OutlineColor)
                    drawLineSeg(data.headLines[3], maxX, maxY, minX, maxY, Config.ESP_OutlineColor)
                    drawLineSeg(data.headLines[4], minX, maxY, minX, minY, Config.ESP_OutlineColor)
                else
                    for _, l in ipairs(data.headLines) do l.Visible = false end
                end
            else
                for _, l in ipairs(data.headLines) do l.Visible = false end
            end
        else
            for _, l in ipairs(data.headLines) do l.Visible = false end
        end
    else
        for _, l in ipairs(data.headLines) do l.Visible = false end
    end
end

-- HOLOGRAM
local function getHoloFrame()
    local mode = Config.HologramMode
    local baseO = Config.HologramColor
    local baseF = Config.HologramFillColor
    local ot = Config.HologramOutlineTrans / 100
    local ft = Config.HologramFillTrans / 100
    if mode == "RGB" then
        local h = (tick() * 0.3) % 1
        return Color3.fromHSV(h, 1, 1), Color3.fromHSV((h + 0.5) % 1, 1, 1), 0, 0.4
    elseif mode == "Pulse" then
        local p = (math.sin(tick() * 3) + 1) / 2
        return baseO, baseF, p * 0.6, 0.2 + p * 0.5
    elseif mode == "Flicker" then
        if math.random() < 0.08 then
            return baseO, baseF, 0.9, 0.9
        else
            return baseO, baseF, ot, ft
        end
    else
        return baseO, baseF, ot, ft
    end
end

local function updateHologram()
    if not Config.HologramOn then
        if next(highlightObjs) ~= nil then
            for plr, hl in pairs(highlightObjs) do pcall(function() hl:Destroy() end) end
            highlightObjs = {}
        end
        return
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and plr.Character then
            local skip = false
            if Config.TeamCheck and LP.Team and plr.Team == LP.Team then skip = true end
            local hum = plr.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health <= 0 then skip = true end
            if skip then
                if highlightObjs[plr] then
                    pcall(function() highlightObjs[plr]:Destroy() end)
                    highlightObjs[plr] = nil
                end
            else
                local hl = highlightObjs[plr]
                if not hl or not hl.Parent then
                    hl = Instance.new("Highlight")
                    hl.Name = "SR4X_Holo"
                    hl.Adornee = plr.Character
                    hl.Parent = plr.Character
                    highlightObjs[plr] = hl
                end
                local oc, fc, ot, ft = getHoloFrame()
                hl.OutlineColor = oc
                hl.FillColor = fc
                hl.OutlineTransparency = ot
                hl.FillTransparency = ft
                pcall(function()
                    hl.DepthMode = (Config.HologramDepth == "AlwaysOnTop")
                        and Enum.HighlightDepthMode.AlwaysOnTop
                        or Enum.HighlightDepthMode.Occluded
                end)
            end
        end
    end
end

-- MAIN ESP UPDATE
local function updateESP()
    if not Camera then return end
    local vs = Camera.ViewportSize
    if not vs or vs.X <= 0 then return end
    if not Config.ESP_Enabled then
        for plr in pairs(espObjects) do hideESPObject(plr) end
        for plr in pairs(skeletonObjs) do hideSkeleton(plr) end
        counterFrame.Visible = false
        return
    end
    local visibleCount = 0
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LP and plr.Character then
            local char = plr.Character
            local head = char:FindFirstChild("Head")
            local hrp = char:FindFirstChild("HumanoidRootPart")
            local hum = char:FindFirstChildOfClass("Humanoid")
            if head and hrp and hum and hum.Health > 0 then
                local skip = false
                if Config.TeamCheck and LP.Team and plr.Team == LP.Team then skip = true end
                if skip then
                    hideESPObject(plr); hideSkeleton(plr)
                else
                    local bounds = getCharBounds(char)
                    local sb = bounds and getScreenBox(bounds)
                    local headPos = Camera:WorldToViewportPoint(head.Position)
                    if sb and headPos.Z > 0 then
                        visibleCount = visibleCount + 1
                        local o = getESPObject(plr)
                        local dist = (Camera.CFrame.Position - hrp.Position).Magnitude
                        -- BOX (full char bounding)
                        if Config.ESP_Box then
                            o.box.Visible = true
                            o.box.Size = UDim2.fromOffset(sb.w, sb.h)
                            o.box.Position = UDim2.fromOffset(sb.cx, sb.cy)
                            o.stroke.Color = Config.ESP_OutlineColor
                        else o.box.Visible = false end
                        -- NAME
                        if Config.ESP_Name then
                            o.name.Visible = true
                            o.name.Text = string.format("%s [%d]", plr.Name, math.floor(dist))
                            o.name.TextColor3 = Config.ESP_Color
                            o.name.Size = UDim2.fromOffset(math.max(sb.w * 3, 120), 18)
                            o.name.Position = UDim2.fromOffset(sb.cx, sb.y - 4)
                        else o.name.Visible = false end
                        -- LINE
                        if Config.ESP_Line then
                            local fromX, fromY
                            if Config.ESP_LineStyle == "Bottom" then
                                fromX = vs.X / 2; fromY = vs.Y
                            else
                                fromX = vs.X / 2; fromY = 0
                            end
                            local toX, toY = sb.cx, sb.cy
                            local dx = toX - fromX
                            local dy = toY - fromY
                            local length = math.sqrt(dx*dx + dy*dy)
                            if length > 5 and length < 5000 then
                                local angle = math.deg(atan2(dy, dx))
                                if angle == angle then
                                    o.line.Visible = true
                                    o.line.Size = UDim2.fromOffset(length, 1)
                                    o.line.Position = UDim2.fromOffset(fromX, fromY)
                                    o.line.Rotation = angle
                                    o.line.BackgroundColor3 = Config.ESP_Color
                                else o.line.Visible = false end
                            else o.line.Visible = false end
                        else o.line.Visible = false end
                        updateSkeleton(plr, char)
                    else
                        hideESPObject(plr); hideSkeleton(plr)
                    end
                end
            else
                hideESPObject(plr); hideSkeleton(plr)
            end
        else
            if plr ~= LP then hideESPObject(plr); hideSkeleton(plr) end
        end
    end
    -- COUNTER
    if Config.ESP_Counter then
        counterFrame.Visible = true
        counterLabel.Text = "ENEMY " .. tostring(visibleCount)
        counterLabel.TextColor3 = visibleCount > 0 and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(150, 150, 150)
        counterStroke.Color = visibleCount > 0 and Color3.fromRGB(255, 50, 50) or Color3.fromRGB(100, 100, 100)
    else
        counterFrame.Visible = false
    end
end

Players.PlayerRemoving:Connect(function(plr)
    local o = espObjects[plr]
    if o then
        if o.box then o.box:Destroy() end
        if o.line then o.line:Destroy() end
        if o.name then o.name:Destroy() end
        espObjects[plr] = nil
    end
    local s = skeletonObjs[plr]
    if s then
        for _, l in ipairs(s.lines) do pcall(function() l:Destroy() end) end
        for _, l in ipairs(s.headLines) do pcall(function() l:Destroy() end) end
        skeletonObjs[plr] = nil
    end
    if highlightObjs[plr] then pcall(function() highlightObjs[plr]:Destroy() end) highlightObjs[plr] = nil end
end)

RunService.RenderStepped:Connect(function()
    pcall(updateESP)
    pcall(updateHologram)
    if Config.ESP_OutlineRGB then
        Config.ESP_OutlineColor = Color3.fromHSV((tick() * 0.3) % 1, 1, 1)
    end
end)

-- MAIN GUI
local ok_create, err_create = pcall(function()
local gui = Instance.new("ScreenGui")
gui.Name = "SR4X_MainUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Enabled = true
gui.DisplayOrder = BASE_DO + 1
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = guiParent
task.wait(0.1)

local testBar = Instance.new("Frame")
testBar.Size = UDim2.new(1, 0, 0, 40); testBar.Position = UDim2.new(0, 0, 0, 0)
testBar.BackgroundColor3 = Color3.fromRGB(255, 0, 0); testBar.BackgroundTransparency = 0.2
testBar.BorderSizePixel = 0; testBar.ZIndex = 999999; testBar.Parent = gui
local testLbl = Instance.new("TextLabel")
testLbl.Size = UDim2.new(1, 0, 1, 0); testLbl.BackgroundTransparency = 1
testLbl.Text = "SR4X v25 LOADED"; testLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
testLbl.Font = Enum.Font.SourceSansBold; testLbl.TextSize = 20; testLbl.ZIndex = 1000000; testLbl.Parent = testBar
task.delay(2.5, function()
    pcall(function()
        Tween:Create(testBar, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
        Tween:Create(testLbl, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
    end)
    task.delay(0.6, function() pcall(function() testBar:Destroy() end) end)
end)

local themeEls = {boxes = {}, strokes = {}, accents = {}}
local toggleRegistry = {}
local function applyTheme()
    for _, b in ipairs(themeEls.boxes) do if b and b.Parent then b.BackgroundColor3 = Config.BoxColor b.BackgroundTransparency = Config.BoxTransp end end
    for _, t in ipairs(toggleRegistry) do if t.btn and t.btn.Parent then if t.getActive() then t.btn.BackgroundColor3 = t.activeColor t.btn.BackgroundTransparency = 0.5 t.btn.TextColor3 = Color3.fromRGB(255,255,255) else t.btn.BackgroundColor3 = Config.BoxColor t.btn.BackgroundTransparency = Config.BoxTransp t.btn.TextColor3 = Color3.fromRGB(220,220,220) end end end
    for _, s in ipairs(themeEls.strokes) do if s and s.Parent then s.Color = Config.AccentA end end
    for _, a in ipairs(themeEls.accents) do if a and a.Parent then a.TextColor3 = Config.AccentA end end
end

local chGui = Instance.new("ScreenGui")
chGui.Name = "SR4X_Crosshair"; chGui.ResetOnSpawn = false; chGui.IgnoreGuiInset = true
chGui.Enabled = true; chGui.DisplayOrder = BASE_DO + 2; chGui.Parent = guiParent

local crosshairRing = Instance.new("Frame")
crosshairRing.Size = UDim2.fromOffset(20, 20); crosshairRing.AnchorPoint = Vector2.new(0.5, 0.5)
crosshairRing.Position = UDim2.fromScale(0.5, 0.5); crosshairRing.BackgroundTransparency = 1
crosshairRing.Visible = false; crosshairRing.Parent = chGui
Instance.new("UICorner", crosshairRing).CornerRadius = UDim.new(1, 0)
local chStroke = Instance.new("UIStroke")
chStroke.Thickness = 3.5; chStroke.Color = Color3.fromRGB(255, 50, 50); chStroke.Parent = crosshairRing
local crosshairDot = Instance.new("Frame")
crosshairDot.Size = UDim2.fromOffset(5, 5); crosshairDot.AnchorPoint = Vector2.new(0.5, 0.5)
crosshairDot.Position = UDim2.fromScale(0.5, 0.5); crosshairDot.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
crosshairDot.BorderSizePixel = 0; crosshairDot.Visible = false; crosshairDot.Parent = chGui
Instance.new("UICorner", crosshairDot).CornerRadius = UDim.new(1, 0)
local fovFrame = Instance.new("Frame")
fovFrame.AnchorPoint = Vector2.new(0.5, 0.5); fovFrame.Position = UDim2.fromScale(0.5, 0.5)
fovFrame.BackgroundTransparency = 1; fovFrame.BorderSizePixel = 0; fovFrame.Visible = false
fovFrame.ZIndex = 1; fovFrame.Parent = gui
Instance.new("UICorner", fovFrame).CornerRadius = UDim.new(1, 0)
local fovStroke = Instance.new("UIStroke")
fovStroke.Thickness = 1.5; fovStroke.Transparency = 0.5; fovStroke.Parent = fovFrame
table.insert(themeEls.strokes, fovStroke)

local btn = Instance.new("TextButton")
btn.Size = UDim2.fromOffset(Config.OrbSize, Config.OrbSize)
btn.Position = UDim2.new(0, 24, 0.5, -Config.OrbSize/2)
btn.BackgroundColor3 = Color3.fromRGB(18,18,22); btn.Text = "◎"
btn.TextColor3 = Color3.fromRGB(255,255,255); btn.Font = Enum.Font.SourceSansBold
btn.TextSize = 24; btn.AutoButtonColor = false; btn.BorderSizePixel = 0
btn.Active = true; btn.ZIndex = 5; btn.Parent = gui
Instance.new("UICorner", btn).CornerRadius = UDim.new(1, 0)
local btnStroke = Instance.new("UIStroke"); btnStroke.Parent = btn
local btnGrad = Instance.new("UIGradient"); btnGrad.Parent = btnStroke
table.insert(themeEls.strokes, btnStroke)

local freezeBtn = Instance.new("TextButton")
freezeBtn.Size = UDim2.fromOffset(Config.FreezeOrbSize, Config.FreezeOrbSize)
freezeBtn.Position = UDim2.new(0, 24, 0.5, 40)
freezeBtn.BackgroundColor3 = Config.FreezeInactiveColor; freezeBtn.Text = "❄"
freezeBtn.TextColor3 = Color3.fromRGB(255,255,255); freezeBtn.Font = Enum.Font.SourceSansBold
freezeBtn.TextSize = math.clamp(Config.FreezeOrbSize * 0.42, 12, 60)
freezeBtn.AutoButtonColor = false; freezeBtn.BorderSizePixel = 0
freezeBtn.Active = true; freezeBtn.Visible = false; freezeBtn.ZIndex = 5; freezeBtn.Parent = gui
Instance.new("UICorner", freezeBtn).CornerRadius = UDim.new(1, 0)
local freezeStroke = Instance.new("UIStroke")
freezeStroke.Thickness = 2; freezeStroke.Color = Color3.fromRGB(255,255,255); freezeStroke.Parent = freezeBtn
local pindahLabel = Instance.new("TextLabel")
pindahLabel.Size = UDim2.fromOffset(80, 20); pindahLabel.AnchorPoint = Vector2.new(0.5, 1)
pindahLabel.Position = UDim2.new(0.5, 0, 0, -6); pindahLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
pindahLabel.BackgroundTransparency = 0.3; pindahLabel.Text = "PINDAH"
pindahLabel.Font = Enum.Font.GothamBold; pindahLabel.TextSize = 10
pindahLabel.TextColor3 = Color3.fromRGB(0, 255, 150); pindahLabel.Visible = false
pindahLabel.ZIndex = 6; pindahLabel.Parent = freezeBtn
Instance.new("UICorner", pindahLabel).CornerRadius = UDim.new(0, 6)

local ninjaBtn = Instance.new("TextButton")
ninjaBtn.Name = "SR4X_NinjaBtn"
ninjaBtn.Size = UDim2.fromOffset(64, 64); ninjaBtn.Position = UDim2.new(1, -88, 0.5, -32)
ninjaBtn.BackgroundColor3 = Color3.fromRGB(255, 140, 0); ninjaBtn.BackgroundTransparency = 0.15
ninjaBtn.Text = "⚡"; ninjaBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ninjaBtn.Font = Enum.Font.SourceSansBold; ninjaBtn.TextSize = 34
ninjaBtn.AutoButtonColor = false; ninjaBtn.BorderSizePixel = 0
ninjaBtn.Active = true; ninjaBtn.Visible = false; ninjaBtn.ZIndex = 5; ninjaBtn.Parent = gui
Instance.new("UICorner", ninjaBtn).CornerRadius = UDim.new(1, 0)
local ninjaStroke = Instance.new("UIStroke")
ninjaStroke.Thickness = 2; ninjaStroke.Color = Color3.fromRGB(255, 220, 100); ninjaStroke.Parent = ninjaBtn

do
    local dN, sN, pN, mN = false, nil, nil, false
    ninjaBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dN = true; mN = false; sN = input.Position; pN = ninjaBtn.Position
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if dN and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - sN
            if d.Magnitude > 6 then mN = true end
            ninjaBtn.Position = UDim2.new(pN.X.Scale, pN.X.Offset + d.X, pN.Y.Scale, pN.Y.Offset + d.Y)
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if dN and not mN then task.spawn(ninjaFire) end
            dN = false
        end
    end)
end

local function applyOrbThickness(v) Config.OrbThick = v local a = v / 100 btnStroke.Thickness = a * 12 btnStroke.Transparency = 1 - a btn.BackgroundTransparency = 1 - a btn.TextTransparency = 1 - a end
local function applyFreezeThickness(v) Config.FreezeOrbThick = v local a = v / 100 freezeStroke.Thickness = a * 12 freezeStroke.Transparency = 1 - a freezeBtn.BackgroundTransparency = 1 - a freezeBtn.TextTransparency = 1 - a end
local function applyFreezeSize(v) Config.FreezeOrbSize = v freezeBtn.Size = UDim2.fromOffset(v, v) freezeBtn.TextSize = math.clamp(v * 0.42, 10, 70) end
applyOrbThickness(Config.OrbThick) applyFreezeThickness(Config.FreezeOrbThick) applyFreezeSize(Config.FreezeOrbSize)

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(290, 460); panel.Position = UDim2.new(0.5, -145, 0.5, -230)
panel.BackgroundColor3 = Config.BoxColor; panel.BackgroundTransparency = Config.BoxTransp
panel.Visible = false; panel.BorderSizePixel = 0; panel.ZIndex = 10; panel.Parent = gui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 16)
local pStroke = Instance.new("UIStroke")
pStroke.Color = Color3.fromRGB(255,255,255); pStroke.Transparency = 0.55
pStroke.Thickness = 1; pStroke.Parent = panel
table.insert(themeEls.boxes, panel)

local panelScale = Instance.new("UIScale"); panelScale.Parent = panel
local function updatePanelScale()
    local vp = Vector2.new(1280, 720)
    if Camera then pcall(function() vp = Camera.ViewportSize end) end
    local s = math.min(1, vp.Y / 540); if s < 0.55 then s = 0.55 end
    panelScale.Scale = s
end
pcall(updatePanelScale)
if Camera then pcall(function() Camera:GetPropertyChangedSignal("ViewportSize"):Connect(updatePanelScale) end) end

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -50, 0, 32); title.Position = UDim2.fromOffset(14, 6)
title.BackgroundTransparency = 1; title.Text = "SR4X TEAM v25"
title.TextColor3 = Config.AccentA; title.Font = Enum.Font.SourceSansBold
title.TextSize = 16; title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 11; title.Parent = panel
table.insert(themeEls.accents, title)

local dragHandle = Instance.new("Frame")
dragHandle.Size = UDim2.new(1, -50, 0, 34); dragHandle.Position = UDim2.fromOffset(0, 2)
dragHandle.BackgroundTransparency = 1; dragHandle.Active = true
dragHandle.ZIndex = 12; dragHandle.Parent = panel

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(28, 28); closeBtn.Position = UDim2.new(1, -36, 0, 8)
closeBtn.BackgroundColor3 = Color3.fromRGB(255,80,80); closeBtn.Text = "X"
closeBtn.TextColor3 = Color3.fromRGB(255,255,255); closeBtn.Font = Enum.Font.SourceSansBold
closeBtn.TextSize = 14; closeBtn.ZIndex = 13; closeBtn.Parent = panel
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)
closeBtn.MouseButton1Click:Connect(function() panel.Visible = false end)

do
    local pD, pS, pO = false, nil, nil
    dragHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            pD = true; pS = input.Position; pO = panel.Position
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if pD and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - pS
            panel.Position = UDim2.new(pO.X.Scale, pO.X.Offset + d.X, pO.Y.Scale, pO.Y.Offset + d.Y)
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then pD = false end
    end)
end

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -20, 1, -52); scroll.Position = UDim2.fromOffset(10, 44)
scroll.BackgroundTransparency = 1; scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = UIS.TouchEnabled and 8 or 4
scroll.ScrollBarImageColor3 = Color3.fromRGB(255,255,255)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.ScrollingDirection = Enum.ScrollingDirection.Y
scroll.ElasticBehavior = Enum.ElasticBehavior.WhenScrollable
scroll.ZIndex = 11; scroll.Parent = panel

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8); layout.SortOrder = Enum.SortOrder.LayoutOrder; layout.Parent = scroll

local function section(txt)
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, 22); l.BackgroundTransparency = 1
    l.Text = txt; l.TextColor3 = Config.AccentA
    l.Font = Enum.Font.SourceSansBold; l.TextSize = 13
    l.TextXAlignment = Enum.TextXAlignment.Left; l.Parent = scroll
    table.insert(themeEls.accents, l); return l
end

local function makeToggle(text, initial, cb, activeColor)
    activeColor = activeColor or Config.AccentA
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, 34); b.BackgroundColor3 = Config.BoxColor
    b.BackgroundTransparency = Config.BoxTransp; b.TextColor3 = Color3.fromRGB(220,220,220)
    b.Font = Enum.Font.SourceSans; b.TextSize = 14; b.Parent = scroll
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    table.insert(themeEls.boxes, b)
    local state = {value = initial}
    table.insert(toggleRegistry, {btn = b, getActive = function() return state.value end, activeColor = activeColor})
    local function render()
        b.Text = text .. ": " .. (state.value and "ON" or "OFF")
        if state.value then b.BackgroundColor3 = activeColor b.BackgroundTransparency = 0.5 b.TextColor3 = Color3.fromRGB(255,255,255)
        else b.BackgroundColor3 = Config.BoxColor b.BackgroundTransparency = Config.BoxTransp b.TextColor3 = Color3.fromRGB(220,220,220) end
    end
    render()
    b.MouseButton1Click:Connect(function() state.value = not state.value render() cb(state.value) end)
    return b
end

local function makeNumber(t, initial, min, max, step, onChange)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 34); row.BackgroundColor3 = Config.BoxColor
    row.BackgroundTransparency = Config.BoxTransp; row.Parent = scroll
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
    table.insert(themeEls.boxes, row)
    local lbl = Instance.new("TextButton")
    lbl.Size = UDim2.new(1, -84, 1, 0); lbl.Position = UDim2.fromOffset(10, 0)
    lbl.BackgroundTransparency = 1; lbl.Text = t .. ": " .. initial
    lbl.TextColor3 = Color3.fromRGB(255,255,255); lbl.Font = Enum.Font.SourceSans
    lbl.TextSize = 14; lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.AutoButtonColor = false; lbl.Parent = row
    local inputBox = Instance.new("TextBox")
    inputBox.Size = UDim2.new(1, -84, 1, 0); inputBox.Position = UDim2.fromOffset(10, 0)
    inputBox.BackgroundColor3 = Color3.fromRGB(50, 50, 70); inputBox.BackgroundTransparency = 0.3
    inputBox.TextColor3 = Color3.fromRGB(255,255,255); inputBox.Font = Enum.Font.SourceSans
    inputBox.TextSize = 14; inputBox.TextXAlignment = Enum.TextXAlignment.Left
    inputBox.ClearTextOnFocus = false; inputBox.Visible = false; inputBox.Parent = row
    Instance.new("UICorner", inputBox).CornerRadius = UDim.new(0, 6)
    local val = initial
    local function setVal(v)
        v = math.clamp(tonumber(v) or val, min, max); val = v
        lbl.Text = t .. ": " .. val; onChange(val)
    end
    lbl.MouseButton1Click:Connect(function()
        inputBox.Text = tostring(val); inputBox.Visible = true; lbl.Visible = false
        inputBox:CaptureFocus()
    end)
    inputBox.FocusLost:Connect(function()
        local n = tonumber(inputBox.Text)
        if n then setVal(n) else inputBox.Text = tostring(val) end
        inputBox.Visible = false; lbl.Visible = true
    end)
    local minus = Instance.new("TextButton")
    minus.Size = UDim2.fromOffset(32, 26); minus.Position = UDim2.new(1, -74, 0.5, -13)
    minus.BackgroundTransparency = 0.3; minus.BackgroundColor3 = Config.AccentA
    minus.Text = "-"; minus.TextColor3 = Color3.fromRGB(255,255,255)
    minus.Font = Enum.Font.SourceSansBold; minus.Parent = row
    Instance.new("UICorner", minus).CornerRadius = UDim.new(0, 6)
    local plus = Instance.new("TextButton")
    plus.Size = UDim2.fromOffset(32, 26); plus.Position = UDim2.new(1, -38, 0.5, -13)
    plus.BackgroundTransparency = 0.3; plus.BackgroundColor3 = Config.AccentA
    plus.Text = "+"; plus.TextColor3 = Color3.fromRGB(255,255,255)
    plus.Font = Enum.Font.SourceSansBold; plus.Parent = row
    Instance.new("UICorner", plus).CornerRadius = UDim.new(0, 6)
    minus.MouseButton1Click:Connect(function() setVal(val - step) end)
    plus.MouseButton1Click:Connect(function() setVal(val + step) end)
end

local function makeCycle(t, items, initialIdx, onChange)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, 0, 0, 34); b.BackgroundColor3 = Config.BoxColor
    b.BackgroundTransparency = Config.BoxTransp; b.TextColor3 = Color3.fromRGB(255,255,255)
    b.Font = Enum.Font.SourceSans; b.TextSize = 14; b.Parent = scroll
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    table.insert(themeEls.boxes, b)
    local i = initialIdx
    local function render() b.Text = t .. ": " .. tostring(items[i].name or items[i]) end
    render()
    b.MouseButton1Click:Connect(function() i = i % #items + 1 render() onChange(i, items[i]) end)
    return b
end

-- FREEZE ENGINE (unchanged)
local freezeConn = nil local lastCollect = 0
local function freezeModel(model)
    if frozenData[model] then return end
    local hrp = model:FindFirstChild("HumanoidRootPart")
    local hum = model:FindFirstChildOfClass("Humanoid")
    if not hrp then return end
    frozenData[model] = {cf = hrp.CFrame, origSize = hrp.Size, origTrans = hrp.Transparency,
        speed = hum and hum.WalkSpeed or 16, jump = hum and hum.JumpPower or 50, jheight = hum and hum.JumpHeight or 7.2}
    for _, part in ipairs(model:GetDescendants()) do
        if part:IsA("BasePart") then pcall(function() part.Anchored = true part.CanCollide = false part.Velocity = Vector3.zero part.RotVelocity = Vector3.zero end) end
    end
    pcall(function() hrp.Size = Vector3.new(15, 15, 15) hrp.Transparency = 1 hrp.CanQuery = true hrp.CanTouch = true hrp.Massless = true end)
    if hum then pcall(function() hum.WalkSpeed = 0 hum.JumpPower = 0 hum.JumpHeight = 0 hum.PlatformStand = true hum.AutoRotate = false hum:ChangeState(Enum.HumanoidStateType.Physics) end) end
end
local function unfreezeModel(model)
    local d = frozenData[model]
    if not d then return end
    local hum = model:FindFirstChildOfClass("Humanoid")
    local hrp = model:FindFirstChild("HumanoidRootPart")
    for _, part in ipairs(model:GetDescendants()) do if part:IsA("BasePart") then pcall(function() part.Anchored = false; part.CanCollide = true end) end end
    if hrp then pcall(function() hrp.Size = d.origSize hrp.Transparency = d.origTrans hrp.CanCollide = true hrp.Massless = false end) end
    if hum then pcall(function() hum.WalkSpeed = d.speed; hum.JumpPower = d.jump hum.JumpHeight = d.jheight; hum.PlatformStand = false hum.AutoRotate = true end) end
    frozenData[model] = nil
end
local function freezeTick()
    if not Config.FreezeActive then return end
    for model, data in pairs(frozenData) do
        if not model.Parent then frozenData[model] = nil
        else
            local hrp = model:FindFirstChild("HumanoidRootPart")
            if hrp then pcall(function() hrp.CFrame = data.cf hrp.Velocity = Vector3.zero hrp.RotVelocity = Vector3.zero hrp.Anchored = true hrp.Transparency = 1 end) end
            local hum = model:FindFirstChildOfClass("Humanoid")
            if hum then pcall(function() hum.WalkSpeed = 0 hum.JumpPower = 0 hum.PlatformStand = true hum:ChangeState(Enum.HumanoidStateType.Physics) end) end
        end
    end
    if os.clock() - lastCollect > 0.5 then
        lastCollect = os.clock()
        for _, model in ipairs(getCachedTargets()) do if not frozenData[model] then freezeModel(model) end end
    end
end
local function setFreezeActive(v)
    Config.FreezeActive = v
    if v then
        freezeBtn.BackgroundColor3 = Color3.fromRGB(75, 145, 255)
        if not freezeConn then freezeConn = RunService.PreSimulation:Connect(freezeTick) end
    else
        if Config.FreezeInactiveRGB then freezeBtn.BackgroundColor3 = Color3.fromHSV((tick() % 5)/5, 0.8, 1)
        else freezeBtn.BackgroundColor3 = Config.FreezeInactiveColor end
        if freezeConn then freezeConn:Disconnect(); freezeConn = nil end
        for model in pairs(frozenData) do pcall(unfreezeModel, model) end
        frozenData = {}
    end
end
local function startFreeze() if Config.FreezeActive then return end for _, m in ipairs(getCachedTargets()) do if not frozenData[m] then freezeModel(m) end end setFreezeActive(true) end
local function stopFreeze() if not Config.FreezeActive then return end setFreezeActive(false) end

-- UI SECTIONS
section("FREEZE")
makeToggle("Freeze Module", Config.FreezeEnabled, function(v)
    Config.FreezeEnabled = v; freezeBtn.Visible = v
    if not v and Config.FreezeActive then stopFreeze() end
    invalidateTargets()
end, Color3.fromRGB(0, 150, 255))

section("FREEZE SETTING")
makeNumber("Besar Tombol Freeze", Config.FreezeOrbSize, 20, 120, 4, function(v) applyFreezeSize(v) end)
makeNumber("Ketebalan Freeze", Config.FreezeOrbThick, 0, 100, 5, function(v) applyFreezeThickness(v) end)
makeCycle("Warna OFF", FreezeInactiveColors, 1, function(_, v)
    if v.name == "RGB" then Config.FreezeInactiveRGB = true
    else Config.FreezeInactiveRGB = false Config.FreezeInactiveColor = v.color
        if not Config.FreezeActive then freezeBtn.BackgroundColor3 = v.color end end
end)

section("SILENT AIM (BIG HEAD)")
makeToggle("Silent Aim", Config.SilentAim, function(v)
    Config.SilentAim = v
    if not v then clearAllBigHeads() end
end, Color3.fromRGB(255, 50, 100))
makeNumber("Head Offset", Config.SilentAimHeadSize, 1, 100, 1, function(v) Config.SilentAimHeadSize = v clearAllBigHeads() end)
makeNumber("Max Range", Config.SilentAimRange, 50, 2000, 50, function(v) Config.SilentAimRange = v end)
makeToggle("Silent Team Check", Config.SilentAimTeam, function(v) Config.SilentAimTeam = v end)
makeToggle("Silent NPCs", Config.SilentAimNPCs, function(v) Config.SilentAimNPCs = v end)

section("NINJA FIRE")
makeToggle("Ninja Fire", Config.NinjaFire, function(v) Config.NinjaFire = v ninjaBtn.Visible = v end, Color3.fromRGB(255, 140, 0))
makeNumber("Ninja Offset", Config.NinjaFireDist, 2, 15, 1, function(v) Config.NinjaFireDist = v end)
makeNumber("Return Delay x1000", math.floor(Config.NinjaFireReturnDelay*1000), 10, 300, 10, function(v) Config.NinjaFireReturnDelay = v/1000 end)

section("AIMBOT")
makeToggle("Aimbot", Config.Aimbot, function(v) Config.Aimbot = v end)
makeNumber("FOV", Config.AimbotFOV, 40, 600, 20, function(v) Config.AimbotFOV = v end)
makeNumber("Smooth x100", math.floor(Config.AimbotSmooth*100), 0, 95, 5, function(v) Config.AimbotSmooth = v/100 end)
makeCycle("Target Part", {{name="Head"}, {name="HRP"}}, 1, function(_, v) Config.AimbotPart = v.name end)
makeToggle("Target Players", Config.TargetPlayers, function(v) Config.TargetPlayers = v invalidateTargets() end)
makeToggle("Target NPCs", Config.TargetNPCs, function(v) Config.TargetNPCs = v invalidateTargets() end)
makeToggle("Team Check", Config.TeamCheck, function(v) Config.TeamCheck = v invalidateTargets() end)
makeToggle("Wall Check", Config.WallCheck, function(v) Config.WallCheck = v end)
makeToggle("Show FOV Circle", Config.ShowFOV, function(v) Config.ShowFOV = v end)

section("AIMBOT POV")
makeNumber("POV X", Config.POV_X, -100, 100, 5, function(v) Config.POV_X = v end)
makeNumber("POV Y", Config.POV_Y, -100, 100, 5, function(v) Config.POV_Y = v end)

section("AIM MAGNET")
makeToggle("Magnet Manual", Config.AimMagnetManual, function(v) Config.AimMagnetManual = v if v then Config.AimMagnetPro = false end end, Color3.fromRGB(255, 0, 255))
makeToggle("Magnet Pro", Config.AimMagnetPro, function(v) Config.AimMagnetPro = v if v then Config.AimMagnetManual = false end end, Color3.fromRGB(255, 0, 255))
makeCycle("Magnet Target", {{name="Head"}, {name="HRP"}}, 1, function(_, v) Config.MagnetTarget = v.name end)

section("NOCLIP")
makeToggle("Noclip Master", Config.NoclipEnabled, function(v) Config.NoclipEnabled = v end, Color3.fromRGB(0, 255, 150))
makeToggle("Noclip Auto", Config.NoclipAuto, function(v) Config.NoclipAuto = v end, Color3.fromRGB(0, 255, 150))
makeToggle("Anti-Fling", Config.AntiFlingEnabled, function(v) Config.AntiFlingEnabled = v end, Color3.fromRGB(0, 255, 150))

section("ANTI-BAN")
makeToggle("Anti-Ban Master", Config.AntiBanEnabled, function(v) Config.AntiBanEnabled = v Config.AntiKick = v end, Color3.fromRGB(0, 255, 100))
makeToggle("Anti-Kick", Config.AntiKick, function(v) Config.AntiKick = v end, Color3.fromRGB(0, 255, 150))

section("AUTO SHOOT & UTILITY")
makeToggle("Auto Shoot", Config.AutoShoot, function(v) Config.AutoShoot = v end, Color3.fromRGB(255, 100, 0))
makeCycle("Shoot Target", {{name="Head"}, {name="HRP"}}, 1, function(_, v) Config.AutoShootTarget = v.name end)
makeNumber("Shoot Speed ms", math.floor(Config.AutoShootSpeed*1000), 80, 500, 10, function(v) Config.AutoShootSpeed = v/1000 end)
makeToggle("Fast Reload", Config.FastReload, function(v) Config.FastReload = v end, Color3.fromRGB(0, 255, 255))
makeToggle("No Reload", Config.NoReload, function(v) Config.NoReload = v end, Color3.fromRGB(0, 255, 0))
makeToggle("Auto Magnet", Config.AutoMagnet, function(v) Config.AutoMagnet = v end, Color3.fromRGB(255, 215, 0))

section("ESP (WITH SKELETON)")
makeToggle("Enable ESP", Config.ESP_Enabled, function(v) Config.ESP_Enabled = v end)
makeToggle("ESP Box", Config.ESP_Box, function(v) Config.ESP_Box = v end)
makeToggle("ESP Line", Config.ESP_Line, function(v) Config.ESP_Line = v end)
makeCycle("ESP Line Style", LineStyles, 1, function(_, v) Config.ESP_LineStyle = v.name end)
makeToggle("ESP Name", Config.ESP_Name, function(v) Config.ESP_Name = v end)
makeToggle("ESP Counter", Config.ESP_Counter, function(v) Config.ESP_Counter = v end)
makeToggle("ESP Skeleton", Config.ESP_Skeleton, function(v) Config.ESP_Skeleton = v end)
makeToggle("ESP Head Outline", Config.ESP_HeadOutline, function(v) Config.ESP_HeadOutline = v end)
makeCycle("ESP Color", ESP_Colors, 1, function(_, v) Config.ESP_Color = v.color end)
makeCycle("ESP Outline Color", ESP_OutlineColors, 1, function(_, v) Config.ESP_OutlineRGB = false Config.ESP_OutlineColor = v.color end)
makeToggle("ESP Outline RGB", Config.ESP_OutlineRGB, function(v)
    Config.ESP_OutlineRGB = v
    if not v then Config.ESP_OutlineColor = ESP_OutlineColors[1].color end
end, Color3.fromRGB(255, 0, 255))

section("HOLOGRAM OUTLINE")
makeToggle("Enable Hologram", Config.HologramOn, function(v) Config.HologramOn = v end, Color3.fromRGB(0, 255, 255))
makeCycle("Hologram Mode", HologramModes, 2, function(_, v) Config.HologramMode = v.name end)
makeCycle("Holo Color", ESP_OutlineColors, 7, function(_, v) Config.HologramColor = v.color end)
makeCycle("Holo Fill Color", ESP_OutlineColors, 7, function(_, v) Config.HologramFillColor = v.color end)
makeNumber("Outline Transparency %", Config.HologramOutlineTrans, 0, 100, 5, function(v) Config.HologramOutlineTrans = v end)
makeNumber("Fill Transparency %", Config.HologramFillTrans, 0, 100, 5, function(v) Config.HologramFillTrans = v end)
makeCycle("Holo Depth", DepthModes, 1, function(_, v) Config.HologramDepth = v.name end)

section("THEME")
makeCycle("Mode", {{name="Gradient"}, {name="RGB"}, {name="Solid"}}, 1, function(_, v) Config.Theme = v.name end)
makeCycle("Preset", ThemePresets, 1, function(_, v) Config.BoxColor = v.box Config.AccentA = v.a Config.AccentB = v.b applyTheme() end)

section("ORB MENU")
makeNumber("Ketebalan Menu", Config.OrbThick, 0, 100, 5, function(v) applyOrbThickness(v) end)
applyTheme()

-- THEME LOOP
local rgbT = 0
RunService.RenderStepped:Connect(function(dt)
    pcall(function()
        local currentRGB = Color3.fromHSV((tick() * 0.6) % 1, 1, 1)
        chStroke.Color = currentRGB; crosshairDot.BackgroundColor3 = currentRGB
        crosshairRing.Position = UDim2.fromScale(0.5, 0.5); crosshairDot.Position = UDim2.fromScale(0.5, 0.5)
        fovFrame.Position = UDim2.new(0.5, Config.POV_X, 0.5, Config.POV_Y)
        fovFrame.Size = UDim2.fromOffset(Config.AimbotFOV*2, Config.AimbotFOV*2)
        if not Config.FreezeActive and Config.FreezeInactiveRGB then freezeBtn.BackgroundColor3 = Color3.fromHSV((tick() * 0.5) % 1, 0.9, 1) end
        if Config.Theme == "RGB" then
            rgbT = rgbT + dt
            local c1 = Color3.fromHSV((rgbT*0.3)%1, 1, 1)
            local c2 = Color3.fromHSV((rgbT*0.3+0.5)%1, 1, 1)
            btnStroke.Color = c1; btnGrad.Color = ColorSequence.new(c1, c2); fovStroke.Color = c1
        elseif Config.Theme == "Gradient" then
            btnStroke.Color = Config.AccentA; btnGrad.Color = ColorSequence.new(Config.AccentA, Config.AccentB); fovStroke.Color = Config.AccentA
        else
            btnStroke.Color = Config.AccentA; btnGrad.Color = ColorSequence.new(Config.AccentA, Config.AccentA); fovStroke.Color = Config.AccentA
        end
        fovFrame.Visible = Config.ShowFOV
    end)
end)

-- ORB DRAG
local dM, sM, pM, mM
btn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dM = true; mM = false; sM = input.Position; pM = btn.Position
    end
end)
UIS.InputChanged:Connect(function(input)
    if dM and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local d = input.Position - sM
        if d.Magnitude > 6 then mM = true end
        btn.Position = UDim2.new(pM.X.Scale, pM.X.Offset + d.X, pM.Y.Scale, pM.Y.Offset + d.Y)
    end
end)
UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        if dM and not mM then panel.Visible = not panel.Visible end
        dM = false
    end
end)

task.delay(2, function()
    pcall(function()
        if btn and btn.Parent then
            btn.Visible = true
            btn.Position = UDim2.new(0, 24, 0.5, -Config.OrbSize/2)
            btn.BackgroundTransparency = 0; btn.TextTransparency = 0
        end
    end)
end)

-- FREEZE ORB DRAG
local fLocked = true; local fHold = false; local fThread = nil; local fMoved = false
local fStart, fPosStart
local function lockF() fLocked = true pindahLabel.Visible = false freezeStroke.Color = Color3.fromRGB(255, 255, 255) end
local function unlockF()
    fLocked = false; pindahLabel.Visible = true; freezeStroke.Color = Color3.fromRGB(0, 255, 150)
    pcall(function()
        Tween:Create(freezeBtn, TweenInfo.new(0.1, Enum.EasingStyle.Bounce), {Size = UDim2.fromOffset(Config.FreezeOrbSize+6, Config.FreezeOrbSize+6)}):Play()
        task.wait(0.1)
        Tween:Create(freezeBtn, TweenInfo.new(0.1), {Size = UDim2.fromOffset(Config.FreezeOrbSize, Config.FreezeOrbSize)}):Play()
    end)
end
freezeBtn.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        fHold = true; fMoved = false; fStart = input.Position; fPosStart = freezeBtn.Position
        if fThread then task.cancel(fThread) end
        fThread = task.delay(2, function() if fHold and not fMoved then unlockF() end end)
    end
end)
UIS.InputChanged:Connect(function(input)
    if fHold and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local d = input.Position - fStart
        if d.Magnitude > 8 then fMoved = true end
        if not fLocked and fMoved then
            freezeBtn.Position = UDim2.new(fPosStart.X.Scale, fPosStart.X.Offset + d.X, fPosStart.Y.Scale, fPosStart.Y.Offset + d.Y)
        end
    end
end)
UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        if fHold then
            if fThread then task.cancel(fThread) fThread = nil end
            if fLocked then
                if not fMoved then
                    if Config.FreezeActive then stopFreeze() else startFreeze() end
                end
            else lockF() end
        end
        fHold = false; fMoved = false
    end
end)

-- VISUAL AIMBOT
local function targetPos(model)
    if not model then return nil end
    if Config.AimbotPart == "Head" then
        local h = model:FindFirstChild("Head"); if h then return h.Position end
    end
    local hrp = model:FindFirstChild("HumanoidRootPart")
    return hrp and hrp.Position or nil
end
local function pickTarget()
    if not Camera then return nil end
    local vs = Camera.ViewportSize
    if not vs or vs.X <= 0 then return nil end
    local best, bestDist = nil, Config.AimbotFOV
    local center = Vector2.new(vs.X/2 + Config.POV_X, vs.Y/2 + Config.POV_Y)
    local myTeam = LP.Team
    local function consider(model, team, isPlayer)
        local pos = targetPos(model)
        if not pos then return end
        if isPlayer and Config.TeamCheck and myTeam and team == myTeam then return end
        local ok, sp = pcall(function() return Camera:WorldToViewportPoint(pos) end)
        if ok and sp and sp.Z > 0 then
            local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
            if d < bestDist and isVisible(model, pos) then best, bestDist = pos, d end
        end
    end
    if Config.TargetPlayers then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and p.Character then
                local hum = p.Character:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 and p.Character:FindFirstChild("HumanoidRootPart") then consider(p.Character, p.Team, true) end
            end
        end
    end
    if Config.TargetNPCs then
        refreshNPCs()
        for _, m in ipairs(npcCache) do if m.Parent then consider(m, nil, false) end end
    end
    return best
end
RunService:BindToRenderStep("SR4XAimbotCamera", Enum.RenderPriority.Camera.Value + 1, function()
    if not Camera then return end
    if not Config.Aimbot then crosshairRing.Visible = false; crosshairDot.Visible = false return end
    crosshairRing.Visible = true; crosshairDot.Visible = true
    local tpos = pickTarget()
    if not tpos then return end
    local camPos = Camera.CFrame.Position
    if (tpos - camPos).Magnitude < 0.1 then return end
    pcall(function()
        local desired = CFrame.lookAt(camPos, tpos)
        Camera.CFrame = Camera.CFrame:Lerp(desired, math.clamp(1 - Config.AimbotSmooth, 0, 1))
    end)
end)

-- AUTO MAGNET
task.spawn(function()
    while task.wait(1) do
        if Config.AutoMagnet then
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("ProximityPrompt") then
                    pcall(function()
                        if not obj:GetAttribute("SR4X_Magnet") then
                            obj:SetAttribute("SR4X_Magnet", true)
                            obj:SetAttribute("OrigMaxDist", obj.MaxActivationDistance)
                            obj:SetAttribute("OrigLOS", obj.RequiresLineOfSight)
                            obj:SetAttribute("OrigHold", obj.HoldDuration)
                        end
                        obj.MaxActivationDistance = 1000; obj.RequiresLineOfSight = false; obj.HoldDuration = 0
                    end)
                end
            end
        else
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("ProximityPrompt") and obj:GetAttribute("SR4X_Magnet") then
                    pcall(function()
                        obj.MaxActivationDistance = obj:GetAttribute("OrigMaxDist") or 10
                        obj.RequiresLineOfSight = obj:GetAttribute("OrigLOS") ~= false
                        obj.HoldDuration = obj:GetAttribute("OrigHold") or 0
                        obj:SetAttribute("SR4X_Magnet", nil)
                    end)
                end
            end
        end
    end
end)

-- AIM MAGNET
local magnetData = {}
RunService.RenderStepped:Connect(function()
    if not Camera then return end
    if not Config.AimMagnetManual and not Config.AimMagnetPro then
        for m, d in pairs(magnetData) do
            if m.Parent then
                local hrp = m:FindFirstChild("HumanoidRootPart")
                if hrp then pcall(function() hrp.Anchored = d.origAnchored hrp.CanCollide = d.origCanCollide hrp.CFrame = d.origCF end) end
            end
        end
        magnetData = {}; return
    end
    local targetModel = nil; local nearestDist = math.huge
    local vs = Camera.ViewportSize
    if not vs then return end
    local center = Vector2.new(vs.X/2 + Config.POV_X, vs.Y/2 + Config.POV_Y)
    for _, m in ipairs(getCachedTargets()) do
        local hrp = m:FindFirstChild("HumanoidRootPart")
        if hrp then
            local isInsideFOV = false
            local sp, onScreen = Camera:WorldToViewportPoint(hrp.Position)
            if onScreen and sp.Z > 0 then
                local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                if d <= Config.AimbotFOV then isInsideFOV = true end
            end
            if Config.AimMagnetPro or (Config.AimMagnetManual and isInsideFOV) then
                if isVisible(m, hrp.Position) then
                    local dist = (Camera.CFrame.Position - hrp.Position).Magnitude
                    if dist < nearestDist then nearestDist = dist; targetModel = m end
                end
            end
        end
    end
    if targetModel then
        local hrp = targetModel:FindFirstChild("HumanoidRootPart")
        if not magnetData[targetModel] then
            magnetData[targetModel] = {origCF = hrp.CFrame, origAnchored = hrp.Anchored, origCanCollide = hrp.CanCollide}
        end
        pcall(function()
            hrp.Anchored = true; hrp.CanCollide = false
            local centerRay = Camera:ViewportPointToRay(vs.X/2 + Config.POV_X, vs.Y/2 + Config.POV_Y)
            local tPos = centerRay.Origin + centerRay.Direction * 15
            if Config.MagnetTarget == "Head" and targetModel:FindFirstChild("Head") then
                local head = targetModel.Head
                hrp.CFrame = CFrame.lookAt(tPos, Camera.CFrame.Position) * hrp.CFrame:ToObjectSpace(head.CFrame):Inverse()
            else
                hrp.CFrame = CFrame.lookAt(tPos, Camera.CFrame.Position)
            end
        end)
    end
end)

-- FAST RELOAD
task.spawn(function()
    while task.wait(0.05) do
        if Config.FastReload then
            local tool = getWeaponTool()
            if tool then
                pcall(function()
                    for _, v in pairs(tool:GetDescendants()) do
                        if v:IsA("ValueBase") and (v.Name:lower():find("ammo") or v.Name:lower():find("clip")) then
                            if v.Value < 99 then v.Value = 99 end
                        end
                    end
                    local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
                    if hum and hum:FindFirstChildOfClass("Animator") then
                        for _, t in ipairs(hum.Animator:GetPlayingAnimationTracks()) do
                            if t.Name:lower():find("reload") then t:AdjustSpeed(10) end
                        end
                    end
                end)
            end
        end
    end
end)

-- NO RELOAD
task.spawn(function()
    while task.wait(0.05) do
        if Config.NoReload then
            local tool = getWeaponTool()
            if tool then
                pcall(function()
                    for _, v in pairs(tool:GetDescendants()) do
                        if v:IsA("ValueBase") and (v.Name:lower():find("ammo") or v.Name:lower():find("clip") or v.Name:lower():find("mag")) then v.Value = 999 end
                    end
                    local hum = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
                    if hum and hum:FindFirstChildOfClass("Animator") then
                        for _, t in ipairs(hum.Animator:GetPlayingAnimationTracks()) do
                            if t.Name:lower():find("reload") then t:Stop(0) end
                        end
                    end
                end)
            end
        end
    end
end)

-- AUTO SHOOT
task.spawn(function()
    local lastShot = 0
    while task.wait(0.01) do
        if Config.AutoShoot and Camera then
            local now = tick()
            if now - lastShot >= Config.AutoShootSpeed then
                local targetFound = false
                pcall(function()
                    local vs = Camera.ViewportSize
                    if not vs then return end
                    local center = Vector2.new(vs.X/2 + Config.POV_X, vs.Y/2 + Config.POV_Y)
                    for _, m in ipairs(getCachedTargets()) do
                        local part = m:FindFirstChild(Config.AutoShootTarget == "Head" and "Head" or "HumanoidRootPart")
                        if part then
                            local sp, onScreen = Camera:WorldToViewportPoint(part.Position)
                            if onScreen and sp.Z > 0 then
                                local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
                                if d < Config.AimbotFOV and isVisible(m, part.Position) then targetFound = true break end
                            end
                        end
                    end
                end)
                if targetFound then
                    local tool = getWeaponTool()
                    if tool and tool.Enabled then pcall(function() tool:Activate() end) end
                    lastShot = now
                end
            end
        end
    end
end)

-- INTRO
local DURATION = 9.83
local introDone = false
local introConn
local startTime = os.clock()
local introGui, intro

local function showSuccessNotif()
    if not guiParent then return end
    pcall(function()
        local nGui = Instance.new("ScreenGui")
        nGui.Name = "SR4X_SuccessNotif"; nGui.ResetOnSpawn = false
        nGui.Enabled = true; nGui.DisplayOrder = BASE_DO + 4; nGui.Parent = guiParent
        local nFrame = Instance.new("Frame")
        nFrame.Size = UDim2.fromOffset(280, 50); nFrame.AnchorPoint = Vector2.new(0.5, 0)
        nFrame.Position = UDim2.new(0.5, 0, 0, -60)
        nFrame.BackgroundColor3 = Color3.fromRGB(20, 80, 40); nFrame.BackgroundTransparency = 0.1
        nFrame.BorderSizePixel = 0; nFrame.ZIndex = 10000; nFrame.Parent = nGui
        Instance.new("UICorner", nFrame).CornerRadius = UDim.new(0, 12)
        local ns = Instance.new("UIStroke"); ns.Color = Color3.fromRGB(0, 255, 100); ns.Thickness = 1.5; ns.Parent = nFrame
        local nl = Instance.new("TextLabel")
        nl.Size = UDim2.new(1, 0, 1, 0); nl.BackgroundTransparency = 1
        nl.Text = "LOADING SUCCESS"; nl.Font = Enum.Font.GothamBold
        nl.TextSize = 16; nl.TextColor3 = Color3.fromRGB(255, 255, 255)
        nl.ZIndex = 10001; nl.Parent = nFrame
        Tween:Create(nFrame, TweenInfo.new(0.5, Enum.EasingStyle.Back), {Position = UDim2.new(0.5, 0, 0, 20)}):Play()
        task.delay(2.5, function()
            Tween:Create(nFrame, TweenInfo.new(0.4), {Position = UDim2.new(0.5, 0, 0, -60), BackgroundTransparency = 1}):Play()
            task.wait(0.5); pcall(function() nGui:Destroy() end)
        end)
    end)
end

local function endIntro()
    if introDone then return end
    introDone = true
    if introConn then pcall(function() introConn:Disconnect() end) end
    if introGui and introGui.Parent then
        pcall(function()
            for _, obj in ipairs(introGui:GetDescendants()) do
                if obj:IsA("TextLabel") then Tween:Create(obj, TweenInfo.new(0.4), {TextTransparency = 1}):Play()
                elseif obj:IsA("Frame") then Tween:Create(obj, TweenInfo.new(0.4), {BackgroundTransparency = 1}):Play() end
            end
        end)
        task.delay(0.5, function()
            if introGui and introGui.Parent then pcall(function() introGui:Destroy() end) end
            showSuccessNotif()
        end)
    else showSuccessNotif() end
end
task.delay(DURATION, endIntro)

if guiParent then
    pcall(function()
        introGui = Instance.new("ScreenGui")
        introGui.Name = "SR4X_Loading"; introGui.ResetOnSpawn = false
        introGui.IgnoreGuiInset = true; introGui.Enabled = true
        introGui.DisplayOrder = BASE_DO + 3; introGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
        introGui.Parent = guiParent
        intro = Instance.new("Frame")
        intro.Size = UDim2.fromScale(1, 1); intro.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        intro.BorderSizePixel = 0; intro.Active = true; intro.ZIndex = 100; intro.Parent = introGui
        local particles = {}
        for i = 1, 60 do
            local p = Instance.new("Frame")
            p.Size = UDim2.fromOffset(math.random(2, 5), math.random(2, 5))
            p.Position = UDim2.fromScale(math.random(), math.random())
            p.BackgroundColor3 = Color3.fromHSV(math.random(), 1, 1)
            p.BorderSizePixel = 0; p.ZIndex = 101; p.Parent = intro
            Instance.new("UICorner", p).CornerRadius = UDim.new(1, 0)
            table.insert(particles, {frame = p, sX = (math.random() - 0.5) * 0.05, sY = (math.random() - 0.5) * 0.05, hue = math.random()})
        end
        local tN = Instance.new("TextLabel")
        tN.Size = UDim2.new(1, 0, 0, 80); tN.AnchorPoint = Vector2.new(0.5, 0.5)
        tN.Position = UDim2.fromScale(0.5, 0.4); tN.BackgroundTransparency = 1
        tN.Text = "SR4X TEAM"; tN.Font = Enum.Font.SourceSansBold
        tN.TextSize = 60; tN.TextColor3 = Color3.fromRGB(255, 255, 255)
        tN.ZIndex = 102; tN.Parent = intro
        local sT = Instance.new("TextLabel")
        sT.Size = UDim2.new(1, 0, 0, 30); sT.AnchorPoint = Vector2.new(0.5, 0.5)
        sT.Position = UDim2.fromScale(0.5, 0.55); sT.BackgroundTransparency = 1
        sT.Text = "Menyiapkan data..."; sT.TextColor3 = Color3.fromRGB(200, 200, 200)
        sT.Font = Enum.Font.SourceSans; sT.TextSize = 18; sT.ZIndex = 102; sT.Parent = intro
        local bB = Instance.new("Frame")
        bB.Size = UDim2.new(0.7, 0, 0, 10); bB.AnchorPoint = Vector2.new(0.5, 0.5)
        bB.Position = UDim2.fromScale(0.5, 0.62); bB.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        bB.BorderSizePixel = 0; bB.ZIndex = 103; bB.Parent = intro
        Instance.new("UICorner", bB).CornerRadius = UDim.new(1, 0)
        local bF = Instance.new("Frame")
        bF.Size = UDim2.new(0, 0, 1, 0)
        bF.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        bF.BorderSizePixel = 0; bF.ZIndex = 104; bF.Parent = bB
        Instance.new("UICorner", bF).CornerRadius = UDim.new(1, 0)
        local pL = Instance.new("TextLabel")
        pL.Size = UDim2.new(1, 0, 0, 20); pL.Position = UDim2.new(0, 0, 1, 5)
        pL.BackgroundTransparency = 1; pL.Text = "0%"
        pL.TextColor3 = Color3.fromRGB(200, 200, 200); pL.Font = Enum.Font.SourceSansBold
        pL.TextSize = 14; pL.ZIndex = 104; pL.Parent = bB
        local ft = Instance.new("TextLabel")
        ft.Size = UDim2.new(1, 0, 0, 20); ft.Position = UDim2.new(0, 0, 1, -30)
        ft.BackgroundTransparency = 1; ft.Text = "Dibuat oleh NanzzzProject | 2026"
        ft.TextColor3 = Color3.fromRGB(120, 120, 120); ft.Font = Enum.Font.Code
        ft.TextSize = 11; ft.ZIndex = 105; ft.Parent = intro
        local msgs = {"Menyiapkan data...", "Memuat script SR4X...", "Menginjeksi module...", "Menghubungkan ke server...", "Menyelesaikan setup...", "Selesai!"}
        intro.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                endIntro()
            end
        end)
        introConn = RunService.RenderStepped:Connect(function(dt)
            pcall(function()
                local t = os.clock()
                local pct = math.clamp((t - startTime) / DURATION, 0, 1)
                for _, p in ipairs(particles) do
                    local pos = p.frame.Position
                    local nX = pos.X.Scale + p.sX * dt
                    local nY = pos.Y.Scale + p.sY * dt
                    if nX < 0 then nX = 1 elseif nX > 1 then nX = 0 end
                    if nY < 0 then nY = 1 elseif nY > 1 then nY = 0 end
                    p.frame.Position = UDim2.fromScale(nX, nY)
                    p.hue = (p.hue + dt * 0.5) % 1
                    p.frame.BackgroundColor3 = Color3.fromHSV(p.hue, 1, 1)
                end
                bF.Size = UDim2.new(pct, 0, 1, 0)
                bF.BackgroundColor3 = Color3.fromHSV((t * 0.3) % 1, 0.8, 1)
                tN.TextColor3 = Color3.fromHSV((t * 0.3) % 1, 0.8, 1)
                pL.Text = string.format("%d%%", math.floor(pct * 100))
                local mI = math.clamp(math.floor(pct * #msgs) + 1, 1, #msgs)
                sT.Text = msgs[mI]
                if pct >= 1 then endIntro() end
            end)
        end)
    end)
else
    warn("[SR4X] No guiParent — intro skipped")
    introDone = true
end

end)  -- end pcall main creation

if not ok_create then
    warn("[SR4X] MAIN GUI CREATION FAILED: " .. tostring(err_create))
else
    print("[SR4X] STEP 14: everything OK")
end

print("[SR4X] v25 — SR4X TEAM by NanzzzProject. Loaded.")
print("[SR4X] If GUI not visible, check console for last STEP printed.")