-- ============================================================
-- CLEAN HUB v5.2 – KEYBINDS PARA TODOS LOS BOTONES Y FUNCIONES
-- (Versión compacta vertical, colores rosado/morado)
-- ============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer

local LOGO_ID = "rbxassetid://74152855887666"
task.spawn(function() pcall(function() ContentProvider:PreloadAsync({LOGO_ID}) end) end)

local _isfile = isfile or (syn and syn.isfile) or (getgenv and getgenv().isfile) or function() return false end
local _readfile = readfile or (syn and syn.readfile) or (getgenv and getgenv().readfile) or function() return nil end
local _writefile = writefile or (syn and syn.writefile) or (getgenv and getgenv().writefile) or function() end
local getconnections = getconnections or get_signal_cons or getconnects or (syn and syn.get_signal_cons)

-- ============================================================
-- STATE
-- ============================================================
local State = {
    normalSpeed = 60, carrySpeed = 30, laggerSpeed = 10.1, lagguerSpeed = 5,
    speedToggled = false, laggerEnabled = false, lagguerSpeedEnabled = false,
    infJumpEnabled = false, infJumpMode = "manual",
    antiRagdollEnabled = false,
    guiVisible = true, uiLocked = false,
    autoLeftEnabled = false, autoRightEnabled = false,
    autoLeftPhase = 1, autoRightPhase = 1,
    medusaLastUsed = 0, medusaDebounce = false, medusaCounterEnabled = false,
    batAimbotToggled = false,
    hittingCooldown = false,
    batCounterEnabled = false, batCounterDebounce = false,
    dropEnabled = false, _tpInProgress = false,
    lastMoveDir = Vector3.new(0, 0, 0),
    unwalkEnabled = false,
    batV2Toggled = false,
    batV2HittingCooldown = false,
}

-- ============================================================
-- AUTO TP DOWN
-- ============================================================
local autoTpDownEnabled = false
local autoTpDownYTarget = -8.80
local autoTpDownThreshold = 6
local autoTpDownJumpBoost = 75
local autoTpDownFallMultiplier = 3.5
local lastAutoTpTime = 0
local AUTO_TP_COOLDOWN = 0.2

-- ============================================================
-- KEYBINDS (con valores por defecto)
-- ============================================================
local Keys = {
    speed = Enum.KeyCode.Q,
    lagguerSpeed = Enum.KeyCode.Z,
    lagger = Enum.KeyCode.X,
    autoLeft = Enum.KeyCode.L,
    autoRight = Enum.KeyCode.R,
    aimbot = Enum.KeyCode.G,
    batV2 = Enum.KeyCode.V,
    batCounter = Enum.KeyCode.B,
    medusaCounter = Enum.KeyCode.M,
    drop = Enum.KeyCode.H,
    tpDown = Enum.KeyCode.T,
    autoSteal = Enum.KeyCode.K,
    autoTpDown = Enum.KeyCode.J,
    cleanTime = Enum.KeyCode.N,
    infJump = Enum.KeyCode.I,
    antiRagdoll = Enum.KeyCode.U,
    lockUI = Enum.KeyCode.P,
    guiHide = Enum.KeyCode.LeftControl,
}

-- ============================================================
-- AUTO STEAL
-- ============================================================
local AnimalsData = require(ReplicatedStorage:WaitForChild("Datas"):WaitForChild("Animals"))

local AutoStealConfig = {
    Enabled = false,
    Radius = 64,
    StealDuration = 1.3,
}

local allAnimalsCache = {}
local PromptMemoryCache = {}
local InternalStealCache = {}
local LastTargetUID = nil
local LastPlayerPosition = nil
local PlayerVelocity = Vector3.zero

local IsStealing = false
local StealProgress = 0
local CurrentStealTarget = nil
local StealStartTime = 0
local progressConnection = nil

local progressFill = nil
local progressPct = nil
local progressRadLbl = nil

-- ================================
-- Funciones auxiliares
-- ================================
local function getHRP()
    local char = LP.Character
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("UpperTorso")
end

local function isMyBase(plotName)
    local plots = workspace:FindFirstChild("Plots")
    if not plots then return false end
    local plot = plots:FindFirstChild(plotName)
    if not plot then return false end
    local sign = plot:FindFirstChild("PlotSign")
    if sign then
        local yourBase = sign:FindFirstChild("YourBase")
        if yourBase and yourBase:IsA("BillboardGui") then
            return yourBase.Enabled == true
        end
    end
    return false
end

local function scanSinglePlot(plot)
    if not plot or not plot:IsA("Model") then return end
    if isMyBase(plot.Name) then return end

    local podiums = plot:FindFirstChild("AnimalPodiums")
    if not podiums then return end

    for _, podium in ipairs(podiums:GetChildren()) do
        if podium:IsA("Model") and podium:FindFirstChild("Base") then
            local animalName = "Unknown"
            local spawn = podium.Base:FindFirstChild("Spawn")
            if spawn then
                for _, child in ipairs(spawn:GetChildren()) do
                    if child:IsA("Model") and child.Name ~= "PromptAttachment" then
                        animalName = child.Name
                        local animalInfo = AnimalsData[animalName]
                        if animalInfo and animalInfo.DisplayName then
                            animalName = animalInfo.DisplayName
                        end
                        break
                    end
                end
            end

            table.insert(allAnimalsCache, {
                name = animalName,
                plot = plot.Name,
                slot = podium.Name,
                worldPosition = podium:GetPivot().Position,
                uid = plot.Name .. "_" .. podium.Name,
            })
        end
    end
end

local function initializeScanner()
    task.wait(2)
    local plots = workspace:FindFirstChild("Plots")
    if not plots then
        workspace.ChildAdded:Wait(function(c) return c.Name == "Plots" end, 10)
        plots = workspace.Plots
    end
    if not plots then return end

    for _, plot in ipairs(plots:GetChildren()) do
        if plot:IsA("Model") then
            scanSinglePlot(plot)
        end
    end

    plots.ChildAdded:Connect(function(plot)
        if plot:IsA("Model") then
            task.wait(0.5)
            scanSinglePlot(plot)
        end
    end)

    task.spawn(function()
        while task.wait(5) do
            allAnimalsCache = {}
            for _, plot in ipairs(plots:GetChildren()) do
                if plot:IsA("Model") then
                    scanSinglePlot(plot)
                end
            end
        end
    end)
end

local function findProximityPromptForAnimal(animalData)
    if not animalData then return nil end

    local cachedPrompt = PromptMemoryCache[animalData.uid]
    if cachedPrompt and cachedPrompt.Parent then
        return cachedPrompt
    end

    local plots = workspace:FindFirstChild("Plots")
    if not plots then return nil end
    local plot = plots:FindFirstChild(animalData.plot)
    if not plot then return nil end
    local podiums = plot:FindFirstChild("AnimalPodiums")
    if not podiums then return nil end
    local podium = podiums:FindFirstChild(animalData.slot)
    if not podium then return nil end
    local base = podium:FindFirstChild("Base")
    if not base then return nil end
    local spawn = base:FindFirstChild("Spawn")
    if not spawn then return nil end
    local attach = spawn:FindFirstChild("PromptAttachment")
    if not attach then return nil end

    for _, p in ipairs(attach:GetChildren()) do
        if p:IsA("ProximityPrompt") then
            PromptMemoryCache[animalData.uid] = p
            return p
        end
    end
    return nil
end

local function updatePlayerVelocity()
    local hrp = getHRP()
    if not hrp then return end
    local currentPos = hrp.Position
    if LastPlayerPosition then
        PlayerVelocity = (currentPos - LastPlayerPosition) / task.wait()
    end
    LastPlayerPosition = currentPos
end

local function shouldSteal(animalData)
    if not animalData or not animalData.worldPosition then return false end
    local hrp = getHRP()
    if not hrp then return false end
    local currentDistance = (hrp.Position - animalData.worldPosition).Magnitude
    return currentDistance <= AutoStealConfig.Radius
end

local function buildStealCallbacks(prompt)
    if InternalStealCache[prompt] then return end

    local data = {
        holdCallbacks = {},
        triggerCallbacks = {},
        ready = true,
    }

    local ok1, conns1 = pcall(getconnections, prompt.PromptButtonHoldBegan)
    if ok1 and type(conns1) == "table" then
        for _, conn in ipairs(conns1) do
            if type(conn.Function) == "function" then
                table.insert(data.holdCallbacks, conn.Function)
            end
        end
    end

    local ok2, conns2 = pcall(getconnections, prompt.Triggered)
    if ok2 and type(conns2) == "table" then
        for _, conn in ipairs(conns2) do
            if type(conn.Function) == "function" then
                table.insert(data.triggerCallbacks, conn.Function)
            end
        end
    end

    if (#data.holdCallbacks > 0) or (#data.triggerCallbacks > 0) then
        InternalStealCache[prompt] = data
    end
end

-- ============================================================
-- PROGRESO SUAVE Y CONSTANTE
-- ============================================================
local function updateStealUI(progress)
    if progressFill and progressPct then
        progressFill.Size = UDim2.new(progress, 0, 1, 0)
        progressPct.Text = math.floor(progress * 100) .. "%"
    end
end

local function startSmoothProgress(duration, animalData)
    if progressConnection then progressConnection:Disconnect() end
    local startTime = tick()
    progressConnection = RunService.Heartbeat:Connect(function()
        if not IsStealing or CurrentStealTarget ~= animalData then
            if not IsStealing then
                updateStealUI(0)
            end
            return
        end
        local elapsed = tick() - startTime
        local p = math.min(1, elapsed / duration)
        StealProgress = p
        updateStealUI(p)
        if p >= 1 then
            if progressConnection then progressConnection:Disconnect(); progressConnection = nil end
        end
    end)
end

local function resetStealUI()
    updateStealUI(0)
end

local function executeInternalStealAsync(prompt, animalData, duration)
    duration = duration or AutoStealConfig.StealDuration
    local data = InternalStealCache[prompt]
    if not data or not data.ready then return false end

    data.ready = false
    IsStealing = true
    StealProgress = 0
    CurrentStealTarget = animalData
    StealStartTime = tick()

    startSmoothProgress(duration, animalData)

    task.spawn(function()
        if #data.holdCallbacks > 0 then
            for _, fn in ipairs(data.holdCallbacks) do
                task.spawn(fn)
            end
        end

        local startTime = tick()
        while tick() - startTime < duration and IsStealing do
            task.wait()
        end

        StealProgress = 1
        updateStealUI(1)

        if #data.triggerCallbacks > 0 then
            for _, fn in ipairs(data.triggerCallbacks) do
                task.spawn(fn)
            end
        end

        task.wait(0.1)
        data.ready = true
        task.wait(0.3)
        IsStealing = false
        StealProgress = 0
        CurrentStealTarget = nil
        resetStealUI()
        if progressConnection then progressConnection:Disconnect(); progressConnection = nil end
    end)

    return true
end

local function attemptSteal(prompt, animalData, duration)
    if not prompt or not prompt.Parent then return false end
    buildStealCallbacks(prompt)
    if not InternalStealCache[prompt] then return false end
    return executeInternalStealAsync(prompt, animalData, duration)
end

local function getNearestAnimal()
    local hrp = getHRP()
    if not hrp then return nil end

    local nearest = nil
    local minDist = math.huge

    for _, animalData in ipairs(allAnimalsCache) do
        if not isMyBase(animalData.plot) then
            local dist = (hrp.Position - animalData.worldPosition).Magnitude
            if dist < minDist then
                minDist = dist
                nearest = animalData
            end
        end
    end
    return nearest
end

local stealConnection = nil
local velocityConnection = nil

local function startAutoStealLoop()
    if stealConnection then stealConnection:Disconnect() end
    if velocityConnection then velocityConnection:Disconnect() end

    velocityConnection = RunService.Heartbeat:Connect(updatePlayerVelocity)

    stealConnection = RunService.Heartbeat:Connect(function()
        if not AutoStealConfig.Enabled then return end
        if IsStealing then return end

        local targetAnimal = getNearestAnimal()
        if not targetAnimal then return end

        if not shouldSteal(targetAnimal) then return end

        if LastTargetUID ~= targetAnimal.uid then
            LastTargetUID = targetAnimal.uid
        end

        local prompt = PromptMemoryCache[targetAnimal.uid]
        if not prompt or not prompt.Parent then
            prompt = findProximityPromptForAnimal(targetAnimal)
        end

        if prompt then
            attemptSteal(prompt, targetAnimal)
        end
    end)
end

local function stopAutoStealLoop()
    if stealConnection then stealConnection:Disconnect(); stealConnection = nil end
    if velocityConnection then velocityConnection:Disconnect(); velocityConnection = nil end
    IsStealing = false
    StealProgress = 0
    CurrentStealTarget = nil
    if progressConnection then progressConnection:Disconnect(); progressConnection = nil end
    resetStealUI()
end

-- ============================================================
-- PRESETS, CONFIG, POSICIONES
-- ============================================================
local Presets = {}
local PRESET_FILE = "CleanHubPresets.json"
local LAST_PRESET_FILE = "CleanHubLastPreset.json"
local CONFIG_FILE = "CleanHubConfig.json"
local POSITIONS_FILE = "CleanHubPositions.json"
local BATV2_POS_FILE = "CleanHubBatV2Pos.json"

local function buildPresetSnapshot() return {} end
local function savePresetsFile() end
local function loadPresetsFile() end
local function saveLastPresetName(name) end
local function loadLastPresetName() return nil end
local function rebuildPresetList() end

-- Contenedores
local buttonContainer = nil
local batV2Container = nil

local MOVE_KEYS = { [Enum.KeyCode.W] = true, [Enum.KeyCode.A] = true, [Enum.KeyCode.S] = true, [Enum.KeyCode.D] = true,
    [Enum.KeyCode.Up] = true, [Enum.KeyCode.Left] = true, [Enum.KeyCode.Down] = true, [Enum.KeyCode.Right] = true }

local POS = {
    L1 = Vector3.new(-476.48, -6.28, 92.73), L2 = Vector3.new(-483.12, -4.95, 94.80),
    R1 = Vector3.new(-476.16, -6.52, 25.62), R2 = Vector3.new(-483.04, -5.09, 23.14),
}

Conns = { autoSteal = nil, antiRag = nil, autoLeft = nil, autoRight = nil, aimbot = nil, batV2Aimbot = nil, anchor = {}, progress = nil, batCounter = nil, unwalk = nil, autoTpDown = nil, dropConnection = nil, holdJump = nil }

local h, hrp
local setAutoLeft, setAutoRight, setInfJump, setAntiRag
local setMedusaCounter, setUnwalkToggle, setAimbot
local setLagger, setDropBrainrot, setInstaGrab, setAutoTpDown
local setupMedusaCounter, stopMedusaCounter, startAntiRagdoll, stopAntiRagdoll
local runDropBrainrot, stopDropBrainrot, doTpDown
local startBatAimbot, stopBatAimbot, startBatCounter, stopBatCounter, setBatCounter
local startAutoTpDown, stopAutoTpDown
local stackBtnRefs = {}; local keybindBtnRefs = {}
local normalBox, carryBox, laggerBox, lagguerBox, stealRadBox, thresholdBox
local jumpModeContainer, manuelBtn, holdBtn
local setStunTimerToggle, setLockUIToggle, setAutoStealToggle, setBatV2Toggle, setInfJumpToggle, setAntiRagdollToggle, setMedusaCounterToggle, setBatCounterToggle, setAutoTpDownToggle

-- ============================================================
-- COLORES ROSA / MORADO (tema claro-oscuro mezclado)
-- ============================================================
local WHITE_PURE = Color3.fromRGB(255, 255, 255)
local BLACK_PURE = Color3.fromRGB(20, 8, 40)          -- casi negro, se usará poco
local PINK_ACCENT = Color3.fromRGB(255, 105, 180)     -- rosa fuerte
local PURPLE_ACCENT = Color3.fromRGB(180, 130, 255)   -- morado claro
local DARK_PINK_BG = Color3.fromRGB(42, 16, 48)       -- fondo principal rosado oscuro
local ROW_BG = Color3.fromRGB(255, 120, 160)          -- rosa vivo para las filas
local TOGGLE_BAR_BG = Color3.fromRGB(33, 10, 38)      -- barra flotante
local MOBILE_BTN_BG = Color3.fromRGB(123, 45, 142)    -- morado para botones móviles
local MOBILE_BTN_ACTIVE = PINK_ACCENT                  -- rosa al activarse
local LIGHT_PINK = Color3.fromRGB(255, 200, 220)
local DARK_PURPLE = Color3.fromRGB(30, 15, 55)

-- Nuevos colores rosados para inputs y botones de keybind (fondo completo)
local PINK_INPUT_BG = Color3.fromRGB(255, 140, 170)    -- rosa claro para cuadros de números y keybinds

local C = {
    winBg = DARK_PINK_BG, winBorder = PURPLE_ACCENT,
    topBg = DARK_PINK_BG, topTitle = LIGHT_PINK,
    topSub = LIGHT_PINK, topBtn = PINK_ACCENT,
    topBtnHov = WHITE_PURE, topDivider = PINK_ACCENT,
    tabBarBg = DARK_PINK_BG, tabBarDiv = PURPLE_ACCENT,
    tabIdle = LIGHT_PINK, tabActive = WHITE_PURE,
    tabActiveBg = DARK_PINK_BG, tabUnderline = PINK_ACCENT,
    sectionTxt = LIGHT_PINK, sectionDiv = PINK_ACCENT,
    rowBg = ROW_BG, rowBorder = PURPLE_ACCENT,
    rowLabel = LIGHT_PINK, rowSub = LIGHT_PINK,
    rowValue = WHITE_PURE, rowHov = DARK_PURPLE,
    inputBg = PINK_INPUT_BG, inputBorder = PURPLE_ACCENT,
    inputFocus = PINK_ACCENT, inputTxt = WHITE_PURE,
    pillOff = DARK_PURPLE, pillOn = PINK_ACCENT,
    dotOff = DARK_PURPLE, dotOn = WHITE_PURE,
    pillBorder = PURPLE_ACCENT,
    modeBtnBg = DARK_PINK_BG, modeBtnBrd = PURPLE_ACCENT,
    modeBtnTxt = LIGHT_PINK, modeBtnActBg = PINK_ACCENT,
    modeBtnActTx = BLACK_PURE,
    chipBg = PINK_INPUT_BG, chipBorder = PURPLE_ACCENT,
    chipTxt = WHITE_PURE,  -- texto blanco para contraste
    btnBg = DARK_PINK_BG, btnBorder = PURPLE_ACCENT,
    btnTxt = LIGHT_PINK, btnHov = PINK_ACCENT,
    stackBg = WHITE_PURE, stackBrd = BLACK_PURE,
    stackTxt = BLACK_PURE, stackActBg = PINK_ACCENT,
    stackActTxt = BLACK_PURE, stackDot = WHITE_PURE,
    stackDotOn = PINK_ACCENT,
    infoBg = DARK_PINK_BG, infoBrd = PURPLE_ACCENT,
    infoTxt = LIGHT_PINK, infoVal = WHITE_PURE,
    infoFill = PINK_ACCENT, accent = PINK_ACCENT,
    accentDim = PURPLE_ACCENT, presetBg = DARK_PINK_BG,
    presetBrd = PURPLE_ACCENT, presetLoad = PINK_ACCENT,
    presetDel = PINK_ACCENT, delBrd = PURPLE_ACCENT,
    lockOn = PINK_ACCENT, divider = PURPLE_ACCENT,
    toggleBarBg = TOGGLE_BAR_BG, toggleBarBorder = PURPLE_ACCENT,
    toggleBarText = LIGHT_PINK,
}

-- ============================================================
-- LIMPIEZA Y GUI PRINCIPAL (VERSIÓN COMPACTA VERTICAL)
-- ============================================================
for _, name in pairs({ "VyseSlottedGUI", "VyseAsireGUI", "VyseAsireHubV4", "VyseAsireHubV5", "VyseAsireHubV5_1", "AsireHubV5_1", "AsireHubV5_2", "OpiumGGV5_2", "SaskHubV5_2", "CleanHubV5_2" }) do
    pcall(function() local o = game:GetService("CoreGui"):FindFirstChild(name); if o then o:Destroy() end end)
    pcall(function() local o = LP:WaitForChild("PlayerGui"):FindFirstChild(name); if o then o:Destroy() end end)
end

local gui = Instance.new("ScreenGui")
gui.Name = "CleanHubV5_2"
gui.ResetOnSpawn = false
gui.DisplayOrder = 10
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = LP:WaitForChild("PlayerGui")

local uiScaleObj = Instance.new("UIScale", gui)
uiScaleObj.Scale = 1.0

-- ============================================================
-- FUNCIONES UI
-- ============================================================
local function mkCorner(p, r) local c = Instance.new("UICorner", p); c.CornerRadius = UDim.new(0, r or 6); return c end
local function mkStroke(p, col, th) local s = Instance.new("UIStroke", p); s.Color = col; s.Thickness = th or 1; s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; return s end

local function saveContainerPosition()
    if not buttonContainer then return end
    local pos = buttonContainer.Position
    local data = { XScale = pos.X.Scale, XOffset = pos.X.Offset, YScale = pos.Y.Scale, YOffset = pos.Y.Offset }
    local encoded = HttpService:JSONEncode(data)
    pcall(function() _writefile(POSITIONS_FILE, encoded) end)
end

local function loadContainerPosition()
    if not _isfile(POSITIONS_FILE) then return false end
    local content = _readfile(POSITIONS_FILE)
    if not content then return false end
    local ok, data = pcall(HttpService.JSONDecode, HttpService, content)
    if not ok then return false end
    buttonContainer.Position = UDim2.new(data.XScale, data.XOffset, data.YScale, data.YOffset)
    return true
end

local function saveBatV2Position()
    if not batV2Container then return end
    local pos = batV2Container.Position
    local data = { XScale = pos.X.Scale, XOffset = pos.X.Offset, YScale = pos.Y.Scale, YOffset = pos.Y.Offset }
    local encoded = HttpService:JSONEncode(data)
    pcall(function() _writefile(BATV2_POS_FILE, encoded) end)
end

local function loadBatV2Position()
    if not _isfile(BATV2_POS_FILE) then return false end
    local content = _readfile(BATV2_POS_FILE)
    if not content then return false end
    local ok, data = pcall(HttpService.JSONDecode, HttpService, content)
    if not ok then return false end
    batV2Container.Position = UDim2.new(data.XScale, data.XOffset, data.YScale, data.YOffset)
    return true
end

-- Reposiciona el BAT V2 a la izquierda del botón Aimbot
local function repositionBatV2ToLeftOfAimbot()
    task.wait(0.05)
    local aimbotFrame = buttonContainer and buttonContainer:FindFirstChild("Btn_aimbot")
    if aimbotFrame then
        local aimbotAbsPos = aimbotFrame.AbsolutePosition
        local aimbotSize = aimbotFrame.AbsoluteSize
        local batSize = batV2Container.AbsoluteSize
        local gap = 5
        local newX = aimbotAbsPos.X - batSize.X - gap
        local newY = aimbotAbsPos.Y + (aimbotSize.Y / 2) - (batSize.Y / 2)
        newX = math.max(5, newX)
        newY = math.max(5, newY)
        batV2Container.Position = UDim2.new(0, newX, 0, newY)
        saveBatV2Position()
    end
end

local function makeDraggable(frame, onPositionChanged)
    local dragging = false
    local dragStart = nil
    local startPos = nil
    frame.InputBegan:Connect(function(input)
        if State.uiLocked then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end)
    frame.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            if onPositionChanged then onPositionChanged() end
        end
    end)
    local function stopDrag()
        if dragging then
            dragging = false
            if onPositionChanged then onPositionChanged() end
        end
    end
    frame.InputEnded:Connect(stopDrag)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then stopDrag() end
    end)
