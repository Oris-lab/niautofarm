local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TweenService = game:GetService("TweenService")
local VirtualUser = game:GetService("VirtualUser")
local HttpService = game:GetService("HttpService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = workspace.CurrentCamera

local correctKey = "WLCHECKERONTOP"
local isKeyValid = false

local mobPositions = {
    Vector3.new(746.3298950195312, 9.149518013000488, 13745.45703125),
    Vector3.new(750.185546875, 9.149518013000488, 13785.9130859375),
    Vector3.new(720.824951171875, 9.149518013000488, 13779.53515625),
    Vector3.new(720.9591064453125, 9.149517059326172, 13749.767578125),
    Vector3.new(689.1298828125, 9.100165367126465, 13752.7939453125),
    Vector3.new(690.6495361328125, 9.100165367126465, 13779.7041015625),
    Vector3.new(655.9246215820312, 9.23295783996582, 13765.9072265625),
}

local platePosition = Vector3.new(907.6802368164062, 14.440231323242188, 13440.5947265625)

-- Настройки по умолчанию
local savedPosition = platePosition 
local hasSavedPosition = false
local isRunning = false
local isWaitingOnPlate = false
local isBetweenRuns = false
local maxTargetWave = 20
local moveSpeedMultiplier = 1.0
local savedKey = ""

local targetMinutes = {29, 59}
local configFileName = "TrialFarmConfig.json"

-- Функция загрузки конфигурации из файла экзекютора
local function loadConfig()
    if pcall(function()
        if isfile and isfile(configFileName) then
            local content = readfile(configFileName)
            local data = HttpService:JSONDecode(content)
            if data then
                if data.maxTargetWave then maxTargetWave = data.maxTargetWave end
                if data.moveSpeedMultiplier then moveSpeedMultiplier = data.moveSpeedMultiplier end
                if data.savedKey then savedKey = data.savedKey end
                if data.savedPosX and data.savedPosY and data.savedPosZ then
                    savedPosition = Vector3.new(data.savedPosX, data.savedPosY, data.savedPosZ)
                    hasSavedPosition = data.hasSavedPosition or true
                end
            end
        end
    end) then
        print("[TrialFarm]: Config loaded successfully!")
    end
end

-- Функция сохранения конфигурации в файл экзекютора
local function saveConfig()
    pcall(function()
        local data = {
            maxTargetWave = maxTargetWave,
            moveSpeedMultiplier = moveSpeedMultiplier,
            savedKey = savedKey,
            hasSavedPosition = hasSavedPosition,
            savedPosX = savedPosition.X,
            savedPosY = savedPosition.Y,
            savedPosZ = savedPosition.Z
        }
        writefile(configFileName, HttpService:JSONEncode(data))
    end)
end

-- Загружаем при старте
loadConfig()

local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

task.spawn(function()
    local connection
    connection = player.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TrialFarmGUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = CoreGui

local function createCorner(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 8)
    corner.Parent = parent
    return corner
end

local keyScreenGui = Instance.new("ScreenGui")
keyScreenGui.Name = "TrialKeyGUI"
keyScreenGui.ResetOnSpawn = false
keyScreenGui.Parent = CoreGui

local keyFrame = Instance.new("Frame")
keyFrame.Size = UDim2.new(0, 300, 0, 160)
keyFrame.Position = UDim2.new(0.5, -150, 0.5, -80)
keyFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
keyFrame.BackgroundTransparency = 0.1
keyFrame.BorderSizePixel = 0
keyFrame.Active = true
keyFrame.Draggable = true
keyFrame.Parent = keyScreenGui
createCorner(keyFrame, 12)

local keyTitle = Instance.new("TextLabel")
keyTitle.Size = UDim2.new(1, 0, 0, 35)
keyTitle.BackgroundTransparency = 1
keyTitle.Text = "Enter Script Key"
keyTitle.TextColor3 = Color3.fromRGB(240, 240, 240)
keyTitle.TextSize = 16
keyTitle.Font = Enum.Font.GothamBold
keyTitle.Parent = keyFrame

local keyTextBox = Instance.new("TextBox")
keyTextBox.Size = UDim2.new(0.85, 0, 0, 35)
keyTextBox.Position = UDim2.new(0.075, 0, 0, 45)
keyTextBox.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
keyTextBox.BackgroundTransparency = 0.2
keyTextBox.TextColor3 = Color3.fromRGB(240, 240, 240)
keyTextBox.TextSize = 14
keyTextBox.Font = Enum.Font.Gotham
keyTextBox.PlaceholderText = "Paste your key here..."
keyTextBox.Text = savedKey -- подставляем сохраненный ключ автоматически
keyTextBox.ClearTextOnFocus = false
keyTextBox.Parent = keyFrame
createCorner(keyTextBox, 6)

local submitKeyButton = Instance.new("TextButton")
submitKeyButton.Size = UDim2.new(0.85, 0, 0, 35)
submitKeyButton.Position = UDim2.new(0.075, 0, 0, 95)
submitKeyButton.BackgroundColor3 = Color3.fromRGB(35, 110, 55)
submitKeyButton.BackgroundTransparency = 0.1
submitKeyButton.BorderSizePixel = 0
submitKeyButton.Text = "Check Key"
submitKeyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
submitKeyButton.TextSize = 14
submitKeyButton.Font = Enum.Font.GothamBold
submitKeyButton.Parent = keyFrame
createCorner(submitKeyButton, 6)

screenGui.Enabled = false

-- Автоматическая проверка ключа, если он уже был сохранен и верен
if savedKey == correctKey then
    isKeyValid = true
    keyScreenGui:Destroy()
    screenGui.Enabled = true
end

local mobileToggleButton = nil
if isMobile then
    mobileToggleButton = Instance.new("TextButton")
    mobileToggleButton.Size = UDim2.new(0, 90, 0, 32)
    mobileToggleButton.Position = UDim2.new(0, 10, 0.4, 0)
    mobileToggleButton.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    mobileToggleButton.BackgroundTransparency = 0.2
    mobileToggleButton.BorderSizePixel = 0
    mobileToggleButton.Text = "Toggle UI"
    mobileToggleButton.TextColor3 = Color3.fromRGB(220, 220, 220)
    mobileToggleButton.TextSize = 13
    mobileToggleButton.Font = Enum.Font.GothamBold
    mobileToggleButton.Active = true
    mobileToggleButton.Draggable = true
    mobileToggleButton.Parent = screenGui
    createCorner(mobileToggleButton, 8)
end

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 240, 0, 310)
mainFrame.Position = UDim2.new(0.5, -120, 0.1, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
mainFrame.BackgroundTransparency = 0.15
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui
createCorner(mainFrame, 10)

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -35, 0, 30)
titleLabel.Position = UDim2.new(0, 12, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "Trial Auto Farm"
titleLabel.TextColor3 = Color3.fromRGB(240, 240, 240)
titleLabel.TextSize = 15
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = mainFrame

local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 26, 0, 26)
closeButton.Position = UDim2.new(1, -32, 0, 10)
closeButton.BackgroundColor3 = Color3.fromRGB(60, 30, 30)
closeButton.BackgroundTransparency = 0.2
closeButton.Text = "❌"
closeButton.TextColor3 = Color3.fromRGB(255, 100, 100)
closeButton.TextSize = 13
closeButton.Font = Enum.Font.GothamBold
closeButton.Parent = mainFrame
createCorner(closeButton, 6)

closeButton.MouseButton1Click:Connect(function()
    isRunning = false
    screenGui:Destroy()
    pcall(function() keyScreenGui:Destroy() end)
end)

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, 0, 0, 20)
statusLabel.Position = UDim2.new(0, 0, 0, 32)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Status: OFF"
statusLabel.TextColor3 = Color3.fromRGB(220, 80, 80)
statusLabel.TextSize = 12
statusLabel.Font = Enum.Font.Gotham
statusLabel.Parent = mainFrame

