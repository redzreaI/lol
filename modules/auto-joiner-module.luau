-- Módulo de Auto Joiner
local AutoJoinerModule = {}

local TPS = game:GetService("TeleportService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local wsConnection = nil
local isWebSocketConnected = false
local wsReconnectAttempts = 0
local maxWsReconnectAttempts = 5
local useWebSocket = true
local lastJobCheck = 0
local jobCheckInterval = 1

local jobBanner = nil
local jobSound = nil
local manualTeleportActive = false
local manualTeleportJobId = nil
local manualTeleportAttempts = 0
local maxManualTeleportAttempts = 45

-- Mapa de encode/decode
local encode_map = {
    a="G7Q", b="L2R", c="M8X", d="K5T", e="N9V", f="P3Z", g="Q6B", h="R1F",
    i="S4J", j="T0M", k="U7C", l="V2G", m="W8K", n="X5N", o="Y9P", p="Z3S",
    q="A6U", r="B1X", s="C4A", t="D0D", u="E7F", v="F2H", w="H8J", x="I5L",
    y="J9O", z="K3Q",
    A="m6Z", B="n1B", C="o4D", D="p0F", E="q7H", F="r2J", G="s8L", H="t5N",
    I="u9P", J="v3R", K="w6T", L="x1V", M="y4X", N="z0A", O="A7C", P="B2E",
    Q="C8G", R="D5I", S="E9K", T="F3M", U="G6O", V="H1Q", W="I4S", X="J0U",
    Y="K7W", Z="L2Y",
    ["0"]="p7Q", ["1"]="q2R", ["2"]="r8T", ["3"]="s5V", ["4"]="t9X", ["5"]="u3Z",
    ["6"]="v6B", ["7"]="w1D", ["8"]="x4F", ["9"]="y0H", ["-"]="z7J"
}

local function decode_jobid(encoded)
    local decode_map = {}
    for k, v in pairs(encode_map) do
        decode_map[v] = k
    end

    local job_id = ""
    for i = 9, #encoded, 3 do
        local code = encoded:sub(i, i+2)
        if decode_map[code] then
            job_id = job_id .. decode_map[code]
        else
            job_id = job_id .. "?"
        end
    end

    return job_id
end

local function extractMutationAndBaseName(brainrotName)
    local BRAINROT_MUTATIONS = {
        ["Rainbow"] = true,
        ["Diamond"] = true,
        ["Gold"] = true,
        ["Galaxy"] = true,
        ["Bloodrot"] = true,
        ["Yin Yang"] = true,
        ["Lava"] = true
    }
    
    local mutation = nil
    local baseName = brainrotName
    
    for mutationName, _ in pairs(BRAINROT_MUTATIONS) do
        if brainrotName:find("^" .. mutationName .. " ") then
            mutation = mutationName
            baseName = brainrotName:sub(#mutationName + 2)
            break
        end
    end
    
    return mutation, baseName
end

local function isBrainrotValid(brainrotName, selectedMethod)
    local mutation, baseName = extractMutationAndBaseName(brainrotName)

    local brainrotNameLower = baseName:lower()
    local selectedMethodLower = selectedMethod:lower()

    return brainrotNameLower:find(selectedMethodLower, 1, true) ~= nil
end

local function getBrasiliaTime()
    local timeAPI = "https://worldtimeapi.org/api/timezone/America/Sao_Paulo"
    local requestFunc = http_request or request or (syn and syn.request) or (fluxus and fluxus.request) or (http and http.request)
    
    if not requestFunc then
        return os.time() - (3 * 3600)
    end
    
    local success, res = pcall(function()
        return requestFunc({
            Url = timeAPI,
            Method = "GET",
            Headers = {
                ["Content-Type"] = "application/json",
                ["User-Agent"] = "Roblox/AutoJoiner"
            }
        })
    end)
    
    if not success or not res then
        return os.time() - (3 * 3600)
    end
    
    local body = res.Body or res.body or res[1]
    if not body or body == "" then
        return os.time() - (3 * 3600)
    end
    
    if type(body) ~= "string" then
        body = tostring(body)
    end
    body = body:gsub("[\n\r]", ""):gsub("%s+$", "")
    
    local ok, data = pcall(function()
        return HttpService:JSONDecode(body)
    end)
    
    if not ok or not data then
        return os.time() - (3 * 3600)
    end
    
    local timestamp = data.unixtime or data.timestamp or data.unix
    if timestamp then
        return timestamp
    end
    
    if data.datetime then
        local year, month, day, hour, min, sec, tz_sign, tz_hour = data.datetime:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)([%+%-])(%d+)")
        if year then
            local utcTime = os.time({
                year = tonumber(year),
                month = tonumber(month),
                day = tonumber(day),
                hour = tonumber(hour),
                min = tonumber(min),
                sec = tonumber(sec)
            })
            
            if tz_sign and tz_hour then
                local offset = tonumber(tz_hour) * 3600
                if tz_sign == "-" then
                    utcTime = utcTime + offset
                else
                    utcTime = utcTime - offset
                end
            end
            
            return utcTime
        end
    end
    
    return os.time() - (3 * 3600)
end

local function parseTimer(timerStr)
    if not timerStr or type(timerStr) ~= "string" then
        return 0
    end
    
    local day, month, year, hour, min, sec = timerStr:match("(%d+)/(%d+)/(%d+) (%d+):(%d+):(%d+)")
    
    if not day then
        return 0
    end
    
    local jobTimestamp = os.time({
        year = tonumber(year),
        month = tonumber(month),
        day = tonumber(day),
        hour = tonumber(hour),
        min = tonumber(min),
        sec = tonumber(sec)
    })
    
    return jobTimestamp
end

local function getJobsHTTP(url)
    local requestFunc = http_request or request or (syn and syn.request) or (fluxus and fluxus.request) or (http and http.request)
    
    if not requestFunc then
        return nil
    end
    
    local success, res = pcall(function()
        return requestFunc({
            Url = url,
            Method = "GET",
            Headers = {
                ["Content-Type"] = "application/json",
                ["User-Agent"] = "Roblox/AutoJoiner-HTTP"
            }
        })
    end)
    
    if not success or not res then
        return nil
    end
    
    local body = res.Body or res.body or res[1]
    if not body or body == "" then
        return nil
    end
    
    if type(body) ~= "string" then
        body = tostring(body)
    end
    body = body:gsub("[\n\r]", ""):gsub("%s+$", "")
    
    local ok, data = pcall(function()
        return HttpService:JSONDecode(body)
    end)
    
    if ok and data then
        return data
    end
    
    return nil
end

local function playJobSound(showBrainrots)
    if showBrainrots then
        if jobSound then
            pcall(function()
                jobSound:Stop()
                jobSound:Destroy()
            end)
            jobSound = nil
        end
        
        local sound = Instance.new("Sound")
        sound.SoundId = "rbxassetid://5476307813"
        sound.Volume = 0.5
        sound.Looped = true
        sound.Name = "JobNotificationSound"
        
        local success = pcall(function()
            sound.Parent = game:GetService("Workspace")
        end)
        if not success then
            sound.Parent = game:GetService("SoundService")
        end
        
        pcall(function()
            sound:Play()
        end)
        
        jobSound = sound
    end
end

local function stopJobSound()
    if jobSound then
        pcall(function()
            jobSound:Stop()
            jobSound:Destroy()
        end)
        jobSound = nil
    end
end

local function updateJobBanner(playerName, playerValue, attempts, maxAttempts, showBrainrots, lp)
    if not showBrainrots then return end
    
    if jobBanner then
        pcall(function()
            jobBanner:Destroy()
        end)
        jobBanner = nil
    end
    
    local playerGui = lp:WaitForChild("PlayerGui")
    
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "JobBanner"
    screenGui.ResetOnSpawn = false
    screenGui.Enabled = true
    screenGui.IgnoreGuiInset = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = playerGui
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 500, 0, 90)
    frame.Position = UDim2.new(0.5, -250, 0.1, 0)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    frame.BackgroundTransparency = 0.2
    frame.BorderSizePixel = 0
    frame.ZIndex = 100
    frame.Parent = screenGui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 10)
    
    local border = Instance.new("UIStroke")
    border.Color = Color3.fromRGB(0, 255, 255)
    border.Thickness = 3
    border.Parent = frame

    local playerLabel = Instance.new("TextLabel")
    playerLabel.Size = UDim2.new(1, -20, 0, 30)
    playerLabel.Position = UDim2.new(0, 10, 0, 15)
    playerLabel.BackgroundTransparency = 1
    playerLabel.Text = (playerName or "Desconhecido")
    playerLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    playerLabel.TextScaled = true
    playerLabel.Font = Enum.Font.GothamBold
    playerLabel.TextStrokeTransparency = 0
    playerLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    playerLabel.ZIndex = 101
    playerLabel.Parent = frame
    
    local valueLabel = Instance.new("TextLabel")
    valueLabel.Size = UDim2.new(1, -20, 0, 30)
    valueLabel.Position = UDim2.new(0, 10, 0, 45)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text = (playerValue or "N/A")
    valueLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
    valueLabel.TextScaled = true
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextStrokeTransparency = 0
    valueLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
    valueLabel.ZIndex = 101
    valueLabel.Parent = frame
    
    jobBanner = screenGui
    
    local bannerClicked = false
    
    local function onBannerClick()
        if bannerClicked then return end
        bannerClicked = true
        
        local lastJob = getgenv and getgenv().lastWebSocketJob or nil
        if lastJob then
            local jobData = lastJob
            local jobId = jobData.job_id
            
            if jobId then
                AutoJoinerModule.startManualTeleport(jobId, lp)
                
                task.spawn(function()
                    task.wait(5)
                    
                    if jobBanner then
                        pcall(function()
                            jobBanner:Destroy()
                        end)
                        jobBanner = nil
                    end
                end)
            end
        end
    end
    
    frame.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            onBannerClick()
        end
    end)
    
    task.spawn(function()
        local colors = {
            Color3.fromRGB(255, 0, 0),
            Color3.fromRGB(255, 165, 0),
            Color3.fromRGB(255, 255, 0),
            Color3.fromRGB(0, 255, 0),
            Color3.fromRGB(0, 255, 255),
            Color3.fromRGB(0, 0, 255),
            Color3.fromRGB(128, 0, 255),
            Color3.fromRGB(255, 0, 255)
        }
        local colorIndex = 1
        while jobBanner and jobBanner.Parent do
            if border and border.Parent then
                border.Color = colors[colorIndex]
                colorIndex = colorIndex % #colors + 1
            end
            task.wait(0.3)
        end
    end)