end

-- ============================================================
-- BARRA FLOTANTE TOGGLE
-- ============================================================
local toggleBar = Instance.new("Frame", gui)
toggleBar.Name = "CleanHubToggle"
toggleBar.Size = UDim2.new(0, 90, 0, 28)
toggleBar.Position = UDim2.new(0, 10, 0, 50)
toggleBar.BackgroundColor3 = C.toggleBarBg
toggleBar.BackgroundTransparency = 0
toggleBar.BorderSizePixel = 0
toggleBar.Active = true
toggleBar.ZIndex = 20
mkCorner(toggleBar, 14)
mkStroke(toggleBar, C.toggleBarBorder, 1)

local label = Instance.new("TextLabel", toggleBar)
label.Size = UDim2.new(1, 0, 1, 0)
label.BackgroundTransparency = 1
label.Text = "Clean"
label.TextColor3 = C.toggleBarText
label.Font = Enum.Font.GothamBold
label.TextSize = 11
label.ZIndex = 21

local clickButton = Instance.new("TextButton", toggleBar)
clickButton.Size = UDim2.new(1, 0, 1, 0)
clickButton.BackgroundTransparency = 1
clickButton.Text = ""
clickButton.ZIndex = 22
clickButton.AutoButtonColor = false

makeDraggable(toggleBar, nil)

-- ============================================================
-- VENTANA PRINCIPAL - SOLO COLUMNA VERTICAL
-- ============================================================
local WIN_W = 320
local WIN_H = 500
local TITLE_H = 28

local mainOuter = Instance.new("Frame", gui)
mainOuter.Name = "MainOuter"
mainOuter.Size = UDim2.new(0, WIN_W, 0, WIN_H)
mainOuter.Position = UDim2.new(0, 10, 0, 85)
mainOuter.BackgroundTransparency = 0
mainOuter.BackgroundColor3 = C.winBg
mainOuter.BorderSizePixel = 0
mainOuter.ClipsDescendants = true
mkCorner(mainOuter, 8)
mkStroke(mainOuter, C.winBorder, 1)

do
    local dragging, dragStart, startPos, dragInput = false, nil, nil, nil
    mainOuter.InputBegan:Connect(function(input)
        if State.uiLocked then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = mainOuter.Position
            dragInput = input
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if input == dragInput and dragging and not State.uiLocked then
            local delta = input.Position - dragStart
            mainOuter.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input == dragInput then dragging = false; dragInput = nil end
    end)
end

local bgOverlay = Instance.new("Frame", mainOuter)
bgOverlay.Size = UDim2.new(1, 0, 1, 0)
bgOverlay.BackgroundColor3 = C.winBg
bgOverlay.BackgroundTransparency = 0
bgOverlay.BorderSizePixel = 0
bgOverlay.ZIndex = 1
mkCorner(bgOverlay, 8)

-- ========== BARRA SUPERIOR ==========
local titleBar = Instance.new("Frame", mainOuter)
titleBar.Size = UDim2.new(1, 0, 0, TITLE_H)
titleBar.Position = UDim2.new(0, 0, 0, 0)
titleBar.BackgroundColor3 = C.topBg
titleBar.BackgroundTransparency = 1
titleBar.BorderSizePixel = 0
titleBar.ZIndex = 5

local titleLbl = Instance.new("TextLabel", titleBar)
titleLbl.Size = UDim2.new(0, 140, 1, 0)
titleLbl.Position = UDim2.new(0, 8, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text = "Clean Hub"
titleLbl.TextColor3 = C.topTitle
titleLbl.Font = Enum.Font.GothamBlack
titleLbl.TextSize = 11
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.TextStrokeTransparency = 0
titleLbl.ZIndex = 6

local closeBtn = Instance.new("TextButton", titleBar)
closeBtn.Size = UDim2.new(0, 18, 0, 18)
closeBtn.Position = UDim2.new(1, -24, 0.5, -9)
closeBtn.BackgroundColor3 = C.modeBtnBg
closeBtn.BorderSizePixel = 0
closeBtn.Text = "×"
closeBtn.TextColor3 = C.topBtn
closeBtn.Font = Enum.Font.GothamBlack
closeBtn.TextSize = 12
closeBtn.ZIndex = 7
mkCorner(closeBtn, 4)
mkStroke(closeBtn, C.chipBorder, 1)
closeBtn.MouseEnter:Connect(function() TweenService:Create(closeBtn, TweenInfo.new(0.1), { TextColor3 = Color3.fromRGB(255, 80, 80) }):Play() end)
closeBtn.MouseLeave:Connect(function() TweenService:Create(closeBtn, TweenInfo.new(0.1), { TextColor3 = C.topBtn }):Play() end)
closeBtn.MouseButton1Click:Connect(function()
    State.guiVisible = false
    local tween = TweenService:Create(mainOuter, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 })
    tween:Play()
    tween.Completed:Connect(function() mainOuter.Visible = false end)
end)

local titleDiv = Instance.new("Frame", mainOuter)
titleDiv.Size = UDim2.new(1, 0, 0, 1)
titleDiv.Position = UDim2.new(0, 0, 0, TITLE_H)
titleDiv.BackgroundColor3 = C.topDivider
titleDiv.BorderSizePixel = 0
titleDiv.ZIndex = 5

-- ============================================================
-- SCROLL Y COLUMNA ÚNICA VERTICAL
-- ============================================================
local CONTENT_Y = TITLE_H + 1
local contentScroller = Instance.new("ScrollingFrame", mainOuter)
contentScroller.Size = UDim2.new(1, 0, 1, -CONTENT_Y)
contentScroller.Position = UDim2.new(0, 0, 0, CONTENT_Y)
contentScroller.BackgroundTransparency = 1
contentScroller.BorderSizePixel = 0
contentScroller.ScrollBarThickness = 3
contentScroller.ScrollBarImageColor3 = C.accent
contentScroller.ScrollBarImageTransparency = 0.3
contentScroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
contentScroller.CanvasSize = UDim2.new(0, 0, 0, 0)

local mainColumn = Instance.new("Frame", contentScroller)
mainColumn.Size = UDim2.new(1, -12, 0, 0)
mainColumn.Position = UDim2.new(0, 6, 0, 0)
mainColumn.BackgroundTransparency = 1
mainColumn.AutomaticSize = Enum.AutomaticSize.Y

local columnLayout = Instance.new("UIListLayout", mainColumn)
columnLayout.SortOrder = Enum.SortOrder.LayoutOrder
columnLayout.Padding = UDim.new(0, 0)

local function addToMainColumn(element)
    element.Parent = mainColumn
    element.LayoutOrder = #mainColumn:GetChildren() + 1
end

local function makeGap(px)
    local f = Instance.new("Frame")
    f.Size = UDim2.new(1, 0, 0, px or 4)
    f.BackgroundTransparency = 1
    f.BorderSizePixel = 0
    addToMainColumn(f)
end

local function makeSectionHeader(label)
    local wrap = Instance.new("Frame")
    wrap.Size = UDim2.new(1, 0, 0, 20)
    wrap.BackgroundTransparency = 1
    wrap.BorderSizePixel = 0
    local lbl = Instance.new("TextLabel", wrap)
    lbl.Size = UDim2.new(1, -12, 1, 0)
    lbl.Position = UDim2.new(0, 6, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label and label:upper() or ""
    lbl.TextColor3 = C.sectionTxt
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 8
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    addToMainColumn(wrap)
end

local function makeInputRow(label, default, onChange)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 34)
    row.BackgroundColor3 = C.rowBg
    row.BackgroundTransparency = 1
    row.BorderSizePixel = 0
    local div = Instance.new("Frame", row)
    div.Size = UDim2.new(1, -12, 0, 1)
    div.Position = UDim2.new(0, 6, 1, -1)
    div.BackgroundColor3 = C.rowBorder
    div.BorderSizePixel = 0
    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1, -65, 1, 0)
    lbl.Position = UDim2.new(0, 6, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = C.rowLabel
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    local boxWrap = Instance.new("Frame", row)
    boxWrap.Size = UDim2.new(0, 50, 0, 22)
    boxWrap.Position = UDim2.new(1, -56, 0.5, -11)
    boxWrap.BackgroundColor3 = C.inputBg
    boxWrap.BorderSizePixel = 0
    mkCorner(boxWrap, 4)
    local bs = mkStroke(boxWrap, C.inputBorder, 1)
    local box = Instance.new("TextBox", boxWrap)
    box.Size = UDim2.new(1, -4, 1, 0)
    box.Position = UDim2.new(0, 2, 0, 0)
    box.BackgroundTransparency = 1
    box.Text = tostring(default)
    box.TextColor3 = C.inputTxt
    box.Font = Enum.Font.GothamBold
    box.TextSize = 10
    box.ClearTextOnFocus = false
    box.ZIndex = 8
    box.TextXAlignment = Enum.TextXAlignment.Center
    box.Focused:Connect(function() TweenService:Create(bs, TweenInfo.new(0.15), { Color = C.inputFocus }):Play() end)
    box.FocusLost:Connect(function()
        TweenService:Create(bs, TweenInfo.new(0.15), { Color = C.inputBorder }):Play()
        if onChange then
            local n = tonumber(box.Text)
            if n then onChange(n) else box.Text = tostring(default) end
        end
    end)
    addToMainColumn(row)
    return box, row
end

local function makeToggleRow(label, defaultOn, onToggle)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 34)
    row.BackgroundTransparency = 1
    row.BorderSizePixel = 0
    local div = Instance.new("Frame", row)
    div.Size = UDim2.new(1, -12, 0, 1)
    div.Position = UDim2.new(0, 6, 1, -1)
    div.BackgroundColor3 = C.rowBorder
    div.BorderSizePixel = 0
    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1, -55, 1, 0)
    lbl.Position = UDim2.new(0, 6, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = C.rowLabel
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    local pillBg = Instance.new("Frame", row)
    pillBg.Size = UDim2.new(0, 32, 0, 16)
    pillBg.Position = UDim2.new(1, -38, 0.5, -8)
    pillBg.BackgroundColor3 = defaultOn and C.pillOn or C.pillOff
    pillBg.BorderSizePixel = 0
    pillBg.ZIndex = 7
    mkCorner(pillBg, 8)
    mkStroke(pillBg, C.pillBorder, 1)
    local dot = Instance.new("Frame", pillBg)
    dot.Size = UDim2.new(0, 10, 0, 10)
    dot.Position = defaultOn and UDim2.new(1, -13, 0.5, -5) or UDim2.new(0, 3, 0.5, -5)
    dot.BackgroundColor3 = defaultOn and C.dotOn or C.dotOff
    dot.BorderSizePixel = 0
    dot.ZIndex = 8
    mkCorner(dot, 5)
    local isOn = defaultOn or false
    local function setV(on)
        isOn = on
        TweenService:Create(pillBg, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { BackgroundColor3 = on and C.pillOn or C.pillOff }):Play()
        TweenService:Create(dot, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Position = on and UDim2.new(1, -13, 0.5, -5) or UDim2.new(0, 3, 0.5, -5), BackgroundColor3 = on and C.dotOn or C.dotOff }):Play()
    end
    local function toggle()
        isOn = not isOn
        setV(isOn)
        if onToggle then pcall(onToggle, isOn) end
    end
    local clk = Instance.new("TextButton", row)
    clk.Size = UDim2.new(1, -55, 1, 0)
    clk.BackgroundTransparency = 1
    clk.Text = ""
    clk.ZIndex = 5
    clk.BorderSizePixel = 0
    clk.MouseButton1Click:Connect(toggle)
    local pClk = Instance.new("TextButton", pillBg)
    pClk.Size = UDim2.new(1, 0, 1, 0)
    pClk.BackgroundTransparency = 1
    pClk.Text = ""
    pClk.ZIndex = 9
    pClk.BorderSizePixel = 0
    pClk.MouseButton1Click:Connect(toggle)
    addToMainColumn(row)
    return setV
