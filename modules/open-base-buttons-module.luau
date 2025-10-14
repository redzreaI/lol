-- Módulo de Open Base Buttons
local OpenBaseButtonsModule = {}

local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local openBaseButtonsEnabled = false
local openBaseButtonsGui = nil
local nearestPrompts = {}

-- Função para obter cores do tema atual
local function getCurrentThemeColors(Labs, activetheme)
    local themeName = Labs.ActiveTheme or activetheme or "Normal"
    
    local themeColors = {
        Normal = {
            PRIMARY = Color3.fromRGB(99, 102, 241),
            SUCCESS = Color3.fromRGB(34, 197, 94),
            DANGER = Color3.fromRGB(239, 68, 68),
            SURFACE = Color3.fromRGB(30, 41, 59),
            CARD = Color3.fromRGB(51, 65, 85),
            TEXT_PRIMARY = Color3.fromRGB(248, 250, 252),
            TEXT_SECONDARY = Color3.fromRGB(148, 163, 184),
            BORDER = Color3.fromRGB(71, 85, 105)
        },
        White = {
            PRIMARY = Color3.fromRGB(59, 130, 246),
            SUCCESS = Color3.fromRGB(34, 197, 94),
            DANGER = Color3.fromRGB(239, 68, 68),
            SURFACE = Color3.fromRGB(255, 255, 255),
            CARD = Color3.fromRGB(249, 250, 251),
            TEXT_PRIMARY = Color3.fromRGB(17, 24, 39),
            TEXT_SECONDARY = Color3.fromRGB(107, 114, 128),
            BORDER = Color3.fromRGB(229, 231, 235)
        },
        Dark = {
            PRIMARY = Color3.fromRGB(99, 102, 241),
            SUCCESS = Color3.fromRGB(34, 197, 94),
            DANGER = Color3.fromRGB(239, 68, 68),
            SURFACE = Color3.fromRGB(20, 20, 25),
            CARD = Color3.fromRGB(35, 35, 42),
            TEXT_PRIMARY = Color3.fromRGB(255, 255, 255),
            TEXT_SECONDARY = Color3.fromRGB(160, 160, 170),
            BORDER = Color3.fromRGB(50, 50, 58)
        },
        ExtraDark = {
            PRIMARY = Color3.fromRGB(99, 102, 241),
            SUCCESS = Color3.fromRGB(34, 197, 94),
            DANGER = Color3.fromRGB(239, 68, 68),
            SURFACE = Color3.fromRGB(0, 0, 0),
            CARD = Color3.fromRGB(18, 18, 22),
            TEXT_PRIMARY = Color3.fromRGB(255, 255, 255),
            TEXT_SECONDARY = Color3.fromRGB(140, 140, 150),
            BORDER = Color3.fromRGB(30, 30, 35)
        },
        Ruby = {
            PRIMARY = Color3.fromRGB(185, 28, 28),
            SUCCESS = Color3.fromRGB(34, 197, 94),
            DANGER = Color3.fromRGB(254, 226, 226),
            SURFACE = Color3.fromRGB(25, 15, 15),
            CARD = Color3.fromRGB(45, 20, 20),
            TEXT_PRIMARY = Color3.fromRGB(254, 226, 226),
            TEXT_SECONDARY = Color3.fromRGB(185, 120, 120),
            BORDER = Color3.fromRGB(127, 29, 29)
        },
        WhiteRuby = {
            PRIMARY = Color3.fromRGB(225, 29, 72),
            SUCCESS = Color3.fromRGB(34, 197, 94),
            DANGER = Color3.fromRGB(190, 18, 60),
            SURFACE = Color3.fromRGB(255, 250, 252),
            CARD = Color3.fromRGB(254, 242, 247),
            TEXT_PRIMARY = Color3.fromRGB(63, 17, 30),
            TEXT_SECONDARY = Color3.fromRGB(136, 19, 55),
            BORDER = Color3.fromRGB(251, 207, 232)
        }
    }
    
    return themeColors[themeName] or themeColors.Normal
end

