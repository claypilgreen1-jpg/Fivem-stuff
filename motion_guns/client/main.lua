-- Weapon wheel / HUD names come from the WT_* labels set in weapons.meta.
CreateThread(function()
    for _, weapon in ipairs(MotionGuns.Weapons) do
        AddTextEntry('WT_' .. weapon.name:sub(8), weapon.label)
    end
end)

RegisterNetEvent('motion_guns:give', function(name, ammo)
    local hash = joaat(name)
    if not IsWeaponValid(hash) then
        print(('[motion_guns] %s is not loaded - check the server console for meta errors'):format(name))
        return
    end
    GiveWeaponToPed(PlayerPedId(), hash, ammo, false, true)
end)