end

local function getKeyDisplayName(kc)
    local n = kc.Name
    local gpNames = {
        ButtonA = "A", ButtonB = "B", ButtonX = "X", ButtonY = "Y",
        ButtonL1 = "LB", ButtonL2 = "LT", ButtonL3 = "LS",
        ButtonR1 = "RB", ButtonR2 = "RT", ButtonR3 = "RS",
        ButtonSelect = "SEL", ButtonStart = "STA",
        DPadUp = "D↑", DPadDown = "D↓", DPadLeft = "D←", DPadRight = "D→",
        Thumbstick1 = "LS", Thumbstick2 = "RS",
    }
    if gpNames[n] then return gpNames[n] end
    return n:sub(1, 5)
end

local function makeKeybindRow(label, currentKey, onChanged, keyName)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, 34)
    row.BackgroundTransparency = 1
    row.BorderSizePixel = 0
    local div = Instance.new("Frame", row)
    div.Size = UDim2.new(1, -12, 0, 1)
    div.Position = UDim2.new(0, 6, 1, -1)
    div.BackgroundColor3 = C.rowBorder
    div.BorderSizePixel = 0
    local lbl = Instance.new("TextLabel", row)
    lbl.Size = UDim2.new(1, -65, 1, 0)
    lbl.Position = UDim2.new(0, 6, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = C.rowLabel
    lbl.Font = Enum.Font.GothamBold
    lbl.TextSize = 10
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    local kbtn = Instance.new("TextButton", row)
    kbtn.Size = UDim2.new(0, 44, 0, 22)
    kbtn.Position = UDim2.new(1, -50, 0.5, -11)
    kbtn.BackgroundColor3 = C.chipBg
    kbtn.BorderSizePixel = 0
    kbtn.Text = getKeyDisplayName(currentKey)
    kbtn.TextColor3 = C.chipTxt
    kbtn.Font = Enum.Font.GothamBold
    kbtn.TextSize = 9
    kbtn.ZIndex = 8
    mkCorner(kbtn, 4)
    local ks = mkStroke(kbtn, C.chipBorder, 1)
    local listening = false
    local lconnKeyboard, lconnGamepad
    local function stopL(key)
        listening = false
        if lconnKeyboard then lconnKeyboard:Disconnect() end
        if lconnGamepad then lconnGamepad:Disconnect() end
        TweenService:Create(ks, TweenInfo.new(0.12), { Color = C.chipBorder }):Play()
        kbtn.TextColor3 = C.chipTxt
        if key then
            kbtn.Text = getKeyDisplayName(key)
            if onChanged then onChanged(key) end
            task.spawn(function() if saveConfig then pcall(saveConfig) end end)
        end
    end
    kbtn.MouseButton1Click:Connect(function()
        if listening then stopL(nil); return end
        listening = true
        kbtn.Text = "···"
        kbtn.TextColor3 = C.inputTxt
        TweenService:Create(ks, TweenInfo.new(0.12), { Color = C.inputFocus }):Play()
        lconnKeyboard = UIS.InputBegan:Connect(function(inp)
            if not listening then return end
            if inp.UserInputType ~= Enum.UserInputType.Keyboard then return end
            if inp.KeyCode == Enum.KeyCode.Escape then stopL(nil); return end
            stopL(inp.KeyCode)
        end)
        lconnGamepad = UIS.InputBegan:Connect(function(inp)
            if not listening then return end
            if inp.UserInputType ~= Enum.UserInputType.Gamepad1 and inp.UserInputType ~= Enum.UserInputType.Gamepad2 and inp.UserInputType ~= Enum.UserInputType.Gamepad3 and inp.UserInputType ~= Enum.UserInputType.Gamepad4 then return end
            local kc = inp.KeyCode
            if kc == Enum.KeyCode.Unknown then return end
            stopL(kc)
        end)
    end)
    if keyName then keybindBtnRefs[keyName] = kbtn end
    addToMainColumn(row)
    return kbtn
end

-- ============================================================
-- EXCLUSIÓN MUTUA AUTO LEFT/RIGHT
-- ============================================================
local function disableAutoLeft()
    if State.autoLeftEnabled then
        State.autoLeftEnabled = false
        if stackBtnRefs.autoLeft then stackBtnRefs.autoLeft.setOn(false) end
        if setAutoLeft then setAutoLeft(false) end
        stopAutoLeft()
    end
end

local function disableAutoRight()
    if State.autoRightEnabled then
        State.autoRightEnabled = false
        if stackBtnRefs.autoRight then stackBtnRefs.autoRight.setOn(false) end
        if setAutoRight then setAutoRight(false) end
        stopAutoRight()
    end
end

-- ============================================================
-- CONSTRUCCIÓN DE UI (UNA COLUMNA)
-- ============================================================
makeGap(2)
makeSectionHeader("Speed")
makeGap(2)
normalBox = makeInputRow("Normal", State.normalSpeed, function(n)
    if n > 0 and n <= 500 then State.normalSpeed = n end
    if not State.speedToggled and not State.laggerEnabled and not State.lagguerSpeedEnabled and h then h.WalkSpeed = State.normalSpeed end
end)
carryBox = makeInputRow("Carry", State.carrySpeed, function(n)
    if n > 0 and n <= 500 then State.carrySpeed = n end
    if State.speedToggled and h then h.WalkSpeed = State.carrySpeed end
end)
laggerBox = makeInputRow("Lag SPD 2", State.laggerSpeed, function(n)
    if n > 0 and n <= 500 then State.laggerSpeed = n end
    if State.laggerEnabled and h then h.WalkSpeed = State.laggerSpeed end
end)
lagguerBox = makeInputRow("Lag SPD 1", State.lagguerSpeed, function(n)
    if n >= 0 and n <= 500 then State.lagguerSpeed = n end
    if State.lagguerSpeedEnabled and h then h.WalkSpeed = State.lagguerSpeed end
end)

makeGap(4)
makeSectionHeader("Keybinds")
makeGap(2)
makeKeybindRow("Carry Speed", Keys.speed, function(k) Keys.speed = k; saveConfig() end, "speed")
makeKeybindRow("Lag SPD 1", Keys.lagguerSpeed, function(k) Keys.lagguerSpeed = k; saveConfig() end, "lagguerSpeed")
makeKeybindRow("Lag SPD 2", Keys.lagger, function(k) Keys.lagger = k; saveConfig() end, "lagger")
makeKeybindRow("Auto Left", Keys.autoLeft, function(k) Keys.autoLeft = k; saveConfig() end, "autoLeft")
makeKeybindRow("Auto Right", Keys.autoRight, function(k) Keys.autoRight = k; saveConfig() end, "autoRight")
makeKeybindRow("Aimbot (Bat)", Keys.aimbot, function(k) Keys.aimbot = k; saveConfig() end, "aimbot")
makeKeybindRow("Bat V2", Keys.batV2, function(k) Keys.batV2 = k; saveConfig() end, "batV2")
makeKeybindRow("Bat Counter", Keys.batCounter, function(k) Keys.batCounter = k; saveConfig() end, "batCounter")
makeKeybindRow("Medusa", Keys.medusaCounter, function(k) Keys.medusaCounter = k; saveConfig() end, "medusaCounter")
makeKeybindRow("Drop Brainrot", Keys.drop, function(k) Keys.drop = k; saveConfig() end, "drop")
makeKeybindRow("TP Down", Keys.tpDown, function(k) Keys.tpDown = k; saveConfig() end, "tpDown")
makeKeybindRow("Auto Steal", Keys.autoSteal, function(k) Keys.autoSteal = k; saveConfig() end, "autoSteal")
makeKeybindRow("Auto TP Down", Keys.autoTpDown, function(k) Keys.autoTpDown = k; saveConfig() end, "autoTpDown")
makeKeybindRow("Clean Time", Keys.cleanTime, function(k) Keys.cleanTime = k; saveConfig() end, "cleanTime")
makeKeybindRow("Inf Jump", Keys.infJump, function(k) Keys.infJump = k; saveConfig() end, "infJump")
makeKeybindRow("Anti Ragdoll", Keys.antiRagdoll, function(k) Keys.antiRagdoll = k; saveConfig() end, "antiRagdoll")
makeKeybindRow("Lock UI", Keys.lockUI, function(k) Keys.lockUI = k; saveConfig() end, "lockUI")

makeGap(4)
makeSectionHeader("Movement")
makeGap(2)
setAutoLeft = makeToggleRow("Auto Left", false, function(on)
    if on then disableAutoRight() end
    State.autoLeftEnabled = on
    if on then startAutoLeft() else stopAutoLeft() end
    if stackBtnRefs.autoLeft then stackBtnRefs.autoLeft.setOn(on) end
end)
setAutoRight = makeToggleRow("Auto Right", false, function(on)
    if on then disableAutoLeft() end
    State.autoRightEnabled = on
    if on then startAutoRight() else stopAutoRight() end
    if stackBtnRefs.autoRight then stackBtnRefs.autoRight.setOn(on) end
end)

makeGap(4)
makeSectionHeader("Combat")
makeGap(2)
setInfJumpToggle = makeToggleRow("Inf Jump", false, function(on) 
    State.infJumpEnabled = on 
    if not on then 
        local char = LP.Character
        if char then
            local root = char:FindFirstChild("HumanoidRootPart")
            if root and root.Velocity.Y > 55 then
                root.Velocity = Vector3.new(root.Velocity.X, 0, root.Velocity.Z)
            end
        end
    end
end)

makeGap(2)
jumpModeContainer = Instance.new("Frame")
jumpModeContainer.Size = UDim2.new(1, 0, 0, 34)
jumpModeContainer.BackgroundTransparency = 1
jumpModeContainer.BorderSizePixel = 0

manuelBtn = Instance.new("TextButton", jumpModeContainer)
manuelBtn.Size = UDim2.new(0.5, -3, 1, 0)
manuelBtn.Position = UDim2.new(0, 0, 0, 0)
manuelBtn.BackgroundColor3 = C.accent
manuelBtn.BorderSizePixel = 0
manuelBtn.Text = "Manual"
manuelBtn.TextColor3 = BLACK_PURE
manuelBtn.Font = Enum.Font.GothamBold
manuelBtn.TextSize = 10
manuelBtn.AutoButtonColor = false
mkCorner(manuelBtn, 6)
mkStroke(manuelBtn, C.pillBorder, 1)

holdBtn = Instance.new("TextButton", jumpModeContainer)
holdBtn.Size = UDim2.new(0.5, -3, 1, 0)
holdBtn.Position = UDim2.new(0.5, 3, 0, 0)
holdBtn.BackgroundColor3 = C.pillOff
holdBtn.BorderSizePixel = 0
holdBtn.Text = "Hold"
holdBtn.TextColor3 = WHITE_PURE
holdBtn.Font = Enum.Font.GothamBold
holdBtn.TextSize = 10
holdBtn.AutoButtonColor = false
mkCorner(holdBtn, 6)
mkStroke(holdBtn, C.pillBorder, 1)

local function updateInfJumpModeUI()
    if State.infJumpMode == "manual" then
        manuelBtn.BackgroundColor3 = C.accent
        manuelBtn.TextColor3 = BLACK_PURE
        holdBtn.BackgroundColor3 = C.pillOff
        holdBtn.TextColor3 = WHITE_PURE
    else
        manuelBtn.BackgroundColor3 = C.pillOff
        manuelBtn.TextColor3 = WHITE_PURE
        holdBtn.BackgroundColor3 = C.accent
        holdBtn.TextColor3 = BLACK_PURE
    end
end

manuelBtn.MouseButton1Click:Connect(function()
    State.infJumpMode = "manual"
    updateInfJumpModeUI()
    saveConfig()
end)

holdBtn.MouseButton1Click:Connect(function()
    State.infJumpMode = "hold"
    updateInfJumpModeUI()
    saveConfig()
end)

addToMainColumn(jumpModeContainer)
updateInfJumpModeUI()

setAntiRagdollToggle = makeToggleRow("Anti Ragdoll", false, function(on)
    State.antiRagdollEnabled = on
    if on then startAntiRagdoll() else stopAntiRagdoll() end
end)

setMedusaCounterToggle = makeToggleRow("Medusa Counter", false, function(on)
    State.medusaCounterEnabled = on
    if on then setupMedusaCounter(LP.Character) else stopMedusaCounter() end
end)

setAutoTpDownToggle = makeToggleRow("Auto TP Down", false, function(on)
    autoTpDownEnabled = on
    if on then startAutoTpDown() else stopAutoTpDown() end
end)
thresholdBox = makeInputRow("TP Thres", autoTpDownThreshold, function(n)
    if n >= 4 and n <= 50 then autoTpDownThreshold = math.floor(n) end
end)

makeGap(4)
makeSectionHeader("Stealing")
makeGap(2)
setAutoStealToggle = makeToggleRow("Auto Steal", false, function(on)
    AutoStealConfig.Enabled = on
    if on then startAutoStealLoop() else stopAutoStealLoop() end
end)
stealRadBox = makeInputRow("Radius", AutoStealConfig.Radius, function(n)
    if n >= 5 and n <= 300 then
        AutoStealConfig.Radius = math.floor(n)
        PromptMemoryCache = {}
    end
end)
makeInputRow("Duration", AutoStealConfig.StealDuration, function(n)
    if n >= 0.2 and n <= 3 then AutoStealConfig.StealDuration = n end
end)

makeGap(4)
makeSectionHeader("Clean Time")
makeGap(2)
local stunTimerEnabled = true
local stunTimerGuiBB = nil
local stunTimerText = nil
local stunActive = false
local stunStartTime = 0
local stunDuration = 3.0
local stunConnection = nil
local stateChangedConnection = nil
local lastDisplayedSecond = nil

local function createStunTimerBillboard()
    if stunTimerGuiBB then return end
    local char = LP.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if not head then return end

    stunTimerGuiBB = Instance.new("BillboardGui")
    stunTimerGuiBB.Name = "CleanTimeBB"
    stunTimerGuiBB.Adornee = head
    stunTimerGuiBB.Size = UDim2.new(0, 120, 0, 36)
    stunTimerGuiBB.StudsOffset = Vector3.new(0, 5.5, 0)
    stunTimerGuiBB.AlwaysOnTop = true
    stunTimerGuiBB.ZIndexBehavior = Enum.ZIndexBehavior.Global
    stunTimerGuiBB.Parent = gui

    stunTimerText = Instance.new("TextLabel", stunTimerGuiBB)
    stunTimerText.Size = UDim2.new(1, 0, 1, 0)
    stunTimerText.BackgroundTransparency = 1
    stunTimerText.Text = ""
    stunTimerText.Font = Enum.Font.GothamBlack
    stunTimerText.TextSize = 24
    stunTimerText.TextStrokeTransparency = 0.5
    stunTimerText.TextStrokeColor3 = BLACK_PURE
    stunTimerText.TextXAlignment = Enum.TextXAlignment.Center
    stunTimerText.TextYAlignment = Enum.TextYAlignment.Center
end

local function updateStunDisplay()
    if not stunTimerText then return end

    if not stunActive then
        stunTimerText.Text = "Steal!!"
        stunTimerText.TextColor3 = Color3.fromRGB(0, 255, 100)
        stunTimerText.TextSize = 20
        stunTimerGuiBB.Enabled = stunTimerEnabled
        return
    end

    local elapsed = tick() - stunStartTime
    local remaining = math.max(0, stunDuration - elapsed)
    if remaining <= 0 then
        stunActive = false
        if stunConnection then stunConnection:Disconnect(); stunConnection = nil end
        stunTimerText.Text = "Steal!!"
        stunTimerText.TextColor3 = Color3.fromRGB(0, 255, 100)
        stunTimerText.TextSize = 20
        if stunTimerGuiBB then stunTimerGuiBB.Enabled = true end
        return
    end

    local second = math.ceil(remaining)
    if second ~= lastDisplayedSecond then
        lastDisplayedSecond = second
        stunTimerText.Text = tostring(second)
        stunTimerText.TextSize = 32
        if second == 3 then
            stunTimerText.TextColor3 = Color3.fromRGB(0, 255, 100)
        elseif second == 2 then
            stunTimerText.TextColor3 = Color3.fromRGB(255, 165, 0)
        elseif second == 1 then
            stunTimerText.TextColor3 = Color3.fromRGB(255, 50, 50)
        end
    end
    if stunTimerGuiBB then stunTimerGuiBB.Enabled = true end
end

local function onStunDetected()
    if not stunTimerEnabled then return end
    if stunActive then return end
    stunActive = true
    stunStartTime = tick()
    lastDisplayedSecond = nil
    createStunTimerBillboard()
    updateStunDisplay()
    if stunConnection then stunConnection:Disconnect() end
    stunConnection = RunService.Heartbeat:Connect(updateStunDisplay)

    if AutoStealConfig.Enabled and not IsStealing then
        local targetAnimal = getNearestAnimal()
        if targetAnimal and shouldSteal(targetAnimal) then
            local prompt = PromptMemoryCache[targetAnimal.uid]
            if not prompt or not prompt.Parent then
                prompt = findProximityPromptForAnimal(targetAnimal)
            end
            if prompt then
                attemptSteal(prompt, targetAnimal, stunDuration)
            end
        end
    end
end

local function setupStunDetection(char)
    if stateChangedConnection then stateChangedConnection:Disconnect() end
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    stateChangedConnection = hum.StateChanged:Connect(function(_, newState)
        if not stunTimerEnabled then return end
        local isStunned = (newState == Enum.HumanoidStateType.Physics or
                           newState == Enum.HumanoidStateType.Ragdoll or
                           newState == Enum.HumanoidStateType.FallingDown)
        if isStunned then
            onStunDetected()
        end
    end)
end

setStunTimerToggle = makeToggleRow("Clean Time", true, function(on)
    stunTimerEnabled = on
    if not on then
        if stunConnection then stunConnection:Disconnect(); stunConnection = nil end
        stunActive = false
        if stunTimerGuiBB then stunTimerGuiBB.Enabled = false end
        if stateChangedConnection then stateChangedConnection:Disconnect(); stateChangedConnection = nil end
    else
        createStunTimerBillboard()
        local char = LP.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                local st = hum:GetState()
                if st == Enum.HumanoidStateType.Physics or st == Enum.HumanoidStateType.Ragdoll then
                    onStunDetected()
                end
            end
            setupStunDetection(char)
        end
    end
end)

makeGap(4)
makeSectionHeader("Bat Aimbot")
makeGap(2)
setBatCounterToggle = makeToggleRow("Bat Counter", false, function(on)
    State.batCounterEnabled = on
    if on then startBatCounter() else stopBatCounter() end
end)

makeGap(4)
makeSectionHeader("Interface")
makeGap(2)

local resetWrap = Instance.new("Frame")
resetWrap.Size = UDim2.new(1, 0, 0, 34)
resetWrap.BackgroundTransparency = 1
resetWrap.BorderSizePixel = 0
local resetBtn = Instance.new("TextButton", resetWrap)
resetBtn.Size = UDim2.new(1, -12, 0, 24)
resetBtn.Position = UDim2.new(0, 6, 0, 5)
resetBtn.BackgroundColor3 = C.btnBg
resetBtn.BorderSizePixel = 0
resetBtn.Text = "↺ Reset Panel Pos"
resetBtn.TextColor3 = C.btnTxt
resetBtn.Font = Enum.Font.GothamBold
resetBtn.TextSize = 10
resetBtn.ZIndex = 5
mkCorner(resetBtn, 4)
mkStroke(resetBtn, C.btnBorder, 1)
resetBtn.MouseEnter:Connect(function() TweenService:Create(resetBtn, TweenInfo.new(0.1), { BackgroundColor3 = C.btnHov }):Play() end)
resetBtn.MouseLeave:Connect(function() TweenService:Create(resetBtn, TweenInfo.new(0.1), { BackgroundColor3 = C.btnBg }):Play() end)
resetBtn.MouseButton1Click:Connect(function()
    if buttonContainer then
        buttonContainer.Position = UDim2.new(1, -150, 0.5, -155)
        saveContainerPosition()
    end
    if batV2Container then
        repositionBatV2ToLeftOfAimbot()
    end
    resetBtn.Text = "✓ Reset!"
    task.delay(1.5, function() if resetBtn and resetBtn.Parent then resetBtn.Text = "↺ Reset Panel Pos" end end)
end)
addToMainColumn(resetWrap)

makeGap(2)
setLockUIToggle = makeToggleRow("Lock UI", false, function(on) State.uiLocked = on end)

local saveWrap = Instance.new("Frame")
saveWrap.Size = UDim2.new(1, 0, 0, 34)
saveWrap.BackgroundTransparency = 1
saveWrap.BorderSizePixel = 0
local saveCfgBtn = Instance.new("TextButton", saveWrap)
saveCfgBtn.Size = UDim2.new(1, -12, 0, 24)
saveCfgBtn.Position = UDim2.new(0, 6, 0, 5)
saveCfgBtn.BackgroundColor3 = C.btnBg
saveCfgBtn.BorderSizePixel = 0
saveCfgBtn.Text = "💾 Save"
saveCfgBtn.TextColor3 = C.btnTxt
saveCfgBtn.Font = Enum.Font.GothamBold
saveCfgBtn.TextSize = 10
saveCfgBtn.ZIndex = 9
mkCorner(saveCfgBtn, 4)
mkStroke(saveCfgBtn, C.btnBorder, 1)
saveCfgBtn.MouseEnter:Connect(function() TweenService:Create(saveCfgBtn, TweenInfo.new(0.1), { BackgroundColor3 = C.btnHov }):Play() end)
saveCfgBtn.MouseLeave:Connect(function() TweenService:Create(saveCfgBtn, TweenInfo.new(0.1), { BackgroundColor3 = C.btnBg }):Play() end)
saveCfgBtn.MouseButton1Click:Connect(function()
    saveContainerPosition()
    saveBatV2Position()
    saveConfig()
    saveCfgBtn.Text = "✓ Saved!"
    task.delay(1.5, function() if saveCfgBtn and saveCfgBtn.Parent then saveCfgBtn.Text = "💾 Save" end end)
end)
addToMainColumn(saveWrap)

makeGap(4)
local fw = Instance.new("Frame")
fw.Size = UDim2.new(1, 0, 0, 16)
fw.BackgroundTransparency = 1
fw.BorderSizePixel = 0
local fl = Instance.new("TextLabel", fw)
fl.Size = UDim2.new(1, 0, 1, 0)
fl.BackgroundTransparency = 1
fl.Text = "Clean Hub v5.2"
fl.TextColor3 = WHITE_PURE
fl.Font = Enum.Font.Gotham
fl.TextSize = 8
fl.TextXAlignment = Enum.TextXAlignment.Center
addToMainColumn(fw)

-- ============================================================
-- BARRA DE PROGRESO AUTO STEAL (posición ajustada)
-- ============================================================
local function createProgressBar()
    local pbFrame = Instance.new("Frame", gui)
    pbFrame.Name = "StealProgressBar"
    pbFrame.Size = UDim2.new(0, 200, 0, 40)
    pbFrame.Position = UDim2.new(0, 10, 1, -50)
    pbFrame.BackgroundColor3 = DARK_PINK_BG
    pbFrame.BorderSizePixel = 0
    pbFrame.Active = true
    pbFrame.ZIndex = 15
    mkCorner(pbFrame, 8)
    mkStroke(pbFrame, PURPLE_ACCENT, 1)

    progressPct = Instance.new("TextLabel", pbFrame)
    progressPct.Size = UDim2.new(0, 40, 0, 16)
    progressPct.Position = UDim2.new(0, 8, 0, 4)
    progressPct.BackgroundTransparency = 1
    progressPct.Text = "0%"
    progressPct.TextColor3 = WHITE_PURE
    progressPct.Font = Enum.Font.GothamBold
    progressPct.TextSize = 10
    progressPct.TextXAlignment = Enum.TextXAlignment.Left
    progressPct.ZIndex = 16

    progressRadLbl = Instance.new("TextLabel", pbFrame)
    progressRadLbl.Size = UDim2.new(0, 100, 0, 16)
    progressRadLbl.Position = UDim2.new(1, -108, 0, 4)
    progressRadLbl.BackgroundTransparency = 1
    progressRadLbl.Text = tostring(AutoStealConfig.Radius)
    progressRadLbl.TextColor3 = WHITE_PURE
    progressRadLbl.Font = Enum.Font.GothamBold
    progressRadLbl.TextSize = 10
    progressRadLbl.TextXAlignment = Enum.TextXAlignment.Right
    progressRadLbl.ZIndex = 16

    local pbBg = Instance.new("Frame", pbFrame)
    pbBg.Size = UDim2.new(1, -16, 0, 8)
    pbBg.Position = UDim2.new(0, 8, 0, 26)
    pbBg.BackgroundColor3 = DARK_PINK_BG
    pbBg.BorderSizePixel = 0
    mkCorner(pbBg, 4)
    mkStroke(pbBg, PURPLE_ACCENT, 1)

    progressFill = Instance.new("Frame", pbBg)
    progressFill.Size = UDim2.new(0, 0, 1, 0)
    progressFill.BackgroundColor3 = PINK_ACCENT
    progressFill.BorderSizePixel = 0
    mkCorner(progressFill, 4)

    makeDraggable(pbFrame, nil)
end

task.spawn(function()
    task.wait(0.1)
    createProgressBar()
    resetStealUI()
end)

task.spawn(function()
    while true do
        task.wait(0.5)
        pcall(function()
            if progressRadLbl and AutoStealConfig then
                progressRadLbl.Text = tostring(AutoStealConfig.Radius)
            end
        end)
    end
end)

-- ============================================================
-- TP DOWN
-- ============================================================
doTpDown = function()
    pcall(function()
        local char = LP.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not root or not hum then return end
        
        local hipHeight = hum.HipHeight or 2
        local rayParams = RaycastParams.new()
        rayParams.FilterDescendantsInstances = { char }
        rayParams.FilterType = Enum.RaycastFilterType.Exclude
        
        local rayOrigin = root.Position
        local rayDirection = Vector3.new(0, -500, 0)
        local rayResult = workspace:Raycast(rayOrigin, rayDirection, rayParams)
        
        if rayResult then
            local groundY = rayResult.Position.Y
            local newY = groundY + hipHeight + 0.1
            root.CFrame = CFrame.new(root.Position.X, newY, root.Position.Z)
            root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
        end
    end)
end

-- ============================================================
-- AUTO TP DOWN
-- ============================================================
startAutoTpDown = function()
    if Conns.autoTpDown then return end
    Conns.autoTpDown = RunService.Heartbeat:Connect(function()
        if not autoTpDownEnabled or State.dropEnabled then return end
        local char = LP.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not root or not hum then return end
        
        local now = tick()
        if now - lastAutoTpTime < AUTO_TP_COOLDOWN then return end
        
        local currentY = root.Position.Y
        local floorY = autoTpDownYTarget
        local heightFromGround = currentY - floorY
        
        local isOnGround = (hum.FloorMaterial ~= Enum.Material.Air) or (hum:GetState() == Enum.HumanoidStateType.Landed)
        if isOnGround and hum:GetState() ~= Enum.HumanoidStateType.Jumping then
            if UIS:IsKeyDown(Enum.KeyCode.Space) then
                local velY = root.Velocity.Y
                if velY > 0 and velY < autoTpDownJumpBoost then
                    root.Velocity = Vector3.new(root.Velocity.X, autoTpDownJumpBoost, root.Velocity.Z)
                end
            end
        end
        
        local velY = root.Velocity.Y
        if velY < 0 and currentY > floorY + 15 then
            root.Velocity = Vector3.new(root.Velocity.X, velY * autoTpDownFallMultiplier, root.Velocity.Z)
        end
        
        local isFallingFast = velY < -30
        local isHighUp = currentY > floorY + autoTpDownThreshold
        if isHighUp or (isFallingFast and heightFromGround >= autoTpDownThreshold) then
            local rayParams = RaycastParams.new()
            rayParams.FilterDescendantsInstances = { char }
            rayParams.FilterType = Enum.RaycastFilterType.Exclude
            local rayResult = workspace:Raycast(root.Position, Vector3.new(0, -500, 0), rayParams)
            
            local targetY = floorY
            if rayResult then
                targetY = rayResult.Position.Y + (hum.HipHeight or 2) + 0.1
            end
            
            root.CFrame = CFrame.new(root.Position.X, targetY, root.Position.Z)
            root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
            hum:ChangeState(Enum.HumanoidStateType.Landed)
            lastAutoTpTime = now
        end
    end)
end

stopAutoTpDown = function()
    if Conns.autoTpDown then
        Conns.autoTpDown:Disconnect()
        Conns.autoTpDown = nil
    end
end

-- ============================================================
-- VELOCIDAD ACTIVA
-- ============================================================
local function getActiveSpeed()
    if State.lagguerSpeedEnabled then return State.lagguerSpeed
    elseif State.laggerEnabled then return State.laggerSpeed
    elseif State.speedToggled then return State.carrySpeed
    else return State.normalSpeed end
end

-- ============================================================
-- CONTENEDOR MÓVIL PRINCIPAL (8 BOTONES) – Color morado, activo rosa
-- ============================================================
buttonContainer = Instance.new("Frame", gui)
buttonContainer.Name = "MobileButtonContainer"
buttonContainer.Size = UDim2.new(0, 140, 0, 310)
buttonContainer.BackgroundTransparency = 1
buttonContainer.Position = UDim2.new(1, -150, 0.5, -155)
buttonContainer.ZIndex = 15
buttonContainer.Active = true

local grid = Instance.new("UIGridLayout", buttonContainer)
grid.CellSize = UDim2.new(0, 58, 0, 58)
grid.CellPadding = UDim2.new(0, 10, 0, 10)
grid.StartCorner = Enum.StartCorner.TopLeft
grid.SortOrder = Enum.SortOrder.LayoutOrder

local buttonDefs = {
    { id = "drop",       label = "DROP\nBR"          },
    { id = "autoLeft",   label = "AUTO\nLEFT"        },
    { id = "aimbot",     label = "AIM\nBOT"          },
    { id = "autoRight",  label = "AUTO\nRIGHT"       },
    { id = "tpDown",     label = "TP\nDOWN"          },
    { id = "carrySpeed", label = "CARRY\nSPEED"      },
    { id = "lagguerSpeed", label = "LAG\nSPD 1"      },
    { id = "lagger",     label = "LAG\nSPD 2"        },
}

stackBtnRefs = {}

for idx, def in ipairs(buttonDefs) do
    local btnFrame = Instance.new("Frame", buttonContainer)
    btnFrame.Name = "Btn_" .. def.id
    btnFrame.Size = UDim2.new(0, 58, 0, 58)
    btnFrame.BackgroundColor3 = MOBILE_BTN_BG   -- morado
    btnFrame.BorderSizePixel = 0
    btnFrame.ZIndex = 16
    mkCorner(btnFrame, 14)
    local stroke = mkStroke(btnFrame, PURPLE_ACCENT, 1)
    stroke.Transparency = 0.8

    local lbl = Instance.new("TextLabel", btnFrame)
    lbl.Size = UDim2.new(1, -8, 1, -8)
    lbl.Position = UDim2.new(0, 4, 0, 2)
    lbl.BackgroundTransparency = 1
    lbl.Text = def.label
    lbl.TextColor3 = LIGHT_PINK
    lbl.Font = Enum.Font.GothamBlack
    lbl.TextSize = 11
    lbl.TextWrapped = true
    lbl.TextXAlignment = Enum.TextXAlignment.Center
    lbl.ZIndex = 17

    local isActive = false
    local function setActive(active)
        isActive = active
        local targetBg = active and MOBILE_BTN_ACTIVE or MOBILE_BTN_BG
        local targetTextColor = active and BLACK_PURE or LIGHT_PINK
        TweenService:Create(btnFrame, TweenInfo.new(0.15), { BackgroundColor3 = targetBg }):Play()
        TweenService:Create(lbl, TweenInfo.new(0.15), { TextColor3 = targetTextColor }):Play()
    end

    stackBtnRefs[def.id] = { setOn = setActive }

    btnFrame.MouseEnter:Connect(function()
        if not isActive then
            TweenService:Create(btnFrame, TweenInfo.new(0.1), { BackgroundColor3 = MOBILE_BTN_ACTIVE }):Play()
            TweenService:Create(lbl, TweenInfo.new(0.1), { TextColor3 = BLACK_PURE }):Play()
        end
    end)
    btnFrame.MouseLeave:Connect(function()
        local targetBg = isActive and MOBILE_BTN_ACTIVE or MOBILE_BTN_BG
        local targetTx = isActive and BLACK_PURE or LIGHT_PINK
        TweenService:Create(btnFrame, TweenInfo.new(0.1), { BackgroundColor3 = targetBg }):Play()
        TweenService:Create(lbl, TweenInfo.new(0.1), { TextColor3 = targetTx }):Play()
    end)

    local function onTap()
        if def.id == "drop" then
            if State.dropEnabled then
                stopDropBrainrot()
                setActive(false)
            else
                runDropBrainrot()
                setActive(true)
                task.delay(0.5, function()
                    if not State.dropEnabled then setActive(false) end
                end)
            end
        elseif def.id == "tpDown" then
            doTpDown()
            setActive(true)
            task.delay(0.2, function() setActive(false) end)
        elseif def.id == "aimbot" then
            State.batAimbotToggled = not State.batAimbotToggled
            setActive(State.batAimbotToggled)
            if State.batAimbotToggled then
                if State.autoLeftEnabled then
                    State.autoLeftEnabled = false
                    if stackBtnRefs.autoLeft then stackBtnRefs.autoLeft.setOn(false) end
                    stopAutoLeft()
                end
                if State.autoRightEnabled then
                    State.autoRightEnabled = false
                    if stackBtnRefs.autoRight then stackBtnRefs.autoRight.setOn(false) end
                    stopAutoRight()
                end
                pcall(startBatAimbot)
            else
                stopBatAimbot()
            end
            saveConfig()
        elseif def.id == "autoLeft" then
            local newState = not State.autoLeftEnabled
            if newState then
                if State.autoRightEnabled then
                    State.autoRightEnabled = false
                    if stackBtnRefs.autoRight then stackBtnRefs.autoRight.setOn(false) end
                    stopAutoRight()
                end
                if State.batAimbotToggled then
                    State.batAimbotToggled = false
                    if stackBtnRefs.aimbot then stackBtnRefs.aimbot.setOn(false) end
                    stopBatAimbot()
                end
            end
            State.autoLeftEnabled = newState
            setActive(newState)
            if newState then startAutoLeft() else stopAutoLeft() end
            saveConfig()
        elseif def.id == "autoRight" then
            local newState = not State.autoRightEnabled
            if newState then
                if State.autoLeftEnabled then
                    State.autoLeftEnabled = false
                    if stackBtnRefs.autoLeft then stackBtnRefs.autoLeft.setOn(false) end
                    stopAutoLeft()
                end
                if State.batAimbotToggled then
                    State.batAimbotToggled = false
                    if stackBtnRefs.aimbot then stackBtnRefs.aimbot.setOn(false) end
                    stopBatAimbot()
                end
            end
            State.autoRightEnabled = newState
            setActive(newState)
            if newState then startAutoRight() else stopAutoRight() end
            saveConfig()
        elseif def.id == "carrySpeed" then
            local newState = not State.speedToggled
            if newState then
                if State.laggerEnabled then
                    State.laggerEnabled = false
                    if stackBtnRefs.lagger then stackBtnRefs.lagger.setOn(false) end
                end
                if State.lagguerSpeedEnabled then
                    State.lagguerSpeedEnabled = false
                    if stackBtnRefs.lagguerSpeed then stackBtnRefs.lagguerSpeed.setOn(false) end
                end
            end
            State.speedToggled = newState
            setActive(newState)
            if h then h.WalkSpeed = getActiveSpeed() end
            saveConfig()
        elseif def.id == "lagger" then
            local newState = not State.laggerEnabled
            if newState then
                if State.speedToggled then
                    State.speedToggled = false
                    if stackBtnRefs.carrySpeed then stackBtnRefs.carrySpeed.setOn(false) end
                end
                if State.lagguerSpeedEnabled then
                    State.lagguerSpeedEnabled = false
                    if stackBtnRefs.lagguerSpeed then stackBtnRefs.lagguerSpeed.setOn(false) end
                end
            end
            State.laggerEnabled = newState
            setActive(newState)
            if h then h.WalkSpeed = getActiveSpeed() end
            saveConfig()
        elseif def.id == "lagguerSpeed" then
            local newState = not State.lagguerSpeedEnabled
            if newState then
                if State.speedToggled then
                    State.speedToggled = false
                    if stackBtnRefs.carrySpeed then stackBtnRefs.carrySpeed.setOn(false) end
                end
                if State.laggerEnabled then
                    State.laggerEnabled = false
                    if stackBtnRefs.lagger then stackBtnRefs.lagger.setOn(false) end
                end
                if State.autoLeftEnabled then
                    State.autoLeftEnabled = false
                    if stackBtnRefs.autoLeft then stackBtnRefs.autoLeft.setOn(false) end
                    stopAutoLeft()
                end
                if State.autoRightEnabled then
                    State.autoRightEnabled = false
                    if stackBtnRefs.autoRight then stackBtnRefs.autoRight.setOn(false) end
                    stopAutoRight()
                end
                if State.batAimbotToggled then
                    State.batAimbotToggled = false
                    if stackBtnRefs.aimbot then stackBtnRefs.aimbot.setOn(false) end
                    stopBatAimbot()
                end
            end
            State.lagguerSpeedEnabled = newState
            setActive(newState)
            if h then h.WalkSpeed = getActiveSpeed() end
            saveConfig()
        end
    end

    local clickArea = Instance.new("TextButton", btnFrame)
    clickArea.Size = UDim2.new(1, 0, 1, 0)
    clickArea.BackgroundTransparency = 1
    clickArea.Text = ""
    clickArea.ZIndex = 18
    clickArea.AutoButtonColor = false
    clickArea.MouseButton1Click:Connect(onTap)
end

makeDraggable(buttonContainer, saveContainerPosition)
loadContainerPosition()

-- ============================================================
-- BOTÓN BAT V2 INDEPENDIENTE (también morado/rosa)
-- ============================================================
batV2Container = Instance.new("Frame", gui)
batV2Container.Name = "BatV2Container"
batV2Container.Size = UDim2.new(0, 58, 0, 58)
batV2Container.BackgroundTransparency = 1
batV2Container.Position = UDim2.new(0, 10, 0.5, -29)
batV2Container.ZIndex = 15
batV2Container.Active = true

local batV2Frame = Instance.new("Frame", batV2Container)
batV2Frame.Size = UDim2.new(1, 0, 1, 0)
batV2Frame.BackgroundColor3 = MOBILE_BTN_BG
batV2Frame.BorderSizePixel = 0
batV2Frame.ZIndex = 16
mkCorner(batV2Frame, 14)
local strokeV2 = mkStroke(batV2Frame, PURPLE_ACCENT, 1)
strokeV2.Transparency = 0.8

local batV2Lbl = Instance.new("TextLabel", batV2Frame)
batV2Lbl.Size = UDim2.new(1, -8, 1, -8)
batV2Lbl.Position = UDim2.new(0, 4, 0, 2)
batV2Lbl.BackgroundTransparency = 1
batV2Lbl.Text = "BAT\nV2"
batV2Lbl.TextColor3 = LIGHT_PINK
batV2Lbl.Font = Enum.Font.GothamBlack
batV2Lbl.TextSize = 11
batV2Lbl.TextWrapped = true
batV2Lbl.TextXAlignment = Enum.TextXAlignment.Center
batV2Lbl.ZIndex = 17

local batV2Active = false
local function setBatV2Active(active)
    batV2Active = active
    local targetBg = active and MOBILE_BTN_ACTIVE or MOBILE_BTN_BG
    local targetTextColor = active and BLACK_PURE or LIGHT_PINK
    TweenService:Create(batV2Frame, TweenInfo.new(0.15), { BackgroundColor3 = targetBg }):Play()
    TweenService:Create(batV2Lbl, TweenInfo.new(0.15), { TextColor3 = targetTextColor }):Play()
end

batV2Frame.MouseEnter:Connect(function()
    if not batV2Active then
        TweenService:Create(batV2Frame, TweenInfo.new(0.1), { BackgroundColor3 = MOBILE_BTN_ACTIVE }):Play()
        TweenService:Create(batV2Lbl, TweenInfo.new(0.1), { TextColor3 = BLACK_PURE }):Play()
    end
end)
batV2Frame.MouseLeave:Connect(function()
    local targetBg = batV2Active and MOBILE_BTN_ACTIVE or MOBILE_BTN_BG
    local targetTx = batV2Active and BLACK_PURE or LIGHT_PINK
    TweenService:Create(batV2Frame, TweenInfo.new(0.1), { BackgroundColor3 = targetBg }):Play()
    TweenService:Create(batV2Lbl, TweenInfo.new(0.1), { TextColor3 = targetTx }):Play()
end)

local batV2Click = Instance.new("TextButton", batV2Frame)
batV2Click.Size = UDim2.new(1, 0, 1, 0)
batV2Click.BackgroundTransparency = 1
batV2Click.Text = ""
batV2Click.ZIndex = 18
batV2Click.AutoButtonColor = false
batV2Click.MouseButton1Click:Connect(function()
    State.batV2Toggled = not State.batV2Toggled
    setBatV2Active(State.batV2Toggled)
    if State.batV2Toggled then
        if State.batAimbotToggled then
            State.batAimbotToggled = false
            if stackBtnRefs.aimbot then stackBtnRefs.aimbot.setOn(false) end
            stopBatAimbot()
        end
        startBatV2Aimbot()
    else
        stopBatV2Aimbot()
    end
    saveConfig()
end)

makeDraggable(batV2Container, function()
    saveBatV2Position()
end)

-- Carga inicial de posición o la coloca a la izquierda del aimbot
local positionLoaded = loadBatV2Position()
if not positionLoaded then
    task.spawn(function()
        task.wait(0.2)
        repositionBatV2ToLeftOfAimbot()
    end)
else
    -- Aún así, asegurar que queda a la izquierda del aimbot (en caso de que la posición guardada sea antigua)
    task.spawn(function()
        task.wait(0.3)
        repositionBatV2ToLeftOfAimbot()
    end)
end

setBatV2Active(State.batV2Toggled)

task.wait(0.2)
if stackBtnRefs.carrySpeed then stackBtnRefs.carrySpeed.setOn(State.speedToggled) end
if stackBtnRefs.lagger then stackBtnRefs.lagger.setOn(State.laggerEnabled) end
if stackBtnRefs.lagguerSpeed then stackBtnRefs.lagguerSpeed.setOn(State.lagguerSpeedEnabled) end
if stackBtnRefs.autoLeft then stackBtnRefs.autoLeft.setOn(State.autoLeftEnabled) end
if stackBtnRefs.autoRight then stackBtnRefs.autoRight.setOn(State.autoRightEnabled) end
if stackBtnRefs.aimbot then stackBtnRefs.aimbot.setOn(State.batAimbotToggled) end

-- ============================================================
-- DROP BRAINROT (sin cambios, solo funcionalidad)
-- ============================================================
local DROP_ASCEND_DURATION = 0.2
local DROP_ASCEND_SPEED = 150

runDropBrainrot = function()
    if State.dropEnabled then return end
    local char = LP.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end
    if Conns.dropConnection then Conns.dropConnection:Disconnect() end
    State.dropEnabled = true
    if stackBtnRefs.drop then stackBtnRefs.drop.setOn(true) end
    local t0 = tick()
    local conn = nil
    conn = RunService.Heartbeat:Connect(function()
        local r = char and char:FindFirstChild("HumanoidRootPart")
        if not r then
            conn:Disconnect()
            Conns.dropConnection = nil
            if State.dropEnabled then State.dropEnabled = false; if stackBtnRefs.drop then stackBtnRefs.drop.setOn(false) end end
            return
        end
        if tick() - t0 >= DROP_ASCEND_DURATION then
            conn:Disconnect()
            Conns.dropConnection = nil
            local rp = RaycastParams.new()
            rp.FilterDescendantsInstances = { char }
            rp.FilterType = Enum.RaycastFilterType.Exclude
            local rr = workspace:Raycast(r.Position, Vector3.new(0, -2000, 0), rp)
            if rr then
                local hum2 = char:FindFirstChildOfClass("Humanoid")
                local off = (hum2 and hum2.HipHeight or 2) + (r.Size.Y / 2)
                r.CFrame = CFrame.new(r.Position.X, rr.Position.Y + off, r.Position.Z)
                r.AssemblyLinearVelocity = Vector3.zero
            end
            State.dropEnabled = false
            if stackBtnRefs.drop then stackBtnRefs.drop.setOn(false) end
            return
        end
        r.AssemblyLinearVelocity = Vector3.new(r.AssemblyLinearVelocity.X, DROP_ASCEND_SPEED, r.AssemblyLinearVelocity.Z)
    end)
    Conns.dropConnection = conn
end

stopDropBrainrot = function()
    if Conns.dropConnection then
        Conns.dropConnection:Disconnect()
        Conns.dropConnection = nil
    end
    if State.dropEnabled then
        State.dropEnabled = false
        if stackBtnRefs.drop then stackBtnRefs.drop.setOn(false) end
    end
    local c = LP.Character
    if c then
        local root = c:FindFirstChild("HumanoidRootPart")
        if root and root.AssemblyLinearVelocity.Y > 0 then
            root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
        end
    end
end

-- ============================================================
-- BAT AIMBOT (sin cambios funcionales)
-- ============================================================
local BAT_SLAP_LIST = {
    "Bat", "Slap", "Iron Slap", "Gold Slap", "Diamond Slap", "Emerald Slap",
    "Ruby Slap", "Dark Matter Slap", "Flame Slap", "Nuclear Slap",
    "Galaxy Slap", "Glitched Slap"
}
local HIT_DIST = 8
local SWING_CD = 0.35
local AIMBOT_SPEED = 60

local _hittingCooldown = false
local _aimbotConn = nil
local _prevAutoRotate = nil

local function getBat()
    local char = LP.Character
    if not char then return nil end
    for _, name in ipairs(BAT_SLAP_LIST) do
        local t = char:FindFirstChild(name)
        if t and t:IsA("Tool") then return t end
    end
    local bp = LP:FindFirstChildOfClass("Backpack")
    if bp then
        for _, name in ipairs(BAT_SLAP_LIST) do
            local t = bp:FindFirstChild(name)
            if t and t:IsA("Tool") then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then pcall(function() hum:EquipTool(t) end) end
                return t
            end
        end
    end
    for _, ch in ipairs(char:GetChildren()) do
        if ch:IsA("Tool") and (ch.Name:lower():find("bat") or ch.Name:lower():find("slap")) then
            return ch
        end
    end
    if bp then
        for _, ch in ipairs(bp:GetChildren()) do
            if ch:IsA("Tool") and (ch.Name:lower():find("bat") or ch.Name:lower():find("slap")) then
                local hum = char:FindFirstChildOfClass("Humanoid")
                if hum then pcall(function() hum:EquipTool(ch) end) end
                return ch
            end
        end
    end
    return nil
end

local function trySwing()
    if _hittingCooldown then return end
    _hittingCooldown = true
    pcall(function()
        local char = LP.Character
        if char then
            local bat = getBat()
            if bat then
                if bat.Parent ~= char then
                    local hum = char:FindFirstChildOfClass("Humanoid")
                    if hum then pcall(function() hum:EquipTool(bat) end) end
                end
                pcall(function() bat:Activate() end)
            end
        end
    end)
    task.delay(SWING_CD, function() _hittingCooldown = false end)
end

local function getClosestPlayerAimbot()
    local char = LP.Character
    if not char then return nil, math.huge end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return nil, math.huge end
    local closest, dist = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local tr = p.Character:FindFirstChild("HumanoidRootPart")
            local ph = p.Character:FindFirstChildOfClass("Humanoid")
            if tr and ph and ph.Health > 0 then
                local d = (hrp.Position - tr.Position).Magnitude
                if d < dist then dist = d; closest = p end
            end
        end
    end
    return closest, dist
end

startBatAimbot = function()
    if _aimbotConn then return end

    local hum0 = LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")
    if hum0 then
        if _prevAutoRotate == nil then _prevAutoRotate = hum0.AutoRotate end
        hum0.AutoRotate = false
    end

    _aimbotConn = RunService.RenderStepped:Connect(function()
        if not State.batAimbotToggled then return end
        local char = LP.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not root or not hum then return end

        if not char:FindFirstChildOfClass("Tool") then
            local bat = getBat()
            if bat then pcall(function() hum:EquipTool(bat) end) end
        end

        local targetPlr, targetDist = getClosestPlayerAimbot()
        if not targetPlr or not targetPlr.Character then return end
        local target = targetPlr.Character:FindFirstChild("HumanoidRootPart")
        if not target then return end

        local targetVel = target.AssemblyLinearVelocity
        local myPos = root.Position
        local targetPos = target.Position

        local predictPos = targetPos + targetVel * 0.14
        predictPos = predictPos + target.CFrame.LookVector * 0.3

        local direction = predictPos - myPos
        local flatDir = Vector3.new(direction.X, 0, direction.Z)
        if flatDir.Magnitude > 0 then flatDir = flatDir.Unit else flatDir = Vector3.new(0,0,0) end

        local desiredHeight = targetPos.Y + 3.7
        local yVel = (desiredHeight - myPos.Y) * 19.5 + targetVel.Y * 0.8
        if hum.FloorMaterial ~= Enum.Material.Air then
            yVel = math.max(yVel, 13)
        end
        yVel = math.clamp(yVel, -70, 110)

        local desiredVel = Vector3.new(flatDir.X * AIMBOT_SPEED, yVel, flatDir.Z * AIMBOT_SPEED)
        root.AssemblyLinearVelocity = root.AssemblyLinearVelocity:Lerp(desiredVel, 0.8)

        local speed3 = targetVel.Magnitude
        local predictTime = math.clamp(speed3 / 150, 0.05, 0.2)
        local predictedPos = targetPos + targetVel * predictTime
        local toPredict = predictedPos - myPos
        if toPredict.Magnitude > 0.1 then
            local goalCF = CFrame.lookAt(myPos, predictedPos)
            local diffCF = root.CFrame:Inverse() * goalCF
            local rx, ry, rz = diffCF:ToEulerAnglesXYZ()
            rx = math.clamp(rx, -2.5, 2.5)
            ry = math.clamp(ry, -2.5, 2.5)
            rz = math.clamp(rz, -2.5, 2.5)
            root.AssemblyAngularVelocity = root.CFrame:VectorToWorldSpace(
                Vector3.new(rx * 42, ry * 42, rz * 42)
            )
        end

        if targetDist <= HIT_DIST then
            trySwing()
        end
    end)
end

stopBatAimbot = function()
    if _aimbotConn then
        pcall(function() _aimbotConn:Disconnect() end)
        _aimbotConn = nil
    end
    local char = LP.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")

    if hum then
        hum.AutoRotate = (_prevAutoRotate == nil) and true or _prevAutoRotate
        hum.PlatformStand = false
        pcall(function() hum:ChangeState(Enum.HumanoidStateType.GettingUp) end)
    end
    if root then
        root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y * 0.3, 0)
        root.AssemblyAngularVelocity = Vector3.zero
    end
    _prevAutoRotate = nil
    _hittingCooldown = false