local waveInputBox = Instance.new("TextBox")
waveInputBox.Size = UDim2.new(0.85, 0, 0, 32)
waveInputBox.Position = UDim2.new(0.075, 0, 0, 60)
waveInputBox.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
waveInputBox.BackgroundTransparency = 0.2
waveInputBox.TextColor3 = Color3.fromRGB(240, 240, 240)
waveInputBox.TextSize = 13
waveInputBox.Font = Enum.Font.Gotham
waveInputBox.PlaceholderText = "Max Wave"
waveInputBox.Text = tostring(maxTargetWave)
waveInputBox.ClearTextOnFocus = false
waveInputBox.Parent = mainFrame
createCorner(waveInputBox, 6)

waveInputBox:GetPropertyChangedSignal("Text"):Connect(function()
    local val = tonumber(waveInputBox.Text)
    if val then 
        maxTargetWave = val 
        saveConfig()
    end
end)

local speedLabel = Instance.new("TextLabel")
speedLabel.Size = UDim2.new(0.85, 0, 0, 18)
speedLabel.Position = UDim2.new(0.075, 0, 0, 98)
speedLabel.BackgroundTransparency = 1
speedLabel.Text = "Speed: " .. string.format("%.2f", moveSpeedMultiplier) .. "x"
speedLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
speedLabel.TextSize = 11
speedLabel.Font = Enum.Font.Gotham
speedLabel.TextXAlignment = Enum.TextXAlignment.Left
speedLabel.Parent = mainFrame

