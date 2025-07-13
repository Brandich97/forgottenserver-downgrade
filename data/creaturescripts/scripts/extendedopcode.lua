
local OPCODE_LANGUAGE = 1

function onExtendedOpcode(player, opcode, buffer)
    if opcode == OPCODE_LANGUAGE then
        -- ...
    elseif opcode == 215 then
        if TaskSystem and type(TaskSystem.onAction) == 'function' then
            local status, data = pcall(json.decode, buffer)
            if status then
                TaskSystem.onAction(player, data)
            else
                print("[Error] ExtendedOpcode: Failed to decode JSON for opcode 215. Error: " .. data)
            end
        else
            print("[Warning] ExtendedOpcode: TaskSystem.onAction is not defined or not a function. Task system might not be loaded.")
        end
    else
        -- ...
    end
    return true
end