-------------------------------------
------- Created by T1GER#9080 -------
-------------------------------------
ESX 					= nil
TriggerEvent(Config.ESXSHAREDOBJECT, function(obj) ESX = obj end)

-- Fetch all player shops:
RegisterServerEvent('t1ger_shops:fetchPlyShops')
AddEventHandler('t1ger_shops:fetchPlyShops', function()
    local xPlayers = ESX.GetPlayers()
    local players  = {}
    local ownedShops = {}
    local DataFetched = false
	for i = 1, #xPlayers, 1 do
		local xPlayer = ESX.GetPlayerFromId(xPlayers[i])
		table.insert(players, { source = xPlayer.source, identifier = xPlayer.identifier, shopID = 0, employeeID = 0 })
    end
    MySQL.Async.fetchAll("SELECT * FROM t1ger_shops", {}, function(results)
        if #results > 0 then
            for l,ply in pairs(players) do
                for i = 1, #results do
                    if ply.identifier == results[i].identifier then
                        ply.shopID = results[i].shopID
                    end
                    if #results[i].employees ~= nil then
                        local employees = json.decode(results[i].employees)
                        for k,v in pairs(employees) do
                            if ply.identifier == v.identifier then
                                ply.employeeID = results[i].shopID
                            end
                        end
                    end
                    table.insert(ownedShops, {id = results[i].shopID})
                    if i == #results then DataFetched = true end
                end
            end
        else
            DataFetched = true
        end
    end)
    while not DataFetched do Wait(5) end
    local plyShopID, plyEmployeeID = 0, 0
    if DataFetched then 
        for k,v in pairs(players) do
            if v.shopID > 0 then plyShopID = v.shopID else plyShopID = 0 end
            if v.employeeID > 0 then plyEmployeeID = v.employeeID else plyEmployeeID = 0 end
            TriggerClientEvent('t1ger_shops:applyPlyShops', v.source, plyShopID, plyEmployeeID, ownedShops)
        end
    end
end)

-- Purchase Shop:
ESX.RegisterServerCallback('t1ger_shops:buyShop',function(source, cb, id, val)
    local xPlayer = ESX.GetPlayerFromId(source)
    local money = 0
    if Config.BuyShopWithCash then money = xPlayer.getMoney() else money = xPlayer.getAccount('bank').money end
	if money >= val.price then
		if Config.BuyShopWithCash then xPlayer.removeMoney(val.price) else xPlayer.removeAccountMoney('bank', val.price) end
        MySQL.Sync.execute("INSERT INTO t1ger_shops (identifier, shopID) VALUES (@identifier, @shopID)", {['identifier'] = xPlayer.identifier, ['shopID'] = id})
        cb(true)
    else
        cb(false)
    end
end)

-- Sell Shop:
ESX.RegisterServerCallback('t1ger_shops:sellShop',function(source, cb, id, val, sellPrice)
    local xPlayer = ESX.GetPlayerFromId(source)
    MySQL.Async.fetchAll("SELECT shopID FROM t1ger_shops WHERE identifier = @identifier", {['@identifier'] = xPlayer.identifier}, function(data)
        if data[1].shopID ~= nil then 
            if data[1].shopID == id then
                MySQL.Async.execute("DELETE FROM t1ger_shops WHERE shopID = @shopID", {['@shopID'] = id}) 
                if Config.BuyShopWithCash then xPlayer.addMoney(sellPrice) else xPlayer.addAccountMoney('bank',sellPrice) end
                cb(true)
            else
                cb(false)
            end
        end
    end)
end)

-- Callback to Get online players:
ESX.RegisterServerCallback('t1ger_shops:getOnlinePlayers', function(source, cb)
	local fetchedPlayers = GetOnlinePlayers()
	cb(fetchedPlayers)
end)

