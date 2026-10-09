Outfit = {}

local COMPONENTS = {
    { id = 0, label = 'Face' }, { id = 1, label = 'Mask' }, { id = 2, label = 'Hair' },
    { id = 3, label = 'Arms / gloves' }, { id = 4, label = 'Pants' }, { id = 5, label = 'Bag' },
    { id = 6, label = 'Shoes' }, { id = 7, label = 'Chain / scarf' }, { id = 8, label = 'Undershirt' },
    { id = 9, label = 'Body armor' }, { id = 10, label = 'Decals' }, { id = 11, label = 'Top / jacket' },
}
local PROPS = {
    { id = 0, label = 'Hat' }, { id = 1, label = 'Glasses' }, { id = 2, label = 'Earrings' },
    { id = 6, label = 'Watch' }, { id = 7, label = 'Bracelet' },
}

local FREEMODE = { [`mp_m_freemode_01`] = true, [`mp_f_freemode_01`] = true }

local function isFreemode(ped)
    return FREEMODE[GetEntityModel(ped)] == true
end

local function randomHead(ped)
    local mum, dad = math.random(21, 41), math.random(0, 20)
    SetPedHeadBlendData(ped, mum, dad, 0, mum, dad, 0, math.random(), math.random(), 0.0, false)
    SetPedHairColor(ped, math.random(0, 63), math.random(0, 63))
end

-- Freemode (online character) peds look broken until they get a head and default clothes.
function Outfit.SetupNew(ped, model)
    if isFreemode(ped) then
        SetPedHeadBlendData(ped, 21, 0, 0, 21, 0, 0, 0.5, 0.5, 0.0, false)
        SetPedDefaultComponentVariation(ped)
    else
        SetPedRandomComponentVariation(ped, 0)
    end
end

function Outfit.Get(ped)
    local out = { freemode = isFreemode(ped), components = {}, props = {} }
    for _, c in ipairs(COMPONENTS) do
        local max = GetNumberOfPedDrawableVariations(ped, c.id)
        if max > 1 then
            local drawable = GetPedDrawableVariation(ped, c.id)
            out.components[#out.components + 1] = {
                id = c.id, label = c.label, drawable = drawable, maxDrawable = max,
                texture = GetPedTextureVariation(ped, c.id),
                maxTexture = GetNumberOfPedTextureVariations(ped, c.id, drawable),
            }
        end
    end
    for _, p in ipairs(PROPS) do
        local max = GetNumberOfPedPropDrawableVariations(ped, p.id)
        if max > 0 then
            local drawable = GetPedPropIndex(ped, p.id)
            out.props[#out.props + 1] = {
                id = p.id, label = p.label, drawable = drawable, maxDrawable = max,
                texture = drawable >= 0 and GetPedPropTextureIndex(ped, p.id) or 0,
                maxTexture = drawable >= 0 and GetNumberOfPedPropTextureVariations(ped, p.id, drawable) or 0,
            }
        end
    end
    return out
end

-- kind = 'component' | 'prop'. For props, drawable -1 removes it.
function Outfit.Set(ped, kind, id, drawable, texture)
    id, drawable, texture = math.floor(id), math.floor(drawable), math.floor(texture or 0)
    if kind == 'prop' then
        if drawable < 0 then
            ClearPedProp(ped, id)
        else
            SetPedPropIndex(ped, id, drawable, texture, true)
        end
    else
        SetPedComponentVariation(ped, id, drawable, texture, 0)
    end
end

function Outfit.Randomize(ped)
    if isFreemode(ped) then
        randomHead(ped)
        for _, c in ipairs(COMPONENTS) do
            if c.id ~= 0 then
                local max = GetNumberOfPedDrawableVariations(ped, c.id)
                if max > 0 then
                    local drawable = math.random(0, max - 1)
                    local textures = GetNumberOfPedTextureVariations(ped, c.id, drawable)
                    SetPedComponentVariation(ped, c.id, drawable, textures > 0 and math.random(0, textures - 1) or 0, 0)
                end
            end
        end
        SetPedComponentVariation(ped, 1, 0, 0, 0) -- no random mask
        SetPedComponentVariation(ped, 9, 0, 0, 0) -- no random armor
    else
        SetPedRandomComponentVariation(ped, 0)
    end
    ClearAllPedProps(ped)
    SetPedRandomProps(ped)
end

function Outfit.Default(ped)
    SetPedDefaultComponentVariation(ped)
    ClearAllPedProps(ped)
end

-- Applies a saved preset: { components = {{id, drawable, texture}}, props = {...} }
function Outfit.Apply(ped, preset)
    for _, c in ipairs(preset.components or {}) do
        Outfit.Set(ped, 'component', c.id, c.drawable, c.texture)
    end
    ClearAllPedProps(ped)
    for _, p in ipairs(preset.props or {}) do
        Outfit.Set(ped, 'prop', p.id, p.drawable, p.texture)
    end
end
