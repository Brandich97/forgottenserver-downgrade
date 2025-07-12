-- ##################################################################################
-- ## game_store.lua - Compatível com OTClient(Redemption) ##
-- ##################################################################################

local redemptionShopOpcode = 201

local function deepCopy(original)
    local copy = {}
    for k, v in pairs(original) do
        if type(v) == "table" then
            v = deepCopy(v)
        end
        copy[k] = v
    end
    return copy
end

-- ####### CONFIGURAÇÃO DA LOJA #######
-- Configure sua loja aqui.
local SHOP_CONFIG = {
    buyUrl = "http://seu-site-de-doacoes.com",
    categories = {
        {title = "Premium Time", iconId = 1, offers = {
            {name = "7 Days of Premium", price = 100, isSecondPrice = false, categoryId = 0, id = "Premium_Time_7.png", count = 7, description = "7 dias de Acesso Premium para sua conta."},
            {name = "30 Days of Premium", price = 300, isSecondPrice = false, categoryId = 0, id = "Premium_Time_30.png", count = 30, description = "30 dias de Acesso Premium para sua conta."},
            {name = "90 Days of Premium", price = 850, isSecondPrice = false, categoryId = 0, id = "Premium_Time_90.png", count = 90, description = "90 dias de Acesso Premium para sua conta."},
            {name = "180 Days of Premium", price = 1650, isSecondPrice = false, categoryId = 0, id = "Premium_Time_180.png", count = 180, description = "180 dias de Acesso Premium para sua conta."},
            {name = "365 Days of Premium", price = 3000, isSecondPrice = false, categoryId = 0, id = "Premium_Time_360.png", count = 365, description = "365 dias de Acesso Premium para sua conta."}
        }},
        {title = "Itens", iconId = 2, offers = {
            {name = "Crystal Coin", price = 1, isSecondPrice = false, categoryId = 1, id = 2160, count = 1, description = "Uma moeda feita de puro cristal."},
            {name = "2 Crystal Coin", price = 2, isSecondPrice = false, categoryId = 1, id = 2160, count = 2, description = "Uma moeda feita de puro cristal."},
            {name = "3 Crystal Coin", price = 3, isSecondPrice = false, categoryId = 1, id = 2160, count = 3, description = "Uma moeda feita de puro cristal."},
            {name = "4 Crystal Coin", price = 4, isSecondPrice = false, categoryId = 1, id = 2160, count = 4, description = "Uma moeda feita de puro cristal."},
            {name = "5 Crystal Coin", price = 5, isSecondPrice = false, categoryId = 1, id = 2160, count = 5, description = "Uma moeda feita de puro cristal."},
            {name = "10 Crystal Coin", price = 10, isSecondPrice = false, categoryId = 1, id = 2160, count = 10, description = "Uma moeda feita de puro cristal."},
            {name = "100 Crystal Coins", price = 90, isSecondPrice = false, categoryId = 1, id = 2160, count = 100, description = "Um pacote com 100 moedas de cristal."},
            {name = "Demon Helmet", price = 200, isSecondPrice = false, categoryId = 1, id = 2493, count = 1, description = "Um elmo poderoso forjado nas profundezas."}
        }},
        {title = "Bless", iconId = 3, offers = {
            {name = "The Adventurer's Blessing", price = 50, isSecondPrice = false, categoryId = 2, id = "bless_1", count = 1, description = "Protege contra a perda de itens e experiência na morte."}
        }},
        {title = "Outfits", iconId = 4, offers = {}},
        {title = "Montarias", iconId = 5, offers = {}},
        {title = "Extras", iconId = 6, offers = {
            {name = "Name Change", price = 250, isSecondPrice = false, categoryId = 5, id = "namechange", count = 1, description = "Permite a troca do nome do seu personagem."}
        }}
    }
}
-- ####### FIM DA CONFIGURAÇÃO #######

-- Funções internas do sistema
local function getPlayerPoints(player)
    local points = 0
    local resultId = db.storeQuery("SELECT `premium_points` FROM `accounts` WHERE `id` = " .. player:getAccountId())
    if resultId ~= false then
        points = result.getNumber(resultId, "premium_points")
        result.free(resultId)
    end
    return points
end

local function sendData(player, action, data)
    local payload = {action = action, data = data}
    player:sendExtendedOpcode(redemptionShopOpcode, json.encode(payload))
end

local function sendMsg(player, type, title, msg)
    sendData(player, "msg", {type = type, title = title, msg = msg})