local sliderBg = Instance.new("Frame")
sliderBg.Size = UDim2.new(0.85, 0, 0, 16)
sliderBg.Position = UDim2.new(0.075, 0, 0, 118)
sliderBg.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
sliderBg.BackgroundTransparency = 0.2
sliderBg.BorderSizePixel = 0
sliderBg.Parent = mainFrame
createCorner(sliderBg, 4)

local sliderFill = Instance.new("Frame")
local initialPercent = math.clamp((moveSpeedMultiplier - 0.1) / (3.0 - 0.1), 0, 1)
sliderFill.Size = UDim2.new(initialPercent, 0, 1, 0)
sliderFill.BackgroundColor3 = Color3.fromRGB(70, 130, 180)
sliderFill.BorderSizePixel = 0
sliderFill.Parent = sliderBg
createCorner(sliderFill, 4)

local sliderButton = Instance.new("TextButton")
sliderButton.Size = UDim2.new(1, 0, 1, 0)
sliderButton.BackgroundTransparency = 1
sliderButton.Text = ""
sliderButton.Parent = sliderBg

local draggingSlider = false
sliderButton.MouseButton1Down:Connect(function()
    draggingSlider = true
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        if draggingSlider then
            draggingSlider = false
            saveConfig()
        end
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if draggingSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local mousePos = UserInputService:GetMouseLocation()
        local absPos = sliderBg.AbsolutePosition
        local absSize = sliderBg.AbsoluteSize
        local percent = math.clamp((mousePos.X - absPos.X) / absSize.X, 0, 1)
        
        sliderFill.Size = UDim2.new(percent, 0, 1, 0)
        moveSpeedMultiplier = 0.1 + percent * (3.0 - 0.1)
        speedLabel.Text = "Speed: " .. string.format("%.2f", moveSpeedMultiplier) .. "x"
    end
end)

local savePosButton = Instance.new("TextButton")
savePosButton.Size = UDim2.new(0.85, 0, 0, 32)
savePosButton.Position = UDim2.new(0.075, 0, 0, 142)
savePosButton.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
savePosButton.BackgroundTransparency = 0.2
savePosButton.BorderSizePixel = 0
savePosButton.Text = "Save Position (P)"
savePosButton.TextColor3 = Color3.fromRGB(220, 220, 220)
savePosButton.TextSize = 13
savePosButton.Font = Enum.Font.GothamBold
savePosButton.Parent = mainFrame
createCorner(savePosButton, 6)

local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(0.85, 0, 0, 35)
toggleButton.Position = UDim2.new(0.075, 0, 0, 182)
toggleButton.BackgroundColor3 = Color3.fromRGB(35, 110, 55)
toggleButton.BackgroundTransparency = 0.1
toggleButton.BorderSizePixel = 0
toggleButton.Text = "Enable (G)"
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.TextSize = 13
toggleButton.Font = Enum.Font.GothamBold
toggleButton.Parent = mainFrame
createCorner(toggleButton, 6)

local waveInfoLabel = Instance.new("TextLabel")
waveInfoLabel.Size = UDim2.new(1, 0, 0, 20)
waveInfoLabel.Position = UDim2.new(0, 0, 0, 224)
waveInfoLabel.BackgroundTransparency = 1
waveInfoLabel.Text = "Wave: 0 / Target: " .. maxTargetWave
waveInfoLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
waveInfoLabel.TextSize = 12
waveInfoLabel.Font = Enum.Font.Gotham
waveInfoLabel.Parent = mainFrame

