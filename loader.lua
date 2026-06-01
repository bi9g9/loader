--[[
    ██████╗ ██╗ ██████╗ ██╗  ██╗██╗   ██╗██████╗ 
    ██╔══██╗██║██╔════╝ ██║  ██║██║   ██║██╔══██╗
    ██████╔╝██║██║  ███╗███████║██║   ██║██████╔╝
    ██╔══██╗██║██║   ██║██╔══██║██║   ██║██╔══██╗
    ██████╔╝██║╚██████╔╝██║  ██║╚██████╔╝██████╔╝
    ╚═════╝ ╚═╝ ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚═════╝ 
    
    Universal Script Loader v2.0
    bi9hub.xyz
]]

local API_URL = "https://bi9hub.xyz/api/v1"

-- ============================================================
-- Services
-- ============================================================
local Players       = game:GetService("Players")
local HttpService   = game:GetService("HttpService")
local TweenService  = game:GetService("TweenService")
local RunService    = game:GetService("RunService")
local LocalPlayer   = Players.LocalPlayer
local PlayerGui     = LocalPlayer:WaitForChild("PlayerGui")

-- ============================================================
-- HWID
-- ============================================================
local function getHWID()
    local ok, id = pcall(function()
        return game:GetService("RbxAnalyticsService"):GetClientId()
    end)
    if ok and id and id ~= "" then return id end
    return tostring(LocalPlayer.UserId)
end

-- ============================================================
-- HTTP
-- ============================================================
local function request(url, method, body)
    local ok, res = pcall(function()
        return HttpService:RequestAsync({
            Url     = url,
            Method  = method or "GET",
            Headers = {
                ["Content-Type"] = "application/json",
                ["User-Agent"]   = "Bi9Hub-Loader/2.0"
            },
            Body = body and HttpService:JSONEncode(body) or nil
        })
    end)
    if not ok then return nil, "connection failed" end
    if res.StatusCode ~= 200 then return nil, "HTTP " .. res.StatusCode end
    local ok2, data = pcall(HttpService.JSONDecode, HttpService, res.Body)
    if not ok2 then return nil, "invalid response" end
    return data, nil
end

-- ============================================================
-- Validate Key → ได้ script_id กลับมา
-- ============================================================
local function validateKey(key)
    local data, err = request(API_URL .. "/license/validate", "POST", {
        key  = key,
        hwid = getHWID()
    })
    if err then return nil, "เชื่อมต่อเซิร์ฟเวอร์ไม่ได้: " .. err end
    if not data.valid then
        local msgs = {
            ["key not found"]  = "❌ Key ไม่ถูกต้อง",
            ["key expired"]    = "❌ Key หมดอายุแล้ว",
            ["hwid mismatch"]  = "❌ Key นี้ผูกกับเครื่องอื่นแล้ว",
            ["key is disabled"]= "❌ Key ถูกปิดใช้งาน",
        }
        return nil, msgs[data.reason] or ("❌ " .. (data.reason or "ไม่ทราบสาเหตุ"))
    end
    return data, nil -- { valid, script_id, expires_at }
end

-- ============================================================
-- Load Script
-- ============================================================
local function loadScript(scriptId)
    local data, err = request(API_URL .. "/script-content/" .. scriptId, "GET")
    if err then return false, "โหลดสคริปต์ไม่ได้: " .. err end
    if not data or not data.data or not data.data.content then
        return false, "ไม่พบเนื้อหาสคริปต์"
    end
    local fn, compErr = loadstring(data.data.content)
    if not fn then return false, "Compile error: " .. tostring(compErr) end
    local ok2, runErr = pcall(fn)
    if not ok2 then return false, "Runtime error: " .. tostring(runErr) end
    return true, nil
end

-- ============================================================
-- UI Helper
-- ============================================================
local UI = {}