end

-- ============================================================
-- BAT V2 AIMBOT (sin cambios)
-- ============================================================
local BAT_V2_FOLLOW_DIST = 1.0
local BAT_V2_HEIGHT_OFFSET = 1.5
local BAT_V2_VERTICAL_OFFSET = 0.0
local BAT_V2_AIMBOT_SPEED = 60
local BAT_V2_SWING_COOLDOWN = 0.08
local BAT_V2_HIT_DIST = 4.5

local function findAnyToolV2()
    local c = LP.Character
    if c then
        for _, v in ipairs(c:GetChildren()) do if v:IsA("Tool") then return v end end
    end
    local bp = LP:FindFirstChildOfClass("Backpack")
    if bp then
        for _, v in ipairs(bp:GetChildren()) do if v:IsA("Tool") then return v end end
    end
    return nil
end

local function getClosestPlayerV2()
    if not hrp then return nil, math.huge end
    local closest, bestDist = nil, math.huge
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            local tr = p.Character:FindFirstChild("HumanoidRootPart")
            local ph = p.Character:FindFirstChildOfClass("Humanoid")
            if tr and ph and ph.Health > 0 then
                local d = (hrp.Position - tr.Position).Magnitude
                if d < bestDist then bestDist = d; closest = p end
            end
        end
    end
    return closest, bestDist
