-- data/lib/taskSystem.lua
-- Sistema de Tasks Simplificado para OTClient Redemption (Server-side)

local taskPointStorage = 5151 -- which player storage holds task points.

-- Funcao auxiliar: table.contains (para compatibilidade)
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

-- Funcao auxiliar para deep copy de tabelas (se table.copy nao for nativa)
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
    -- Mova a configuracao 'configTasks' para DENTRO de TaskSystem
    configTasks = {
        [1] = {
            nameOfTheTask = "Troll",
            looktype = { type = 79 },
            killsRequired = 25,
            rewards = {
                expReward = 1000,
                pointsReward = 0,
            }
        },
        [2] = {
            nameOfTheTask = "Rotworm",
            looktype = { type = 81 },
            killsRequired = 25,
            rewards = {
                expReward = 1500,
                pointsReward = 0,
            }
        },
        [3] = {
            nameOfTheTask = "Spider",
            looktype = { type = 99},
            killsRequired = 25,
            rewards = {
                expReward = 2000,
                pointsReward = 0,
            }
        },
        -- Adicione mais tasks aqui com seus respectivos IDs, Nomes, Monstros, Recompensas e OutfitLookType
    },
    list = {},
    baseStorage = 1500,
    maximumTasks = 3, -- Max tasks ativas
    countForParty = true,
    maxDist = 7,
    players = {},
    loadDatabase = function()
        if (#TaskSystem.list > 0) then
            print("[Task System Debug] loadDatabase called, but already loaded.")
            return true
        end

        print("[Task System Debug] Loading Task Database...")
        for i = 1, #TaskSystem.configTasks do
            local taskConfig = TaskSystem.configTasks[i]
            table.insert(TaskSystem.list, {
                id = i,
                name = taskConfig.nameOfTheTask,
                looktype = taskConfig.looktype,
                kills = taskConfig.killsRequired,
                exp = taskConfig.rewards.expReward,
                taskPoints = taskConfig.rewards.pointsReward or 0,
            })
        end
        print("[Task System Debug] Task Database Loaded. Total tasks: " .. #TaskSystem.list)
        return true
    end,
    getCurrentTasks = function(player)
        local tasks = {}
        for _, task in ipairs(TaskSystem.list) do
            local storageValue = player:getStorageValue(TaskSystem.baseStorage + task.id)
            if (storageValue and storageValue > 0) then
                local playerTask = table.copy(task)
                playerTask.left = storageValue - 1
                playerTask.done = playerTask.kills - playerTask.left
                table.insert(tasks, playerTask)
            end
        end
        return tasks
    end,
    getPlayerTaskIds = function(player)
        local tasks = {}
        for _, task in ipairs(TaskSystem.list) do
            local storageValue = player:getStorageValue(TaskSystem.baseStorage + task.id)
            if (storageValue and storageValue > 0) then
                table.insert(tasks, task.id)
            end
        end
        return tasks
    end,
    getTaskNames = function(player)
        local tasks = {}
        for _, task in ipairs(TaskSystem.list) do
            table.insert(tasks, '{' .. task.name:lower() .. '}')
        end
        return table.concat(tasks, ', ')
    end,
    onAction = function(player, data)
        if (data['action'] == 'info') then
            TaskSystem.sendData(player)
            TaskSystem.players[player.uid] = 1
        elseif (data['action'] == 'hide') then
            TaskSystem.players[player.uid] = nil
        elseif (data['action'] == 'start') then
            local playerTaskIds = TaskSystem.getPlayerTaskIds(player)

            if (#playerTaskIds >= TaskSystem.maximumTasks) then
                return player:sendExtendedOpcode(215, json.encode({
                    message = "You can't take more tasks.",
                    color = 'red'
                }))
            end

            for _, task in ipairs(TaskSystem.list) do
                if (task.id == data['entry']) then
                    if (table.contains(playerTaskIds, task.id)) then
                        return player:sendExtendedOpcode(215, json.encode({
                            message = 'You already have this task active.',
                            color = 'red'
                        }))
                    end

                    player:setStorageValue(TaskSystem.baseStorage + task.id, task.kills + 1)
                    player:sendExtendedOpcode(215, json.encode({
                        message = 'Task started.',
                        color = 'green'
                    }))
                    return TaskSystem.sendData(player)
                end
            end

            return player:sendExtendedOpcode(215, json.encode({
                message = 'Unknown task.',
                color = 'red'
            }))
        elseif (data['action'] == 'cancel') then
            for _, task in ipairs(TaskSystem.list) do
                if (task.id == data['entry']) then
                    local playerTaskIds = TaskSystem.getPlayerTaskIds(player)

                    if (not table.contains(playerTaskIds, task.id)) then
                        return player:sendExtendedOpcode(215, json.encode({
                            message = "You don't have this task active.",
                            color = 'red'
                        }))
                    end

                    player:setStorageValue(TaskSystem.baseStorage + task.id, -1)
                    player:sendExtendedOpcode(215, json.encode({
                        message = 'Task aborted.',
                        color = 'green'
                    }))
                    return TaskSystem.sendData(player)
                end
            end

            return player:sendExtendedOpcode(215, json.encode({
                message = 'Unknown task.',
                color = 'red'
            }))
        elseif (data['action'] == 'finish') then
            for _, task in ipairs(TaskSystem.list) do
                if (task.id == data['entry']) then
                    local playerTaskIds = TaskSystem.getPlayerTaskIds(player)

                    if (not table.contains(playerTaskIds, task.id)) then
                        return player:sendExtendedOpcode(215, json.encode({
                            message = "You don't have this task active.",
                            color = 'red'
                        }))
                    end

                    local left = player:getStorageValue(TaskSystem.baseStorage + task.id)
                    if not left or left < 1 then
                        return player:sendExtendedOpcode(215, json.encode({
                            message = "Task is not active or already completed.",
                            color = 'red'
                        }))
                    end

                    if (left > 1) then
                        return player:sendExtendedOpcode(215, json.encode({
                            message = "Task isn't completed yet.",
                            color = 'red'
                        }))
                    end

                    player:setStorageValue(TaskSystem.baseStorage + task.id, -1)
                    player:addExperience(task.exp)
                    local currentTaskPoints = player:getStorageValue(taskPointStorage) or 0
                    if task.taskPoints then
                        player:setStorageValue(taskPointStorage, currentTaskPoints + task.taskPoints)
                    end

                    player:sendExtendedOpcode(215, json.encode({
                        message = 'Task finished. Rewards granted.',
                        color = 'green'
                    }))
                    return TaskSystem.sendData(player)
                end
            end

            return player:sendExtendedOpcode(215, json.encode({
                message = 'Unknown task.',
                color = 'red'
            }))
        end
    end, -- Fim da funcao onAction
    killForPlayer = function(player, task)
        local storageKey = TaskSystem.baseStorage + task.id
        local left = player:getStorageValue(storageKey)
        if not left or left <= 0 then
            return
        end

        if (left == 1) then
            player:addExperience(task.exp)
            local currentTaskPoints = player:getStorageValue(taskPointStorage) or 0
            if task.taskPoints then
                player:setStorageValue(taskPointStorage, currentTaskPoints + task.taskPoints)
          end

            if (TaskSystem.players[player.uid]) then
                player:sendExtendedOpcode(215, json.encode({
                    message = 'Task finished. Rewards granted.',
                    color = 'green'
                }))
            end
            player:setStorageValue(storageKey, -1)
            return true
        end

        player:setStorageValue(storageKey, left - 1)

        if (TaskSystem.players[player.uid]) then
            return TaskSystem.sendData(player)
        end
    end, -- Fim da funcao killForPlayer

    onKill = function(player, target)
     if not TaskSystem.list or #TaskSystem.list == 0 then
            TaskSystem.loadDatabase()
        end

        local targetName = target:getName():lower()
        local foundTask = nil
        for _, task in ipairs(TaskSystem.list) do
            if (task.name:lower() == targetName) then
                foundTask = task
              break
            end
        end

        if not foundTask then
            return true
        end

        local playerTaskIds = TaskSystem.getPlayerTaskIds(player)
        if (not table.contains(playerTaskIds, foundTask.id)) then
           return true
        end
        local party = player:getParty()
        local tpos = target:getPosition()

        if (TaskSystem.countForParty and party and party:getMembers()) then
            for i, creature in pairs(party:getMembers()) do
                local pos = creature:getPosition()
                if (pos.z == tpos.z and pos:getDistance(tpos) <= TaskSystem.maxDist) then
                   TaskSystem.killForPlayer(creature, foundTask)
                end
            end

            local leader = party:getLeader()
            if (leader and leader:isPlayer() and leader ~= player) then
                local pos = leader:getPosition()
                if (pos.z == tpos.z and pos:getDistance(tpos) <= TaskSystem.maxDist) then
                   TaskSystem.killForPlayer(leader, foundTask)
                end
            end
        else
           TaskSystem.killForPlayer(player, foundTask)
        end

        return true
    end, -- Fim da funcao onKill. Nao ha virgula se for o ultimo campo da tabela.

    sendData = function(player)
        if not TaskSystem.list or #TaskSystem.list == 0 then
            TaskSystem.loadDatabase()
        end

        local playerTasks = TaskSystem.getCurrentTasks(player)

        local response = {
            allTasks = TaskSystem.list,
            playerTasks = playerTasks
        }

        local jsonOutput = json.encode(response)
       
        return player:sendExtendedOpcode(215, jsonOutput)
    end -- Fim da funcao sendData (este e o ultimo campo da tabela)
} -- Fim da tabela TaskSystem

TaskSystem.loadDatabase()