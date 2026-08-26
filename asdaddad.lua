--[[
    RICK'S PORTAL GUN (MESH ASSET EDITION)
    Single-Script Payload for Client Executors.
    
    HOTKEYS:
    - Scroll Wheel Click (Middle Click): Project Rick's Green Portal at Mouse Target
    - M Key: Toggle Configuration Overlay HUD
    - X Key: Immediately Close and Purge Active Portals
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()

--============================================================
-- ASSET ID CONFIGURATIONS & CANON RICK THEME DEFINITIONS
--============================================================
local isEvilMortyMode = false -- Switched off to enable Rick's Theme
local GREEN = Color3.fromRGB(0, 255, 68) -- Rick's Canonical Portal Lime Green
local LIGHT_GREEN = Color3.fromRGB(180, 255, 190)

-- Raw Asset ID Endpoints
local GUN_MESH_ID = "rbxassetid://1148760431"
local GUN_TEXT_ID = "rbxassetid://1148760515"
local PORTAL_MESH_ID = "rbxassetid://4617180479" -- Rick and Morty Animated Swirl Portal Vortex Mesh

local PORTAL_LIFETIME = 15
local PORTAL_DISTANCE = 7
local PORTAL_TELEPORT_COOLDOWN = 0.8

local portalTeleportLocked = false
local teleportMode = "Coordinates"
local mainGui, menu, status, playerBox, xBox, yBox, zBox
local currentPortal, returnPortal, flipPortalFacing
local portalConnections = {}
local playerListButtons = {}
local gunAnimationConnection
local activeMeshModel
local coreLightRef

local function getCharacter() return player.Character end
local function getRoot(char) return (char or getCharacter()):FindFirstChild("HumanoidRootPart") end

--============================================================
-- PORTAL DIMENSIONAL CORE MECHANICS
--============================================================
local function teleportPlayerTo(targetCFrame)
    local character = getCharacter()
    local root = getRoot(character)
    if not root or not targetCFrame then return end
    root.CFrame = targetCFrame
    root.AssemblyLinearVelocity = Vector3.zero
    root.AssemblyAngularVelocity = Vector3.zero
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if humanoid then humanoid.AutoRotate = false end
    
    local camera = workspace.CurrentCamera
    if camera then
        RunService:BindToRenderStep("PortalCameraSnap", Enum.RenderPriority.Camera.Value + 1, function()
            if not workspace.CurrentCamera then return end
            local camPos = workspace.CurrentCamera.CFrame.Position
            workspace.CurrentCamera.CFrame = CFrame.lookAt(camPos, camPos + targetCFrame.LookVector)
        end)
        task.delay(0.25, function()
            pcall(function() RunService:UnbindFromRenderStep("PortalCameraSnap") end)
            if character:FindFirstChildOfClass("Humanoid") then character:FindFirstChildOfClass("Humanoid").AutoRotate = true end
        end)
    end
end

local function destroyPortal(p) if p and p.Parent then p:Destroy() end end
local function removeAllPortals() destroyPortal(currentPortal) destroyPortal(returnPortal) currentPortal = nil returnPortal = nil portalTeleportLocked = false end

local function createPortalAsset(position, facing, labelText, targetCFrame, isReturn)
    local activeColor = GREEN
    local model = Instance.new("Model")
    model.Name = isReturn and "ReturnPortal" or "DestinationPortal"
    model.Parent = workspace

    local portalCFrame = CFrame.lookAt(position, position + facing)
    
    -- Main structural base part holding the asset mesh
    local portalPart = Instance.new("Part")
    portalPart.Name = isReturn and "RETURN" or "DESTINATION"
    portalPart.Size = Vector3.new(7, 10, 0.5)
    portalPart.CFrame = portalCFrame
    portalPart.Color = activeColor
    portalPart.Material = Enum.Material.Neon
    portalPart.Transparency = 0.15
    portalPart.Anchored = true
    portalPart.CanCollide = false
    portalPart.Parent = model

    -- Inject Rick's Green Vortex Mesh Asset ID
    local specialMesh = Instance.new("SpecialMesh")
    specialMesh.MeshType = Enum.MeshType.FileMesh
    specialMesh.MeshId = PORTAL_MESH_ID
    specialMesh.Scale = Vector3.new(4.5, 4.5, 1.5)
    specialMesh.Parent = portalPart

    local light = Instance.new("PointLight")
    light.Color = activeColor
    light.Brightness = 8
    light.Range = 16
    light.Parent = portalPart

    -- Teleport Hit Detection Setup
    local debounce = false
    portalPart.Touched:Connect(function(hit)
        if debounce or portalTeleportLocked then return end
        local character = getCharacter()
        if not character or not hit:IsDescendantOf(character) then return end
        debounce = true
        portalTeleportLocked = true

        if isReturn then
            if targetCFrame then teleportPlayerTo(targetCFrame) end
        else
            if targetCFrame then
                local root = getRoot(character)
                root.CFrame = targetCFrame
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
            end
        end
        task.delay(PORTAL_TELEPORT_COOLDOWN, function() debounce = false; portalTeleportLocked = false end)
    end)

    -- Dynamic Spin Animation Engine for Asset Portals (Rick's Swirl Effect)
    local spinConn
    spinConn = RunService.RenderStepped:Connect(function()
        if not portalPart.Parent then spinConn:Disconnect() return end
        portalPart.CFrame = portalPart.CFrame * CFrame.Angles(0, 0, math.rad(-3)) -- Spins fluidly counter-clockwise
    end)

    task.delay(PORTAL_LIFETIME, function() if model.Parent then model:Destroy() end end)
    return model
end

local function computeExitCFrame(position, facing)
    local horizontal = Vector3.new(facing.X, 0, facing.Z)
    if horizontal.Magnitude < 0.05 then horizontal = Vector3.new(0, 0, -1) end
    return CFrame.lookAt(position, position + horizontal.Unit, Vector3.new(0, 1, 0))
end

local function shootPortalAtCursor()
    local character = getCharacter()
    local root = getRoot(character)
    if not character or not root then return end
    local camera = workspace.CurrentCamera
    if not camera then return end

    local mousePosition = UserInputService:GetMouseLocation()
    local ray = camera:ViewportPointToRay(mousePosition.X, mousePosition.Y)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {character, activeMeshModel}

    local result = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
    if not result then return end

    local portalPosition = result.Position + result.Normal * 0.25
    local entrancePosition = root.Position + root.CFrame.LookVector * PORTAL_DISTANCE
    
    local destinationCFrame = computeExitCFrame(portalPosition + result.Normal * 3, result.Normal)
    local entranceCFrame = computeExitCFrame(entrancePosition + root.CFrame.LookVector * 3, -root.CFrame.LookVector)

    destroyPortal(currentPortal)
    destroyPortal(returnPortal)

    currentPortal = createPortalAsset(portalPosition, result.Normal, "DESTINATION", entranceCFrame, false)
    returnPortal = createPortalAsset(entrancePosition, -root.CFrame.LookVector, "GO TO PORTAL", destinationCFrame, true)
end

--============================================================
-- INTERFACE DISPLAY LAYER (GREEN STYLE)
--============================================================
local function createGUI()
    local gui = Instance.new("ScreenGui")
    gui.Name = "PortalGunGUI"
    gui.ResetOnSpawn = false
    gui.Parent = player:WaitForChild("PlayerGui")
    mainGui = gui

    local main = Instance.new("Frame")
    main.Size = UDim2.fromOffset(390, 480)
    main.Position = UDim2.fromScale(0.5, 0.5)
    main.AnchorPoint = Vector2.new(0.5, 0.5)
    main.BackgroundColor3 = Color3.fromRGB(10, 15, 11)
    main.Parent = gui
    menu = main

    local stroke = Instance.new("UIStroke")
    stroke.Color = GREEN
    stroke.Thickness = 2
    stroke.Parent = main

    status = Instance.new("TextLabel")
    status.Size = UDim2.new(1, -60, 0, 30)
    status.Position = UDim2.fromOffset(30, 310)
    status.BackgroundTransparency = 1
    status.Text = "Rick's Portal Gun Active | Click Scroll Wheel to fire"
    status.TextColor3 = Color3.fromRGB(110, 140, 115)
    status.Font = Enum.Font.Gotham
    status.TextSize = 13
    status.Parent = main

    local deployButton = Instance.new("TextButton")
    deployButton.Size = UDim2.new(1, -60, 0, 42)
    deployButton.Position = UDim2.fromOffset(30, 350)
    deployButton.BackgroundColor3 = Color3.fromRGB(25, 130, 45)
    deployButton.Text = "OPEN PORTAL"
    deployButton.TextColor3 = Color3.fromRGB(230, 255, 235)
    deployButton.Font = Enum.Font.GothamBold
    deployButton.TextSize = 16
    deployButton.Parent = main

    deployButton.MouseButton1Click:Connect(function()
        local character = getCharacter()
        local root = getRoot(character)
        if not root then return end
        shootPortalAtCursor()
        main.Visible = false
    end)

    return gui
end

--============================================================
-- PORTAL GUN MESH ASSET SPARK COMPONENT
--============================================================
local function spawnPortalMeshModel()
    local activeColor = GREEN
    local character = getCharacter()
    local root = getRoot(character)
    
    local model = Instance.new("Model")
    model.Name = "AperturePortalGunModel"
    model.Parent = workspace

    local mainPart = Instance.new("Part")
    mainPart.Name = "GunMeshHandle"
    mainPart.Size = Vector3.new(2, 2, 4)
    mainPart.CanCollide = true
    mainPart.Anchored = true
    mainPart.CastShadow = true
    mainPart.Material = Enum.Material.Glass
    
    if root then
        mainPart.CFrame = root.CFrame * CFrame.new(0, 0, -4) * CFrame.Angles(0, math.rad(180), 0)
else mainPart.CFrame = CFrame.new(0, 5, 0)endmainPart.Parent = model-- Core Asset Mesh Injectionslocal specialMesh = Instance.new("SpecialMesh")specialMesh.MeshType = Enum.MeshType.FileMeshspecialMesh.MeshId = GUN_MESH_IDspecialMesh.TextureId = GUN_TEXT_IDspecialMesh.Scale = Vector3.new(2.5, 2.5, 2.5)specialMesh.Parent = mainPartlocal lightNode = Instance.new("Part")lightNode.Size = Vector3.new(0.4, 0.4, 0.4)lightNode.Transparency = 1lightNode.CanCollide = falselightNode.Anchored = truelightNode.CFrame = mainPart.CFrame * CFrame.new(0, 0.2, 0.3)lightNode.Parent = modellocal coreLight = Instance.new("PointLight")coreLight.Color = activeColorcoreLight.Brightness = 6coreLight.Range = 10coreLight.Parent = lightNodecoreLightRef = coreLightreturn modelend--============================================================-- DUPLICATION ENVIRONMENT PIPELINES (STARTERPACK & SERVERSTORAGE)--============================================================local function executeDuplicationPipelines()-- 1. Double the gun into Local StarterPack representationlocal packTarget = player:WaitForChild("StarterPack", 2) or Instance.new("Folder", player)packTarget.Name = "StarterPack"local playerTool = Instance.new("Tool")playerTool.Name = "Rick's Portal Gun (Inventory Tool)"playerTool.RequiresHandle = trueplayerTool.Grip = CFrame.new(0, -0.05, -0.15) * CFrame.Angles(0, math.rad(90), 0)local toolHandle = Instance.new("Part")toolHandle.Name = "Handle"toolHandle.Size = Vector3.new(2, 2, 4)toolHandle.CanCollide = falsetoolHandle.Parent = playerToollocal toolMesh = Instance.new("SpecialMesh")toolMesh.MeshType = Enum.MeshType.FileMeshtoolMesh.MeshId = GUN_MESH_IDtoolMesh.TextureId = GUN_TEXT_IDtoolMesh.Scale = Vector3.new(2.5, 2.5, 2.5)toolMesh.Parent = toolHandleplayerTool.Activated:Connect(function() if menu then menu.Visible = not menu.Visible end end)playerTool.Parent = packTarget-- 2. Clone and mirror a standalone base into ServerStorage if network allows itpcall(function()local serverStorage = game:GetService("ServerStorage")if serverStorage thenlocal storageClone = activeMeshModel:Clone()storageClone.Name = "ServerStoragePortalGunModel"for _, part in ipairs(storageClone:GetDescendants()) doif part:IsA("BasePart") then part.Anchored = true endendstorageClone.Parent = serverStorageendend)end--============================================================-- SYSTEM INPUT REGISTRATIONS--============================================================local function initializeInputListeners()UserInputService.InputBegan:Connect(function(input, processed)if processed then return endif input.UserInputType == Enum.UserInputType.MouseButton3 thenshootPortalAtCursor()elseif input.KeyCode == Enum.KeyCode.X thenremoveAllPortals()elseif input.KeyCode == Enum.KeyCode.M thenif menu then menu.Visible = not menu.Visible endendend)RunService.RenderStepped:Connect(function()if coreLightRef thencoreLightRef.Brightness = 5 + math.sin(os.clock() * 6) * 2endend)end--============================================================-- INITIALIZATION OVERLAY--============================================================createGUI()activeMeshModel = spawnPortalMeshModel()executeDuplicationPipelines()initializeInputListeners()player.CharacterAdded:Connect(function()removeAllPortals()task.wait(1)if activeMeshModel then activeMeshModel:Destroy() endactiveMeshModel = spawnPortalMeshModel()end)