local function getPosition(obj)
    if obj:IsA("BasePart") then return obj.Position end
    if obj:IsA("Model") then
        if obj.PrimaryPart then return obj.PrimaryPart.Position end
        for _,v in ipairs(obj:GetDescendants()) do
            if v:IsA("BasePart") then return v.Position end
        end
    end
    return nil
end

local function updateNearestPrompts(lp)
    local hrp = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local temp = {[1]={prompt=nil, dist=math.huge}, [2]={prompt=nil, dist=math.huge}, [3]={prompt=nil, dist=math.huge}}
    
    local plots = Workspace:WaitForChild("Plots", 10)
    if not plots then return end

    for _, plot in ipairs(plots:GetChildren()) do
        if plot:IsA("Model") then
            local unlock = plot:FindFirstChild("Unlock")
            if unlock then
                for _, main in ipairs(unlock:GetChildren()) do
                    if main.Name == "Main" then
                        local unlockBase = main:FindFirstChild("UnlockBase")
                        if unlockBase and unlockBase:IsA("ProximityPrompt") then
                            local floorAttr = unlockBase:GetAttribute("Floor")
                            local floorNum = tonumber(floorAttr)
                            
                            if floorNum and floorNum >= 1 and floorNum <= 3 then
                                local pos = getPosition(main) or getPosition(unlockBase)
                                if pos then
                                    local dist = (hrp.Position - pos).Magnitude
                                    
                                    if dist < temp[floorNum].dist then
                                        temp[floorNum] = {prompt=unlockBase, dist=dist}
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    nearestPrompts = temp
end

local function firePrompt(prompt, lp)
    if not prompt then return end
    
    local success = false
    
    if typeof(fireproximityprompt) == "function" then
        success = pcall(fireproximityprompt, prompt)
        if success then return end
    end
    
    if prompt.Enabled and prompt.RequiresLineOfSight == false then
        success = pcall(function()
            prompt:InputHoldBegin()
            task.wait(0.1)
            prompt:InputHoldEnd()
        end)
        if success then return end
    end

    if lp.Character and lp.Character:FindFirstChild("HumanoidRootPart") then
        local hrp = lp.Character.HumanoidRootPart
        local originalPos = hrp.CFrame

        local promptPos = getPosition(prompt.Parent) or getPosition(prompt)
        if promptPos then
            hrp.CFrame = CFrame.new(promptPos + Vector3.new(0, 5, 0))
            task.wait(0.2)
            
            if typeof(fireproximityprompt) == "function" then
                pcall(fireproximityprompt, prompt)
            end

            task.wait(0.3)
            hrp.CFrame = originalPos
        end
    end
end

