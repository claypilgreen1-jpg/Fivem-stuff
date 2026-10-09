Photo = { touring = false }

local pending

-- Hide the HUD for every frame while a screenshot is being captured,
-- including when the free cam is off.
local function hideHudWhileCapturing()
    while Freecam.hideUi do
        HideHudAndRadarThisFrame()
        Wait(0)
    end
end

-- Takes a screenshot and waits for the server to save it. Returns ok, fileNameOrError.
function Photo.Take(label)
    if pending then return false, 'a screenshot is already in progress' end
    local p = promise.new()
    pending = p
    Freecam.hideUi = true
    CreateThread(hideHudWhileCapturing)
    Wait(100) -- let a couple of frames render without the HUD

    TriggerServerEvent('motion_testbot:screenshot', label or 'shot')
    SetTimeout(20000, function()
        if pending == p then
            pending = nil
            p:resolve({ false, 'timed out waiting for screenshot-basic' })
        end
    end)
    local result = Citizen.Await(p)
    Freecam.hideUi = false

    if result[1] then
        Util.Notify(('Saved screenshots/%s'):format(result[2]))
    else
        Util.Notify(('Screenshot failed: %s'):format(result[2]))
    end
    return result[1], result[2]
end

RegisterNetEvent('motion_testbot:screenshotDone', function(ok, info)
    local p = pending
    if p then
        pending = nil
        p:resolve({ ok, info })
    end
end)

local function loadScene(spot, rot)
    local dir = Util.RotationToDirection(rot)
    NewLoadSceneStart(spot.cam.x, spot.cam.y, spot.cam.z, dir.x, dir.y, dir.z, 500.0, 0)
    local deadline = GetGameTimer() + 10000
    while not IsNewLoadSceneLoaded() and GetGameTimer() < deadline do
        Wait(100)
    end
    NewLoadSceneStop()
end

-- Flies the free cam through Config.PhotoSpots (or just the named ones) and
-- takes a screenshot at each.
function Photo.Tour(names)
    if Photo.touring then
        Util.Notify('A tour is already running. Use "/bot tour stop" first.')
        return
    end

    local spots = {}
    for _, spot in ipairs(Config.PhotoSpots) do
        if #names == 0 then
            spots[#spots + 1] = spot
        else
            for _, name in ipairs(names) do
                if name:lower() == spot.name:lower() then spots[#spots + 1] = spot end
            end
        end
    end
    if #spots == 0 then
        Util.Notify('No matching photo spots. Check Config.PhotoSpots.')
        return
    end

    Photo.touring = true
    local wasActive = Freecam.active
    local returnPos, returnRot = Freecam.GetView()
    if not wasActive then Freecam.Start() end
    Freecam.locked = true
    Util.Notify(('Photo tour: %d spot(s).'):format(#spots))

    for i, spot in ipairs(spots) do
        if not Photo.touring then break end
        local rot = spot.rot or Util.RotationTo(spot.cam, spot.look)
        Freecam.SetView(spot.cam, rot, spot.fov)
        if spot.hour then NetworkOverrideClockTime(spot.hour, 0, 0) end
        loadScene(spot, rot)
        Wait(Config.Screenshots.settleTime)
        if not Photo.touring then break end
        Util.Notify(('(%d/%d) %s'):format(i, #spots, spot.name))
        Photo.Take(spot.name)
        if spot.hour then NetworkClearClockTimeOverride() end
    end

    NetworkClearClockTimeOverride()
    Photo.touring = false
    if Freecam.active then
        Freecam.locked = false
        if wasActive then
            Freecam.SetView(returnPos, returnRot)
        else
            Freecam.Stop()
        end
    end
    Util.Notify('Photo tour finished.')
end

function Photo.StopTour()
    Photo.touring = false
end

-- Prints a Config.PhotoSpots line for the current free cam view.
function Photo.PrintSpot(name)
    if not Freecam.active then
        Util.Notify('Open the free cam first ("/bot cam"), then frame the shot.')
        return
    end
    local p, r, f = Freecam.GetView()
    local line = ("{ name = '%s', cam = vec3(%.2f, %.2f, %.2f), rot = vec3(%.2f, 0.0, %.2f), fov = %.1f },")
        :format(name or 'spot', p.x, p.y, p.z, r.x, r.z, f)
    print(line)
    Util.Notify(line)
    Util.Notify('Also printed to the F8 console for copying.')
end