-- Recruit Employee:
RegisterServerEvent('t1ger_shops:recruitEmployee')
AddEventHandler('t1ger_shops:recruitEmployee', function(id, plyIdentifier, newJobGrade, name)
    local xPlayer = ESX.GetPlayerFromId(source)
    local loopDone = false
    local identifierMatch = false
    local noEmployees = false
    MySQL.Async.fetchAll("SELECT employees FROM t1ger_shops WHERE shopID = @shopID", {['@shopID'] = id}, function(data)
        if data[1].employees ~= nil then 
            local employees = json.decode(data[1].employees)
            if #employees > 0 then
                for k,v in pairs(employees) do 
                    if plyIdentifier == v.identifier then
                        identifierMatch = true
                        break
                    else
                        if k == #employees then 
                            loopDone = true
                        end
                    end
                end
            else
                noEmployees = true
                loopDone = true
            end
        end
    end)
    while not loopDone do 
        Citizen.Wait(3)
    end
    if identifierMatch then 
        TriggerClientEvent('t1ger_shops:ShowNotifyESX', xPlayer.source, Lang['already_hired'])
    end
    if loopDone then
        if noEmployees then
            MySQL.Async.fetchAll("SELECT * FROM t1ger_shops WHERE shopID = @shopID", {['@shopID'] = id}, function(data)
                for _,y in pairs(data) do 
                    local employees = {}
                    table.insert(employees,{identifier = plyIdentifier, jobGrade = newJobGrade})
                    MySQL.Sync.execute("UPDATE t1ger_shops SET employees = @employees WHERE shopID = @shopID", {
                        ['@employees'] = json.encode(employees),
                        ['@shopID'] = id
                    })
                    TriggerClientEvent('t1ger_shops:ShowNotifyESX', xPlayer.source, (Lang['you_recruited_x']:format(name)))
                    local xTarget = ESX.GetPlayerFromIdentifier(plyIdentifier)
                    xTarget.setJob("shop", tonumber(newJobGrade))
                    TriggerClientEvent('t1ger_shops:ShowNotifyESX', xTarget.source, Lang['you_have_been_recruited'])
                    TriggerClientEvent('t1ger_shops:updateEmployeeID', xTarget.source, id)
                    break
                end
            end)
        else
            if not identifierMatch then
                MySQL.Async.fetchAll("SELECT * FROM t1ger_shops WHERE shopID = @shopID", {['@shopID'] = id}, function(data)
                    for _,y in pairs(data) do 
                        local employees = json.decode(y.employees)
                        table.insert(employees,{identifier = plyIdentifier, jobGrade = newJobGrade})
                        MySQL.Sync.execute("UPDATE t1ger_shops SET employees = @employees WHERE shopID = @shopID", {
                            ['@employees'] = json.encode(employees),
                            ['@shopID'] = id
                        })
                        TriggerClientEvent('t1ger_shopsjob:ShowNotifyESX', xPlayer.source, (Lang['you_recruited_x']:format(name)))
                        local xTarget = ESX.GetPlayerFromIdentifier(plyIdentifier)
                        xTarget.setJob("shop", 0)
                        TriggerClientEvent('t1ger_shopsjob:ShowNotifyESX', xTarget.source, Lang['you_have_been_recruited'])
                        TriggerClientEvent('t1ger_shops:updateEmployeeID', xTarget.source, id)
                        break
                    end
                end)
            end
        end
    end
end)