local posStatusLabel = Instance.new("TextLabel")
posStatusLabel.Size = UDim2.new(1, 0, 0, 18)
posStatusLabel.Position = UDim2.new(0, 0, 0, 244)
posStatusLabel.BackgroundTransparency = 1
posStatusLabel.Text = hasSavedPosition and "Position Saved!" or "Error Position: Not Saved"
posStatusLabel.TextColor3 = hasSavedPosition and Color3.fromRGB(100, 220, 100) or Color3.fromRGB(220, 100, 100)
posStatusLabel.TextSize = 11
posStatusLabel.Font = Enum.Font.Gotham
posStatusLabel.Parent = mainFrame

local hideHintLabel = Instance.new("TextLabel")
hideHintLabel.Size = UDim2.new(1, 0, 0, 18)
hideHintLabel.Position = UDim2.new(0, 0, 0, 272)
hideHintLabel.BackgroundTransparency = 1
hideHintLabel.Text = "Hide UI: [ K ]"
hideHintLabel.TextColor3 = Color3.fromRGB(120, 120, 120)
hideHintLabel.TextSize = 10
hideHintLabel.Font = Enum.Font.Gotham
hideHintLabel.Parent = mainFrame

local function updateStatus(text, color)
    statusLabel.Text = "Status: " .. text
    statusLabel.TextColor3 = color
end

submitKeyButton.MouseButton1Click:Connect(function()
    savedKey = keyTextBox.Text
    if savedKey == correctKey then
        isKeyValid = true
        saveConfig() -- сохраняем правильный ключ в файл
        pcall(function() keyScreenGui:Destroy() end)
        screenGui.Enabled = true
    else
        submitKeyButton.Text = "Invalid Key!"
        submitKeyButton.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
        task.wait(1.5)
        submitKeyButton.Text = "Check Key"
        submitKeyButton.BackgroundColor3 = Color3.fromRGB(35, 110, 55)
    end
end)

local function saveCurrentPosition()
    local character = player.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        savedPosition = character.HumanoidRootPart.CFrame.Position
        hasSavedPosition = true
        saveConfig()
        posStatusLabel.Text = "Position Saved!"
        posStatusLabel.TextColor3 = Color3.fromRGB(100, 220, 100)
    else
        posStatusLabel.Text = "Error: Character not found!"
        posStatusLabel.TextColor3 = Color3.fromRGB(220, 80, 80)
    end
end
savePosButton.MouseButton1Click:Connect(saveCurrentPosition)

local function safeMoveTo(targetPos)
    local character = player.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        local hrp = character.HumanoidRootPart
        local distance = (hrp.Position - targetPos).Magnitude
        local baseSpeed = 150 
        local currentSpeed = math.max(baseSpeed * moveSpeedMultiplier, 5)
        local timeDuration = distance / currentSpeed
        
        local tweenInfo = TweenInfo.new(timeDuration, Enum.EasingStyle.Linear)
        local tween = TweenService:Create(hrp, tweenInfo, {CFrame = CFrame.new(targetPos)})
        tween:Play()
        task.wait(timeDuration)
    end
end

local function usePortal(portalName)
    local portal = workspace:FindFirstChild(portalName, true)
    if portal then
        local character = player.Character
        if character and character:FindFirstChild("HumanoidRootPart") then
            local hrp = character.HumanoidRootPart
            local targetCFrame = nil
            
            if portal:IsA("BasePart") then
                targetCFrame = portal.CFrame
            elseif portal:IsA("Model") then
                if portal.PrimaryPart then
                    targetCFrame = portal.PrimaryPart.CFrame
                else
                    local firstPart = portal:FindFirstChildWhichIsA("BasePart", true)
                    if firstPart then targetCFrame = firstPart.CFrame end
                end
            end
            
            if targetCFrame then
                hrp.CFrame = targetCFrame + Vector3.new(0, 2, 0)
                task.wait(0.2)
                
                if portal:IsA("BasePart") and type(firetouchinterest) == "function" then
                    firetouchinterest(hrp, portal, 0)
                    task.wait(0.05)
                    firetouchinterest(hrp, portal, 1)
                end
                
                task.wait(1.5)
                return true
            end
        end
    end
    return false
end

