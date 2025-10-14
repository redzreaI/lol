-- Módulo de Float
local FloatModule = {}

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

-- Variáveis do módulo
local floatEnabled = false
local floatGui = nil
local floatMovementConnection = nil
local floatAntiGravityConnection = nil
local floatFlyConnection = nil
local floatIsMoving = false
local floatFlying = false
local floatDeliverySpeed = 21
local floatFlySpeed = 22

-- Função para encontrar DeliveryHitbox
local function findDeliveryHitbox()
    local plots = Workspace:FindFirstChild("Plots")
    if not plots then return nil end
    for _, plot in ipairs(plots:GetChildren()) do
        local sign = plot:FindFirstChild("PlotSign")
        if sign and sign:FindFirstChild("YourBase") and sign.YourBase.Enabled then
            local delivery = plot:FindFirstChild("DeliveryHitbox")
            if delivery then
                return delivery.Position
            end
        end
    end
    return nil
end

-- Função para parar movimento
local function stopFloatMovement(rootPart)
    floatIsMoving = false
    if floatMovementConnection then
        floatMovementConnection:Disconnect()
        floatMovementConnection = nil
    end
    if floatAntiGravityConnection then
        floatAntiGravityConnection:Disconnect()
        floatAntiGravityConnection = nil
    end
    
    if rootPart and rootPart.Parent then
        rootPart.AssemblyLinearVelocity = Vector3.new(0,0,0)
        task.wait(0.1)
        rootPart.AssemblyLinearVelocity = Vector3.new(0,-50,0)
    end
end

-- Função para iniciar movimento
local function startFloatMovement(rootPart, updateCharacterRefsFn)
    if floatIsMoving then return end
    local deliveryPos = findDeliveryHitbox()
    if not deliveryPos then return end
    floatIsMoving = true
    
    updateCharacterRefsFn()
    
    floatAntiGravityConnection = RunService.Heartbeat:Connect(function()
        if not floatIsMoving or not rootPart or not rootPart.Parent then return end
        if floatFlying then return end
        
        local currentVel = rootPart.AssemblyLinearVelocity
        rootPart.AssemblyLinearVelocity = Vector3.new(currentVel.X, 0, currentVel.Z)
    end)
    
    floatMovementConnection = RunService.Heartbeat:Connect(function()
        if not floatIsMoving or not rootPart or not rootPart.Parent then 
            stopFloatMovement(rootPart) 
            return 
        end
        
        local currentPos = rootPart.Position
        local direction = Vector3.new(deliveryPos.X - currentPos.X, 0, deliveryPos.Z - currentPos.Z)
        local horizontalDistance = direction.Magnitude
        
        if horizontalDistance <= 3 then
            stopFloatMovement(rootPart)
            return
        end
        
        local velocity = direction.Unit * floatDeliverySpeed
        velocity = Vector3.new(velocity.X, 0, velocity.Z)
        
        if floatFlying then
            local flyVel = rootPart.AssemblyLinearVelocity
            velocity = Vector3.new(velocity.X, flyVel.Y, velocity.Z)
        end
        
        rootPart.AssemblyLinearVelocity = velocity
    end)
end

-- Função para toggle fly
local function toggleFloatFly(rootPart)
    floatFlying = not floatFlying
    if not floatFlying and rootPart and rootPart.Parent then
        rootPart.AssemblyLinearVelocity = Vector3.new(0,0,0)
    end
end

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

