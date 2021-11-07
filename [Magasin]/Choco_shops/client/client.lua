-------------------------------------
------- Created by T1GER#9080 -------
------------------------------------- 
player = nil
coords = {}
Citizen.CreateThread(function()
    while true do
		player = PlayerPedId()
		coords = GetEntityCoords(player)
        Citizen.Wait(500)
    end
end)

plyShopID 	= 0
emptyShops = {}
RegisterNetEvent('t1ger_shops:applyPlyShops')
AddEventHandler('t1ger_shops:applyPlyShops', function(shopID, employeeID, ownedShops)
	plyShopID = shopID
	plyEmployeeID = employeeID
	for k,v in pairs(shopBlips) do RemoveBlip(v) end
	for k,v in pairs(ownedShops) do if v.id ~= plyShopID then emptyShops[v.id] = v.id end end
	for k,v in ipairs(Config.Shops) do
		if plyShopID == k then
			for _,y in pairs(ownedShops) do
				if y.id == plyShopID then
					v.owned = true
					CreateShopBlips(k,v,'Your ')
					break
				end
			end
		else
			if emptyShops[k] == k then
				for _,y in pairs(ownedShops) do
					if y.id == k then
						v.owned = true
						CreateShopBlips(k,v,'')
					end
				end
			else
				v.owned = false
				CreateShopBlips(k,v,'')
			end
		end
	end
end)

-- ## CASHIER SECTION ## --

-- Thread for CASHIER menu:
cashier_menu = nil
basket = {bill = 0, items = {}, shopID = 0}
Citizen.CreateThread(function()
	while true do
		Citizen.Wait(5)
		local sleep = true
		for k,v in pairs(Config.Shops) do
			local distance = GetDistanceBetweenCoords(coords.x, coords.y, coords.z, v.cashier[1], v.cashier[2], v.cashier[3], false)
			if cashier_menu ~= nil then
				distance = GetDistanceBetweenCoords(coords.x, coords.y, coords.z, cashier_menu.cashier[1], cashier_menu.cashier[2], cashier_menu.cashier[3], false)
				while cashier_menu ~= nil and distance > 1.5 do cashier_menu = nil Citizen.Wait(1) end
				if cashier_menu == nil then ESX.UI.Menu.CloseAll() end
			else
				local mk = Config.MarkerSettings['cashier']
				if distance < 20.0 then
					sleep = false
					if distance > 13.0 and basket.bill > 0 then 
						EmptyShopBasket(Lang['basket_emptied'])
					elseif distance < 13.0 then 
						if distance > 1.5 and distance < 5.0 then
							if mk.enable then
								DrawMarker(mk.type, v.cashier[1], v.cashier[2], v.cashier[3], 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, mk.scale.x, mk.scale.y, mk.scale.z, mk.color.r, mk.color.g, mk.color.b, mk.color.a, false, true, 2, false, false, false, false)
							end
						elseif distance < 1.5 then
							DrawText3Ds(v.cashier[1], v.cashier[2], v.cashier[3], "~r~[E]~s~ "..Lang['cashier_draw'])
							if IsControlJustPressed(0, 38) then
								cashier_menu = v
								OpenCashierMenu(k,v)
							end 
						end
					end
				end
			end
		end
		if sleep then Citizen.Wait(1000) end
	end
end)

-- Cashier Menu:
function OpenCashierMenu(id,val)
	local elements = {}
	if val.owned then 
		if basket.bill > 0 and #basket.items then
			elements = {{label = ('<span style="color:MediumSeaGreen;">%s</span>'):format(Lang['confirm_basket']), value = "confirm_basket"}}
			for k,v in pairs(basket.items) do
				local listLabel = ('<span style="color:GoldenRod;">%sx</span> %s <span style="color:MediumSeaGreen;">[ $%s ]</span>'):format(v.count,v.label,v.price)
				table.insert(elements, {label = listLabel, v.count, v.price, value = "item_data", num = k})
			end
			ESX.UI.Menu.CloseAll()
			ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'shop_basket_confirm_items',
				{
					title    = ('%s <span style="color:MediumSeaGreen;"> [ $%s ]</span>'):format("Basket Bill",basket.bill),
					align    = "center",
					elements = elements
				},
			function(data, menu)
				if data.current.value == "confirm_basket" then
					ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'shop_basket_select_payment_type', {
						title    = Lang['shop_payment_type'],
						align    = 'center',
						elements = {
							{label = Lang['button_cash'], value = 'button_cash'},
							{label = Lang['button_card'], value = 'button_card'},
							{label = Lang['button_no'],  value = 'button_no'},
						}
					}, function(data2, menu2)
						if data2.current.value ~= "button_no" then 
							menu.close()
							cashier_menu = nil
							ESX.TriggerServerCallback('t1ger_shops:getPlayerMoney', function(hasMoney)
								if hasMoney then
									ESX.TriggerServerCallback('t1ger_shops:getPlayerInvLimit', function(limitExceeded)
										if not limitExceeded then
											TriggerServerEvent('t1ger_shops:checkoutBasket', basket, data2.current.value, id)
											EmptyShopBasket(nil)
										end
									end, basket.items)
								end
							end, basket.bill, data2.current.value)
						end
						menu2.close()
					end, function(data2, menu2)
						menu2.close()
					end)
				end 
			end, function(data, menu)
				menu.close()
				cashier_menu = nil
			end)
		else
			ShowNotifyESX(Lang['basket_is_empty'])
			cashier_menu = nil
		end
	else
		for k,v in pairs(Config.Items) do
			for i = 1, #v.type do
				if val.type == v.type[i] then
					table.insert(elements, {label = (('%s <span style="color:MediumSeaGreen;">[ $%s ]</span>'):format(v.label,v.price)), name = v.label, item = v.item, price = v.price, type = 'slider', value = 1, min = 1, max = 100})
				end
			end
		end
		ESX.UI.Menu.CloseAll()
		ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'shop_item_list_menu',
			{
				title    = 'Shop',
				align    = 'center',
				elements = elements
			},
		function(data, menu)
			local item = data.current
			local price = (item.value * item.price)
			ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'shop_item_confirm_purchase', {
				title    = (Lang['shop_confirm_item']):format(item.value, item.name, price),
				align    = 'center',
				elements = {
					{label = Lang['button_cash'], value = 'button_cash'},
					{label = Lang['button_card'], value = 'button_card'},
					{label = Lang['button_no'],  value = 'button_no'},
				}
			}, function(data2, menu2)
				if data2.current.value ~= 'button_no' then 
					ESX.TriggerServerCallback('t1ger_shops:getPlayerMoney', function(hasMoney)
						if hasMoney then
							ESX.TriggerServerCallback('t1ger_shops:getPlayerInvLimit', function(limitExceeded)
								if not limitExceeded then
									TriggerServerEvent('t1ger_shops:purchaseItem', item, price, data2.current.value)
								end
							end, item)
						else
							ShowNotifyESX(Lang['not_enough_money'])
						end
					end, price, data2.current.value)
				end
				menu2.close()
			end, function(data2, menu2)
				menu2.close()
			end)
		end, function(data, menu)
			menu.close()
			cashier_menu = nil
		end)
	end