local function teleportToSavedPosition()
    usePortal("__TrialExitTeleport")
    task.wait(0.3)
    
    local character = player.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        if not hasSavedPosition then
            savedPosition = platePosition
            hasSavedPosition = true
        end
        
        local hrp = character.HumanoidRootPart
        hrp.CFrame = CFrame.new(savedPosition)
        task.wait(0.1)
        return true
    end
    return false
end

local function checkErrorTemplate()
    local errorTemplate = playerGui:FindFirstChild("ErrorTemplate", true)
    if errorTemplate and errorTemplate:IsA("GuiObject") and errorTemplate.Visible then
        return true
    end
    return false
end

local function leaveTrial()
    updateStatus("Leaving trial...", Color3.fromRGB(220, 140, 0))
    local found = false
    
    for _, descendant in ipairs(playerGui:GetDescendants()) do
        if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
            if string.find(descendant.Text:lower(), "leave trial") then
                local btn = descendant:FindFirstAncestorWhichIsA("GuiButton") or descendant
                if btn:IsA("GuiButton") then
                    pcall(function()
                        for _, connection in ipairs(getconnections(btn.MouseButton1Click)) do connection:Fire() end
                        for _, connection in ipairs(getconnections(btn.Activated)) do connection:Fire() end
                    end)
                end
                
                local absPos = btn.AbsolutePosition
                local absSize = btn.AbsoluteSize
                local targetX = absPos.X + absSize.X / 2
                local targetY = absPos.Y + absSize.Y / 2
                
                VirtualInputManager:SendMouseButtonEvent(targetX, targetY, 0, true, game, 0)
                task.wait(0.05)
                VirtualInputManager:SendMouseButtonEvent(targetX, targetY, 0, false, game, 0)
                
                found = true
                break
            end
        end
    end
    
    if not found then
        local viewportSize = camera.ViewportSize
        VirtualInputManager:SendMouseButtonEvent(viewportSize.X * 0.5, viewportSize.Y * 0.9, 0, true, game, 0)
        task.wait(0.05)
        VirtualInputManager:SendMouseButtonEvent(viewportSize.X * 0.5, viewportSize.Y * 0.9, 0, false, game, 0)
    end
    
    task.wait(0.8)
    usePortal("__TrialExitTeleport")
    task.wait(0.8)
end

local function getCurrentWave()
    for _, descendant in ipairs(playerGui:GetDescendants()) do
        if descendant:IsA("TextLabel") then
            local nameLower = descendant.Name:lower()
            local textLower = descendant.Text:lower()
            
            if nameLower == "wavecount" or string.find(textLower, "wave") or string.find(textLower, "волн") then
                for num in string.gmatch(descendant.Text, "%d+") do
                    local n = tonumber(num)
                    if n and n > 0 and n <= 100 then 
                        return n 
                    end
                end
            end
        end
    end
    
    for _, descendant in ipairs(playerGui:GetDescendants()) do
        if descendant:IsA("TextLabel") and descendant.Visible and descendant.Text ~= "" then
            for num in string.gmatch(descendant.Text, "%d+") do
                local n = tonumber(num)
                if n and n > 0 and n <= 50 then
                    return n
                end
            end
        end
    end
    
    return 0
end

local function startTrialSequenceWithPlate()
    isWaitingOnPlate = true
    updateStatus("Entering Chamber...", Color3.fromRGB(220, 140, 0))
    
    usePortal("__TrialTeleport")
    
    updateStatus("Plate: 0/60s", Color3.fromRGB(220, 140, 0))
    local character = player.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        safeMoveTo(platePosition)
    end
    
    local elapsed = 0
    while elapsed < 60 and isRunning do
        if checkErrorTemplate() then
            updateStatus("Error! Recovering...", Color3.fromRGB(220, 120, 0))
            teleportToSavedPosition()
            isWaitingOnPlate = false
            isBetweenRuns = true
            task.wait(5)
            return false
        end
        task.wait(1)
        elapsed = elapsed + 1
        updateStatus("Plate: " .. elapsed .. "/60s", Color3.fromRGB(220, 140, 0))
    end
    
    if checkErrorTemplate() then
        updateStatus("Error! Recovering...", Color3.fromRGB(220, 120, 0))
        teleportToSavedPosition()
        isWaitingOnPlate = false
        isBetweenRuns = true
        task.wait(5)
        return false
    end
    
    isWaitingOnPlate = false
    return true
end