-- Função para criar GUI
local function createFloatGui(playerGui, Labs, activetheme, rootPart, updateCharacterRefsFn)
    if floatGui then return end
    
    local colors = getCurrentThemeColors(Labs, activetheme)
    
    local sg = Instance.new("ScreenGui")
    sg.Name = "DeliveryTPGui"
    sg.ResetOnSpawn = false
    sg.DisplayOrder = 999
    sg.Parent = playerGui
    floatGui = sg
    
    local mf = Instance.new("Frame")
    mf.Size = UDim2.new(0, 200, 0, 80)
    mf.Position = UDim2.new(0.5, -100, 0, 20)
    mf.BackgroundColor3 = colors.SURFACE
    mf.BackgroundTransparency = 0.1
    mf.BorderSizePixel = 0
    mf.Active = true
    mf.Draggable = true
    mf.Parent = sg
    
    Instance.new("UICorner", mf).CornerRadius = UDim.new(0, 16)
    
    local hd = Instance.new("Frame")
    hd.Size = UDim2.new(1, 0, 0, 30)
    hd.BackgroundColor3 = colors.CARD
    hd.BackgroundTransparency = 0.2
    hd.BorderSizePixel = 0
    hd.ZIndex = 2
    hd.Parent = mf
    Instance.new("UICorner", hd).CornerRadius = UDim.new(0, 16)
    
    local tt = Instance.new("TextLabel")
    tt.Size = UDim2.new(1, -40, 0, 20)
    tt.Position = UDim2.new(0, 10, 0, 5)
    tt.BackgroundTransparency = 1
    tt.Text = "Labs Hub - Float"
    tt.TextColor3 = colors.TEXT_PRIMARY
    tt.Font = Enum.Font.GothamBold
    tt.TextSize = 12
    tt.TextXAlignment = Enum.TextXAlignment.Left
    tt.Parent = hd
    
    local sb = Instance.new("TextButton")
    sb.Size = UDim2.new(0.45, -5, 0, 25)
    sb.Position = UDim2.new(0.025, 0, 0.4, 0)
    sb.BackgroundColor3 = colors.SUCCESS
    sb.BorderSizePixel = 0
    sb.Text = "START"
    sb.TextColor3 = colors.TEXT_PRIMARY
    sb.Font = Enum.Font.GothamBold
    sb.TextSize = 10
    sb.Parent = mf
    Instance.new("UICorner", sb).CornerRadius = UDim.new(0, 8)
    
    local stb = Instance.new("TextButton")
    stb.Size = UDim2.new(0.45, -5, 0, 25)
    stb.Position = UDim2.new(0.525, 0, 0.4, 0)
    stb.BackgroundColor3 = colors.DANGER
    stb.BorderSizePixel = 0
    stb.Text = "STOP"
    stb.TextColor3 = colors.TEXT_PRIMARY
    stb.Font = Enum.Font.GothamBold
    stb.TextSize = 10
    stb.Parent = mf
    Instance.new("UICorner", stb).CornerRadius = UDim.new(0, 8)
    
    local fl = Instance.new("TextLabel")
    fl.Size = UDim2.new(1, -10, 0, 15)
    fl.Position = UDim2.new(0, 5, 0.75, 0)
    fl.BackgroundTransparency = 1
    fl.Text = "Fly: F key"
    fl.TextColor3 = colors.TEXT_SECONDARY
    fl.Font = Enum.Font.Gotham
    fl.TextSize = 9
    fl.TextXAlignment = Enum.TextXAlignment.Center
    fl.Parent = mf
    
    sb.MouseButton1Click:Connect(function()
        startFloatMovement(rootPart, updateCharacterRefsFn)
    end)
    stb.MouseButton1Click:Connect(function()
        stopFloatMovement(rootPart)
    end)
    
    sb.MouseEnter:Connect(function() TweenService:Create(sb, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundColor3 = Color3.fromRGB(22, 163, 74)}):Play() end)
    sb.MouseLeave:Connect(function() TweenService:Create(sb, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundColor3 = colors.SUCCESS}):Play() end)
    stb.MouseEnter:Connect(function() TweenService:Create(stb, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundColor3 = Color3.fromRGB(185, 28, 28)}):Play() end)
    stb.MouseLeave:Connect(function() TweenService:Create(stb, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {BackgroundColor3 = colors.DANGER}):Play() end)
end

-- Função para remover GUI
local function removeFloatGui()
    if floatGui then
        pcall(function() floatGui:Destroy() end)
        floatGui = nil
    end
end

-- Funções públicas
function FloatModule.enable(playerGui, Labs, activetheme, rootPart, updateCharacterRefsFn)
    floatEnabled = true
    createFloatGui(playerGui, Labs, activetheme, rootPart, updateCharacterRefsFn)
    
    if not floatFlyConnection then
        floatFlyConnection = UserInputService.InputBegan:Connect(function(input, gp)
            if gp then return end
            if not floatEnabled then return end
            if input.KeyCode == Enum.KeyCode.F then
                toggleFloatFly(rootPart)
            end
        end)
    end
    
    task.spawn(function()
        while floatEnabled do
            if floatFlying and rootPart and rootPart.Parent then
                updateCharacterRefsFn()
                
                local moveDir = Vector3.new()
                local cam = workspace.CurrentCamera.CFrame
                local horizontalLook = Vector3.new(cam.LookVector.X,0,cam.LookVector.Z).Unit
                local horizontalRight = Vector3.new(cam.RightVector.X,0,cam.RightVector.Z).Unit
                
                if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir += horizontalLook end
                if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir -= horizontalLook end
                if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir -= horizontalRight end
                if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir += horizontalRight end
                if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir += Vector3.new(0,1,0) end
                if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then moveDir -= Vector3.new(0,1,0) end
                
                rootPart.AssemblyLinearVelocity = moveDir.Magnitude > 0 and moveDir.Unit * floatFlySpeed or Vector3.new(0,0,0)
            end
            task.wait()
        end
    end)
end

function FloatModule.disable(rootPart)
    floatEnabled = false
    stopFloatMovement(rootPart)
    floatFlying = false
    removeFloatGui()
    
    if floatFlyConnection then
        floatFlyConnection:Disconnect()
        floatFlyConnection = nil
    end
    
    if rootPart and rootPart.Parent then
        rootPart.AssemblyLinearVelocity = Vector3.new(0,0,0)
    end
end

function FloatModule.isEnabled()
    return floatEnabled
end

return FloatModule