-- Get Employees:
ESX.RegisterServerCallback('t1ger_shops:getEmployees',function(source, cb, id)
    local xPlayer = ESX.GetPlayerFromId(source)
    local dataFected = false
    local shopEmployees = {}
    local noEmployees = false
    MySQL.Async.fetchAll("SELECT employees FROM t1ger_shops WHERE shopID = @shopID", {['@shopID'] = id}, function(data)
        if data[1].employees ~= nil then
            local employees = json.decode(data[1].employees)
            if #employees > 0 then
                for k,v in pairs(employees) do 
                    MySQL.Async.fetchAll('SELECT * FROM users WHERE identifier = @identifier', {['@identifier'] = v.identifier}, function (info)
                        for j,l in pairs(info) do 
                            if v.identifier == l.identifier then 
                                table.insert(shopEmployees,{identifier = v.identifier, firstname = l.firstname, lastname = l.lastname, jobGrade = v.jobGrade})
                                if k == #employees then 
                                    dataFected = true
                                end
                            end
                        end
                    end)
                end
            else
                noEmployees = true
                dataFected = true
            end
        end 
    end)
    while not dataFected do
        Citizen.Wait(1)
    end
    if dataFected then
        if noEmployees then cb(nil) else cb(shopEmployees) end
    end
end)

-- Fire Employee:
RegisterServerEvent('t1ger_shops:fireEmployee')
AddEventHandler('t1ger_shops:fireEmployee', function(id, plyIdentifier)
    local xPlayer = ESX.GetPlayerFromId(source)
    MySQL.Async.fetchAll("SELECT * FROM t1ger_shops WHERE shopID = @shopID", {['@shopID'] = id}, function(data)
        if data[1].employees ~= nil then
            local employees = json.decode(data[1].employees)
            if #employees > 0 then 
                for k,v in pairs(employees) do 
                    if plyIdentifier == v.identifier then 
                        table.remove(employees, k)
                        MySQL.Sync.execute("UPDATE t1ger_shops SET employees = @employees WHERE shopID = @shopID", {
                            ['@employees'] = json.encode(employees),
                            ['@shopID'] = id
                        })
                        local xTarget = ESX.GetPlayerFromIdentifier(plyIdentifier)
                        xTarget.setJob("unemployed", 0)
                        TriggerClientEvent('t1ger_shops:ShowNotifyESX', xTarget.source, Lang['shop_employee_fired'])
                        TriggerClientEvent('t1ger_shops:updateEmployeeID', xTarget.source, 0)
                        break
                    end
                end
            end
        end
    end)
end)