function UI.create()
    -- ลบ UI เก่าถ้ามี
    local old = PlayerGui:FindFirstChild("Bi9HubLoader")
    if old then old:Destroy() end

    local gui = Instance.new("ScreenGui")
    gui.Name            = "Bi9HubLoader"
    gui.ResetOnSpawn    = false
    gui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
    gui.Parent          = PlayerGui

    -- Backdrop
    local backdrop = Instance.new("Frame")
    backdrop.Name              = "Backdrop"
    backdrop.Size              = UDim2.new(1, 0, 1, 0)
    backdrop.BackgroundColor3  = Color3.fromRGB(0, 0, 0)
    backdrop.BackgroundTransparency = 0.4
    backdrop.BorderSizePixel   = 0
    backdrop.ZIndex            = 1
    backdrop.Parent            = gui

    -- Main Frame
    local frame = Instance.new("Frame")
    frame.Name              = "Main"
    frame.Size              = UDim2.new(0, 380, 0, 260)
    frame.Position          = UDim2.new(0.5, -190, 0.5, -130)
    frame.BackgroundColor3  = Color3.fromRGB(13, 17, 23)
    frame.BorderSizePixel   = 0
    frame.ZIndex            = 2
    frame.Parent            = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = frame

    -- Border glow
    local stroke = Instance.new("UIStroke")
    stroke.Color     = Color3.fromRGB(88, 101, 242)
    stroke.Thickness = 1.5
    stroke.Parent    = frame

    -- Logo / Title
    local title = Instance.new("TextLabel")
    title.Size                  = UDim2.new(1, 0, 0, 50)
    title.Position              = UDim2.new(0, 0, 0, 10)
    title.BackgroundTransparency = 1
    title.Text                  = "Bi9Hub"
    title.TextColor3            = Color3.fromRGB(255, 255, 255)
    title.TextSize              = 26
    title.Font                  = Enum.Font.GothamBold
    title.ZIndex                = 3
    title.Parent                = frame

    local subtitle = Instance.new("TextLabel")
    subtitle.Size                  = UDim2.new(1, 0, 0, 20)
    subtitle.Position              = UDim2.new(0, 0, 0, 42)
    subtitle.BackgroundTransparency = 1
    subtitle.Text                  = "Universal Script Loader"
    subtitle.TextColor3            = Color3.fromRGB(100, 116, 139)
    subtitle.TextSize              = 12
    subtitle.Font                  = Enum.Font.Gotham
    subtitle.ZIndex                = 3
    subtitle.Parent                = frame

    -- Divider
    local div = Instance.new("Frame")
    div.Size             = UDim2.new(1, -40, 0, 1)
    div.Position         = UDim2.new(0, 20, 0, 72)
    div.BackgroundColor3 = Color3.fromRGB(30, 41, 59)
    div.BorderSizePixel  = 0
    div.ZIndex           = 3
    div.Parent           = frame

    -- Key Label
    local keyLabel = Instance.new("TextLabel")
    keyLabel.Size                  = UDim2.new(1, -40, 0, 20)
    keyLabel.Position              = UDim2.new(0, 20, 0, 88)
    keyLabel.BackgroundTransparency = 1
    keyLabel.Text                  = "License Key"
    keyLabel.TextColor3            = Color3.fromRGB(148, 163, 184)
    keyLabel.TextSize              = 12
    keyLabel.Font                  = Enum.Font.Gotham
    keyLabel.TextXAlignment        = Enum.TextXAlignment.Left
    keyLabel.ZIndex                = 3
    keyLabel.Parent                = frame

    -- Key Input
    local inputBg = Instance.new("Frame")
    inputBg.Size             = UDim2.new(1, -40, 0, 42)
    inputBg.Position         = UDim2.new(0, 20, 0, 112)
    inputBg.BackgroundColor3 = Color3.fromRGB(22, 27, 34)
    inputBg.BorderSizePixel  = 0
    inputBg.ZIndex           = 3
    inputBg.Parent           = frame

    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 8)
    inputCorner.Parent = inputBg

    local inputStroke = Instance.new("UIStroke")
    inputStroke.Color     = Color3.fromRGB(48, 54, 61)
    inputStroke.Thickness = 1
    inputStroke.Parent    = inputBg

    local input = Instance.new("TextBox")
    input.Size                  = UDim2.new(1, -20, 1, 0)
    input.Position              = UDim2.new(0, 10, 0, 0)
    input.BackgroundTransparency = 1
    input.PlaceholderText       = "XXXX-XXXX-XXXX-XXXX"
    input.PlaceholderColor3     = Color3.fromRGB(71, 85, 105)
    input.Text                  = ""
    input.TextColor3            = Color3.fromRGB(226, 232, 240)
    input.TextSize              = 14
    input.Font                  = Enum.Font.GothamMono
    input.ClearTextOnFocus      = false
    input.ZIndex                = 4
    input.Parent                = inputBg

    -- Status Label
    local status = Instance.new("TextLabel")
    status.Name                  = "Status"
    status.Size                  = UDim2.new(1, -40, 0, 20)
    status.Position              = UDim2.new(0, 20, 0, 162)
    status.BackgroundTransparency = 1
    status.Text                  = ""
    status.TextColor3            = Color3.fromRGB(100, 116, 139)
    status.TextSize              = 11
    status.Font                  = Enum.Font.Gotham
    status.ZIndex                = 3
    status.Parent                = frame

    -- Submit Button
    local btnBg = Instance.new("Frame")
    btnBg.Size             = UDim2.new(1, -40, 0, 44)
    btnBg.Position         = UDim2.new(0, 20, 0, 190)
    btnBg.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
    btnBg.BorderSizePixel  = 0
    btnBg.ZIndex           = 3
    btnBg.Parent           = frame

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 8)
    btnCorner.Parent = btnBg

    local btn = Instance.new("TextButton")
    btn.Name                  = "SubmitBtn"
    btn.Size                  = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text                  = "เข้าใช้งาน"
    btn.TextColor3            = Color3.fromRGB(255, 255, 255)
    btn.TextSize              = 14
    btn.Font                  = Enum.Font.GothamBold
    btn.ZIndex                = 4
    btn.Parent                = btnBg

    return gui, input, btn, status, btnBg