end

-- ## BASKET SECTION ## --

-- Comand to open basket:
RegisterCommand(Config.BasketCommand, function(source, args)
	OpenShopBasket()
end, false)

-- Function to view basket content:
function OpenShopBasket()
	if basket.bill > 0 and #basket.items then
		local elements = {}
		for k,v in pairs(basket.items) do
			local listLabel = ('<span style="color:GoldenRod;">%sx</span> %s <span style="color:MediumSeaGreen;">[ $%s ]</span>'):format(v.count,v.label,v.price)
			table.insert(elements, {label = listLabel, name = v.label, v.count, v.price, value = "item_data", num = k})
		end
		table.insert(elements, {label = ('<span style="color:IndianRed;">%s</span>'):format(Lang['empty_basket']), value = "empty_basket"})
		ESX.UI.Menu.CloseAll()
		ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'shop_basket_overview', {
			title    = ('Basket Bill <span style="color:MediumSeaGreen;">[ $%s</span>'):format(basket.bill),
			align    = 'center',
			elements = elements
		}, function(data, menu)
			if data.current.value == 'empty_basket' then
				menu.close()
				ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'shop_basket_confirm_empty', {
					title    = Lang['confirm_empty_basket'],
					align    = 'center',
					elements = {
						{label = Lang['button_yes'], value = 'button_yes'},
						{label = Lang['button_no'],  value = 'button_no'},
					}
				}, function(data2, menu2)
					menu2.close()
					if data2.current.value == 'button_yes' then
						EmptyShopBasket(Lang['you_emptied_basket'])
					else
						OpenShopBasket()
					end
				end, function(data2, menu2)
					menu2.close()
				end)
			end
			if data.current.value == 'item_data' then
				menu.close()
				local i = data.current.num
				local item = basket.items[i]
				ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'shop_basket_item_data', {
					title    = item.label,
					align    = 'center',
					elements = {
						{label = ('Price <span style="color:MediumSeaGreen;">[ $%s ]</span>'):format(item.price)},
						{label = ('Count <span style="color:GoldenRod;">[ %sx ]</span>'):format(item.count)},
						{label = ('<span style="color:IndianRed;">%s</span>'):format(Lang['basket_remove_item']), value = 'remove_item'},
					}
				}, function(data2, menu2)
					if data2.current.value == 'remove_item' then
						basket.bill = basket.bill - item.price
						TriggerServerEvent('t1ger_shops:removeBasketItem', basket.shopID, item)
						table.remove(basket.items, i)
						ShowNotifyESX((Lang['basket_item_removed']):format(item.count,item.label))
						OpenShopBasket()
					end
				end, function(data2, menu2)
					menu2.close()
					OpenShopBasket()
				end)
			end
		end, function(data, menu)
			menu.close()
		end)
	else
		ShowNotifyESX(Lang['basket_is_empty'])
		ESX.UI.Menu.CloseAll()
	end
end

-- ## SHELVES SECTION ## --

shop_shelves = {}
RegisterNetEvent('t1ger_shops:applyShopShelves')
AddEventHandler('t1ger_shops:applyShopShelves', function(shelvesData)
	if #shelvesData > 0 then 
		for k,v in pairs(shelvesData) do
			shop_shelves[v.id] = {id = v.id, shelves = v.shelves}
		end
	else
		shop_shelves = {}
	end
end)