local function toggleScript()
    if not isKeyValid then return end
    isRunning = not isRunning
    isWaitingOnPlate = false
    isBetweenRuns = false
    if isRunning then
        toggleButton.Text = "Disable (G)"
        toggleButton.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
        updateStatus("Waiting for timer...", Color3.fromRGB(220, 140, 0))
    else
        toggleButton.Text = "Enable (G)"
        toggleButton.BackgroundColor3 = Color3.fromRGB(35, 110, 55)
        updateStatus("OFF", Color3.fromRGB(220, 80, 80))
    end
end

toggleButton.MouseButton1Click:Connect(toggleScript)

local function toggleUI()
    if not isKeyValid then return end
    mainFrame.Visible = not mainFrame.Visible
end

if mobileToggleButton then
    mobileToggleButton.MouseButton1Click:Connect(toggleUI)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not isKeyValid then return end
    if input.KeyCode == Enum.KeyCode.G then
        toggleScript()
    elseif input.KeyCode == Enum.KeyCode.P then
        saveCurrentPosition()
    elseif input.KeyCode == Enum.KeyCode.K or input.KeyCode == Enum.KeyCode.L then
        toggleUI()
    end
end)

task.spawn(function()
    local lastTriggeredKey = ""
    while true do
        if isKeyValid then
            local date = os.date("*t")
            local currentMin = date.min
            local currentSec = date.sec
            local currentHour = date.hour
            local timeKey = currentHour .. ":" .. currentMin
            
            local matchedMinute = false
            for _, m in ipairs(targetMinutes) do
                if currentMin == m then
                    matchedMinute = true
                    break
                end
            end
            
            if matchedMinute and currentSec == 0 and lastTriggeredKey ~= timeKey then
                lastTriggeredKey = timeKey
                if isRunning and isBetweenRuns then
                    isBetweenRuns = false
                end
            elseif not matchedMinute then
                lastTriggeredKey = ""
            end
        end
        task.wait(0.2)
    end
end)

task.spawn(function()
    while true do
        if isKeyValid and isRunning and not isBetweenRuns and not isWaitingOnPlate then
            updateStatus("Checking plate...", Color3.fromRGB(220, 140, 0))
            local success = startTrialSequenceWithPlate()
            
            if success and isRunning then
                updateStatus("Mob Farming", Color3.fromRGB(80, 220, 80))
                
                while isKeyValid and isRunning and not isBetweenRuns and not checkErrorTemplate() do
                    local currentWave = getCurrentWave()
                    waveInfoLabel.Text = "Wave: " .. currentWave .. " / Target: " .. maxTargetWave
                    
                    if currentWave >= maxTargetWave and maxTargetWave > 0 then
                        leaveTrial()
                        teleportToSavedPosition()
                        isBetweenRuns = true
                        updateStatus("Target reached. Waiting...", Color3.fromRGB(120, 120, 220))
                        task.wait(5)
                        break
                    else
                        for index, pos in ipairs(mobPositions) do
                            if not isRunning or isBetweenRuns or checkErrorTemplate() then break end
                            
                            local activeWave = getCurrentWave()
                            waveInfoLabel.Text = "Wave: " .. activeWave .. " / Target: " .. maxTargetWave
                            
                            if activeWave >= maxTargetWave and maxTargetWave > 0 then
                                leaveTrial()
                                teleportToSavedPosition()
                                isBetweenRuns = true
                                updateStatus("Target reached. Waiting...", Color3.fromRGB(120, 120, 220))
                                break
                            end
                            
                            safeMoveTo(pos)
                            
                            local elapsed = 0
                            while elapsed < 0.5 and isRunning and not isBetweenRuns and not checkErrorTemplate() do
                                task.wait(0.1)
                                elapsed = elapsed + 0.1
                            end
                        end
                        
                        if isRunning and not isBetweenRuns then
                            local elapsed = 0
                            while elapsed < 3 and isRunning and not isBetweenRuns and not checkErrorTemplate() do
                                task.wait(0.2)
                                elapsed = elapsed + 0.2
                            end
                        end
                    end
                end
                
                if checkErrorTemplate() then
                    updateStatus("Error! Recovering...", Color3.fromRGB(220, 120, 0))
                    teleportToSavedPosition()
                    isBetweenRuns = true
                    task.wait(5)
                end
            end
        else
            task.wait(1)
        end
    end
end)