end

local function tryHitBatV2()
    if State.batV2HittingCooldown then return end
    State.batV2HittingCooldown = true
    local char = LP.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local tool = findAnyToolV2()
    if tool then
        if tool.Parent ~= char and hum then pcall(function() hum:EquipTool(tool) end) end
        local remote = tool:FindFirstChildOfClass("RemoteEvent")
        if remote then pcall(function() remote:FireServer() end) else pcall(function() tool:Activate() end) end
    end
    task.delay(BAT_V2_SWING_COOLDOWN, function() State.batV2HittingCooldown = false end)
end

startBatV2Aimbot = function()
    if Conns.batV2Aimbot then return end
    Conns.batV2Aimbot = RunService.Heartbeat:Connect(function()
        if not State.batV2Toggled then return end
        local char = LP.Character
        if not char then return end
        local root = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not root or not hum then return end
        local target, dist = getClosestPlayerV2()
        if target and target.Character then
            local targetRoot = target.Character:FindFirstChild("HumanoidRootPart")
            if targetRoot then
                local targetVel = targetRoot.Velocity
                local moveDir = targetVel.Magnitude > 0.1 and targetVel.Unit or targetRoot.CFrame.LookVector
                local offset = moveDir * BAT_V2_FOLLOW_DIST + Vector3.new(0, BAT_V2_HEIGHT_OFFSET + BAT_V2_VERTICAL_OFFSET, 0)
                local desiredPos = targetRoot.Position + offset
                local toTarget = desiredPos - root.Position
                if toTarget.Magnitude > 0.5 then
                    local moveVec = toTarget.Unit * BAT_V2_AIMBOT_SPEED
                    root.Velocity = Vector3.new(moveVec.X, moveVec.Y, moveVec.Z)
                else
                    root.Velocity = root.Velocity * 0.95
                    if root.Velocity.Magnitude < 1 then root.Velocity = Vector3.zero end
                end
                local distToTarget = (root.Position - targetRoot.Position).Magnitude
                if distToTarget <= BAT_V2_HIT_DIST then tryHitBatV2() end
            end
        else
            root.Velocity = root.Velocity * 0.9
            if root.Velocity.Magnitude < 1 then root.AssemblyLinearVelocity = Vector3.zero end
        end
    end)
