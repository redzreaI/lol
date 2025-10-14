-- Módulo de X-Ray Base
local XRayModule = {}

local transparency = 0.8
local savedState = nil

function XRayModule.init(playerGui)
    savedState = Instance.new("BoolValue")
    savedState.Name = "BaseInvisibleState"
    savedState.Value = false
    savedState.Parent = playerGui
end

function XRayModule.setBaseInvisible(state)
    local Plots = workspace:WaitForChild("Plots", 30)
    if Plots then
        if state then
            for _,o in ipairs(Plots:GetDescendants()) do 
                if o:IsA("BasePart") then 
                    pcall(function() o.LocalTransparencyModifier = transparency end) 
                end 
            end
            Plots.DescendantAdded:Connect(function(o) 
                if o:IsA("BasePart") then 
                    pcall(function() o.LocalTransparencyModifier = transparency end) 
                end 
            end)
        else
            for _,o in ipairs(Plots:GetDescendants()) do 
                if o:IsA("BasePart") then 
                    pcall(function() o.LocalTransparencyModifier = 0 end) 
                end 
            end
        end
    end
end

return XRayModule