shelf_menu = nil
-- Thread for SHELVES menu:
Citizen.CreateThread(function()
	while true do
		Citizen.Wait(5)
		local sleep = true
		for k,v in pairs(Config.Shops) do
			if GetDistanceBetweenCoords(coords.x, coords.y, coords.z, v.cashier[1], v.cashier[2], v.cashier[3], false) < 12.0 then
				sleep = false
				if shop_shelves[k] ~= nil then
					for num,shelf in pairs(shop_shelves[k].shelves) do
						local shelfDist = GetDistanceBetweenCoords(coords.x, coords.y, coords.z, shelf.pos[1], shelf.pos[2], shelf.pos[3], false)
						if shelf_menu ~= nil then 
							shelfDist = GetDistanceBetweenCoords(coords.x, coords.y, coords.z, shelf_menu.pos[1], shelf_menu.pos[2], shelf_menu.pos[3], false)
							while shelf_menu ~= nil and shelfDist > 1.5 do shelf_menu = nil Citizen.Wait(1) end
							if shelf_menu == nil then ESX.UI.Menu.CloseAll() end
						else
							if shelfDist > 1.5 and shelfDist < 4.0 then
								local mk = Config.MarkerSettings['shelves']
								if mk.enable then
									DrawMarker(mk.type, shelf.pos[1], shelf.pos[2], shelf.pos[3], 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, mk.scale.x, mk.scale.y, mk.scale.z, mk.color.r, mk.color.g, mk.color.b, mk.color.a, false, true, 2, false, false, false, false)
								end
							end
							if shelfDist <= 1.5 then
								if (plyEmployeeID > 0 and plyEmployeeID == k) or (plyShopID > 0 and plyShopID == k) then 
									DrawText3Ds(shelf.pos[1], shelf.pos[2], shelf.pos[3], "~r~[E]~s~ "..shelf.drawText.." | ~y~[G]~s~ "..Lang['manage_stock'])
									if IsControlJustPressed(0, 47) then 
										shelf_menu = shelf
										OpenShelfStockManageMenu(k,v,num,shelf)
									end
								else
									DrawText3Ds(shelf.pos[1], shelf.pos[2], shelf.pos[3], "~r~[E]~s~ "..shelf.drawText)
								end
								if IsControlJustPressed(0, 38) then
									shelf_menu = shelf
									OpenShelvesMenu(k,v,num,shelf)
								end
							end
						end
					end
				end
			end
		end
		if sleep then Citizen.Wait(1000) end
	end
end)

-- Function view & interact with shelves:
function OpenShelvesMenu(id,val,num,shelf)
	local elements = {}
	ESX.TriggerServerCallback('t1ger_shops:fetchShelfStock', function(stock_data)
		if #stock_data > 0 then 
			for k,v in pairs(stock_data) do
				if v.type == shelf.type then 
					local list_label = ('%s <span style="color:MediumSeaGreen;"> [ $%s ]</span>'):format(v.label,v.price)
					table.insert(elements, {label = list_label, name = v.label, item = v.item, price = v.price, type = 'slider', value = 1, min = 1, max = v.qty})
				end
			end
			ESX.UI.Menu.CloseAll()
			ESX.UI.Menu.Open('default', GetCurrentResourceName(), "shelf_item_menu",
				{
					title    = "Shelf [ "..shelf.drawText.." ]",
					align    = "center",
					elements = elements
				},
			function(data, menu)
				local item_price = math.floor(data.current.price * data.current.value)
				local itemInBasket, int = IsItemInBasket(data.current.item)
				ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'shelf_add_to_basket', {
					title    = Lang['shop_add_to_basket']:format(data.current.value, data.current.name, item_price),
					align    = 'center',
					elements = {
						{label = Lang['button_yes'], value = 'button_yes'},
						{label = Lang['button_no'],  value = 'button_no'},
					}
				}, function(data2, menu2)
					if data2.current.value == 'button_yes' then
						menu.close()
						ESX.TriggerServerCallback('t1ger_shops:updateItemStock', function(hasItemStock)
							if hasItemStock ~= nil and hasItemStock then
								if itemInBasket then
									basket.items[int].count = basket.items[int].count + data.current.value
									basket.items[int].price = basket.items[int].price + item_price
								else
									table.insert(basket.items, {label = data.current.name, item = data.current.item, count = data.current.value, price = item_price})
								end
								basket.bill = basket.bill + item_price
								basket.shopID = id
								ShowNotifyESX((Lang['basket_item_added']):format(data.current.value,data.current.name,item_price))
								menu2.close()
								OpenShelvesMenu(id,val,num,shelf)
							else
								ShowNotifyESX(Lang['item_not_available'])
							end
						end, id, data.current.item, data.current.value)
					end
					menu2.close()
				end, function(data2, menu2)
					menu2.close()
					OpenShelvesMenu(id,val,num,shelf)
				end)
			end, function(data, menu)
				menu.close()
				shelf_menu = nil
			end)
		else
			ShowNotifyESX(Lang['no_stock_in_shelf'])
			shelf_menu = nil
		end
	end, id, shelf)
end