end

stopBatV2Aimbot = function()
    if Conns.batV2Aimbot then Conns.batV2Aimbot:Disconnect(); Conns.batV2Aimbot = nil end
    local c = LP.Character
    local root = c and c:FindFirstChild("HumanoidRootPart")
    if root then root.AssemblyLinearVelocity = Vector3.zero end
    State.batV2HittingCooldown = false
end

-- ============================================================
-- BAT COUNTER (sin cambios)
-- ============================================================
local BAT_COUNTER_SLAP_LIST = { "Bat", "Slap", "Iron Slap", "Gold Slap", "Diamond Slap", "Emerald Slap", "Ruby Slap", "Dark Matter Slap", "Flame Slap", "Nuclear Slap", "Galaxy Slap", "Glitched Slap" }

local function findBatForCounter()
    local c = LP.Character; if not c then return nil end
    local bp = LP:FindFirstChildOfClass("Backpack")
    for _, name in ipairs(BAT_COUNTER_SLAP_LIST) do
        local t = c:FindFirstChild(name) or (bp and bp:FindFirstChild(name))
        if t then return t end
    end
    for _, ch in ipairs(c:GetChildren()) do if ch:IsA("Tool") and ch.Name:lower():find("bat") then return ch end end
    if bp then for _, ch in ipairs(bp:GetChildren()) do if ch:IsA("Tool") and ch.Name:lower():find("bat") then return ch end end end
    return nil
end

local function swingBatForCounter(bat, char)
    local hum2 = char:FindFirstChildOfClass("Humanoid")
    if bat.Parent ~= char then if hum2 then pcall(function() hum2:EquipTool(bat) end) end; task.wait(0.05) end
    local remote = bat:FindFirstChildOfClass("RemoteEvent") or bat:FindFirstChildOfClass("RemoteFunction")
    if remote and remote:IsA("RemoteEvent") then
        pcall(function() remote:FireServer() end); task.wait(0.15); pcall(function() remote:FireServer() end)
    else
        pcall(function() bat:Activate() end); task.wait(0.15); pcall(function() bat:Activate() end)
    end
end

startBatCounter = function()
    if Conns.batCounter then return end
    Conns.batCounter = RunService.Heartbeat:Connect(function()
        if not State.batCounterEnabled then return end
        if State.batCounterDebounce then return end
        local char = LP.Character
        if not char then return end
        local hum2 = char:FindFirstChildOfClass("Humanoid")
        if not hum2 then return end
        local st = hum2:GetState()
        local isRagdolled = st == Enum.HumanoidStateType.Physics or st == Enum.HumanoidStateType.Ragdoll or st == Enum.HumanoidStateType.FallingDown
        if isRagdolled then
            State.batCounterDebounce = true
            task.spawn(function()
                local bat = findBatForCounter()
                if bat then swingBatForCounter(bat, char) end
                task.wait(0.5)
                State.batCounterDebounce = false
            end)
        end
    end)
end

stopBatCounter = function()
    if Conns.batCounter then Conns.batCounter:Disconnect(); Conns.batCounter = nil end
    State.batCounterDebounce = false
end

-- ============================================================
-- MEDUSA (sin cambios)
-- ============================================================
local MEDUSA_COOLDOWN = 25
local function findMedusa()
    local c = LP.Character; if not c then return nil end
    for _, t in ipairs(c:GetChildren()) do if t:IsA("Tool") then local n = t.Name:lower(); if n:find("medusa") or n:find("head") or n:find("stone") then return t end end end
    local bp = LP:FindFirstChild("Backpack")
    if bp then for _, t in ipairs(bp:GetChildren()) do if t:IsA("Tool") then local n = t.Name:lower(); if n:find("medusa") or n:find("head") or n:find("stone") then return t end end end end
    return nil
end

local function useMedusaCounter()
    if State.medusaDebounce then return end
    if tick() - State.medusaLastUsed < MEDUSA_COOLDOWN then return end
    local c = LP.Character; if not c then return end
    State.medusaDebounce = true
    local med = findMedusa()
    if not med then State.medusaDebounce = false; return end
    if med.Parent ~= c then local hum2 = c:FindFirstChildOfClass("Humanoid"); if hum2 then hum2:EquipTool(med) end end
    pcall(function() med:Activate() end)
    State.medusaLastUsed = tick()
    State.medusaDebounce = false
end

local function onAnchorChanged(part)
    return part:GetPropertyChangedSignal("Anchored"):Connect(function()
        if part.Anchored and part.Transparency == 1 then useMedusaCounter() end
    end)
end

setupMedusaCounter = function(char)
    stopMedusaCounter()
    if not char then return end
    for _, part in ipairs(char:GetDescendants()) do if part:IsA("BasePart") then table.insert(Conns.anchor, onAnchorChanged(part)) end end
    table.insert(Conns.anchor, char.DescendantAdded:Connect(function(part) if part:IsA("BasePart") then table.insert(Conns.anchor, onAnchorChanged(part)) end end))
end

stopMedusaCounter = function()
    for _, c2 in pairs(Conns.anchor) do pcall(function() c2:Disconnect() end) end
    Conns.anchor = {}
end

-- ============================================================
-- AUTO LEFT / RIGHT (sin cambios)
-- ============================================================
local function faceSouth()
    pcall(function()
        local c = LP.Character; if not c then return end
        local root = c:FindFirstChild("HumanoidRootPart")
        if root then root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, 0, 0) end
    end)
end

local function faceNorth()
    pcall(function()
        local c = LP.Character; if not c then return end
        local root = c:FindFirstChild("HumanoidRootPart")
        if root then root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, math.rad(180), 0) end
    end)
end

startAutoLeft = function()
    if Conns.autoLeft then Conns.autoLeft:Disconnect() end
    State.autoLeftPhase = 1
    Conns.autoLeft = RunService.Heartbeat:Connect(function()
        if not State.autoLeftEnabled then return end
        local c = LP.Character; if not c then return end
        local root = c:FindFirstChild("HumanoidRootPart"); local hum2 = c:FindFirstChildOfClass("Humanoid")
        if not root or not hum2 then return end
        local spd = State.normalSpeed
        if State.autoLeftPhase == 1 then
            local tgt = Vector3.new(POS.L1.X, root.Position.Y, POS.L1.Z)
            if (tgt - root.Position).Magnitude < 1 then
                State.autoLeftPhase = 2
                local d = (POS.L2 - root.Position)
                local mv = Vector3.new(d.X, 0, d.Z).Unit
                hum2:Move(mv, false)
                root.AssemblyLinearVelocity = Vector3.new(mv.X * spd, root.AssemblyLinearVelocity.Y, mv.Z * spd)
                return
            end
            local d = (POS.L1 - root.Position)
            local mv = Vector3.new(d.X, 0, d.Z).Unit
            hum2:Move(mv, false)
            root.AssemblyLinearVelocity = Vector3.new(mv.X * spd, root.AssemblyLinearVelocity.Y, mv.Z * spd)
        elseif State.autoLeftPhase == 2 then
            local tgt = Vector3.new(POS.L2.X, root.Position.Y, POS.L2.Z)
            if (tgt - root.Position).Magnitude < 1 then
                hum2:Move(Vector3.zero, false)
                root.AssemblyLinearVelocity = Vector3.zero
                State.autoLeftEnabled = false
                if Conns.autoLeft then Conns.autoLeft:Disconnect(); Conns.autoLeft = nil end
                State.autoLeftPhase = 1
                if stackBtnRefs.autoLeft then stackBtnRefs.autoLeft.setOn(false) end
                faceSouth()
                return
            end
            local d = (POS.L2 - root.Position)
            local mv = Vector3.new(d.X, 0, d.Z).Unit
            hum2:Move(mv, false)
            root.AssemblyLinearVelocity = Vector3.new(mv.X * spd, root.AssemblyLinearVelocity.Y, mv.Z * spd)
        end
    end)
end

stopAutoLeft = function()
    if Conns.autoLeft then Conns.autoLeft:Disconnect(); Conns.autoLeft = nil end
    State.autoLeftPhase = 1
    local c = LP.Character
    if c then
        local hum2 = c:FindFirstChildOfClass("Humanoid")
        if hum2 then hum2:Move(Vector3.zero, false) end
    end
    if stackBtnRefs.autoLeft then stackBtnRefs.autoLeft.setOn(false) end
    if setAutoLeft then setAutoLeft(false) end
end

