local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")

local player = Players.LocalPlayer

local CONFIG = {
    GrindEnabled = false,
    AutoTeleportEnabled = false,
    SelectedDifficulty = "Hard",
    MaxWave = 30,
    MoveSpeed = 100,
}

local savedPosition = CFrame.new(0, 5, 0)
local isFarming = false
local isLeaving = false
local isMoving = false
local isWaiting = false
local isEntering = false

task.spawn(function()
    while true do
        task.wait(60)
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:Button2Down(Vector2.new(0, 0))
            task.wait(0.1)
            VirtualUser:Button2Up(Vector2.new(0, 0))
        end)
    end
end)

local function getHRP()
    local char = player.Character
    if char then
        return char:FindFirstChild("HumanoidRootPart")
    end
    return nil
end

task.spawn(function()
    task.wait(1)
    local hrp = getHRP()
    if hrp then
        savedPosition = hrp.CFrame
    end
end)

local function teleportTo(cframe)
    local hrp = getHRP()
    if hrp then
        hrp.CFrame = cframe
    end
end

local function safeMoveTo(targetCFrame)
    if isMoving then return end
    isMoving = true
    local hrp = getHRP()
    if hrp then
        local distance = (hrp.Position - targetCFrame.Position).Magnitude
        if distance < 2 then
            isMoving = false
            return
        end
        local timeSec = distance / CONFIG.MoveSpeed
        if timeSec < 0.1 then timeSec = 0.1 end
        local tween = TweenService:Create(hrp, TweenInfo.new(timeSec, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = targetCFrame})
        tween:Play()
        local startTime = tick()
        while tween.PlaybackState == Enum.PlaybackState.Playing and (tick() - startTime) < (timeSec + 0.5) do
            if not CONFIG.GrindEnabled then
                tween:Cancel()
                break
            end
            RunService.Heartbeat:Wait()
        end
    end
    isMoving = false
end

local function getPlateCFrame(plateName)
    local plate = workspace:FindFirstChild(plateName)
    if plate then
        if plate:IsA("BasePart") then
            return plate.CFrame + Vector3.new(0, 3, 0)
        elseif plate:IsA("Model") then
            local part = plate.PrimaryPart or plate:FindFirstChildWhichIsA("BasePart")
            if part then
                return part.CFrame + Vector3.new(0, 3, 0)
            end
        end
    end
    return nil
end

local function getDifficultyPlateCFrame(difficulty)
    return getPlateCFrame("__Trial" .. difficulty .. "Plate")
end

local function findUIElement(name)
    local success, result = pcall(function()
        return player.PlayerGui:FindFirstChild(name, true)
    end)
    if success then
        return result
    end
    return nil
end

local function getEnemiesCount()
    local count = 0
    pcall(function()
        local label = findUIElement("Enemies")
        if label and label:IsA("TextLabel") then
            local parsed = tonumber(string.match(label.Text, "%d+"))
            if parsed then
                count = parsed
            end
        end
    end)
    return count
end

local function getCurrentWave()
    local wave = 0
    pcall(function()
        local label = findUIElement("WaveCount")
        if label and label:IsA("TextLabel") then
            local parsed = tonumber(string.match(label.Text, "%d+"))
            if parsed then
                wave = parsed
            end
        end
    end)
    return wave
end

local function getRoomCFrame(difficulty)
    local path = workspace:FindFirstChild("__GAME_CONTENT")
    if path then
        local room = path.Trials:FindFirstChild(difficulty .. "TrialRoom")
        if room then
            local trial = room:FindFirstChild("__Trial" .. difficulty .. "Room")
            if trial then
                if trial:IsA("Model") then
                    return trial:GetPivot() + Vector3.new(0, 3, 0)
                elseif trial:IsA("BasePart") then
                    return trial.CFrame + Vector3.new(0, 3, 0)
                end
            end
        end
    end
    return nil
end

local function enterTrial()
    if isEntering then return end
    isEntering = true
    pcall(function()
        local entryPlate = getPlateCFrame("__TrialTeleport")
        if entryPlate then
            teleportTo(entryPlate)
            task.wait(1)
        else
            isEntering = false
            return
        end
        local diffPlate = getDifficultyPlateCFrame(CONFIG.SelectedDifficulty)
        if diffPlate then
            teleportTo(diffPlate)
            task.wait(1)
        else
            isEntering = false
            return
        end
        local startTime = tick()
        local trialStarted = false
        while tick() - startTime < 60 do
            local wave = getCurrentWave()
            if wave > 0 then
                trialStarted = true
                break
            end
            task.wait(1)
        end
        if not trialStarted then
            local roomCFrame = getRoomCFrame(CONFIG.SelectedDifficulty)
            if roomCFrame then
                teleportTo(roomCFrame)
                task.wait(2)
            else
                isEntering = false
                return
            end
        end
        if CONFIG.GrindEnabled and not isFarming then
            task.wait(1)
            startGrindLoop()
        end
    end)
    isEntering = false
end

