
if not table.contains then
    function table.contains(tbl, element)
        for _, value in pairs(tbl) do
            if value == element then
                return true
            end
        end
        return false
    end
end

if not table.copy then
    function table.copy(original)
        local copy = {}
        for k, v in pairs(original) do
            if type(v) == "table" then
                copy[k] = table.copy(v)
            else
                copy[k] = v
            end
        end
        return copy
    end
end
TaskSystem = {
configTasks = {
    [1] = {
        nameOfTheTask = "Troll",
        looktype = { type = 15 },
        monsters = { "Troll", "Frost Troll", "Swamp Troll" },
        minKills = 50,
        maxKills = 500,
        baseKills = 50, -- A recompensa abaixo é baseada neste número de abates
        rewards = {
            baseExpReward = 100,
        }
    },
    [2] = {
        nameOfTheTask = "Rotworm",
        looktype = { type = 26 },
        monsters = { "Rotworm", "Carrion Worm" },
        minKills = 100,
        maxKills = 1000,
        baseKills = 100,
        rewards = {
            baseExpReward = 400,
        }
    },
    [3] = {
        nameOfTheTask = "Minotaur",
        looktype = { type = 25 },
        monsters = {"Minotaur"},
        minKills = 100,
        maxKills = 1000,
        baseKills = 100,
        rewards = {
            baseExpReward = 500,
        }
    },
    },

    list = {},
    baseStorage = 1500,
    maximumTasks = 2, -- Max tasks ativas
    countForParty = true,
    maxDist = 7,
    players = {},

loadDatabase = function()
    if (#TaskSystem.list > 0) then return true end
    print("[Task System] Loading Task Database...")
    TaskSystem.list = {}
    for id, taskConfig in ipairs(TaskSystem.configTasks) do
        table.insert(TaskSystem.list, {
            id = id,
            name = taskConfig.displayName or taskConfig.nameOfTheTask, -- MUDOU DE nameOfTheTask
            monsters = taskConfig.monsters, -- NOVO CAMPO
            looktype = taskConfig.looktype,
            minKills = taskConfig.minKills,
            maxKills = taskConfig.maxKills,
            baseKills = taskConfig.baseKills,
            exp = taskConfig.rewards.baseExpReward
        })
    end
    print("[Task System] Task Database Loaded. Total tasks: " .. #TaskSystem.list)
    return true
end,


getCurrentTasks = function(player)
    local tasks = {}
    for _, taskInfo in ipairs(TaskSystem.list) do
        local progressStorage = TaskSystem.baseStorage + taskInfo.id
        local metadataStorage = TaskSystem.baseStorage + taskInfo.id + 5000

        local killsLeft = player:getStorageValue(progressStorage)
        
        -- A task está ativa se a storage de progresso for > 0
        if killsLeft and killsLeft > 0 then
            local totalKills = player:getStorageValue(metadataStorage)
            
            if totalKills and totalKills > 0 then
                local playerTask = table.copy(taskInfo)
                playerTask.kills = totalKills -- O total que o jogador escolheu
                playerTask.done = totalKills - killsLeft
                table.insert(tasks, playerTask)
            end
        end
    end
    return tasks
end,


   -- NOVO CÓDIGO PARA a função onAction

onAction = function(player, data)
    local action = data['action']
    local entryId = tonumber(data['entry'])

    if (action == 'info') then
        TaskSystem.sendData(player)
        TaskSystem.players[player:getGuid()] = 1
    elseif (action == 'hide') then
        TaskSystem.players[player:getGuid()] = nil
    elseif (action == 'start') then
        local quantity = tonumber(data['quantity'])
        if not entryId or not quantity then
            return
        end

        local taskConfig = TaskSystem.configTasks[entryId]
        if not taskConfig then
            return player:sendExtendedOpcode(215, json.encode({ message = 'Unknown task.', color = 'red' }))
        end

        -- Verifica se o jogador já tem o máximo de tasks
        local currentTasks = TaskSystem.getCurrentTasks(player)
        if #currentTasks >= TaskSystem.maximumTasks then
            return player:sendExtendedOpcode(215, json.encode({ message = "You have reached the maximum number of active tasks.", color = 'red' }))
        end

        -- Verifica se a task já está ativa
        for _, activeTask in ipairs(currentTasks) do
            if activeTask.id == entryId then
                return player:sendExtendedOpcode(215, json.encode({ message = 'You already have this task active.', color = 'red' }))
            end
        end

        -- Valida a quantidade
        if quantity < taskConfig.minKills or quantity > taskConfig.maxKills then
            local msg = string.format("Invalid quantity. Must be between %d and %d.", taskConfig.minKills, taskConfig.maxKills)
            return player:sendExtendedOpcode(215, json.encode({ message = msg, color = 'red' }))
        end
        
        -- Define as DUAS storages
        local progressStorage = TaskSystem.baseStorage + entryId
        local metadataStorage = TaskSystem.baseStorage + entryId + 5000 -- Offset
        
        player:setStorageValue(progressStorage, quantity) -- Armazena os abates restantes
        player:setStorageValue(metadataStorage, quantity) -- Armazena o total original para cálculo
        
        player:sendExtendedOpcode(215, json.encode({ message = 'Task started!', color = 'green' }))
        TaskSystem.sendData(player) -- Atualiza a UI do jogador

    elseif (action == 'cancel') then
        local progressStorage = TaskSystem.baseStorage + entryId
        local metadataStorage = TaskSystem.baseStorage + entryId + 5000

        if player:getStorageValue(progressStorage) > 0 then
            player:setStorageValue(progressStorage, -1)
            player:setStorageValue(metadataStorage, -1)
            player:sendExtendedOpcode(215, json.encode({ message = 'Task aborted.', color = 'green' }))
            TaskSystem.sendData(player)
        else
            player:sendExtendedOpcode(215, json.encode({ message = "You don't have this task active.", color = 'red' }))
        end
    end
end, -- Fim da nova onAction

   -- NOVO CÓDIGO PARA a função killForPlayer

killForPlayer = function(player, taskConfig)
    local progressStorage = TaskSystem.baseStorage + taskConfig.id
    local metadataStorage = TaskSystem.baseStorage + taskConfig.id + 5000

    local killsLeft = player:getStorageValue(progressStorage)
    if not killsLeft or killsLeft <= 0 then
        return -- Não tem a task ativa
    end

    -- Diminui o contador
    killsLeft = killsLeft - 1
    player:setStorageValue(progressStorage, killsLeft)

    -- Chegou a zero? Missão cumprida!
    if killsLeft == 0 then
        local totalKills = player:getStorageValue(metadataStorage)
        if not totalKills or totalKills <= 0 then return end -- Segurança

        -- Cálculo da recompensa proporcional
        local expReward = math.floor((totalKills / taskConfig.baseKills) * taskConfig.rewards.baseExpReward)

        -- Entrega das recompensas
        if expReward > 0 then
            player:addExperience(expReward)
        end
      
        -- Mensagem de conclusão
        local message = string.format("TASK COMPLETED! You killed %d %s and received %d EXP.", totalKills, taskConfig.nameOfTheTask, expReward)
        player:sendTextMessage(MESSAGE_INFO_DESCR, message)
        
        -- Limpa as storages
        player:setStorageValue(progressStorage, -1)
        player:setStorageValue(metadataStorage, -1)
        
        -- Se a janela estiver aberta, manda uma mensagem e atualiza
        if (TaskSystem.players[player:getGuid()]) then
            player:sendExtendedOpcode(215, json.encode({ message = "Task completed!", color = 'lime' }))
            TaskSystem.sendData(player)
        end

    -- Se não completou, apenas atualiza a UI se estiver aberta
    elseif (TaskSystem.players[player:getGuid()]) then
        TaskSystem.sendData(player)
    end
end, -- Fim da nova killForPlayer

-- NOVO CÓDIGO para a função onKill (levemente ajustada para passar o taskConfig)

onKill = function(player, target)
    if not TaskSystem.list or #TaskSystem.list == 0 then
        TaskSystem.loadDatabase()
    end

    local targetName = target:getName():lower()
    local foundTaskConfig = nil
    
      -- Procura o monstro morto na lista de monstros de cada task
   for id, taskConfig in ipairs(TaskSystem.configTasks) do
        for _, monsterName in ipairs(taskConfig.monsters) do
            if monsterName:lower() == targetName then
                foundTaskConfig = taskConfig
                foundTaskConfig.id = id -- Adiciona o ID para referência
                break
            end
        end
        if foundTaskConfig then break end
    end

    if not foundTaskConfig then
        return true -- Monstro não pertence a nenhuma task
    end

    -- A lógica de party permanece a mesma
    local party = player:getParty()
    local tpos = target:getPosition()

    if (TaskSystem.countForParty and party) then
        -- Checa todos os membros da party na tela
        for _, member in ipairs(party:getMembers()) do
            if member:isPlayer() and member:getPosition():isNearTo(tpos, TaskSystem.maxDist) then
                TaskSystem.killForPlayer(member, foundTaskConfig)
            end
        end
    else
        TaskSystem.killForPlayer(player, foundTaskConfig)
    end

    return true
end,
   
sendData = function(player)
    if not TaskSystem.list or #TaskSystem.list == 0 then
        TaskSystem.loadDatabase()
    end

    local playerTasks = TaskSystem.getCurrentTasks(player)
    
    -- Pega os pontos de task do jogador
    local points = player:getStorageValue(taskPointStorage) or 0

    local response = {
        allTasks = TaskSystem.list,
        playerTasks = playerTasks,
        playerTaskPoints = points -- Adiciona a nova informação aqui
    }

    local jsonOutput = json.encode(response)
    
    return player:sendExtendedOpcode(215, jsonOutput)
end
}
TaskSystem.loadDatabase()