startAutoRight = function()
    if Conns.autoRight then Conns.autoRight:Disconnect() end
    State.autoRightPhase = 1
    Conns.autoRight = RunService.Heartbeat:Connect(function()
        if not State.autoRightEnabled then return end
        local c = LP.Character; if not c then return end
        local root = c:FindFirstChild("HumanoidRootPart"); local hum2 = c:FindFirstChildOfClass("Humanoid")
        if not root or not hum2 then return end
        local spd = State.normalSpeed
        if State.autoRightPhase == 1 then
            local tgt = Vector3.new(POS.R1.X, root.Position.Y, POS.R1.Z)
            if (tgt - root.Position).Magnitude < 1 then
                State.autoRightPhase = 2
                local d = (POS.R2 - root.Position)
                local mv = Vector3.new(d.X, 0, d.Z).Unit
                hum2:Move(mv, false)
                root.AssemblyLinearVelocity = Vector3.new(mv.X * spd, root.AssemblyLinearVelocity.Y, mv.Z * spd)
                return
            end
            local d = (POS.R1 - root.Position)
            local mv = Vector3.new(d.X, 0, d.Z).Unit
            hum2:Move(mv, false)
            root.AssemblyLinearVelocity = Vector3.new(mv.X * spd, root.AssemblyLinearVelocity.Y, mv.Z * spd)
        elseif State.autoRightPhase == 2 then
            local tgt = Vector3.new(POS.R2.X, root.Position.Y, POS.R2.Z)
            if (tgt - root.Position).Magnitude < 1 then
                hum2:Move(Vector3.zero, false)
                root.AssemblyLinearVelocity = Vector3.zero
                State.autoRightEnabled = false
                if Conns.autoRight then Conns.autoRight:Disconnect(); Conns.autoRight = nil end
                State.autoRightPhase = 1
                if stackBtnRefs.autoRight then stackBtnRefs.autoRight.setOn(false) end
                faceNorth()
                return
            end
            local d = (POS.R2 - root.Position)
            local mv = Vector3.new(d.X, 0, d.Z).Unit
            hum2:Move(mv, false)
            root.AssemblyLinearVelocity = Vector3.new(mv.X * spd, root.AssemblyLinearVelocity.Y, mv.Z * spd)
        end
    end)
end

stopAutoRight = function()
    if Conns.autoRight then Conns.autoRight:Disconnect(); Conns.autoRight = nil end
    State.autoRightPhase = 1
    local c = LP.Character
    if c then
        local hum2 = c:FindFirstChildOfClass("Humanoid")
        if hum2 then hum2:Move(Vector3.zero, false) end
    end
    if stackBtnRefs.autoRight then stackBtnRefs.autoRight.setOn(false) end
    if setAutoRight then setAutoRight(false) end
end

-- ============================================================
-- ANTI RAGDOLL (sin cambios)
-- ============================================================
startAntiRagdoll = function()
    if Conns.antiRag then return end
    Conns.antiRag = RunService.Heartbeat:Connect(function()
        if not State.antiRagdollEnabled then return end
        local c = LP.Character; if not c then return end
        local hum2 = c:FindFirstChildOfClass("Humanoid"); local root = c:FindFirstChild("HumanoidRootPart")
        if not hum2 or not root then return end
        if hum2.Health <= 0 then return end
        local st = hum2:GetState()
        if st == Enum.HumanoidStateType.Dead then return end
        if st == Enum.HumanoidStateType.Physics or st == Enum.HumanoidStateType.Ragdoll or st == Enum.HumanoidStateType.FallingDown then
            pcall(function() hum2:ChangeState(Enum.HumanoidStateType.GettingUp) end)
            pcall(function() workspace.CurrentCamera.CameraSubject = hum2 end)
            pcall(function() local PM = LP.PlayerScripts:FindFirstChild("PlayerModule"); if PM then local CM = require(PM:FindFirstChild("ControlModule")); if CM then CM:Enable() end end end)
            root.Velocity = Vector3.new(0, 0, 0); root.RotVelocity = Vector3.new(0, 0, 0)
        end
        for _, obj in ipairs(c:GetDescendants()) do
            pcall(function() if obj:IsA("Motor6D") and obj.Enabled == false then obj.Enabled = true end end)
        end
    end)
end

stopAntiRagdoll = function()
    if Conns.antiRag then Conns.antiRag:Disconnect(); Conns.antiRag = nil end
end

-- ============================================================
-- UNWALK (sin cambios)
-- ============================================================
local unwalkAnimateRef = nil
local function startUnwalk()
    local c = LP.Character
    if not c then return end
    local hum2 = c:FindFirstChildOfClass("Humanoid")
    if hum2 then
        hum2.WalkSpeed = 0
        pcall(function() for _, track in ipairs(hum2:GetPlayingAnimationTracks()) do track:Stop(0) end end)
    end
    local animCtrl = c:FindFirstChildOfClass("AnimationController")
    if animCtrl then pcall(function() for _, track in ipairs(animCtrl:GetPlayingAnimationTracks()) do track:Stop(0) end end) end
    local anim = c:FindFirstChild("Animate")
    if anim and anim:IsA("LocalScript") then anim.Disabled = true; unwalkAnimateRef = anim end
    if Conns.unwalk then Conns.unwalk:Disconnect() end
    Conns.unwalk = RunService.Heartbeat:Connect(function()
        if not State.unwalkEnabled then return end
        local c2 = LP.Character
        if not c2 then return end
        local hum3 = c2:FindFirstChildOfClass("Humanoid")
        if hum3 then
            hum3.WalkSpeed = 0
            pcall(function() for _, track in ipairs(hum3:GetPlayingAnimationTracks()) do track:Stop(0) end end)
        end
    end)
end

local function stopUnwalk()
    if Conns.unwalk then Conns.unwalk:Disconnect(); Conns.unwalk = nil end
    local c = LP.Character
    if c then
        local hum2 = c:FindFirstChildOfClass("Humanoid")
        if hum2 then hum2.WalkSpeed = getActiveSpeed() end
        if unwalkAnimateRef and unwalkAnimateRef.Parent == c then unwalkAnimateRef.Disabled = false end
    end
    unwalkAnimateRef = nil
end

-- ============================================================
-- EFECTO DE CLIMA (morado difuminado)
-- ============================================================
local function applyWeatherEffect()
    pcall(function()
        local Lighting = game:GetService("Lighting")
        
        Lighting.ClockTime = 16.5
        Lighting.Brightness = 1.8
        
        Lighting.FogStart = 50
        Lighting.FogEnd = 250
        Lighting.FogColor = Color3.fromRGB(160, 120, 220)
        
        Lighting.Ambient = Color3.fromRGB(120, 80, 180)
        Lighting.OutdoorAmbient = Color3.fromRGB(150, 100, 220)
        
        local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
        if not atmosphere then
            atmosphere = Instance.new("Atmosphere")
            atmosphere.Parent = Lighting
        end
        atmosphere.Density = 0.45
        atmosphere.Haze = 3
        atmosphere.Glare = 0.15
        atmosphere.Color = Color3.fromRGB(180, 130, 255)
        
        local sky = Lighting:FindFirstChildOfClass("Sky")
        if not sky then
            sky = Instance.new("Sky")
            sky.Parent = Lighting
        end
        sky.SkyboxBk = Color3.fromRGB(80, 50, 130)
        sky.SkyboxDn = Color3.fromRGB(60, 35, 100)
        sky.SkyboxFt = Color3.fromRGB(90, 60, 150)
        sky.SkyboxLf = Color3.fromRGB(90, 60, 150)
        sky.SkyboxRt = Color3.fromRGB(90, 60, 150)
        sky.SkyboxUp = Color3.fromRGB(120, 80, 200)
        sky.StarColor = Color3.fromRGB(200, 180, 255)
        sky.MoonAngularSize = 15
        
        local terrain = workspace.Terrain
        if terrain then
            local clouds = terrain:FindFirstChildOfClass("Clouds")
            if clouds then
                clouds.Cover = 0.65
                clouds.Density = 0.5
                clouds.Color = Color3.fromRGB(180, 150, 220)
            end
        end
        
        local rainSound = workspace:FindFirstChild("RainSound")
        if rainSound and rainSound:IsA("Sound") then
            rainSound.Volume = 0.4
            rainSound.Looped = true
            rainSound:Play()
        end
        
        TweenService:Create(atmosphere, TweenInfo.new(5), { Density = 0.5, Haze = 3.5 }):Play()
    end)
end

-- ============================================================
-- SAVE / LOAD CONFIG
-- ============================================================
saveConfig = function()
    local cfg = {
        normalSpeed = State.normalSpeed,
        carrySpeed = State.carrySpeed,
        laggerSpeed = State.laggerSpeed,
        lagguerSpeed = State.lagguerSpeed,
        stealRadius = AutoStealConfig.Radius,
        stealDuration = AutoStealConfig.StealDuration,
        infJump = State.infJumpEnabled,
        infJumpMode = State.infJumpMode,
        antiRagdoll = State.antiRagdollEnabled,
        medusaCounter = State.medusaCounterEnabled,
        batCounter = State.batCounterEnabled,
        autoStealEnabled = AutoStealConfig.Enabled,
        autoTpDown = autoTpDownEnabled,
        tpThreshold = autoTpDownThreshold,
        speedToggled = State.speedToggled,
        laggerEnabled = State.laggerEnabled,
        lagguerSpeedEnabled = State.lagguerSpeedEnabled,
        stunTimer = stunTimerEnabled,
        batV2 = State.batV2Toggled,
        keybinds = {
            speed = Keys.speed.Name,
            lagguerSpeed = Keys.lagguerSpeed.Name,
            lagger = Keys.lagger.Name,
            autoLeft = Keys.autoLeft.Name,
            autoRight = Keys.autoRight.Name,
            aimbot = Keys.aimbot.Name,
            batV2 = Keys.batV2.Name,
            batCounter = Keys.batCounter.Name,
            medusaCounter = Keys.medusaCounter.Name,
            drop = Keys.drop.Name,
            tpDown = Keys.tpDown.Name,
            autoSteal = Keys.autoSteal.Name,
            autoTpDown = Keys.autoTpDown.Name,
            cleanTime = Keys.cleanTime.Name,
            infJump = Keys.infJump.Name,
            antiRagdoll = Keys.antiRagdoll.Name,
            lockUI = Keys.lockUI.Name,
        }
    }
    local ok, encoded = pcall(function() return HttpService:JSONEncode(cfg) end)
    if ok then pcall(function() _writefile(CONFIG_FILE, encoded) end) end
end

loadConfig = function()
    local hasFile = false
    pcall(function() hasFile = _isfile(CONFIG_FILE) end)
    if not hasFile then return end
    local raw
    pcall(function() raw = _readfile(CONFIG_FILE) end)
    if not raw then return end
    local cfg
    pcall(function() cfg = HttpService:JSONDecode(raw) end)
    if not cfg then return end
    
    if cfg.normalSpeed then State.normalSpeed = cfg.normalSpeed; if normalBox then normalBox.Text = tostring(cfg.normalSpeed) end end
    if cfg.carrySpeed then State.carrySpeed = cfg.carrySpeed; if carryBox then carryBox.Text = tostring(cfg.carrySpeed) end end
    if cfg.laggerSpeed then State.laggerSpeed = cfg.laggerSpeed; if laggerBox then laggerBox.Text = tostring(cfg.laggerSpeed) end end
    if cfg.lagguerSpeed then State.lagguerSpeed = cfg.lagguerSpeed; if lagguerBox then lagguerBox.Text = tostring(cfg.lagguerSpeed) end end
    if cfg.stealRadius then AutoStealConfig.Radius = cfg.stealRadius end
    if cfg.stealDuration then AutoStealConfig.StealDuration = cfg.stealDuration end
    if cfg.tpThreshold then autoTpDownThreshold = cfg.tpThreshold; if thresholdBox and not thresholdBox:IsFocused() then thresholdBox.Text = tostring(autoTpDownThreshold) end end
    if cfg.autoStealEnabled then AutoStealConfig.Enabled = true; if setAutoStealToggle then setAutoStealToggle(true) end; startAutoStealLoop() end
    if cfg.infJump then State.infJumpEnabled = true; if setInfJumpToggle then setInfJumpToggle(true) end end
    if cfg.infJumpMode then State.infJumpMode = cfg.infJumpMode; updateInfJumpModeUI() end
    if cfg.antiRagdoll then State.antiRagdollEnabled = true; if setAntiRagdollToggle then setAntiRagdollToggle(true) end; startAntiRagdoll() end
    if cfg.medusaCounter then State.medusaCounterEnabled = true; if setMedusaCounterToggle then setMedusaCounterToggle(true) end; setupMedusaCounter(LP.Character) end
    if cfg.batCounter then State.batCounterEnabled = true; if setBatCounterToggle then setBatCounterToggle(true) end; startBatCounter() end
    if cfg.autoTpDown ~= nil then autoTpDownEnabled = cfg.autoTpDown; if setAutoTpDownToggle then setAutoTpDownToggle(autoTpDownEnabled) end; if autoTpDownEnabled then startAutoTpDown() else stopAutoTpDown() end end
    if cfg.speedToggled ~= nil then State.speedToggled = cfg.speedToggled; if stackBtnRefs.carrySpeed then stackBtnRefs.carrySpeed.setOn(State.speedToggled) end end
    if cfg.laggerEnabled ~= nil then State.laggerEnabled = cfg.laggerEnabled; if stackBtnRefs.lagger then stackBtnRefs.lagger.setOn(State.laggerEnabled) end end
    if cfg.lagguerSpeedEnabled ~= nil then State.lagguerSpeedEnabled = cfg.lagguerSpeedEnabled; if stackBtnRefs.lagguerSpeed then stackBtnRefs.lagguerSpeed.setOn(State.lagguerSpeedEnabled) end end
    if cfg.stunTimer ~= nil then
        stunTimerEnabled = cfg.stunTimer
        if setStunTimerToggle then setStunTimerToggle(stunTimerEnabled) end
        if stunTimerEnabled then
            createStunTimerBillboard()
            if LP.Character then setupStunDetection(LP.Character) end
        end
    else
        stunTimerEnabled = true
        if setStunTimerToggle then setStunTimerToggle(true) end
        createStunTimerBillboard()
        if LP.Character then setupStunDetection(LP.Character) end
    end
    if cfg.batV2 ~= nil then
        State.batV2Toggled = cfg.batV2
        setBatV2Active(State.batV2Toggled)
        if State.batV2Toggled then startBatV2Aimbot() else stopBatV2Aimbot() end
    end
    if cfg.lockUI ~= nil then State.uiLocked = cfg.lockUI; if setLockUIToggle then setLockUIToggle(State.uiLocked) end end

    local function getKeyEnum(name)
        if name == "Unknown" then return Enum.KeyCode.Unknown end
        local success, key = pcall(function() return Enum.KeyCode[name] end)
        if success then return key else return Enum.KeyCode.Unknown end
    end
    if cfg.keybinds then
        local kb = cfg.keybinds
        if kb.speed then Keys.speed = getKeyEnum(kb.speed); if keybindBtnRefs.speed then keybindBtnRefs.speed.Text = getKeyDisplayName(Keys.speed) end end
        if kb.lagguerSpeed then Keys.lagguerSpeed = getKeyEnum(kb.lagguerSpeed); if keybindBtnRefs.lagguerSpeed then keybindBtnRefs.lagguerSpeed.Text = getKeyDisplayName(Keys.lagguerSpeed) end end
        if kb.lagger then Keys.lagger = getKeyEnum(kb.lagger); if keybindBtnRefs.lagger then keybindBtnRefs.lagger.Text = getKeyDisplayName(Keys.lagger) end end
        if kb.autoLeft then Keys.autoLeft = getKeyEnum(kb.autoLeft); if keybindBtnRefs.autoLeft then keybindBtnRefs.autoLeft.Text = getKeyDisplayName(Keys.autoLeft) end end
        if kb.autoRight then Keys.autoRight = getKeyEnum(kb.autoRight); if keybindBtnRefs.autoRight then keybindBtnRefs.autoRight.Text = getKeyDisplayName(Keys.autoRight) end end
        if kb.aimbot then Keys.aimbot = getKeyEnum(kb.aimbot); if keybindBtnRefs.aimbot then keybindBtnRefs.aimbot.Text = getKeyDisplayName(Keys.aimbot) end end
        if kb.batV2 then Keys.batV2 = getKeyEnum(kb.batV2); if keybindBtnRefs.batV2 then keybindBtnRefs.batV2.Text = getKeyDisplayName(Keys.batV2) end end
        if kb.batCounter then Keys.batCounter = getKeyEnum(kb.batCounter); if keybindBtnRefs.batCounter then keybindBtnRefs.batCounter.Text = getKeyDisplayName(Keys.batCounter) end end
        if kb.medusaCounter then Keys.medusaCounter = getKeyEnum(kb.medusaCounter); if keybindBtnRefs.medusaCounter then keybindBtnRefs.medusaCounter.Text = getKeyDisplayName(Keys.medusaCounter) end end
        if kb.drop then Keys.drop = getKeyEnum(kb.drop); if keybindBtnRefs.drop then keybindBtnRefs.drop.Text = getKeyDisplayName(Keys.drop) end end
        if kb.tpDown then Keys.tpDown = getKeyEnum(kb.tpDown); if keybindBtnRefs.tpDown then keybindBtnRefs.tpDown.Text = getKeyDisplayName(Keys.tpDown) end end
        if kb.autoSteal then Keys.autoSteal = getKeyEnum(kb.autoSteal); if keybindBtnRefs.autoSteal then keybindBtnRefs.autoSteal.Text = getKeyDisplayName(Keys.autoSteal) end end
        if kb.autoTpDown then Keys.autoTpDown = getKeyEnum(kb.autoTpDown); if keybindBtnRefs.autoTpDown then keybindBtnRefs.autoTpDown.Text = getKeyDisplayName(Keys.autoTpDown) end end
        if kb.cleanTime then Keys.cleanTime = getKeyEnum(kb.cleanTime); if keybindBtnRefs.cleanTime then keybindBtnRefs.cleanTime.Text = getKeyDisplayName(Keys.cleanTime) end end
        if kb.infJump then Keys.infJump = getKeyEnum(kb.infJump); if keybindBtnRefs.infJump then keybindBtnRefs.infJump.Text = getKeyDisplayName(Keys.infJump) end end
        if kb.antiRagdoll then Keys.antiRagdoll = getKeyEnum(kb.antiRagdoll); if keybindBtnRefs.antiRagdoll then keybindBtnRefs.antiRagdoll.Text = getKeyDisplayName(Keys.antiRagdoll) end end
        if kb.lockUI then Keys.lockUI = getKeyEnum(kb.lockUI); if keybindBtnRefs.lockUI then keybindBtnRefs.lockUI.Text = getKeyDisplayName(Keys.lockUI) end end
    end
    
    if h then h.WalkSpeed = getActiveSpeed() end