end
-- Versão final da função, com a lógica de histórico corrigida para a nova tabela.
-- Versão final da função, agora com a lógica de transferência de coins.
function onExtendedOpcode(player, opcode, buffer)
    if opcode ~= redemptionShopOpcode then
        return true
    end

    local json_data = json.decode(buffer)
    if not json_data or not json_data.action then
        return true
    end

    local action = json_data.action
    local data = json_data.data

    if action == "fetch" then
        local categoriesData = {}
        for i, category in ipairs(SHOP_CONFIG.categories) do
            table.insert(categoriesData, {title = category.title, iconId = category.iconId})
        end
        sendData(player, "fetchBase", {categories = categoriesData, url = SHOP_CONFIG.buyUrl})
        sendData(player, "points", {points = getPlayerPoints(player), secondPoints = -1})

    elseif action == "fetchOffers" then
        local categoryName = data.category
        for _, category in ipairs(SHOP_CONFIG.categories) do
            if category.title == categoryName then
                local translatedOffers = deepCopy(category.offers)
                for i, offer in ipairs(translatedOffers) do
                    if offer.id and type(offer.id) == 'number' then
                        translatedOffers[i].serverId = offer.id
                        translatedOffers[i].id = ItemType(offer.id):getClientId()
                    end
                end
                sendData(player, "fetchOffers", {category = categoryName, offers = translatedOffers})
                break
            end
        end

    elseif action == "getDescription" then
        local offerName = data.name
        local foundOffer = nil
        for _, category in ipairs(SHOP_CONFIG.categories) do
            for _, offer in ipairs(category.offers) do
                if offer.name == offerName then
                    foundOffer = offer
                    break
                end
            end
            if foundOffer then break end
        end
        if foundOffer then
            sendData(player, "fetchDescription", {name = foundOffer.name, description = foundOffer.description or "This item does not have a detailed description."})
        end

    elseif action == "purchase" then
        local offerName = data.name
        local foundOffer = nil
        for _, category in ipairs(SHOP_CONFIG.categories) do
            for _, offer in ipairs(category.offers) do
                if offer.name == offerName then
                    foundOffer = offer
                    break
                end
            end
            if foundOffer then break end
        end

        if not foundOffer then
            return sendMsg(player, "error", "Purchase Error", "The selected offer is no longer valid.")
        end

        local playerPoints = getPlayerPoints(player)
        if playerPoints < foundOffer.price then
            return sendMsg(player, "error", "Insufficient Points", "You do not have enough points to buy this item.")
        end

        local itemIdForDb
        if type(foundOffer.id) == 'number' then
            itemIdForDb = foundOffer.id
        else
            itemIdForDb = db.escapeString(foundOffer.id)
        end

        if foundOffer.categoryId == 0 then -- Categoria Premium Time
            if player:addPremiumDays(foundOffer.count) then
                db.query("UPDATE `accounts` SET `premium_points` = `premium_points` - " .. foundOffer.price .. " WHERE `id` = " .. player:getAccountId())
                db.asyncQuery("INSERT INTO `shop_history` (`player_id`, `date`, `description`, `item_id`, `count`, `price`) VALUES (" .. player:getGuid() .. ", NOW(), " .. db.escapeString(foundOffer.name) .. ", " .. itemIdForDb .. ", " .. foundOffer.count .. ", " .. -foundOffer.price .. ");")
                sendMsg(player, "info", "Purchase Successful", foundOffer.count .. " premium days have been added to your account.")
                sendData(player, "points", {points = getPlayerPoints(player), secondPoints = -1})
            else
                sendMsg(player, "error", "Error", "An unexpected error occurred while adding premium days.")
            end
        elseif foundOffer.categoryId == 1 or foundOffer.categoryId == 5 then -- 
            if type(foundOffer.id) == 'number' then
                if player:addItem(foundOffer.id, foundOffer.count, true) then
                    db.query("UPDATE `accounts` SET `premium_points` = `premium_points` - " .. foundOffer.price .. " WHERE `id` = " .. player:getAccountId())
                    db.asyncQuery("INSERT INTO `shop_history` (`player_id`, `date`, `description`, `item_id`, `count`, `price`) VALUES (" .. player:getGuid() .. ", NOW(), " .. db.escapeString(foundOffer.name) .. ", " .. itemIdForDb .. ", " .. foundOffer.count .. ", " .. -foundOffer.price .. ");")
                    sendMsg(player, "info", "Purchase Successful", "You have bought " .. foundOffer.name .. "! The item is in your backpack.")
                    sendData(player, "points", {points = getPlayerPoints(player), secondPoints = -1})
                else
                    sendMsg(player, "error", "Delivery Error", "You do not have enough space or capacity to receive this item.")
                end
            else
                -- Lógica para comprar serviços (Name Change, ou itens de imagem que não são entregues)
                db.query("UPDATE `accounts` SET `premium_points` = `premium_points` - " .. foundOffer.price .. " WHERE `id` = " .. player:getAccountId())
                db.asyncQuery("INSERT INTO `shop_history` (`player_id`, `date`, `description`, `item_id`, `count`, `price`) VALUES (" .. player:getGuid() .. ", NOW(), " .. db.escapeString(foundOffer.name) .. ", " .. itemIdForDb .. ", " .. foundOffer.count .. ", " .. -foundOffer.price .. ");")
                sendMsg(player, "info", "Purchase Successful", "You have successfully purchased the service: " .. foundOffer.name .. ".")
                sendData(player, "points", {points = getPlayerPoints(player), secondPoints = -1})
            end
        else
            sendMsg(player, "error", "Not Implemented", "Purchasing this type of item has not been implemented on the server yet.")
        end
    
    elseif action == "history" then
        local history = {}
        local query = "SELECT `date`, `description`, `price`, `count` FROM `shop_history` WHERE `player_id` = " .. player:getGuid() .. " ORDER BY `id` DESC LIMIT 100;"
        local resultId = db.storeQuery(query)
        if resultId ~= false then
            repeat
                table.insert(history, {
                    date = result.getDataString(resultId, "date"),
                    name = result.getDataString(resultId, "description"),
                    price = result.getNumber(resultId, "price"),
                    count = result.getNumber(resultId, "count"),
                    isSecondPrice = false
                })
            until not result.next(resultId)
            result.free(resultId)
        end
        sendData(player, "history", history)

    elseif action == "transfer" then
        local targetName = data.target
        local amount = tonumber(data.amount)

        -- 1. Validações de segurança (sem alterações)
        if not targetName or targetName == "" or not amount or amount <= 0 then
            return sendMsg(player, "error", "Invalid Data", "Please enter a valid character name and amount.")
        end

        if player:getName() == targetName then
            return sendMsg(player, "error", "Invalid Target", "You cannot transfer points to yourself.")
        end

        if getPlayerPoints(player) < amount then
            return sendMsg(player, "error", "Insufficient Points", "You do not have enough points to transfer this amount.")
        end

        -- 2. Encontra a conta e o GUID do jogador de destino
        local targetPlayer = Player(targetName)
        local targetAccountId
        local targetGuid
        if targetPlayer then
            targetAccountId = targetPlayer:getAccountId()
            targetGuid = targetPlayer:getGuid()
        else
            -- Procura no banco de dados se o jogador estiver offline
            local resultId = db.storeQuery("SELECT `id`, `account_id` FROM `players` WHERE `name` = " .. db.escapeString(targetName))
            if resultId ~= false then
                targetAccountId = result.getNumber(resultId, "account_id")
                targetGuid = result.getNumber(resultId, "id")
                result.free(resultId)
            end
        end

        if not targetAccountId or targetAccountId == 0 then
            return sendMsg(player, "error", "Character Not Found", "The character '" .. targetName .. "' does not exist.")
        end

        -- 3. Executa a transação no banco de dados (sem alterações)
        local senderAccountId = player:getAccountId()
        db.query("UPDATE `accounts` SET `premium_points` = `premium_points` - " .. amount .. " WHERE `id` = " .. senderAccountId)
        db.query("UPDATE `accounts` SET `premium_points` = `premium_points` + " .. amount .. " WHERE `id` = " .. targetAccountId)

        -- ######### INÍCIO DA NOVA LÓGICA DE HISTÓRICO #########
        -- 4. Registra a transação no histórico para ambos os jogadores
        local senderGuid = player:getGuid()
        local senderDesc = "Transferred " .. amount .. " points to " .. targetName .. "."
        local receiverDesc = "Received " .. amount .. " points from " .. player:getName() .. "."

        -- Log para quem enviou (valor negativo)
        db.asyncQuery("INSERT INTO `shop_history` (`player_id`, `date`, `description`, `item_id`, `count`, `price`) VALUES (" .. senderGuid .. ", NOW(), " .. db.escapeString(senderDesc) .. ", 0, " .. amount .. ", " .. -amount .. ");")

        -- Log para quem recebeu (valor positivo)
        db.asyncQuery("INSERT INTO `shop_history` (`player_id`, `date`, `description`, `item_id`, `count`, `price`) VALUES (" .. targetGuid .. ", NOW(), " .. db.escapeString(receiverDesc) .. ", 0, " .. amount .. ", " .. amount .. ");")
        -- ######### FIM DA NOVA LÓGICA #########

        -- 5. Envia confirmação e notifica o alvo (sem alterações)
        sendMsg(player, "info", "Transfer Successful", "You have successfully transferred " .. amount .. " points to " .. targetName .. ".")
        sendData(player, "points", {points = getPlayerPoints(player), secondPoints = -1})

        if targetPlayer then
            targetPlayer:sendTextMessage(MESSAGE_INFO_DESCR, "You have received a gift of " .. amount .. " points from " .. player:getName() .. "!")
        end
    -- ######### FIM DA LÓGICA DE TRANSFERÊNCIA #########
    end
    return true
end