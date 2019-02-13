local helpers = require "helpers"

local assets =
{
    Asset("ANIM", "anim/armor_honey.zip"),
    Asset("ATLAS", "images/inventoryimages/armorhoney.xml"),
    Asset("IMAGE", "images/inventoryimages/armorhoney.tex"),
}

local prefabs =
{
    "spoiled_food",
}

local function StopHealing(inst)
    inst._healtick = 0

    if inst._healtask then
        inst._healtask:Cancel()
        inst._healtask = nil
    end
end

local function DoHealing(inst)
    local owner = nil

    if inst.components.inventoryitem and inst.components.perishable then
        owner = inst.components.inventoryitem:GetGrandOwner()
        if owner and owner.components.health then
            local percent = Lerp(
                TUNING.ARMORHONEY_MIN_HEAL_PERCENT,
                TUNING.ARMORHONEY_MAX_HEAL_PERCENT,
                inst.components.perishable:GetPercent()
            )
            local extra = Lerp(
                TUNING.ARMORHONEY_MIN_HEAL_EXTRA,
                TUNING.ARMORHONEY_MAX_HEAL_EXTRA,
                inst.components.perishable:GetPercent()
            )
            local delta = (owner.components.health.maxhealth - owner.components.health.currenthealth) * percent + extra
            owner.components.health:DoDelta(delta, nil, "armorhoney_health")
        end
    end

    inst._healtick = inst._healtick - 1
    if inst._healtick <= 0 or (owner and owner.components.health and owner.components.health:IsDead()) then
        StopHealing(inst)
    end
end

local function StartHealing(inst)
    inst._healtick = TUNING.ARMORHONEY_HEAL_TICKS

    if inst._healtask == nil then
        inst._healtask = inst:DoPeriodicTask(TUNING.ARMORHONEY_HEAL_INTERVAL, DoHealing)
    end
end

local function OnTakeDamage(inst, amount)
    inst.components.armor:SetPercent(1)
    StartHealing(inst)
end

local function OnBlocked(owner)
    owner.SoundEmitter:PlaySound("dontstarve/wilson/hit_armour")
end

local function onequip(inst, owner)
    owner.AnimState:OverrideSymbol("swap_body", "armor_honey", "swap_body")

    inst:ListenForEvent("blocked", OnBlocked, owner)
end

local function onunequip(inst, owner)
    owner.AnimState:ClearOverrideSymbol("swap_body")
    inst:RemoveEventCallback("blocked", OnBlocked, owner)
    StopHealing(inst)
end

local function UpdateAbsorption(inst, data)
    if inst.components.armor and inst.components.perishable then
        local absorption = Lerp(
            TUNING.ARMORHONEY_MIN_ABSORPTION,
            TUNING.ARMORHONEY_MAX_ABSORPTION,
            inst.components.perishable:GetPercent()
        )
        inst.components.armor:SetAbsorption(absorption)
    end
end

local function InitFn(inst)
    UpdateAbsorption(inst)
end

local function fn()
    local inst = CreateEntity()

    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("armor_honey")
    inst.AnimState:SetBuild("armor_honey")
    inst.AnimState:PlayAnimation("anim")

    MakeInventoryFloatable(inst, "idle_water", "anim")

    inst:AddTag("wood")
    inst:AddTag("show_spoilage")
    inst:AddTag("icebox_valid")

    inst.foleysound = "dontstarve/movement/foley/logarmour"

    inst:AddComponent("inspectable")

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.imagename = "armorhoney"
    inst.components.inventoryitem.atlasname = "images/inventoryimages/armorhoney.xml"

    inst:AddComponent("armor")
    inst.components.armor:InitCondition(999999, TUNING.ARMORHONEY_MAX_ABSORPTION)
    inst.components.armor.ontakedamage = OnTakeDamage

    inst:AddComponent("appeasement")
    inst.components.appeasement.appeasementvalue = TUNING.WRATH_SMALL

    inst:AddComponent("equippable")
    inst.components.equippable.equipslot = EQUIPSLOTS.BODY
    inst.components.equippable:SetOnEquip(onequip)
    inst.components.equippable:SetOnUnequip(onunequip)

    inst:AddComponent("perishable")
    inst.components.perishable:SetPerishTime(TUNING.PERISH_MED)
    inst.components.perishable:StartPerishing()
    inst.components.perishable.onperishreplacement = "spoiled_food"
    inst:ListenForEvent("perishchange", UpdateAbsorption)

    inst:DoTaskInTime(0, InitFn)

    return inst
end

STRINGS.ARMORHONEY = "Honey Suit"
STRINGS.NAMES.ARMORHONEY = "Honey Suit"
STRINGS.RECIPE_DESC.ARMORHONEY = "Sweet and protective"
STRINGS.CHARACTERS.GENERIC.DESCRIBE.ARMORHONEY = "It's so sticky wearing it."

return Prefab("armorhoney", fn, assets, prefabs)