end

-- ============================================================
-- CHARACTER SETUP (con marcador de velocidad morado)
-- ============================================================
local function setupChar(char)
    task.wait(0.1)
    h = char:WaitForChild("Humanoid", 5)
    hrp = char:WaitForChild("HumanoidRootPart", 5)
    if not h or not hrp then return end
    if State.unwalkEnabled then h.WalkSpeed = 0 else h.WalkSpeed = getActiveSpeed() end
    local head = char:FindFirstChild("Head")
    if head then
        local oldBB = head:FindFirstChild("CleanHubBB")
        if oldBB then oldBB:Destroy() end
        local bb = Instance.new("BillboardGui", head)
        bb.Name = "CleanHubBB"
        bb.Size = UDim2.new(0, 120, 0, 36)
        bb.StudsOffset = Vector3.new(0, 2.5, 0)
        bb.AlwaysOnTop = true
        local speedBillLbl = Instance.new("TextLabel", bb)
        speedBillLbl.Name = "SpeedBillLbl"
        speedBillLbl.Size = UDim2.new(1, 0, 1, 0)
        speedBillLbl.BackgroundTransparency = 1
        speedBillLbl.TextColor3 = PURPLE_ACCENT
        speedBillLbl.Font = Enum.Font.GothamBlack
        speedBillLbl.TextSize = 20
        speedBillLbl.TextStrokeTransparency = 1
        speedBillLbl.TextXAlignment = Enum.TextXAlignment.Center
        speedBillLbl.TextYAlignment = Enum.TextYAlignment.Center
    end
    if Conns.unwalk then Conns.unwalk:Disconnect(); Conns.unwalk = nil end
    unwalkAnimateRef = nil
    if State.unwalkEnabled then task.wait(0.3); startUnwalk() end
    stopAntiRagdoll()
    if State.antiRagdollEnabled then task.wait(0.5); startAntiRagdoll() end
    if State.medusaCounterEnabled then setupMedusaCounter(char) end
    if State.batAimbotToggled then stopBatAimbot(); task.wait(0.2); pcall(startBatAimbot) end
    if State.batCounterEnabled then task.wait(0.3); startBatCounter() end
    if State.batV2Toggled then stopBatV2Aimbot(); task.wait(0.2); startBatV2Aimbot() end
    if autoTpDownEnabled then task.wait(0.3); startAutoTpDown() end
    if stunTimerEnabled then
        setupStunDetection(char)
        createStunTimerBillboard()
    end
end

LP.CharacterAdded:Connect(setupChar)
if LP.Character then task.spawn(function() setupChar(LP.Character) end) end

-- ============================================================
-- RUNTIME LOOPS
-- ============================================================
RunService.Stepped:Connect(function()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and p.Character then
            for _, part in ipairs(p.Character:GetChildren()) do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
        end
    end
end)

-- ============================================================
-- INFINITE JUMP
-- ============================================================
UIS.JumpRequest:Connect(function()
    if not State.infJumpEnabled then return end
    if State.infJumpMode ~= "manual" then return end
    local char = LP.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if root then
        root.Velocity = Vector3.new(root.Velocity.X, 55, root.Velocity.Z)
    end
end)

RunService.Heartbeat:Connect(function()
    if not State.infJumpEnabled and not autoTpDownEnabled then return end
    local char = LP.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    if State.infJumpEnabled then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if State.infJumpMode == "hold" then
            local spaceHeld = UIS:IsKeyDown(Enum.KeyCode.Space) or (hum and hum.Jump == true)
            if spaceHeld and root.Velocity.Y < 30 then
                root.Velocity = Vector3.new(root.Velocity.X, 55, root.Velocity.Z)
            end
        end
        if root.Velocity.Y < -120 then
            root.Velocity = Vector3.new(root.Velocity.X, -120, root.Velocity.Z)
        end
    end
end)

-- Movimiento asistido
RunService.RenderStepped:Connect(function()
    if not (h and hrp) then return end
    if State._tpInProgress then return end
    if not State.batAimbotToggled and not State.autoLeftEnabled and not State.autoRightEnabled and not State.batV2Toggled then
        local md = h.MoveDirection
        local spd = getActiveSpeed()
        if md.Magnitude > 0 then
            State.lastMoveDir = md
            hrp.Velocity = Vector3.new(md.X * spd, hrp.Velocity.Y, md.Z * spd)
        elseif State.antiRagdollEnabled and State.lastMoveDir.Magnitude > 0 then
            local anyHeld = false
            for key in pairs(MOVE_KEYS) do if UIS:IsKeyDown(key) then anyHeld = true; break end end
            if anyHeld then
                hrp.Velocity = Vector3.new(State.lastMoveDir.X * spd, hrp.Velocity.Y, State.lastMoveDir.Z * spd)
            end
        end
    end
    pcall(function()
        local head2 = LP.Character and LP.Character:FindFirstChild("Head")
        if head2 then
            local bb2 = head2:FindFirstChild("CleanHubBB")
            local sl = bb2 and bb2:FindFirstChild("SpeedBillLbl")
            if sl then
                local hspd = Vector3.new(hrp.Velocity.X, 0, hrp.Velocity.Z).Magnitude
                sl.Text = string.format("%.1f", hspd)
            end
        end
    end)
end)

-- ============================================================
-- INPUT HANDLER (keybinds)
-- ============================================================
UIS.InputBegan:Connect(function(inp, gp)
    if gp then return end
    local isKb = inp.UserInputType == Enum.UserInputType.Keyboard
    local isGp = inp.UserInputType == Enum.UserInputType.Gamepad1 or inp.UserInputType == Enum.UserInputType.Gamepad2 or inp.UserInputType == Enum.UserInputType.Gamepad3 or inp.UserInputType == Enum.UserInputType.Gamepad4
    if not isKb and not isGp then return end
    local kc = inp.KeyCode
    if kc == Enum.KeyCode.Unknown then return end

    if kc == Keys.speed then
        State.speedToggled = not State.speedToggled
        if stackBtnRefs.carrySpeed then stackBtnRefs.carrySpeed.setOn(State.speedToggled) end
        if State.speedToggled then
            if State.laggerEnabled then State.laggerEnabled = false; if stackBtnRefs.lagger then stackBtnRefs.lagger.setOn(false) end end
            if State.lagguerSpeedEnabled then State.lagguerSpeedEnabled = false; if stackBtnRefs.lagguerSpeed then stackBtnRefs.lagguerSpeed.setOn(false) end end
        end
        if h then h.WalkSpeed = getActiveSpeed() end
    elseif kc == Keys.lagguerSpeed then
        State.lagguerSpeedEnabled = not State.lagguerSpeedEnabled
        if stackBtnRefs.lagguerSpeed then stackBtnRefs.lagguerSpeed.setOn(State.lagguerSpeedEnabled) end
        if State.lagguerSpeedEnabled then
            if State.speedToggled then State.speedToggled = false; if stackBtnRefs.carrySpeed then stackBtnRefs.carrySpeed.setOn(false) end end
            if State.laggerEnabled then State.laggerEnabled = false; if stackBtnRefs.lagger then stackBtnRefs.lagger.setOn(false) end end
            if State.autoLeftEnabled then State.autoLeftEnabled = false; stopAutoLeft(); if stackBtnRefs.autoLeft then stackBtnRefs.autoLeft.setOn(false) end end
            if State.autoRightEnabled then State.autoRightEnabled = false; stopAutoRight(); if stackBtnRefs.autoRight then stackBtnRefs.autoRight.setOn(false) end end
            if State.batAimbotToggled then State.batAimbotToggled = false; if stackBtnRefs.aimbot then stackBtnRefs.aimbot.setOn(false) end; stopBatAimbot() end
        end
        if h then h.WalkSpeed = getActiveSpeed() end
    elseif kc == Keys.lagger then
        State.laggerEnabled = not State.laggerEnabled
        if stackBtnRefs.lagger then stackBtnRefs.lagger.setOn(State.laggerEnabled) end
        if State.laggerEnabled then
            if State.speedToggled then State.speedToggled = false; if stackBtnRefs.carrySpeed then stackBtnRefs.carrySpeed.setOn(false) end end
            if State.lagguerSpeedEnabled then State.lagguerSpeedEnabled = false; if stackBtnRefs.lagguerSpeed then stackBtnRefs.lagguerSpeed.setOn(false) end end
        end
        if h then h.WalkSpeed = getActiveSpeed() end
    elseif kc == Keys.autoLeft then
        local newState = not State.autoLeftEnabled
        if newState then
            if State.autoRightEnabled then
                State.autoRightEnabled = false
                if stackBtnRefs.autoRight then stackBtnRefs.autoRight.setOn(false) end
                stopAutoRight()
            end
            if State.batAimbotToggled then
                State.batAimbotToggled = false
                if stackBtnRefs.aimbot then stackBtnRefs.aimbot.setOn(false) end
                stopBatAimbot()
            end
        end
        State.autoLeftEnabled = newState
        if stackBtnRefs.autoLeft then stackBtnRefs.autoLeft.setOn(newState) end
        if setAutoLeft then setAutoLeft(newState) end
        if newState then startAutoLeft() else stopAutoLeft() end
    elseif kc == Keys.autoRight then
        local newState = not State.autoRightEnabled
        if newState then
            if State.autoLeftEnabled then
                State.autoLeftEnabled = false
                if stackBtnRefs.autoLeft then stackBtnRefs.autoLeft.setOn(false) end
                stopAutoLeft()
            end
            if State.batAimbotToggled then
                State.batAimbotToggled = false
                if stackBtnRefs.aimbot then stackBtnRefs.aimbot.setOn(false) end
                stopBatAimbot()
            end
        end
        State.autoRightEnabled = newState
        if stackBtnRefs.autoRight then stackBtnRefs.autoRight.setOn(newState) end
        if setAutoRight then setAutoRight(newState) end
        if newState then startAutoRight() else stopAutoRight() end
    elseif kc == Keys.aimbot then
        State.batAimbotToggled = not State.batAimbotToggled
        if stackBtnRefs.aimbot then stackBtnRefs.aimbot.setOn(State.batAimbotToggled) end
        if State.batAimbotToggled then
            if State.autoLeftEnabled then State.autoLeftEnabled = false; stopAutoLeft(); if stackBtnRefs.autoLeft then stackBtnRefs.autoLeft.setOn(false) end end
            if State.autoRightEnabled then State.autoRightEnabled = false; stopAutoRight(); if stackBtnRefs.autoRight then stackBtnRefs.autoRight.setOn(false) end end
            pcall(startBatAimbot)
        else
            stopBatAimbot()
        end
    elseif kc == Keys.batV2 then
        State.batV2Toggled = not State.batV2Toggled
        setBatV2Active(State.batV2Toggled)
        if State.batV2Toggled then
            if State.batAimbotToggled then
                State.batAimbotToggled = false
                if stackBtnRefs.aimbot then stackBtnRefs.aimbot.setOn(false) end
                stopBatAimbot()
            end
            startBatV2Aimbot()
        else
            stopBatV2Aimbot()
        end
        saveConfig()
    elseif kc == Keys.batCounter then
        local newState = not State.batCounterEnabled
        State.batCounterEnabled = newState
        if setBatCounterToggle then setBatCounterToggle(newState) end
        if newState then startBatCounter() else stopBatCounter() end
    elseif kc == Keys.medusaCounter then
        local newState = not State.medusaCounterEnabled
        State.medusaCounterEnabled = newState
        if setMedusaCounterToggle then setMedusaCounterToggle(newState) end
        if newState then setupMedusaCounter(LP.Character) else stopMedusaCounter() end
    elseif kc == Keys.drop then
        if not State.dropEnabled then runDropBrainrot() end
    elseif kc == Keys.tpDown then
        doTpDown()
    elseif kc == Keys.autoSteal then
        local newState = not AutoStealConfig.Enabled
        AutoStealConfig.Enabled = newState
        if setAutoStealToggle then setAutoStealToggle(newState) end
        if newState then startAutoStealLoop() else stopAutoStealLoop() end
    elseif kc == Keys.autoTpDown then
        local newState = not autoTpDownEnabled
        autoTpDownEnabled = newState
        if setAutoTpDownToggle then setAutoTpDownToggle(newState) end
        if newState then startAutoTpDown() else stopAutoTpDown() end
    elseif kc == Keys.cleanTime then
        local newState = not stunTimerEnabled
        stunTimerEnabled = newState
        if setStunTimerToggle then setStunTimerToggle(newState) end
        if not newState then
            if stunConnection then stunConnection:Disconnect(); stunConnection = nil end
            stunActive = false
            if stunTimerGuiBB then stunTimerGuiBB.Enabled = false end
            if stateChangedConnection then stateChangedConnection:Disconnect(); stateChangedConnection = nil end
        else
            createStunTimerBillboard()
            if LP.Character then
                local hum = LP.Character:FindFirstChildOfClass("Humanoid")
                if hum then
                    local st = hum:GetState()
                    if st == Enum.HumanoidStateType.Physics or st == Enum.HumanoidStateType.Ragdoll then onStunDetected() end
                end
                setupStunDetection(LP.Character)
            end
        end
    elseif kc == Keys.infJump then
        local newState = not State.infJumpEnabled
        State.infJumpEnabled = newState
        if setInfJumpToggle then setInfJumpToggle(newState) end
        if not newState then
            local char = LP.Character
            if char then
                local root = char:FindFirstChild("HumanoidRootPart")
                if root and root.Velocity.Y > 55 then
                    root.Velocity = Vector3.new(root.Velocity.X, 0, root.Velocity.Z)
                end
            end
        end
    elseif kc == Keys.antiRagdoll then
        local newState = not State.antiRagdollEnabled
        State.antiRagdollEnabled = newState
        if setAntiRagdollToggle then setAntiRagdollToggle(newState) end
        if newState then startAntiRagdoll() else stopAntiRagdoll() end
    elseif kc == Keys.lockUI then
        State.uiLocked = not State.uiLocked
        if setLockUIToggle then setLockUIToggle(State.uiLocked) end
    elseif kc == Keys.guiHide and isKb then
        State.guiVisible = not State.guiVisible
        if State.guiVisible then
            mainOuter.Visible = true
            TweenService:Create(mainOuter, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { BackgroundTransparency = 0 }):Play()
        else
            local tween = TweenService:Create(mainOuter, TweenInfo.new(0.2), { BackgroundTransparency = 1 })
            tween:Play()
            tween.Completed:Connect(function() if not State.guiVisible then mainOuter.Visible = false end end)
        end
    end
end)

-- ============================================================
-- TOGGLE MENU (botón Clean)
-- ============================================================
local function toggleMenu()
    State.guiVisible = not State.guiVisible
    if State.guiVisible then
        mainOuter.Visible = true
        TweenService:Create(mainOuter, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { BackgroundTransparency = 0 }):Play()
    else
        local tween = TweenService:Create(mainOuter, TweenInfo.new(0.2), { BackgroundTransparency = 1 })
        tween:Play()
        tween.Completed:Connect(function() if not State.guiVisible then mainOuter.Visible = false end end)
    end
end

clickButton.MouseButton1Click:Connect(toggleMenu)

-- ============================================================
-- INICIALIZACIÓN
-- ============================================================
loadPresetsFile()
rebuildPresetList()
loadConfig()
initializeScanner()
applyWeatherEffect()
task.delay(1, function() pcall(saveConfig) end)
task.spawn(function() while true do task.wait(30); pcall(saveConfig) end end)
