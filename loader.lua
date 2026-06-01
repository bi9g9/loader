--[[
    Bi9Hub Script Loader
    ใส่ License Key ของคุณด้านล่าง
    
    วิธีใช้:
    1. ซื้อสคริปต์จาก bi9hub.xyz
    2. ใส่ License Key ที่ได้รับ
    3. รัน script นี้
]]

local LICENSE_KEY = "XXXX-XXXX-XXXX-XXXX" -- ใส่ Key ของคุณที่นี่
local API_URL = "https://bi9hub.xyz/api/v1"

-- ดึง HWID ของเครื่อง
local function getHWID()
    -- ใช้ข้อมูลเครื่องเพื่อสร้าง unique ID
    local hwid = game:GetService("RbxAnalyticsService"):GetClientId()
    if not hwid or hwid == "" then
        -- Fallback: ใช้ UserID
        hwid = tostring(game:GetService("Players").LocalPlayer.UserId)
    end
    return hwid
end

-- HTTP Request wrapper
local function httpRequest(url, method, body, accessToken)
    local HttpService = game:GetService("HttpService")
    
    local headers = {
        ["Content-Type"] = "application/json",
        ["User-Agent"] = "Bi9Hub-Loader/1.0"
    }
    
    if accessToken then
        headers["Authorization"] = "Bearer " .. accessToken
    end
    
    local success, result = pcall(function()
        return HttpService:RequestAsync({
            Url = url,
            Method = method or "GET",
            Headers = headers,
            Body = body and HttpService:JSONEncode(body) or nil
        })
    end)
    
    if not success then
        return nil, "Request failed: " .. tostring(result)
    end
    
    if result.StatusCode ~= 200 then
        return nil, "HTTP " .. result.StatusCode
    end
    
    local ok, data = pcall(function()
        return HttpService:JSONDecode(result.Body)
    end)
    
    if not ok then
        return nil, "Invalid JSON response"
    end
    
    return data, nil
end

-- Validate license key
local function validateLicense()
    local hwid = getHWID()
    
    local data, err = httpRequest(
        API_URL .. "/license/validate",
        "POST",
        { key = LICENSE_KEY, hwid = hwid }
    )
    
    if err then
        return false, "ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้: " .. err
    end
    
    if not data.valid then
        local reason = data.reason or "unknown"
        if reason == "key not found" then
            return false, "License Key ไม่ถูกต้อง"
        elseif reason == "key expired" then
            return false, "License Key หมดอายุแล้ว กรุณาต่ออายุที่ bi9hub.xyz"
        elseif reason == "hwid mismatch" then
            return false, "Key นี้ถูกใช้กับเครื่องอื่นแล้ว"
        elseif reason == "key is disabled" then
            return false, "Key ถูกปิดใช้งาน"
        else
            return false, "License ไม่ถูกต้อง: " .. reason
        end
    end
    
    -- คำนวณวันที่เหลือ
    local expiresAt = data.expires_at
    return true, nil, expiresAt
end

-- Load and execute script content from server
-- 🔒 SECURITY: รัน loadstring() ทันที ไม่บันทึกไฟล์
local function loadAndExecuteScript(scriptId, accessToken)
    local data, err = httpRequest(
        API_URL .. "/script-content/" .. scriptId,
        "GET",
        nil,
        accessToken
    )
    
    if err then
        return false, "ไม่สามารถโหลดสคริปต์ได้: " .. err
    end
    
    if not data.content then
        return false, "ไม่พบเนื้อหาสคริปต์"
    end
    
    -- 🔒 รัน loadstring() ทันที ไม่บันทึกลงไฟล์
    local fn, compileErr = loadstring(data.content)
    if not fn then
        return false, "Compile error: " .. tostring(compileErr)
    end
    
    -- Execute
    local success, execErr = pcall(fn)
    if not success then
        return false, "Runtime error: " .. tostring(execErr)
    end
    
    return true, nil
end

-- Main loader
local function main()
    -- Check if key is set
    if LICENSE_KEY == "XXXX-XXXX-XXXX-XXXX" then
        warn("[Bi9Hub] กรุณาใส่ License Key ของคุณก่อน")
        return
    end
    
    print("[Bi9Hub] กำลังตรวจสอบ License...")
    
    local valid, err, expiresAt = validateLicense()
    
    if not valid then
        warn("[Bi9Hub] ❌ " .. (err or "License ไม่ถูกต้อง"))
        -- แสดง GUI แจ้งเตือน
        local gui = Instance.new("ScreenGui")
        gui.Name = "Bi9HubError"
        gui.ResetOnSpawn = false
        
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(0, 400, 0, 100)
        frame.Position = UDim2.new(0.5, -200, 0, 20)
        frame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        frame.BorderSizePixel = 0
        frame.Parent = gui
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, 8)
        corner.Parent = frame
        
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -20, 1, 0)
        label.Position = UDim2.new(0, 10, 0, 0)
        label.BackgroundTransparency = 1
        label.TextColor3 = Color3.fromRGB(255, 80, 80)
        label.Text = "[Bi9Hub] " .. (err or "License ไม่ถูกต้อง")
        label.TextSize = 14
        label.Font = Enum.Font.GothamBold
        label.TextWrapped = true
        label.Parent = frame
        
        gui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
        
        task.delay(5, function()
            gui:Destroy()
        end)
        
        return
    end
    
    print("[Bi9Hub] ✅ License ถูกต้อง")
    if expiresAt then
        print("[Bi9Hub] หมดอายุ: " .. tostring(expiresAt))
    end
    
    -- 🔒 โหลดและรันสคริปต์ทันที (ไม่บันทึกไฟล์)
    print("[Bi9Hub] กำลังโหลดสคริปต์...")
    
    -- ⚠️ ต้องใส่ Script ID ที่ต้องการโหลด
    local SCRIPT_ID = "your-script-id-here" -- เปลี่ยนตรงนี้
    
    if SCRIPT_ID == "your-script-id-here" then
        warn("[Bi9Hub] ⚠️ กรุณาตั้งค่า SCRIPT_ID ในโค้ด")
        return
    end
    
    -- ต้องมี access token จากการ login (ถ้าใช้ authentication)
    -- สำหรับตอนนี้ใช้ license key validation แทน
    local success, loadErr = loadAndExecuteScript(SCRIPT_ID, nil)
    
    if not success then
        warn("[Bi9Hub] ❌ " .. (loadErr or "ไม่สามารถโหลดสคริปต์ได้"))
        return
    end
    
    print("[Bi9Hub] ✅ โหลดและรันสคริปต์สำเร็จ!")
end

-- Run
main()