end

local function removeJobBanner()
    if jobBanner then
        pcall(function()
            jobBanner:Destroy()
        end)
        jobBanner = nil
    end
end

function AutoJoinerModule.startManualTeleport(jobId, lp)
    if manualTeleportActive then
        return
    end
    
    manualTeleportActive = true
    manualTeleportJobId = jobId
    manualTeleportAttempts = 0
    
    task.spawn(function()
        while manualTeleportActive and manualTeleportAttempts < maxManualTeleportAttempts do
            manualTeleportAttempts = manualTeleportAttempts + 1
            
            local decodedJobId = decode_jobid(manualTeleportJobId)
            pcall(function()
                TPS:TeleportToPlaceInstance(game.PlaceId, decodedJobId, lp)
            end)
            
            task.wait(1)
        end
        
        manualTeleportActive = false
        manualTeleportJobId = nil
        manualTeleportAttempts = 0
    end)
end

function AutoJoinerModule.connectWebSocket(wsUrl, lp, methods, key)
    if not WebSocket then
        return false
    end
    
    local success, connection = pcall(function()
        return WebSocket.connect(wsUrl)
    end)
    
    if success and connection then
        wsConnection = connection
        isWebSocketConnected = true
        wsReconnectAttempts = 0
        
        task.spawn(function()
            task.wait(0.5)
            
            local scriptKey = getgenv and getgenv().script_key or nil
            
            local userInfo = {
                type = "user_connected",
                data = {
                    username = lp.Name,
                    userid = lp.UserId,
                    discord_id = LRM_LinkedDiscordID or "N/A",
                    script_key = scriptKey or "N/A",
                    methods = methods,
                    key = key,
                    timestamp = os.time()
                }
            }
            
            local success, message = pcall(function()
                return HttpService:JSONEncode(userInfo)
            end)
            
            if success and message then
                pcall(function()
                    connection:Send(message)
                end)
            end
        end)
        
        connection.OnMessage:Connect(function(message)
            local ok, data = pcall(function()
                return HttpService:JSONDecode(message)
            end)
            
            if ok and data and data.type == "new_job" then
                if getgenv then
                    getgenv().lastWebSocketJob = data.data
                end
            end
        end)
        
        connection.OnClose:Connect(function()
            isWebSocketConnected = false
            wsConnection = nil
        end)
        
        return true
    else
        return false
    end