end

function UI.setStatus(statusLabel, text, color)
    statusLabel.Text       = text
    statusLabel.TextColor3 = color or Color3.fromRGB(100, 116, 139)
end

function UI.setLoading(btn, btnBg, loading)
    if loading then
        btn.Text             = "กำลังตรวจสอบ..."
        btnBg.BackgroundColor3 = Color3.fromRGB(55, 65, 81)
        btn.Active           = false
    else
        btn.Text             = "เข้าใช้งาน"
        btnBg.BackgroundColor3 = Color3.fromRGB(88, 101, 242)
        btn.Active           = true
    end
end

function UI.close(gui)
    TweenService:Create(gui.Main, TweenInfo.new(0.3), {
        Position = UDim2.new(0.5, -190, 1.5, 0)
    }):Play()
    task.delay(0.35, function()
        gui:Destroy()
    end)
end

-- ============================================================
-- Main
-- ============================================================
local function main()
    local gui, input, btn, statusLabel, btnBg = UI.create()

    -- Animate in
    gui.Main.Position = UDim2.new(0.5, -190, -0.5, 0)
    TweenService:Create(gui.Main, TweenInfo.new(0.4, Enum.EasingStyle.Back), {
        Position = UDim2.new(0.5, -190, 0.5, -130)
    }):Play()

    -- Submit handler
    local function onSubmit()
        local key = input.Text:match("^%s*(.-)%s*$") -- trim
        if key == "" then
            UI.setStatus(statusLabel, "⚠️ กรุณาใส่ Key ก่อน", Color3.fromRGB(251, 191, 36))
            return
        end

        UI.setLoading(btn, btnBg, true)
        UI.setStatus(statusLabel, "🔍 กำลังตรวจสอบ Key...", Color3.fromRGB(148, 163, 184))

        task.spawn(function()
            -- Validate key
            local data, err = validateKey(key)

            if err then
                UI.setLoading(btn, btnBg, false)
                UI.setStatus(statusLabel, err, Color3.fromRGB(248, 113, 113))
                return
            end

            -- Key valid → load script
            UI.setStatus(statusLabel, "✅ Key ถูกต้อง กำลังโหลดสคริปต์...", Color3.fromRGB(74, 222, 128))

            local ok, loadErr = loadScript(data.script_id)

            if not ok then
                UI.setLoading(btn, btnBg, false)
                UI.setStatus(statusLabel, "❌ " .. (loadErr or "โหลดไม่สำเร็จ"), Color3.fromRGB(248, 113, 113))
                return
            end

            -- Success → ปิด UI
            UI.setStatus(statusLabel, "🚀 โหลดสำเร็จ!", Color3.fromRGB(74, 222, 128))
            task.delay(0.8, function()
                UI.close(gui)
            end)
        end)
    end

    btn.MouseButton1Click:Connect(onSubmit)

    -- Enter key
    input.FocusLost:Connect(function(enterPressed)
        if enterPressed then onSubmit() end
    end)
end

main()