-- Shelf Stock Manage Menu:
function OpenShelfStockManageMenu(id,val,num,shelf)
	local elements = {
		{label = "View Stock", value = "view_stock"},
		{label = "Add Stock", value = "add_stock"},
		{label = "Remove Stock", value = "remove_stock"}
	}
	if plyShopID > 0 then
		table.insert(elements, {label = "Order Stock", value = "order_stock"})
	end
	ESX.UI.Menu.CloseAll()
	ESX.UI.Menu.Open('default', GetCurrentResourceName(), "shelf_restock_main_menu",
		{
			title    = "Shelf [ "..shelf.drawText.." ]",
			align    = "center",
			elements = elements
		},
	function(data, menu)
		if data.current.value == "add_stock" then
			menu.close()
			AddStockFunction(id,val,num,shelf)
		elseif data.current.value == "remove_stock" then 
			menu.close()
			RemoveStockFunction(id,val,num,shelf)
		elseif data.current.value == "view_stock" then 
			menu.close()
			ViewShelfStock(id,val,num,shelf)
		elseif data.current.value == "order_stock" then 
			menu.close()
			OrderStockFunction(id,val,num,shelf)
		end
	end, function(data, menu)
		menu.close()
		shelf_menu = nil
	end)
	
end

-- function to add stock:
function AddStockFunction(id,val,num,shelf)
	ESX.TriggerServerCallback('t1ger_shops:getUserInventory', function(inventory)
		local userInventory = {}
		if #inventory > 0 then 
			for k,v in pairs(inventory) do 
				if v.count > 0 then
					if Config.ItemCompatibility then
						for _,y in pairs(Config.Items) do
							if v.name == y.item then
								for arr,shop_type in pairs(y.type) do
									if val.type == shop_type then 
										local inv_label = ('<span style="color:GoldenRod;">%sx</span> %s'):format(v.count,v.label)
										table.insert(userInventory, {label = inv_label, value = v.name, shopID = id, shelf = shelf })
										break
									end
								end
								break
							end
						end
					else
						local inv_label = ('<span style="color:GoldenRod;">%sx</span> %s'):format(v.count,v.label)
						table.insert(userInventory, {label = inv_label, value = v.name, shopID = id, shelf = shelf })
					end
				end
			end
			ESX.UI.Menu.Open('default', GetCurrentResourceName(), "shelf_restock_user_inventory",
				{
					title    = "User Inventory",
					align    = "center",
					elements = userInventory
				},
			function(data, menu)
				menu.close()
				-- menu 2
				ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'shelf_restock_item_amount', {title = "Enter Restock Amount"}, function(data2, menu2)
					local restock_amount = tonumber(data2.value)
					if restock_amount == nil or restock_amount == '' or restock_amount == 0 then
						ShowNotifyESX(Lang['invalid_amount'])
					else
						-- menu 3
						menu2.close()
						ESX.TriggerServerCallback('t1ger_shops:doesItemExists', function(itemExists)
							if itemExists == nil or not itemExists then
								ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'shelf_restock_item_price', {title = "Enter Item Price"}, function(data3, menu3)
									local restock_price = tonumber(data3.value)
									if restock_price == nil or restock_price == '' or restock_price == 0 then
										ShowNotifyESX(Lang['invalid_amount'])
									else
										menu3.close()
										TriggerServerEvent('t1ger_shops:itemDeposit', data.current.value, restock_amount, restock_price, id, data.current.shelf)
										OpenShelfStockManageMenu(id,val,num,shelf)
									end
								end, function(data3, menu3)
									menu3.close()
									OpenShelfRestockMenu(id,val,num,shelf)
								end)
							else
								TriggerServerEvent('t1ger_shops:itemDeposit', data.current.value, restock_amount, 0, id, data.current.shelf)
								OpenShelfStockManageMenu(id,val,num,shelf)
							end
						end, id, data.current.value, shelf.type)
						-- menu 3 end
					end
				end, function(data2, menu2)
					menu2.close()
					OpenShelfRestockMenu(id,val,num,shelf)
				end)
				-- menu 2 end

			end, function(data, menu)
				menu.close()
				OpenShelfStockManageMenu(id,val,num,shelf)
			end)
		else
			OpenShelfStockManageMenu(id,val,num,shelf)
		end
	end, id)
end

-- function to remove stock:
function RemoveStockFunction(id,val,num,shelf)
	ESX.TriggerServerCallback('t1ger_shops:getItemStock', function(item_stock)
		local elements = {}
		if #item_stock > 0 then 
			for k,v in pairs(item_stock) do
				if shelf.type == v.type then
					local list_label = ('<span style="color:GoldenRod;">%sx</span> %s'):format(v.qty,v.label)
					table.insert(elements, {label = list_label, item = v.item, name = v.label, qty = v.qty, type = v.type})
				end
			end
			if #elements > 0 then 
				ESX.UI.Menu.Open('default', GetCurrentResourceName(), "shelf_stock_remove",
					{
						title    = "Shelf Stock",
						align    = "center",
						elements = elements
					},
				function(data, menu)
					ESX.UI.Menu.Open('default', GetCurrentResourceName(), "shelf_stock_remove_confirm",
						{
							title    = "Confirm Withdrawal",
							align    = "center",
							elements = {
								{ label = Lang['button_yes'], value = "button_yes" },
								{ label = Lang['button_no'], value = "button_no" },
							}
						},
					function(data2, menu2)
						menu2.close()
						if data2.current.value ~= 'button_no' then
							menu.close()
							TriggerServerEvent('t1ger_shops:itemWithdraw', data.current.item, data.current.name, data.current.qty, id, data.current.type)
							OpenShelfStockManageMenu(id,val,num,shelf)
						end
					end, function(data, menu)
						menu2.close()
					end)
				end, function(data, menu)
					menu.close()
					OpenShelfStockManageMenu(id,val,num,shelf)
				end)
			else
				ShowNotifyESX(Lang['stock_inv_empty'])
				OpenShelfStockManageMenu(id,val,num,shelf)
			end
		else
			ShowNotifyESX(Lang['stock_inv_empty'])
			OpenShelfStockManageMenu(id,val,num,shelf)
		end
	end, id)