end

function AutoJoinerModule.disconnectWebSocket(lp, methods, key)
    if wsConnection then
        local scriptKey = getgenv and getgenv().script_key or nil
        
        local disconnectInfo = {
            type = "user_disconnected",
            data = {
                username = lp.Name,
                userid = lp.UserId,
                discord_id = LRM_LinkedDiscordID or "N/A",
                script_key = scriptKey or "N/A",
                methods = methods,
                key = key,
                timestamp = os.time()
            }
        }
        
        local success, message = pcall(function()
            return HttpService:JSONEncode(disconnectInfo)
        end)
        
        if success and message then
            pcall(function()
                wsConnection:Send(message)
            end)
        end
        
        pcall(function()
            wsConnection:Close()
        end)
        wsConnection = nil
    end
    isWebSocketConnected = false
end

function AutoJoinerModule.run(config)
    local autoJoinActive = config.autoJoinActive
    local lp = config.lp
    local methods = config.methods
    local specificBrainrots = config.specificBrainrots
    local avaiblemethods = config.avaiblemethods
    local showBrainrots = config.showBrainrots
    local url = config.url
    
    local lastKnownJobId = nil
    local lastKnownPlayerName = nil
    local lastKnownPlayerValue = nil
    local teleportAttempts = 0
    local maxTeleportAttempts = 45

    if isWebSocketConnected then
        while autoJoinActive do
            local wsJob = getgenv and getgenv().lastWebSocketJob or nil

            if wsJob then
                if getgenv then
                    getgenv().lastWebSocketJob = nil
                end

                local currentJobId = wsJob.job_id
                local playerName = wsJob.name or "Desconhecido"
                local playerValue = wsJob.generation or "N/A"

                if currentJobId ~= lastKnownJobId then
                    lastKnownJobId = currentJobId
                    lastKnownPlayerName = playerName
                    lastKnownPlayerValue = playerValue
                    teleportAttempts = 0

                    updateJobBanner(playerName, playerValue, teleportAttempts, maxTeleportAttempts, showBrainrots, lp)
                    playJobSound(showBrainrots)
                end
            end

            if lastKnownJobId then
                teleportAttempts += 1

                local currentPlayerName = lastKnownPlayerName or "Job conhecido"
                local currentPlayerValue = lastKnownPlayerValue or "N/A"
                updateJobBanner(currentPlayerName, currentPlayerValue, teleportAttempts, maxTeleportAttempts, showBrainrots, lp)

                local decodedJobId = decode_jobid(lastKnownJobId)
                pcall(function()
                    TPS:TeleportToPlaceInstance(game.PlaceId, decodedJobId, lp)
                end)

                if teleportAttempts >= maxTeleportAttempts then
                    removeJobBanner()
                    stopJobSound()
                    lastKnownJobId = nil
                    lastKnownPlayerName = nil
                    lastKnownPlayerValue = nil
                    teleportAttempts = 0
                end

                task.wait(1)
            else
                task.wait(0.1)
            end
        end
    else
        local consecutiveErrors = 0
        local maxErrors = 5
        local lastJobData = nil
        local lastKnownPlayerValueHTTP = nil

        while autoJoinActive do
            local data = getJobsHTTP(url)

            if data then
                consecutiveErrors = 0
                lastJobData = data

                local brasiliaNow = getBrasiliaTime()
                local bestJob, bestJobTime, bestJobDiff = nil, 0, math.huge

                if #specificBrainrots > 0 then
                    for _, allowedTier in ipairs(avaiblemethods) do
                        local tierJobs = data[allowedTier]
                        if type(tierJobs) == "table" and tierJobs then
                            for _, job in ipairs(tierJobs) do
                                if job and job.timer and job.job_id and job.job_id ~= game.JobId then
                                    local brainrotName = job.brainrot_name or job.name or ""
                                    
                                    for _, specificBrainrot in ipairs(specificBrainrots) do
                                        if isBrainrotValid(brainrotName, specificBrainrot) then
                                            local jobTime = parseTimer(job.timer)
                                            local diff = brasiliaNow - jobTime
                                            if diff >= 0 and diff <= 60 and diff < bestJobDiff then
                                                bestJob = job
                                                bestJobTime = jobTime
                                                bestJobDiff = diff
                                            end
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    end
                else
                    for _, method in ipairs(methods) do
                        if tonumber(method:match("%d+")) then
                            local jobs = data[method]
                            if jobs and type(jobs) == "table" and #jobs > 0 then
                                local job = jobs[#jobs]
                                if job and job.timer and job.job_id and job.job_id ~= game.JobId then
                                    local jobTime = parseTimer(job.timer)
                                    local diff = brasiliaNow - jobTime
                                    if diff >= 0 and diff <= 60 and diff < bestJobDiff then
                                        bestJob = job
                                        bestJobTime = jobTime
                                        bestJobDiff = diff
                                    end
                                end
                            end
                        end
                    end
                end

                if bestJob then
                    local currentJobId = bestJob.job_id
                    if currentJobId ~= lastKnownJobId then
                        lastKnownJobId = currentJobId
                        teleportAttempts = 0

                        local playerName = bestJob.name or bestJob.player or "Desconhecido"
                        local playerValue = bestJob.generation or "N/A"
                        lastKnownPlayerName = playerName
                        lastKnownPlayerValueHTTP = playerValue

                        updateJobBanner(playerName, playerValue, teleportAttempts, maxTeleportAttempts, showBrainrots, lp)
                        playJobSound(showBrainrots)
                    end

                    teleportAttempts += 1
                    local currentPlayerName = lastKnownPlayerName or "Desconhecido"
                    local currentPlayerValue = lastKnownPlayerValueHTTP or "N/A"
                    updateJobBanner(currentPlayerName, currentPlayerValue, teleportAttempts, maxTeleportAttempts, showBrainrots, lp)

                    local teleportSuccess = pcall(function()
                        if currentJobId ~= game.JobId then
                            TPS:TeleportToPlaceInstance(game.PlaceId, currentJobId, lp)
                        end
                    end)

                    if teleportAttempts >= maxTeleportAttempts then
                        removeJobBanner()
                        stopJobSound()
                        lastKnownJobId = nil
                        lastKnownPlayerName = nil
                        lastKnownPlayerValueHTTP = nil
                        teleportAttempts = 0
                    end

                    task.wait(1)
                else
                    if lastKnownJobId then
                        lastKnownJobId = nil
                        lastKnownPlayerName = nil
                        lastKnownPlayerValueHTTP = nil
                        teleportAttempts = 0
                    end
                    task.wait(1)
                end
            else
                consecutiveErrors += 1
                if consecutiveErrors >= maxErrors then
                    autoJoinActive = false
                    if getgenv then getgenv().AJ = false end
                    break
                end
                task.wait(1)
            end
        end
    end

    removeJobBanner()
    stopJobSound()
end

function AutoJoinerModule.processWebSocketJob(jobData, methods, specificBrainrots, avaiblemethods, showBrainrots, lp)
    if not jobData then 
        return 
    end
    
    local jobTier = jobData.tier or "N/A"
    local brainrotName = jobData.brainrot_name or jobData.name or "N/A"
    
    local isValidJob = false
    
    if #specificBrainrots > 0 then
        for _, specificBrainrot in ipairs(specificBrainrots) do
            if isBrainrotValid(brainrotName, specificBrainrot) then
                local jobTierValid = false
                for _, allowedTier in ipairs(avaiblemethods) do
                    if jobTier == allowedTier then
                        jobTierValid = true
                        break
                    end
                end
                
                if jobTierValid then
                    isValidJob = true
                    break
                end
            end
        end
    else
        for _, selectedMethod in ipairs(methods) do
            if jobTier == selectedMethod then
                isValidJob = true
                break
            end
        end
    end
    
    if not isValidJob then
        return
    end
    
    local playerName = jobData.name or "Desconhecido"
    local playerValue = jobData.generation or "N/A"
    
    updateJobBanner(playerName, playerValue, 0, 0, showBrainrots, lp)
    if playJobSound then
        playJobSound(showBrainrots)
    end
    
    if getgenv then
        getgenv().lastWebSocketJob = jobData
    end
end

return AutoJoinerModule