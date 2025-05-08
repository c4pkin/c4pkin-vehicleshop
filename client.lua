local QBCore = exports['qb-core']:GetCoreObject()

local Config = {
    DealerNPC = {
        model = "ig_molly",
        coords = vector4(-57.02, -1098.94, 26.42, 29.46), 
    },
    CarShop = {
        name = "Vehicle List", 
    }
}

local vehicles = {}
local isShopOpen = false

local function GetVehicleByName(name)
    for _, vehicle in pairs(vehicles) do
        if vehicle.name == name then
            return vehicle
        end
    end
    return nil
end

CreateThread(function()
    local model = GetHashKey(Config.DealerNPC.model)
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(1)
    end
    
    local ped = CreatePed(4, model, Config.DealerNPC.coords.x, Config.DealerNPC.coords.y, Config.DealerNPC.coords.z - 1.0, Config.DealerNPC.coords.w, false, true)
    SetEntityHeading(ped, Config.DealerNPC.coords.w)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    exports['qb-target']:AddTargetEntity(ped, {
        options = {
            {
                type = "client",
                event = "c4pkin-vehicleshop:client:openShop",
                icon = "fas fa-person",
                label = "Diana ile konuş",
            }
        },
        distance = 2.0
    })
end)

CreateThread(function()
    Wait(1000) 
    TriggerServerEvent('c4pkin-vehicleshop:server:requestVehicles')
end)

RegisterNetEvent('c4pkin-vehicleshop:client:receiveVehicles')
AddEventHandler('c4pkin-vehicleshop:client:receiveVehicles', function(vehicleData)
    if vehicleData then
        vehicles = vehicleData
        print("Araç verileri başarıyla alındı: " .. #vehicles .. " araç")
    else
        print("Araç verileri alınamadı veya boş")
        vehicles = {}
    end
end)

CreateThread(function()
    while true do
        Wait(0)
        if isShopOpen then
            if IsControlJustPressed(0, 177) then
                closeVehicleShop()
            end
        else
            Wait(1000)
        end
    end
end)

function closeVehicleShop()
    if isShopOpen then
        isShopOpen = false
        SendNUIMessage({
            action = "close"
        })
        SetNuiFocus(false, false)
        TriggerScreenblurFadeOut(500)
    end
end

RegisterNetEvent('c4pkin-vehicleshop:client:openShop', function()

    TriggerServerEvent('c4pkin-vehicleshop:server:requestVehicles')
    
    Wait(500)
    
    local shopItems = {}
    for _, vehicle in ipairs(vehicles) do
        local item = {
            name = vehicle.name,
            label = vehicle.label,
            category = vehicle.category,
            price = vehicle.price,
            stock = vehicle.stock,
            image = vehicle.image
        }
        table.insert(shopItems, item)
    end

    isShopOpen = true
    TriggerScreenblurFadeIn(500)
    SendNUIMessage({
        action = "open",
        items = shopItems,
        storeId = "c4pkin-vehicleshop",
        storeName = Config.CarShop.name
    })
    SetNuiFocus(true, true)
end)

RegisterNetEvent('c4pkin-vehicleshop:client:updateVehicleStock', function(vehicleName, newStock)
    for i, vehicle in ipairs(vehicles) do
        if vehicle.name == vehicleName then
            vehicle.stock = newStock
            break
        end
    end
    
    if isShopOpen then
        SendNUIMessage({
            action = "updateStock",
            itemName = vehicleName,
            newStock = newStock
        })
    end
end)

RegisterNetEvent('c4pkin-vehicleshop:client:spawnPurchasedVehicle')
AddEventHandler('c4pkin-vehicleshop:client:spawnPurchasedVehicle', function(vehicleName, plate, spawnLocation)
    -- Burada önce orijinal galeri script fonksiyonlarını çalıştır
    local model = GetHashKey(vehicleName)
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(1)
    end

    local vehicle = CreateVehicle(model, spawnLocation.x, spawnLocation.y, spawnLocation.z, spawnLocation.w, true, false)
    SetEntityAsMissionEntity(vehicle, true, true)
    
    SetVehicleNumberPlateText(vehicle, plate)
    
    TriggerEvent('vehiclekeys:client:SetOwner', plate)
    
    local blip = AddBlipForEntity(vehicle)
    SetBlipSprite(blip, 225)
    SetBlipColour(blip, 2) 
    SetBlipScale(blip, 0.8)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Yeni Aracınız")
    EndTextCommandSetBlipName(blip)
    
    SetTimeout(60000, function()
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end)
    
    -- Araç verileri oluştur ve lokasyon sistemine ekle
    local coords = GetEntityCoords(vehicle)
    local heading = GetEntityHeading(vehicle)
    local fuel = GetVehicleFuelLevel(vehicle)
    local engineHealth = GetVehicleEngineHealth(vehicle)
    local bodyHealth = GetVehicleBodyHealth(vehicle)
    
    -- Plakadaki boşlukları temizle
    local cleanPlate = string.gsub(plate, "%s+", "")
    
    -- Araç verilerini hazırla
    local vehicleData = {
        plate = cleanPlate,
        coords = {
            x = coords.x,
            y = coords.y,
            z = coords.z
        },
        heading = heading,
        model = model,
        fuel = fuel,
        engineHealth = engineHealth,
        bodyHealth = bodyHealth,
        parkedAt = math.floor(GetGameTimer() / 1000) -- Saniye cinsinden oyun zamanı
    }
    
    -- Lokasyon sistemine bildir
    TriggerEvent("qb-vehiclelocation:client:SaveNewVehicleLocation", vehicleData)
    
    QBCore.Functions.Notify("Aracınız oluşturuldu ve haritada işaretlendi!", "success")
    
    if isShopOpen then
        closeVehicleShop()
    end
    
    -- Geçerli lokasyon değişikliğini 2 saniye sonra kaydet (aracın yere düzgün oturması için)
    SetTimeout(2000, function()
        if DoesEntityExist(vehicle) then
            local updatedCoords = GetEntityCoords(vehicle)
            local updatedHeading = GetEntityHeading(vehicle)
            
            vehicleData.coords = {
                x = updatedCoords.x,
                y = updatedCoords.y,
                z = updatedCoords.z
            }
            vehicleData.heading = updatedHeading
            
            -- Güncellenmiş konumu kaydet
            TriggerEvent("qb-vehiclelocation:client:SaveNewVehicleLocation", vehicleData)
        end
    end)
end)

RegisterNUICallback('BuyItem', function(data, cb)
    local vehicle = GetVehicleByName(data.item.name)
    local amount = data.amount
    
    if not vehicle then
        QBCore.Functions.Notify("Bu araç mevcut değil.", "error")
        cb('error')
        return
    end
    
    if vehicle.stock < amount then
        QBCore.Functions.Notify("Bu araçtan yeterli stok yok.", "error")
        cb('error')
        return
    end

    TriggerServerEvent('c4pkin-vehicleshop:server:buyVehicle', vehicle.name, amount)
    cb('ok')
end)

RegisterNUICallback('CloseShop', function(_, cb)
    closeVehicleShop()
    cb('ok')
end)

RegisterNUICallback('SetNuiFocus', function(data, cb)
    SetNuiFocus(data.focus, data.cursor)
    cb('ok')
end)