end

-- change item price in shelf stock:
function ViewShelfStock(id,val,num,shelf)
	ESX.TriggerServerCallback('t1ger_shops:getItemStock', function(item_stock)
		local elements = {}
		if #item_stock > 0 then 
			for k,v in pairs(item_stock) do
				if shelf.type == v.type then
					local list_label = ('<span style="color:GoldenRod;">%sx</span> %s <span style="color:MediumSeaGreen;"> [ $%s ]</span>'):format(v.qty,v.label,v.price)
					table.insert(elements, {label = list_label, item = v.item, name = v.label, qty = v.qty, price = v.price, shelf = v.type})
				end
			end
			if #elements > 0 then 
				ESX.UI.Menu.Open('default', GetCurrentResourceName(), "view_shelf_item_stock",
					{
						title    = "Shelf Overview",
						align    = "center",
						elements = elements
					},
				function(data, menu)
					local selected = data.current
					if plyShopID > 0 and plyShopID == id then 
						ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'shelf_edit_selected_item', {
							title    = selected.name,
							align    = 'center',
							elements = {
								{label = "Price", type = 'slider', value = selected.price, min = 1, max = 999, action = "price"},
							}
						}, function(data2, menu2)
							menu2.close()
							if data2.current.action == 'price' then
								TriggerServerEvent('t1ger_shops:updateItemPrice', id, shelf.type, selected.item, data2.current.value)
								ShowNotifyESX((Lang['shelf_item_price_change']):format(selected.name,selected.price,data2.current.value))
								menu.close()
								OpenShelfStockManageMenu(id,val,num,shelf)
							end
						end, function(data2, menu2)
							menu2.close()
						end)
					end
				end, function(data, menu)
					menu.close()
					OpenShelfStockManageMenu(id,val,num,shelf)
				end)
			else
				ShowNotifyESX(Lang['stock_inv_empty'])
				OpenShelfStockManageMenu(id,val,num,shelf)
			end
		else
			ShowNotifyESX(Lang['stock_inv_empty'])
			OpenShelfStockManageMenu(id,val,num,shelf)
		end
	end, id)
end

-- function to order stock:
function OrderStockFunction(id,val,num,shelf)
	ESX.TriggerServerCallback('t1ger_shops:getItemStock', function(stockSV)
		local elements = {}
		for k,v in pairs(Config.Items) do
			local typeChecked = false
			for num,typeC in pairs(v.type) do
				if typeC == val.type then typeChecked = true break end
			end
			if typeChecked then 
				local currentCount = 0
				if #stockSV > 0 then
					for _,y in pairs(stockSV) do if v.item == y.item then currentCount = y.qty end end
					table.insert(elements, {
						label = v.label..'<span style="color:MediumSeaGreen;"> [ '..'<span style="color:GoldenRod;">'..currentCount.."x pcs </span> ]",
						name = v.label, item = v.item, price = v.price, count = currentCount
					})
				else
					table.insert(elements, {
						label = v.label..'<span style="color:MediumSeaGreen;"> [ '..'<span style="color:GoldenRod;">'..currentCount.."x pcs </span> ]",
						name = v.label, item = v.item, price = v.price, count = currentCount
					})
				end
			end
		end
		ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'shop_order_item_stock', {
			title    = "Shelf ["..shelf.drawText.."] Order",
			align    = 'center',
			elements = elements
		}, function(data, menu)
			local selected = data.current
			-- menu 2 start:
			menu.close()
			ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'shop_amount_order_stock', {
				title    = data.current.name..'<span style="color:MediumSeaGreen;"> [ '..'<span style="color:GoldenRod;">'..selected.count.."x pcs </span> ]",
				align    = 'center',
				elements = {
					{label = '<span style="color:GoldenRod;">'.."Order Amount"..'<span style="color:DodgerBlue;">', type = 'slider', value = 1, max = 100, action = "order"},
				}
			}, function(data2, menu2)
				if data2.current.action == 'order' then
					-- menu 3 confirm:
					menu2.close()
					local item_price = (selected.price*(1-(Config.OrderItemPercent/100)))
					local order_price = math.floor(item_price * data2.current.value)
					ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'order_stock_confirmation', {
						title    = "Confirm Order Price: [$"..order_price.."]",
						align    = 'center',
						elements = {
							{label = Lang['button_yes'], value = 'button_yes'},
							{label = Lang['button_no'],  value = 'button_no'},
						}
					}, function(data3, menu3)
						if data3.current.value == 'button_yes' then
							menu3.close()
							TriggerServerEvent('t1ger_shops:sendStockOrder', id, selected.name, selected.item, selected.count, data2.current.value, selected.price, order_price, shelf.type)
							OpenShelfStockManageMenu(id,val,num,shelf)
						end
						menu3.close()
					end, function(data3, menu3)
						menu3.close()
					end)
					-- menu 3 end
				end
			end, function(data2, menu2)
				menu2.close()
				OpenShelfStockManageMenu(id,val,num,shelf)
			end)
			-- menu 2 end:
		end, function(data, menu)
			menu.close()
			OpenShelfStockManageMenu(id,val,num,shelf)
		end)
	end, id)