function OpenBaseButtonsModule.create(playerGui, Labs, activetheme, lp)
    if openBaseButtonsGui then return end
    
    local plots = Workspace:WaitForChild("Plots", 10)
    if not plots then return end

    local BTN_COLORS = getCurrentThemeColors(Labs, activetheme)

    local gui = Instance.new("ScreenGui")
    gui.Name = "FloorGui"
    gui.Parent = playerGui
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 998

    openBaseButtonsGui = gui

    local function createFloorButton(floorNum, yOffset)
        local btnContainer = Instance.new("Frame")
        btnContainer.Name = "Floor"..floorNum.."Container"
        btnContainer.Size = UDim2.new(0, 65, 0, 65)
        btnContainer.Position = UDim2.new(1, -85, 0.5, yOffset)
        btnContainer.BackgroundColor3 = BTN_COLORS.CARD
        btnContainer.BackgroundTransparency = 0.2
        btnContainer.BorderSizePixel = 0
        btnContainer.ZIndex = 1
        btnContainer.Parent = gui
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 12)
        corner.Parent = btnContainer
        
        local stroke = Instance.new("UIStroke")
        stroke.Color = BTN_COLORS.PRIMARY
        stroke.Thickness = 2
        stroke.Transparency = 0.5
        stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        stroke.Parent = btnContainer
        
        local btn = Instance.new("TextButton")
        btn.Name = "Floor"..floorNum
        btn.Size = UDim2.new(1, 0, 1, 0)
        btn.BackgroundTransparency = 1
        btn.Text = floorNum
        btn.TextColor3 = BTN_COLORS.TEXT_PRIMARY
        btn.TextSize = 28
        btn.Font = Enum.Font.GothamBold
        btn.ZIndex = 2
        btn.Parent = btnContainer
        
        local glow = Instance.new("Frame")
        glow.Name = "Glow"
        glow.Size = UDim2.new(1, 6, 1, 6)
        glow.Position = UDim2.new(0.5, 0, 0.5, 0)
        glow.AnchorPoint = Vector2.new(0.5, 0.5)
        glow.BackgroundColor3 = BTN_COLORS.SUCCESS
        glow.BackgroundTransparency = 1
        glow.BorderSizePixel = 0
        glow.ZIndex = 0
        glow.Parent = btnContainer
        
        local glowCorner = Instance.new("UICorner")
        glowCorner.CornerRadius = UDim.new(0, 14)
        glowCorner.Parent = glow
        
        btn.MouseEnter:Connect(function()
            pcall(function()
                TweenService:Create(btnContainer, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.05}):Play()
                TweenService:Create(stroke, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
                    Color = Color3.fromRGB(239, 68, 68),
                    Transparency = 0.2
                }):Play()
                TweenService:Create(glow, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
                    BackgroundColor3 = Color3.fromRGB(239, 68, 68),
                    BackgroundTransparency = 0.7
                }):Play()
            end)
        end)
        
        btn.MouseLeave:Connect(function()
            pcall(function()
                TweenService:Create(btnContainer, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.2}):Play()
                TweenService:Create(stroke, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
                    Color = BTN_COLORS.PRIMARY,
                    Transparency = 0.5
                }):Play()
                TweenService:Create(glow, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
                    BackgroundColor3 = BTN_COLORS.SUCCESS,
                    BackgroundTransparency = 1
                }):Play()
            end)
        end)
        
        return btn, btnContainer, glow, stroke
    end

    local buttons = {
        {createFloorButton(1, -110)},
        {createFloorButton(2, -35)},
        {createFloorButton(3, 40)}
    }
    
    nearestPrompts = {[1]={prompt=nil, dist=math.huge}, [2]={prompt=nil, dist=math.huge}, [3]={prompt=nil, dist=math.huge}}
    
    task.spawn(function()
        while openBaseButtonsEnabled and task.wait(0.2) do
            pcall(function()
                updateNearestPrompts(lp)

                for i = 1, 3 do
                    if nearestPrompts[i].prompt then
                        pcall(function()
                            TweenService:Create(buttons[i][3], TweenInfo.new(0.3, Enum.EasingStyle.Quad), {BackgroundTransparency = 0.6}):Play()
                            TweenService:Create(buttons[i][4], TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
                                Color = BTN_COLORS.SUCCESS,
                                Transparency = 0.3
                            }):Play()
                        end)
                    else
                        pcall(function()
                            TweenService:Create(buttons[i][3], TweenInfo.new(0.3, Enum.EasingStyle.Quad), {BackgroundTransparency = 1}):Play()
                            TweenService:Create(buttons[i][4], TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
                                Color = BTN_COLORS.PRIMARY,
                                Transparency = 0.5
                            }):Play()
                        end)
                    end
                end
            end)
        end
    end)

    buttons[1][1].MouseButton1Click:Connect(function() firePrompt(nearestPrompts[1].prompt, lp) end)
    buttons[2][1].MouseButton1Click:Connect(function() firePrompt(nearestPrompts[2].prompt, lp) end)
    buttons[3][1].MouseButton1Click:Connect(function() firePrompt(nearestPrompts[3].prompt, lp) end)
    
    openBaseButtonsEnabled = true
end

function OpenBaseButtonsModule.remove()
    openBaseButtonsEnabled = false
    
    if openBaseButtonsGui then
        pcall(function() openBaseButtonsGui:Destroy() end)
        openBaseButtonsGui = nil
    end
end

function OpenBaseButtonsModule.isEnabled()
    return openBaseButtonsEnabled
end

return OpenBaseButtonsModule

