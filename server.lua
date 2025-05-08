local QBCore = exports['qb-core']:GetCoreObject()

local Config = {
    DealerLocation = {
        id = 'c4pkin-vehicleshop',
        label = "Vehicle List",
        coords = vector4(-57.02, -1098.94, 26.42, 29.46),
        ped = "a_m_y_business_03"
    },
    SpawnLocations = {
        vector4(104.24, -1078.9, 29.19, 332.12),
        vector4(107.91, -1079.8, 29.19, 334.03),
        vector4(111.43, -1080.89, 29.19, 5.01)
    }
}

local NumberCharset = {}
local Charset = {}

for i = 48, 57 do table.insert(NumberCharset, string.char(i)) end
for i = 65, 90 do table.insert(Charset, string.char(i)) end
for i = 97, 122 do table.insert(Charset, string.char(i)) end

function GeneratePlate()
    local plate = ""
    for i = 1, 3 do
        plate = plate .. Charset[math.random(1, #Charset)]
    end

    for i = 1, 3 do
        plate = plate .. NumberCharset[math.random(1, #NumberCharset)]
    end
    
    local result = MySQL.Async.fetchScalar.await('SELECT plate FROM player_vehicles WHERE plate = ?', {plate})
    if result then
        return GeneratePlate()
    else
        return plate:upper()
    end
end

function IsVehicleAtLocation(coords, radius)
    local vehicles = GetAllVehicles()
    for _, vehicle in ipairs(vehicles) do
        local vehCoords = GetEntityCoords(vehicle)
        local distance = #(vehCoords - vector3(coords.x, coords.y, coords.z))
        if distance <= radius then
            return true
        end
    end
    return false
end

function FindAvailableSpawnLocation()
    for _, location in ipairs(Config.SpawnLocations) do
        if not IsVehicleAtLocation(location, 2.0) then
            return location
        end
    end

    return Config.SpawnLocations[1]
end

RegisterNetEvent('c4pkin-vehicleshop:server:requestVehicles')
AddEventHandler('c4pkin-vehicleshop:server:requestVehicles', function()
    local src = source
    
    MySQL.Async.fetchAll('SELECT * FROM c4pkin_vehicleshp', {}, function(result)
        if result and #result > 0 then
            local vehicles = {}
            for _, v in ipairs(result) do
                table.insert(vehicles, {
                    name = v.vehicle_name,
                    label = v.label,
                    category = v.category,
                    price = v.price,
                    stock = v.stock,
                    image = v.image
                })
            end
            TriggerClientEvent('c4pkin-vehicleshop:client:receiveVehicles', src, vehicles)
        else
            TriggerClientEvent('c4pkin-vehicleshop:client:receiveVehicles', src, {})
        end
    end)
end)

RegisterNetEvent('c4pkin-vehicleshop:server:buyVehicle')
AddEventHandler('c4pkin-vehicleshop:server:buyVehicle', function(vehicleName, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    
    if not Player then return end
    
    MySQL.Async.fetchAll('SELECT * FROM c4pkin_vehicleshp WHERE vehicle_name = ?', {
        vehicleName
    }, function(result)
        if not result or #result == 0 then
            TriggerClientEvent('QBCore:Notify', src, "Bu araç mevcut değil.", "error")
            return
        end
        
        local vehicle = {
            name = result[1].vehicle_name,
            label = result[1].label,
            price = result[1].price,
            stock = result[1].stock
        }
        
        if vehicle.stock < amount then
            TriggerClientEvent('QBCore:Notify', src, "Bu araçtan yeterli stok yok.", "error")
            return
        end
        
        local totalPrice = vehicle.price * amount
        
        if Player.PlayerData.money.bank < totalPrice then
            TriggerClientEvent('QBCore:Notify', src, "Yeterli paranız yok.", "error")
            return
        end
        
        Player.Functions.RemoveMoney('bank', totalPrice, "vehicle-purchase")
        
        MySQL.Async.execute('UPDATE c4pkin_vehicleshp SET stock = stock - ? WHERE vehicle_name = ?', {
            amount,
            vehicleName
        }, function(affectedRows)
            if affectedRows > 0 then

                local plate = GeneratePlate()
                local vehicleProps = {}

                MySQL.Async.execute('INSERT INTO player_vehicles (license, citizenid, vehicle, plate, garage, state) VALUES (?, ?, ?, ?, ?, ?)', {
                    Player.PlayerData.license,
                    Player.PlayerData.citizenid,
                    vehicleName,
                    plate,
                    'pillboxgarage', 
                    1, 
                }, function()

                    local spawnLocation = FindAvailableSpawnLocation()
                    
                    TriggerClientEvent('c4pkin-vehicleshop:client:spawnPurchasedVehicle', src, vehicleName, plate, spawnLocation)
                    
                    TriggerClientEvent('c4pkin-vehicleshop:client:updateVehicleStock', -1, vehicleName, vehicle.stock - amount)
                    
                    local info = {
                        plate = plate,
                        model = vehicle.label,
                        description = plate,
                        text = plate,
                        aciklama = plate,
                        plaka = plate,
                        arac = vehicle.label,
                        label = "Araç Anahtarı: " .. plate
                    }
                    
                    Player.Functions.AddItem("vehiclekey", 1, false, info)
                    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items["vehiclekey"], "add")
                    TriggerEvent('inventory:server:updateItemInfo', src, "vehiclekey", plate)
                    
                    local initialData = {
                        coords = {
                            x = spawnLocation.x,
                            y = spawnLocation.y,
                            z = spawnLocation.z
                        },
                        heading = spawnLocation.w,
                        model = GetHashKey(vehicleName),
                        fuel = 100,
                        engineHealth = 1000,
                        bodyHealth = 1000,
                        parkedAt = os.time()
                    }

                    MySQL.Async.execute('INSERT INTO vehicles_location (plate, data) VALUES (?, ?) ON DUPLICATE KEY UPDATE data = ?',
                        {plate, json.encode(initialData), json.encode(initialData)},
                        function()
                            print("Yeni alınan araç lokasyon sistemine eklendi: " .. plate)
                        end
                    )
                    
                   -- Console Log
                   -- print("Araç satın alma başarılı: " .. vehicleName .. " - Oyuncu: " .. Player.PlayerData.name .. " - Plaka: " .. plate)
                    
                    TriggerClientEvent('QBCore:Notify', src, vehicle.label .. " satın alındı! Aracınız dışarıda sizi bekliyor.", "success", 5000)
                end)
            else

                Player.Functions.AddMoney('bank', totalPrice, "vehicle-purchase-refund")
                TriggerClientEvent('QBCore:Notify', src, "İşlem sırasında bir hata oluştu.", "error")
            end
        end)
    end)
end)

QBCore.Commands.Add("vshopsadd", "Galeriye yeni araç ekle", {
    {name="araç_modeli", help="Araç modeli (örn: adder)"},
    {name="isim", help="Araç ismi (örn: Adder)"},
    {name="kategori", help="Araç kategorisi (örn: super)"},
    {name="fiyat", help="Araç fiyatı"},
    {name="stok", help="Başlangıç stok miktarı"},
    {name="resim", help="Resim dosyası (örn: adder.jpg)"}
}, true, function(source, args)
    local src = source
    
    if #args < 6 then
        TriggerClientEvent('QBCore:Notify', src, "Eksik parametre. Kullanım: /vshopsadd [araç_modeli] [isim] [kategori] [fiyat] [stok] [resim]", "error")
        return
    end
    
    local vehicleName = args[1]:lower()
    local label = args[2]
    local category = args[3]:lower()
    local price = tonumber(args[4])
    local stock = tonumber(args[5])
    local image = args[6]
    
    if not price or price <= 0 then
        TriggerClientEvent('QBCore:Notify', src, "Geçerli bir fiyat giriniz.", "error")
        return
    end
    
    if not stock or stock < 0 then
        TriggerClientEvent('QBCore:Notify', src, "Geçerli bir stok miktarı giriniz.", "error")
        return
    end
    
    MySQL.Async.fetchScalar('SELECT COUNT(*) FROM c4pkin_vehicleshp WHERE vehicle_name = ?', {
        vehicleName
    }, function(count)
        if count > 0 then
            TriggerClientEvent('QBCore:Notify', src, "Bu araç zaten galeriye kayıtlı.", "error")
            return
        end

        MySQL.Async.execute('INSERT INTO c4pkin_vehicleshp (vehicle_name, label, category, price, stock, image) VALUES (?, ?, ?, ?, ?, ?)', {
            vehicleName,
            label,
            category,
            price,
            stock,
            image
        }, function(rowsChanged)
            if rowsChanged > 0 then
                TriggerClientEvent('QBCore:Notify', src, label .. " galeriye eklendi.", "success")
            else
                TriggerClientEvent('QBCore:Notify', src, "Araç eklenirken bir hata oluştu.", "error")
            end
        end)
    end)
end, "admin")

QBCore.Commands.Add("stockadd", "Galeriye stok ekle", {{name="araç", help="Araç modeli"}, {name="miktar", help="Eklenecek stok miktarı"}}, true, function(source, args)
    local src = source
    if args[1] and args[2] then
        local vehicleName = args[1]:lower()
        local amount = tonumber(args[2])
        
        if not amount or amount <= 0 then
            TriggerClientEvent('QBCore:Notify', src, "Geçerli bir miktar giriniz.", "error")
            return
        end
        
        MySQL.Async.fetchScalar('SELECT stock FROM c4pkin_vehicleshp WHERE vehicle_name = ?', {
            vehicleName
        }, function(currentStock)
            if not currentStock then
                TriggerClientEvent('QBCore:Notify', src, "Bu araç galeriye kayıtlı değil.", "error")
                return
            end
            
            MySQL.Async.execute('UPDATE c4pkin_vehicleshp SET stock = stock + ? WHERE vehicle_name = ?', {
                amount,
                vehicleName
            }, function(rowsChanged)
                if rowsChanged > 0 then
                    TriggerClientEvent('QBCore:Notify', src, vehicleName .. " için " .. amount .. " stok eklendi. Yeni stok: " .. (currentStock + amount), "success")
                    TriggerClientEvent('c4pkin-vehicleshop:client:updateVehicleStock', -1, vehicleName, currentStock + amount)
                else
                    TriggerClientEvent('QBCore:Notify', src, "Stok güncellenirken bir hata oluştu.", "error")
                end
            end)
        end)
    else
        TriggerClientEvent('QBCore:Notify', src, "Kullanım: /stockadd [araç_modeli] [miktar]", "error")
    end
end, "admin")

QBCore.Commands.Add("delvehicle", "Galeriden araç sil", {{name="araç_modeli", help="Araç modeli (örn: adder)"}}, true, function(source, args)
    local src = source
    
    if not args[1] then
        TriggerClientEvent('QBCore:Notify', src, "Kullanım: /delvehicle [araç_modeli]", "error")
        return
    end
    
    local vehicleName = args[1]:lower()

    MySQL.Async.fetchScalar('SELECT COUNT(*) FROM c4pkin_vehicleshp WHERE vehicle_name = ?', {
        vehicleName
    }, function(count)
        if count == 0 then
            TriggerClientEvent('QBCore:Notify', src, "Bu araç galeriye kayıtlı değil.", "error")
            return
        end

        MySQL.Async.execute('DELETE FROM c4pkin_vehicleshp WHERE vehicle_name = ?', {
            vehicleName
        }, function(rowsChanged)
            if rowsChanged > 0 then
                TriggerClientEvent('QBCore:Notify', src, vehicleName .. " galeriden silindi.", "success")
            else
                TriggerClientEvent('QBCore:Notify', src, "Araç silinirken bir hata oluştu.", "error")
            end
        end)
    end)
end, "admin")

QBCore.Commands.Add("shopsvehiclelist", "Galerideki araçları listele", {}, false, function(source, args)
    local src = source
    
    MySQL.Async.fetchAll('SELECT * FROM c4pkin_vehicleshp ORDER BY category, label', {}, function(result)
        if not result or #result == 0 then
            TriggerClientEvent('QBCore:Notify', src, "Galeride hiç araç yok.", "error")
            return
        end
        
        local vehicleList = "Galerideki Araçlar:\n"
        local currentCategory = ""
        
        for _, vehicle in ipairs(result) do
            if vehicle.category ~= currentCategory then
                currentCategory = vehicle.category
                vehicleList = vehicleList .. "\n[" .. currentCategory:upper() .. "]\n"
            end
            
            vehicleList = vehicleList .. vehicle.label .. " (" .. vehicle.vehicle_name .. ") - $" .. vehicle.price .. " - Stok: " .. vehicle.stock .. "\n"
        end
        
        TriggerClientEvent('QBCore:Notify', src, vehicleList, "primary", 10000)
    end)
end, "admin")