end


-- ## BOSS MENU SECTION ## --

-- Thread for BOSS menu:
boss_menu = nil
Citizen.CreateThread(function()
	while true do
		Citizen.Wait(5)
		local sleep = true
		for k,v in pairs(Config.Shops) do
			local distance = GetDistanceBetweenCoords(coords.x, coords.y, coords.z, v.b_menu[1], v.b_menu[2], v.b_menu[3], false)
			if boss_menu ~= nil then
				distance = GetDistanceBetweenCoords(coords.x, coords.y, coords.z, boss_menu.b_menu[1], boss_menu.b_menu[2], boss_menu.b_menu[3], false)
				while boss_menu ~= nil and distance > 1.5 do boss_menu = nil Citizen.Wait(1) end
				if boss_menu == nil then ESX.UI.Menu.CloseAll() end
			else
				local mk = Config.MarkerSettings['boss']
				if distance < 10.0 then 
					sleep = false
					if distance >= 2.0 and distance < 5.0 then
						if mk.enable then
							DrawMarker(mk.type, v.b_menu[1], v.b_menu[2], v.b_menu[3], 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, mk.scale.x, mk.scale.y, mk.scale.z, mk.color.r, mk.color.g, mk.color.b, mk.color.a, false, true, 2, false, false, false, false)
						end
					elseif distance < 2.0 then
						if plyShopID == k then
							DrawText3Ds(v.b_menu[1], v.b_menu[2], v.b_menu[3], Lang['boss_menu_access'])
							if IsControlJustPressed(0, 38) then
								boss_menu = v
								BossMenuManage(k,v)
							end
						else
							if v.buyable then 
								if emptyShops[k] ~= k then
									if plyShopID == 0 then
										DrawText3Ds(v.b_menu[1], v.b_menu[2], v.b_menu[3], (Lang['press_to_buy_shop']:format(math.floor(v.price))))
										if IsControlJustPressed(0, 38) then
											boss_menu = v
											BuyClosestShop(k,v)
										end
									end
								end
							end
						end
					end
				end
			end
		end
		if sleep then Citizen.Wait(1000) end
	end
end)

-- Function for boss menu:
function BossMenuManage(id,val)
	local elements = {
		{ label = Lang['sell_shop'], value = "sell_shop" },
		{ label = Lang['employees_action'], value = "employees_menu" },
		{ label = Lang['accounts_action'], value = "accounts_menu" }
	}
	ESX.UI.Menu.Open('default', GetCurrentResourceName(), "shop_boss_manage_menu",
		{
			title    = "Shop ["..tostring(id).."]",
			align    = "center",
			elements = elements
		},
	function(data, menu)
        if data.current.value == 'sell_shop' then
			SellClosestShop(id,val)
			menu.close()
			bossMenu = nil
		end
        if data.current.value == 'employees_menu' then
			EmployeesMainMenu(id,val)
			menu.close()
		end
        if data.current.value == 'accounts_menu' then
			AccountsMainMenu(id,val)
			menu.close()
		end
	end, function(data, menu)
		menu.close()
		boss_menu = nil
	end)
end

-- Function to purchase shop:
function BuyClosestShop(id,val)
	local elements = {
		{ label = Lang['button_yes'], value = "confirm_purchase" },
		{ label = Lang['button_no'], value = "decline_purchase" },
	}
	ESX.UI.Menu.Open('default', GetCurrentResourceName(), "shop_purchase_menu",
		{
			title    = "Confirm | Price: $"..math.floor(val.price),
			align    = "center",
			elements = elements
		},
	function(data, menu)
		if data.current.value ~= 'decline_purchase' then
			ESX.TriggerServerCallback('t1ger_shops:buyShop', function(purchased)
				if purchased then
					ShowNotifyESX((Lang['shop_purchased']):format(math.floor(val.price)))
					TriggerServerEvent('t1ger_shops:fetchPlyShops')
				else
					ShowNotifyESX(Lang['not_enough_money'])
				end
			end, id, val)
		end
		menu.close()
		boss_menu = nil
	end, function(data, menu)
		menu.close()
		boss_menu = nil
	end)
end

-- Function to sell shop:
function SellClosestShop(id,val)
	local sellPrice = (val.price * Config.SellPercent)
	local elements = {
		{ label = Lang['button_yes'], value = "confirm_sale" },
		{ label = Lang['button_no'], value = "decline_sale" },
	}
	ESX.UI.Menu.Open('default', GetCurrentResourceName(), "shop_sell_menu",
		{
			title    = "Confirm Sale | Price: $"..math.floor(sellPrice),
			align    = "center",
			elements = elements
		},
	function(data, menu)
		if data.current.value == 'confirm_sale' then
			ESX.TriggerServerCallback('t1ger_shops:sellShop', function(sold)
				if sold then
					TriggerServerEvent('t1ger_shops:fetchPlyShops')
					ShowNotifyESX((Lang['shop_sold']):format(math.floor(sellPrice)))
					TriggerServerEvent('t1ger_shops:fetchShopShelves')
				end
			end, id, val, math.floor(sellPrice))
			menu.close()
			boss_menu = nil
			ESX.UI.Menu.CloseAll()
		else
			menu.close()
			BossMenuManage(id,val)
		end
	end, function(data, menu)
		menu.close()
		BossMenuManage(id,val)
	end)