-- Update Employee Job Grade:
RegisterServerEvent('t1ger_shops:updateEmployeJobGrade')
AddEventHandler('t1ger_shops:updateEmployeJobGrade', function(id, plyIdentifier, newJobGrade)
    local xPlayer = ESX.GetPlayerFromId(source)
    MySQL.Async.fetchAll("SELECT employees FROM t1ger_shops WHERE shopID = @shopID", {['@shopID'] = id}, function(data)
        if data[1].employees ~= nil then 
            local employees = json.decode(data[1].employees)
            if #employees > 0 then 
                for k,v in pairs(employees) do 
                    if plyIdentifier == v.identifier then
                        local xTarget = ESX.GetPlayerFromIdentifier(plyIdentifier)
                        MySQL.Async.fetchAll('SELECT * FROM job_grades WHERE job_name = @job_name', {['@job_name'] = 'shop'}, function (results)
                            if newJobGrade >= 0 and newJobGrade <= results[#results].grade then
                                if xTarget.job.grade ~= newJobGrade then 
                                    v.jobGrade = newJobGrade
                                    MySQL.Sync.execute("UPDATE t1ger_shops SET employees = @employees WHERE shopID = @shopID", {
                                        ['@employees'] = json.encode(employees),
                                        ['@shopID'] = id
                                    })
                                    xTarget.setJob("shop", tonumber(newJobGrade))
                                    Wait(200)
                                    TriggerClientEvent('t1ger_shops:ShowNotifyESX', xPlayer.source, (Lang['you_updat_job_grade_for']:format(xTarget.getName(), newJobGrade)))
                                    TriggerClientEvent('t1ger_shops:ShowNotifyESX', xTarget.source, (Lang['your_job_grade_updated']:format(newJobGrade)))
                                else
                                    TriggerClientEvent('t1ger_shops:ShowNotifyESX', xPlayer.source, (Lang['target_alrdy_has_job_g']:format(xTarget.getName())))
                                end
                            else
                                TriggerClientEvent('t1ger_shops:ShowNotifyESX', xPlayer.source, (Lang['mix_max_job_grade']:format(results[#results].grade)))
                            end
                        end)
                    end 
                end
            end
        end
    end)
end)

-- Callback to Get accounts:
ESX.RegisterServerCallback('t1ger_shops:getShopAccount', function(source, cb, id)
    MySQL.Async.fetchAll("SELECT money FROM t1ger_shops WHERE shopID = @shopID", {['@shopID'] = id}, function(data)
        if data[1].money ~= nil then 
            cb(data[1].money)
        end
    end)
end)

-- Callback to Get Payment:
ESX.RegisterServerCallback('t1ger_shops:checkUpdateAcount', function(source, cb, id, type, amount)
    local xPlayer = ESX.GetPlayerFromId(source)
    if type == "withdraw" then 
        MySQL.Async.fetchAll("SELECT money FROM t1ger_shops WHERE shopID = @shopID", {['@shopID'] = id}, function(data)
            if data[1].money ~= nil then
                if data[1].money >= amount then cb(true) else cb(false) end
            end
        end)
    elseif type == "deposit" then
        local money = 0
        if Config.AccountsInCash then money = xPlayer.getMoney() else money = xPlayer.getAccount('bank').money end
        if money >= amount then cb(true) else cb(false) end
    end
end)

-- Update Account:
RegisterServerEvent('t1ger_shops:updateAccount')
AddEventHandler('t1ger_shops:updateAccount', function(id, type, amount)
    local xPlayer = ESX.GetPlayerFromId(source)
    local updatedAccount = 0
    MySQL.Async.fetchAll("SELECT money FROM t1ger_shops WHERE shopID = @shopID", {['@shopID'] = id}, function(data)
        if data[1].money ~= nil then
            if type == "withdraw" then 
                updatedAccount = tonumber(data[1].money - amount)
                if Config.AccountsInCash then xPlayer.addMoney(amount) else mxPlayer.addAccountMoney('bank', amount) end
                MySQL.Sync.execute("UPDATE t1ger_shops SET money = @money WHERE shopID = @shopID", {['@money'] = updatedAccount, ['@shopID'] = id})
                TriggerClientEvent('t1ger_shops:ShowNotifyESX', xPlayer.source, "You withdrew ~g~$"..amount.."~s~ from shop account.")
            elseif type == "deposit" then
                updatedAccount = tonumber(data[1].money + amount)
                if Config.AccountsInCash then xPlayer.removeMoney(amount) else mxPlayer.removeAccountMoney('bank', amount) end
                MySQL.Sync.execute("UPDATE t1ger_shops SET money = @money WHERE shopID = @shopID", {['@money'] = updatedAccount, ['@shopID'] = id})
                TriggerClientEvent('t1ger_shops:ShowNotifyESX', xPlayer.source, "You deposited ~g~$"..amount.."~s~ into shop account.")
            end
        end
    end)
end)

-- Events, callbacks & functions for basket, shop & cashier --

-- Get player money:
ESX.RegisterServerCallback('t1ger_shops:getPlayerMoney',function(source, cb, price, type)
    local xPlayer = ESX.GetPlayerFromId(source)
    local money = 0
    if type == 'button_cash' then money = xPlayer.getMoney() elseif type == 'button_card' then money = xPlayer.getAccount('bank').money end
    if price < 0 then
		print('t1ger_shops: ' .. xPlayer.identifier .. ' attempted to exploit the shop!')
		return
    end
	if money >= price then cb(true) else cb(false) end
end)

-- Get player inventory limit:
ESX.RegisterServerCallback('t1ger_shops:getPlayerInvLimit',function(source, cb, data)
    local xPlayer = ESX.GetPlayerFromId(source)
    local limitExceed, DataFetched = false, false
    if #data > 0 then
        for k,v in pairs(data) do
            local invItem = xPlayer.getInventoryItem(v.item)
            if invItem ~= -1 and (invItem.count + v.count) > invItem.limit then
                limitExceed = true
                TriggerClientEvent('t1ger_shops:ShowNotifyESX', xPlayer.source, (Lang['item_limit_exceed']):format(v.label,invItem.limit))
            end
            if k == #data then DataFetched = true end
        end
    else
        local invItem = xPlayer.getInventoryItem(data.item)
        if invItem ~= -1 and (invItem.count + data.value) > invItem.limit then
            TriggerClientEvent('t1ger_shops:ShowNotifyESX', xPlayer.source, (Lang['item_limit_exceed']):format(data.name,invItem.limit))
            limitExceed = true
            DataFetched = true
        else
            DataFetched = true
        end
    end
    while not DataFetched do Citizen.Wait(5) end
    if DataFetched then if limitExceed then cb(true) else cb(false) end end
end)

-- function to purchase selected item:
RegisterServerEvent('t1ger_shops:purchaseItem')
AddEventHandler('t1ger_shops:purchaseItem', function(item, price, type)
    local xPlayer = ESX.GetPlayerFromId(source)
    if type == 'button_cash' then xPlayer.removeMoney(price) elseif type == 'button_card' then xPlayer.removeAccountMoney('bank', price) end
    xPlayer.addInventoryItem(item.item, item.value)
    TriggerClientEvent('t1ger_shops:ShowNotifyESX', xPlayer.source, (Lang['item_purchased']):format(item.value,item.name,price))
end)

-- function to purchase basket items:
RegisterServerEvent('t1ger_shops:checkoutBasket')
AddEventHandler('t1ger_shops:checkoutBasket', function(basket, type, shopID)
    local xPlayer = ESX.GetPlayerFromId(source)
    if type == 'button_cash' then xPlayer.removeMoney(basket.bill) elseif type == 'button_card' then xPlayer.removeAccountMoney('bank', basket.bill) end
    for k,v in pairs(basket.items) do 
        xPlayer.addInventoryItem(v.item, v.count)
    end
    MySQL.Async.fetchAll("SELECT * FROM t1ger_shops WHERE shopID = @shopID", {['@shopID'] = shopID}, function(results)
        if #results > 0 then
            local stock = json.decode(results[1].stock)
            for k,v in pairs(stock) do
                if v.qty == 0 or v.qty <= 0 then table.remove(stock, k) end
            end
            local updated_account = (results[1].money + basket.bill)
            MySQL.Sync.execute("UPDATE t1ger_shops SET money = @money, stock = @stock WHERE shopID = @shopID", {
                ['@stock'] = json.encode(stock),
                ['@money'] = updated_account,
                ['@shopID'] = shopID
            })
        end
    end)
    TriggerClientEvent('t1ger_shops:ShowNotifyESX', xPlayer.source, (Lang['basket_paid']):format(basket.bill))
end)

-- Update item stock when added to basket:
ESX.RegisterServerCallback('t1ger_shops:updateItemStock', function(source, cb, id, item, amount)
    local xPlayer = ESX.GetPlayerFromId(source)
    MySQL.Async.fetchAll("SELECT stock FROM t1ger_shops WHERE shopID = @shopID", {['@shopID'] = id}, function(data)
        if data[1].stock ~= nil then
            local stock = json.decode(data[1].stock)
            if #stock > 0 then 
                for k,v in pairs(stock) do
                    if item == v.item then
                        if amount <= v.qty then
                            v.qty = (v.qty - amount)
                            MySQL.Sync.execute("UPDATE t1ger_shops SET stock = @stock WHERE shopID = @shopID", {
                                ['@stock'] = json.encode(stock),
                                ['@shopID'] = id
                            })
                            cb(true)
                        else
                            cb(false)
                        end
                        break
                    end
                end
            else
                cb(nil)
            end
        end
    end)
end)

-- Fetch shelves from ply shop:
ESX.RegisterServerCallback('t1ger_shops:fetchShelves',function(source, cb, shopID)
    local xPlayer = ESX.GetPlayerFromId(source)
    local shelves = {}
    MySQL.Async.fetchAll("SELECT shelves FROM t1ger_shops WHERE shopID = @shopID", {['@shopID'] = shopID}, function(results)
        if #results > 0 then
            shelves = json.decode(results[1].shelves)
            cb(shelves)
        else
            cb(shelves)
        end
    end)
end)

-- Fetch stock from shelf: 
ESX.RegisterServerCallback('t1ger_shops:fetchShelfStock',function(source, cb, shopID, shelf)
    local xPlayer = ESX.GetPlayerFromId(source)
    local stock_data = {}
    MySQL.Async.fetchAll("SELECT stock FROM t1ger_shops WHERE shopID = @shopID", {['@shopID'] = shopID}, function(results)
        if results[1] ~= nil then
            if #results[1].stock > 0 then 
                for k,v in pairs(json.decode(results[1].stock)) do
                    if v.type == shelf.type then 
                        table.insert(stock_data, {item = v.item, label = v.label, price = v.price, qty = v.qty, type = v.type})
                    end
                end
                cb(stock_data)
            else
                cb(stock_data)
            end
        else
            cb(stock_data)
        end
    end)
end)


-- ## STOCK MANAGEMENT ## --

-- Get User Inventory:
ESX.RegisterServerCallback('t1ger_shops:getUserInventory', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    local inventoryItems = xPlayer.inventory
    cb(inventoryItems)
end)

ESX.RegisterServerCallback('t1ger_shops:doesItemExists', function(source, cb, shopID, item, shelf_type)
    local xPlayer = ESX.GetPlayerFromId(source)
    MySQL.Async.fetchAll("SELECT stock FROM t1ger_shops WHERE shopID = @shopID", {['@shopID'] = shopID}, function(results)
        if results[1].stock ~= nil then
            local stock = json.decode(results[1].stock)
            if #stock > 0 then 
                for k,v in pairs(stock) do
                    if item == v.item then
                        cb(true)
                        break
                    end
                    if k == #stock then
                        cb(false)
                    end
                end
            else
                cb(nil)
            end
        end
    end)
end)

-- Restock items in shelf:
RegisterServerEvent('t1ger_shops:itemDeposit')
AddEventHandler('t1ger_shops:itemDeposit', function(item, amount, price, id, shelf)
    local xPlayer = ESX.GetPlayerFromId(source)
    local restock_item, itemAdded, itemMatch, itemName = item, false, false, ''
    if Config.HasItemLabel then itemName = ESX.GetItemLabel(restock_item) else itemName = tostring(restock_item):gsub("^%l", string.upper) end
    if xPlayer.getInventoryItem(restock_item).count >= amount then
        MySQL.Async.fetchAll("SELECT stock FROM t1ger_shops WHERE shopID = @shopID", {['@shopID'] = id}, function(results)
            if results[1].stock ~= nil then
                local stock = json.decode(results[1].stock)
                if #stock > 0 then
                    for i = 1, #stock do
                        if restock_item == stock[i].item then
                            if stock[i].type == shelf.type then 
                                stock[i].qty = (stock[i].qty + amount); itemAdded = true; itemMatch = true; break
                            else
                                return TriggerClientEvent('t1ger_shops:ShowNotifyESX', xPlayer.source, Lang['item_exists_shelf'])
                            end
                        else
                            if i == #stock then itemAdded = true; break; end
                        end
                    end
                else
                    itemAdded = true
                end
                while not itemAdded do Citizen.Wait(5) end
                if itemAdded then
                    if not itemMatch then table.insert(stock, {item = restock_item, qty = amount, label = itemName, price = price, type = shelf.type}) end 
                    MySQL.Sync.execute("UPDATE t1ger_shops SET stock = @stock WHERE shopID = @shopID", {
                        ['@stock'] = json.encode(stock),
                        ['@shopID'] = id
                    })
                    xPlayer.removeInventoryItem(restock_item, amount)
                    TriggerClientEvent('t1ger_shops:ShowNotifyESX', xPlayer.source, (Lang['shelf_item_deposit']:format(amount, itemName)))
                end
            end
        end)
    else
        TriggerClientEvent('t1ger_shops:ShowNotifyESX', xPlayer.source, Lang['not_enough_items'])
    end
end)

-- Fetch Shelf Item Stock:
ESX.RegisterServerCallback('t1ger_shops:getItemStock', function(source, cb, id)
    local xPlayer = ESX.GetPlayerFromId(source)
    local item_stock = {}
    MySQL.Async.fetchAll("SELECT stock FROM t1ger_shops WHERE shopID = @shopID", {['@shopID'] = id}, function(data)
        if #data > 0 then
            if data[1].stock ~= nil then
                item_stock = json.decode(data[1].stock)
                cb(item_stock)
            else
                cb(item_stock)
            end
        else
            cb(item_stock)
        end
    end)
end)

-- Remove items from shelf:
RegisterServerEvent('t1ger_shops:itemWithdraw')
AddEventHandler('t1ger_shops:itemWithdraw', function(item, label, amount, id, type)
    local xPlayer = ESX.GetPlayerFromId(source)
    MySQL.Async.fetchAll("SELECT stock FROM t1ger_shops WHERE shopID = @shopID", {['@shopID'] = id}, function(results)
        if results[1].stock ~= nil then
            local stock = json.decode(results[1].stock)
            if #stock > 0 then
                for k,v in pairs(stock) do
                    if item == v.item and type == v.type then
                        table.remove(stock, k)
                        MySQL.Sync.execute("UPDATE t1ger_shops SET stock = @stock WHERE shopID = @shopID", {
                            ['@stock'] = json.encode(stock),
                            ['@shopID'] = id
                        })
                        xPlayer.addInventoryItem(item, amount)
                        TriggerClientEvent('t1ger_shops:ShowNotifyESX', xPlayer.source, (Lang['shelf_item_withdraw']:format(amount, label)))
                        break
                    end
                end
            end
        end
    end)
end)

-- Add items from completed order:
RegisterServerEvent('t1ger_shops:addOrderToStock')
AddEventHandler('t1ger_shops:addOrderToStock', function(orderData)
    local order = orderData.data
    local itemAdded, itemMatch = false, false
    MySQL.Async.fetchAll("SELECT stock FROM t1ger_shops WHERE shopID = @shopID", {['@shopID'] = order.shopID}, function(data)
        if data[1].stock ~= nil then
            local stock = json.decode(data[1].stock)
            if #stock > 0 then
                for i = 1, #stock do
                    if order.orderItem == stock[i].item then 
                        stock[i].qty = (stock[i].qty + order.orderQty); itemAdded = true; itemMatch = true; break
                    else
                        if i == #stock then itemAdded = true; break; end
                    end
                end
            else
                stock = {}; itemAdded = true
            end
            while not itemAdded do Citizen.Wait(5) end
            if itemAdded then
                if not itemMatch then 
                    table.insert(stock, {item = order.orderItem , qty = order.orderQty, label = order.itemLabel, price = order.itemPrice, type = order.shelf})
                end 
                MySQL.Sync.execute("UPDATE t1ger_shops SET stock = @stock WHERE shopID = @shopID", {
                    ['@stock'] = json.encode(stock),
                    ['@shopID'] = order.shopID
                })
                print(('Your order of %sx %s has arrived and put into the shop stock.'):format(order.orderQty, order.itemLabel))
            end
        end
    end)
end)