local function leaveTrial()
    if isLeaving then return end
    isLeaving = true
    isFarming = false
    CONFIG.GrindEnabled = false
    pcall(function()
        local mainRemote = ReplicatedStorage:FindFirstChild("__Net") and ReplicatedStorage.__Net:FindFirstChild("MainRemote")
        if mainRemote then
            mainRemote:FireServer("LeaveTrial")
            task.wait(2)
        else
            local net = ReplicatedStorage:FindFirstChild("__Net")
            if net then
                local promptNotif = net:FindFirstChild("PromptNotification")
                if promptNotif then
                    firesignal(promptNotif.OnClientEvent, "Succes", "You left the " .. CONFIG.SelectedDifficulty .. " Trial.", false)
                    task.wait(2)
                end
            end
        end
        local exitPlate = getPlateCFrame("__TrialExitTeleport")
        if exitPlate then
            teleportTo(exitPlate)
            task.wait(1)
        end
        teleportTo(savedPosition)
    end)
    isLeaving = false
end

local mobsPositions = {
    Vector3.new(746.33, 9.15, 13745.45),
    Vector3.new(750.18, 9.15, 13785.91),
    Vector3.new(720.82, 9.15, 13779.53),
    Vector3.new(720.95, 9.15, 13749.76),
    Vector3.new(689.12, 9.10, 13752.79),
    Vector3.new(690.64, 9.10, 13779.70),
    Vector3.new(655.92, 9.23, 13765.90)
}

local function startGrindLoop()
    if isFarming then return end
    isFarming = true
    task.spawn(function()
        local lastWave = -1
        local posIndex = 1
        while isFarming and CONFIG.GrindEnabled do
            if isWaiting then
                task.wait(0.5)
                continue
            end
            local currentWave = getCurrentWave()
            if currentWave <= 0 then
                task.wait(0.5)
                continue
            end
            if currentWave ~= lastWave then
                lastWave = currentWave
                posIndex = 1
            end
            if currentWave > CONFIG.MaxWave then
                Rayfield:Notify({Title = "Trial Bot", Content = "Max wave " .. CONFIG.MaxWave .. " reached! Leaving...", Duration = 3})
                leaveTrial()
                break
            end
            local enemiesCount = getEnemiesCount()
            if enemiesCount > 0 then
                posIndex = posIndex + 1
                if posIndex > #mobsPositions then
                    posIndex = 1
                end
                local hrp = getHRP()
                if hrp then
                    local distance = (hrp.Position - mobsPositions[posIndex]).Magnitude
                    if distance > 4 then
                        safeMoveTo(CFrame.new(mobsPositions[posIndex]))
                    end
                end
            end
            task.wait(0.3)
        end
        isFarming = false
    end)
end

task.spawn(function()
    while true do
        if CONFIG.AutoTeleportEnabled then
            local serverTime = workspace:GetServerTimeNow()
            local minuteInHour = (serverTime / 60) % 60
            local targetMinute = 29
            if minuteInHour >= 30 and minuteInHour < 60 then
                targetMinute = 59
            end
            local currentMinute = math.floor(minuteInHour)
            local currentSeconds = serverTime % 60
            local targetTime = targetMinute * 60
            local nowTime = (currentMinute * 60) + currentSeconds
            local diff = targetTime - nowTime
            if diff < -5 then
                diff = diff + 1800
            end
            if diff <= 1 and diff >= -1 then
                enterTrial()
            end
        end
        task.wait(0.5)
    end
end)

local Window = Rayfield:CreateWindow({
    Name = "⚡ WlChecker | Trial Bot",
    LoadingTitle = "Loading...",
    LoadingSubtitle = "by WlChecker",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false
})

local MainTab = Window:CreateTab("Main", 4483362458)

MainTab:CreateDropdown({
    Name = "Trial Difficulty",
    Options = {"Easy", "Medium", "Hard"},
    CurrentOption = {"Hard"},
    MultipleOptions = false,
    Flag = "DropdownDifficulty",
    Callback = function(Option)
        CONFIG.SelectedDifficulty = Option[1]
    end,
})

MainTab:CreateSlider({
    Name = "Movement Speed",
    Range = {50, 100},
    Increment = 5,
    CurrentValue = 100,
    Flag = "SliderSpeed",
    Callback = function(Value)
        CONFIG.MoveSpeed = Value
    end,
})

MainTab:CreateToggle({
    Name = "Auto-Teleport Timer",
    CurrentValue = false,
    Flag = "ToggleAutoTp",
    Callback = function(Value)
        CONFIG.AutoTeleportEnabled = Value
    end,
})

MainTab:CreateToggle({
    Name = "Trial Grind",
    CurrentValue = false,
    Flag = "ToggleGrind",
    Callback = function(Value)
        CONFIG.GrindEnabled = Value
        if Value then
            if getCurrentWave() > 0 and not isFarming then
                task.wait(1)
                startGrindLoop()
            end
        else
            isFarming = false
        end
    end,
})

MainTab:CreateInput({
    Name = "Max Wave Limit",
    CurrentValue = "30",
    PlaceholderText = "Enter max wave",
    RemoveTextAfterFocusLost = false,
    Flag = "InputMaxWave",
    Callback = function(Text)
        local num = tonumber(Text)
        if num then
            CONFIG.MaxWave = num
        end
    end,
})

MainTab:CreateButton({
    Name = "Save Position",
    Callback = function()
        local hrp = getHRP()
        if hrp then
            savedPosition = hrp.CFrame
            Rayfield:Notify({Title = "Saved", Content = "Position saved!", Duration = 2})
        end
    end,
})