end

-- Employees Main Menu:
function EmployeesMainMenu(id,val)
	local elements = {
		{ label = Lang['hire_employee'], value = "recruit_employee" },
		{ label = Lang['employee_list'], value = "employee_list" },
	}
	ESX.UI.Menu.Open('default', GetCurrentResourceName(), "shop_employees_menu",
		{
			title    = "Shop [Employees]",
			align    = "center",
			elements = elements
		},
	function(data, menu)
		menu.close()
		if data.current.value == 'recruit_employee' then
			ESX.TriggerServerCallback('t1ger_shops:getOnlinePlayers', function(players)
				local elements = {}
				for i=1, #players, 1 do
					table.insert(elements, {
						label = players[i].name,
						value = players[i].source,
						name = players[i].name,
						identifier = players[i].identifier
					})
				end
				ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'shop_recruit_player', {
					title    = "Recruit Employee",
					align    = 'center',
					elements = elements
				}, function(data2, menu2)
					-- YES / NO OPTION:
					ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'shop_recruit_confirm', {
						title    = "Recruit: "..data2.current.name,
						align    = 'center',
						elements = {
							{label = Lang['button_no'],  value = 'no'},
							{label = Lang['button_yes'], value = 'yes'}
						}
					}, function(data3, menu3)
						menu2.close()
						if data3.current.value == 'yes' then
							menu3.close()
							local jobGrade = 0
							TriggerServerEvent('t1ger_shops:recruitEmployee',id,data2.current.identifier,jobGrade,data2.current.name)
							EmployeesMainMenu(id,val)
						end
					end, function(data3, menu3)
						menu3.close()
						EmployeesMainMenu(id,val)
					end)
				end, function(data2, menu2)
					menu2.close()
					EmployeesMainMenu(id,val)
				end)
			end)
		end
        if data.current.value == 'employee_list' then
			OpenEmployeeListMenu(id,val)
		end
	end, function(data, menu)
		menu.close()
		BossMenuManage(id,val)
	end)
end

-- Employe List Menu
function OpenEmployeeListMenu(id,val)
	local elements = {}
	ESX.TriggerServerCallback('t1ger_shops:getEmployees', function(employees)
		if employees ~= nil then 
			for k,v in pairs(employees) do
				table.insert(elements,{label = v.firstname.." "..v.lastname, identifier = v.identifier, jobGrade = v.jobGrade, data = v})
			end
			ESX.UI.Menu.Open('default', GetCurrentResourceName(), "shop_employees_list",
				{
					title    = "Employee List",
					align    = "center",
					elements = elements
				},
			function(data, menu)
				menu.close()
				OpenEmployeeData(data.current,data.current.data,id,val)
			end, function(data, menu)
				menu.close()
				EmployeesMainMenu(id,val)
			end)
		else
			ShowNotifyESX(Lang['no_employees_hired'])
		end
	end, id)
end

-- Get Employee Menu Data
function OpenEmployeeData(info,user,id,val)
	local elements = {
		{ label = Lang['fire_employee'], value = "fire_employee" },
		{ label = Lang['employee_job_grade'], value = "job_grade_manage" },
	}
	ESX.UI.Menu.Open('default', GetCurrentResourceName(), "shop_employee_data_menu",
		{
			title    = "Employee: "..user.firstname,
			align    = "center",
			elements = elements
		},
	function(data, menu)
		menu.close()
		if data.current.value == 'fire_employee' then
			TriggerServerEvent('t1ger_shops:fireEmployee',id,user.identifier)
			EmployeesMainMenu(id,val)
		end
		if data.current.value == 'job_grade_manage' then
			ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'shop_update_employee_job_grade', {
				title = "Current Job Grade: "..user.jobGrade
			}, function(data2, menu2)
				menu2.close()
				local newJobGrade = tonumber(data2.value)
				TriggerServerEvent('t1ger_shops:updateEmployeJobGrade',id,user.identifier,newJobGrade)
				EmployeesMainMenu(id,val)
			end,
			function(data2, menu2)
				menu2.close()	
				EmployeesMainMenu(id,val)
			end)
		end
	end, function(data, menu)
		menu.close()
		OpenEmployeeListMenu(id,val)
	end)
end

-- Acounts Main Menu:
function AccountsMainMenu(id,val)
	local elements = {
		{ label = Lang['account_withdraw'], value = "withdraw" },
		{ label = Lang['account_deposit'], value = "deposit" },
	}
	ESX.TriggerServerCallback('t1ger_shops:getShopAccount', function(account)
		ESX.UI.Menu.Open('default', GetCurrentResourceName(), "shop_account_menu",
			{
				title    = "Account "..'<span style="color:MediumSeaGreen;">[ $'..account.." ]",
				align    = "center",
				elements = elements
			},
		function(data, menu)
			menu.close()
			ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'shop_update_account_menu', {
				title = "Account Money: $"..account
			}, function(data2, menu2)
				menu2.close()
				local amount = tonumber(data2.value)
				ESX.TriggerServerCallback('t1ger_shops:checkUpdateAcount', function(hasMoney)
					if hasMoney then
						TriggerServerEvent('t1ger_shops:updateAccount', id, data.current.value, amount)
						BossMenuManage(id,val)
					end
				end, id, data.current.value, amount)
			end,
			function(data2, menu2)
				menu2.close()	
				AccountsMainMenu(id,val)
			end)
		end, function(data, menu)
			menu.close()
			BossMenuManage(id,val)
		end)
	end, id)
