local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local chatDataStore = DataStoreService:GetDataStore("PlayerChatHistories")
local playerChatData = {}


-- // ФУНКЦИЯ ДЛЯ СОЗДАНИЯ ИЛИ ПОЛУЧЕНИЯ RemoteEvent //
local function getOrCreateEvent(name)
    local event = ReplicatedStorage:FindFirstChild(name)
    if not event then
        event = Instance.new("RemoteEvent")
        event.Name = name
        event.Parent = ReplicatedStorage
        print("Сервер создал недостающий RemoteEvent:", name)
    end
    return event
end

-- // ФУНКЦИЯ ДЛЯ СОЗДАНИЯ ИЛИ ПОЛУЧЕНИЯ RemoteFunction //
local function getOrCreateFunction(name)
    local func = ReplicatedStorage:FindFirstChild(name)
    if not func then
        func = Instance.new("RemoteFunction")
        func.Name = name
        func.Parent = ReplicatedStorage
        print("Сервер создал недостающий RemoteFunction:", name)
    end
    return func
end

-- // СОБЫТИЯ И ФУНКЦИИ //
local sendMessageEvent = getOrCreateEvent("SendMessageToServer")
local receiveMessageEvent = getOrCreateEvent("ReceiveMessageFromServer")
local getChatHistoryFunction = getOrCreateFunction("GetChatHistory")
local updateChatMetadataEvent = getOrCreateEvent("UpdateChatMetadata")
local deleteChatEvent = getOrCreateEvent("DeleteChat")

-- // "БАЗА ДАННЫХ" ЗАГАДОЧНЫХ ОТВЕТОВ //
local fakeAiResponses = {
	"Тени сгущаются там, где свет отбрасывает вопросы...",
	"Я слышу эхо мыслей, которые еще не были произнесены.",
	"Звезды шепчут секреты, но лишь тишина их понимает.",
	"Каждый ответ — это лишь дверь к новому вопросу.",
	"Путь, который ты ищешь, уже проложен в твоем сердце.",
	"Время — это река, в которую нельзя войти дважды, но можно увидеть ее течение.",
	"За гранью видимого лежит то, что действительно имеет значение."
}

-- Функция, которая обрабатывает сообщение от игрока
local function onPlayerMessage(player, chatId, message)
	print(`Игрок {player.Name} отправил сообщение: "{message}" в чат {chatId}`)
	
	local pId = tostring(player.UserId)
	local playerData = playerChatData[pId]
	if not playerData then
		warn("Не найдены данные для игрока " .. player.Name)
		return
	end
	
	if not playerData[chatId] then
		playerData[chatId] = { id = chatId, messages = {} }
	end
	
	local timestamp = os.time()
	table.insert(playerData[chatId].messages, {type = "Player", text = message, timestamp = timestamp})
	playerData[chatId].timestamp = timestamp -- Обновляем время последней активности чата
	
	task.wait(1.5) 
	
	local randomIndex = math.random(1, #fakeAiResponses)
	local response = fakeAiResponses[randomIndex]
	table.insert(playerData[chatId].messages, {type = "AI", text = response, timestamp = os.time()})
	
	receiveMessageEvent:FireClient(player, chatId, response)
	print(`Отправлен ответ для {player.Name}: "{response}"`)
	
	local success, err = pcall(function()
		chatDataStore:SetAsync(pId, playerData)
	end)
	if not success then
		warn("Не удалось сохранить данные чата для " .. player.Name .. ": " .. err)
	end
end

local function onUpdateMetadata(player, chatId, metadata)
	print(`Игрок {player.Name} обновляет метаданные для чата {chatId}`)
	local pId = tostring(player.UserId)
	local playerData = playerChatData[pId]
	if playerData and playerData[chatId] and metadata then
		for key, value in pairs(metadata) do
			playerData[chatId][key] = value
		end
		-- Немедленно сохраняем, так как это важное действие
		local success, err = pcall(function()
			chatDataStore:SetAsync(pId, playerData)
		end)
		if not success then
			warn("Не удалось сохранить метаданные для " .. player.Name .. ": " .. err)
		end
	end
end

local function onDeleteChat(player, chatId)
	print(`Игрок {player.Name} удаляет чат {chatId}`)
	local pId = tostring(player.UserId)
	local playerData = playerChatData[pId]
	if playerData and playerData[chatId] then
		playerData[chatId] = nil
		-- Немедленно сохраняем
		local success, err = pcall(function()
			chatDataStore:SetAsync(pId, playerData)
		end)
		if not success then
			warn("Не удалось сохранить данные после удаления чата для " .. player.Name .. ": " .. err)
		end
	end
end

local function onPlayerAdded(player)
    local pId = tostring(player.UserId)
    local success, data = pcall(function()
        return chatDataStore:GetAsync(pId)
    end)

    if success then
        playerChatData[pId] = data or {}
        print("Данные чата загружены для", player.Name)
    else
        warn("Не удалось загрузить данные чата для " .. player.Name .. ": " .. tostring(data))
        playerChatData[pId] = {} 
    end
end

local function onPlayerRemoving(player)
    local pId = tostring(player.UserId)
    if playerChatData[pId] then
        local success, err = pcall(function()
            chatDataStore:SetAsync(pId, playerChatData[pId])
        end)
        if success then
            print("Данные чата сохранены для", player.Name)
        else
            warn("Не удалось сохранить данные чата при выходе для " .. player.Name .. ": " .. err)
        end
        playerChatData[pId] = nil
    end
end

getChatHistoryFunction.OnServerInvoke = function(player)
    return playerChatData[tostring(player.UserId)] or {}
end

-- // ПОДКЛЮЧЕНИЕ СОБЫТИЯ //
sendMessageEvent.OnServerEvent:Connect(onPlayerMessage)
updateChatMetadataEvent.OnServerEvent:Connect(onUpdateMetadata)
deleteChatEvent.OnServerEvent:Connect(onDeleteChat)
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(onPlayerAdded, player)
end

print("Серверный скрипт чата (v3, с меню) загружен и готов.") 