end


-- ## INTERACTION MENU ## --

-- Mechanic Action Thread:
Citizen.CreateThread(function()
	while true do
		Citizen.Wait(5)
		if IsControlJustPressed(0, Config.InteractionMenuKey) and plyShopID > 0 then
			OpenShopInteractionMenu()
		end
	end
end)

-- function to open menu:
function OpenShopInteractionMenu()
	if PlayerData.job and PlayerData.job.name == "shop" then
		local elements = {}
		if plyShopID > 0 then
			table.insert(elements, { label = "Add Shelf", value = "add_shelf" })
			table.insert(elements, { label = "Remove Shelf", value = "remove_shelf" })
		end
		ESX.UI.Menu.Open('default', GetCurrentResourceName(), "shop_interaction_menu",
			{
				title    = "Shop Owner Menu",
				align    = "center",
				elements = elements
			},
		function(data, menu)
			menu.close()
			if data.current.value == 'add_shelf' then
				AddShelfMenu()
			end
			if data.current.value == 'remove_shelf' then
				RemoveShelfMenu()
			end
		end, function(data, menu)
			menu.close()
		end)
	end
end

-- function to add new shelf in shop:
function AddShelfMenu()
	local pos = {round(coords.x,2),round(coords.y,2),round(coords.z,2),round(GetEntityHeading(player),2)}
	ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'shelf_enter_type', {
		title = "Enter Shelf Type: "
	}, function(data, menu)
		--menu.close()
		if data.value == nil or data.value == '' then
			ShowNotifyESX(Lang['invalid_string'])
		else
			menu.close()
			local type = string.lower(data.value)
			ESX.UI.Menu.Open('dialog', GetCurrentResourceName(), 'shelf_enter_drawText', {
				title = "Enter Shelf 3D Text: "
			}, function(data2, menu2)
				if data2.value == nil or data2.value == '' then
					ShowNotifyESX(Lang['invalid_string'])
				else
					menu2.close()
					local fixChars = string.lower(data2.value)
					local text = (fixChars):gsub("^%l", string.upper)
					local elements = {
						{label = "Confirm New Shelf", value = "confirm_new_shelf"},
						{label = "Pos: { "..pos[1]..", "..pos[2]..", "..pos[3]..", "..pos[4].." }"},
						{label = "Type: "..type},
						{label = "3D Text: "..text}
					}
					ESX.UI.Menu.CloseAll()
					ESX.UI.Menu.Open('default', GetCurrentResourceName(), "new_shelf_overview",
						{
							title    = "New Shelf View",
							align    = "center",
							elements = elements
						},
					function(data3, menu3)
						if data3.current.value == "confirm_new_shelf" then 
							ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'new_shelf_final_confirmation', {
								title    = "Final Confirmation",
								align    = 'center',
								elements = {
									{label = Lang['button_yes'], value = 'button_yes'},
									{label = Lang['button_no'],  value = 'button_no'},
								}
							}, function(data4, menu4)
								if data4.current.value == 'button_yes' then
									local table = {pos = pos, type = type, drawText = text}
									TriggerServerEvent('t1ger_shops:updateShelves', plyShopID, table, true)
									menu3.close()
								end
								menu4.close()
							end, function(data4, menu4)
								menu4.close()
							end)
						end
					end, function(data3, menu3)
						menu3.close()
					end)
				end
			end,
			function(data2, menu2)
				menu2.close()
			end)
		end
	end,
	function(data, menu)
		menu.close()
		OpenShopInteractionMenu()
	end)
end

-- function to remove a shelf from shop:
function RemoveShelfMenu()
	local elements = {}
	ESX.TriggerServerCallback('t1ger_shops:fetchShelves', function(shelves)
		if #shelves > 0 then
			for k,v in pairs(shelves) do 
				table.insert(elements, {label = v.drawText, pos = v.pos, type = v.type, drawText = v.drawText})
			end
			ESX.UI.Menu.CloseAll()
			ESX.UI.Menu.Open('default', GetCurrentResourceName(), "shelves_list_menu",
				{
					title    = "Shop Shelves",
					align    = "center",
					elements = elements
				},
			function(data, menu)
				ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'shelf_confirm_removal', {
					title    = "Confirm Removal",
					align    = 'center',
					elements = {
						{label = Lang['button_yes'], value = 'button_yes'},
						{label = Lang['button_no'],  value = 'button_no'},
					}
				}, function(data2, menu2)
					if data2.current.value == 'button_yes' then
						local chk = data.current
						local table = {pos = chk.pos, type = chk.type, drawText = chk.drawText}
						TriggerServerEvent('t1ger_shops:updateShelves', plyShopID, table, false)
						menu.close()
					end
					menu2.close()
				end, function(data2, menu2)
					menu2.close()
				end)
			end, function(data, menu)
				menu.close()
			end)
		else
			ShowNotifyESX(Lang['no_shelves'])
		end
	end, plyShopID)
end

