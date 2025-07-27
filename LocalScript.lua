--// СЕРВИСЫ //
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local StarterGui        = game:GetService("StarterGui")
local TweenService      = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")

local player        = Players.LocalPlayer
local PlayerScripts = player:WaitForChild("PlayerScripts")
local PlayerModule  = require(PlayerScripts:WaitForChild("PlayerModule"))

--// УПРАВЛЕНИЕ ЧАТАМИ //
local chats = {}
local activeChatId = nil
local nextChatId = 1
local isSidebarExpanded = false

-- Remove isPinned-related logic

--// СОБЫТИЯ И ФУНКЦИИ //
local sendMessageEvent    = ReplicatedStorage:WaitForChild("SendMessageToServer", 30)
local receiveMessageEvent = ReplicatedStorage:WaitForChild("ReceiveMessageFromServer", 30)
local getChatHistoryFunction = ReplicatedStorage:WaitForChild("GetChatHistory", 30)
local updateChatMetadataEvent = ReplicatedStorage:WaitForChild("UpdateChatMetadata", 30)
local deleteChatEvent = ReplicatedStorage:WaitForChild("DeleteChat", 30)


--// ОТКЛЮЧАЕМ СТАНДАРТНЫЙ GUI/КОНТРОЛЫ //
pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
	local controls = PlayerModule:GetControls()
	controls:Disable()
end)

--// ФУНКЦИЯ-ПОМОЩНИК ДЛЯ UI //
local function Create(className, props)
	local inst = Instance.new(className)
	for prop, value in pairs(props) do
		inst[prop] = value
	end
	return inst
end

--// ЦВЕТОВАЯ ПАЛИТРА //
local colors = {
	background         = Color3.fromRGB(31, 33, 37),
	sidebar            = Color3.fromRGB(43, 45, 49),
	input              = Color3.fromRGB(52, 53, 56),
	stroke             = Color3.fromRGB(85, 88, 94), -- Сделал темнее
	text               = Color3.fromRGB(230, 230, 230),
	text_muted         = Color3.fromRGB(150, 150, 150),
	accent             = Color3.fromRGB(138, 148, 255),
	player_message_bg  = Color3.fromRGB(60, 65, 80)
}

--// UI СОЗДАНИЕ //
local screenGui = script.Parent
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn  = false

-- Конфигурация анимации
local expandedSidebarWidth = UDim2.new(0.2, 0, 1, 0)
local collapsedSidebarWidth = UDim2.new(0, 60, 1, 0)
local expandedMainContentPos = UDim2.fromScale(0.2, 0)
local collapsedMainContentPos = UDim2.new(0, 60, 0, 0)
local expandedMainContentSize = UDim2.fromScale(0.8, 1)
local collapsedMainContentSize = UDim2.new(1, -60, 1, 0)
local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

-- Фон
Create("Frame", {
	Parent = screenGui,
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = colors.background,
	BorderSizePixel = 0
})

-- Sidebar
local sidebar = Create("Frame", {
	Name = "Sidebar",
	Parent = screenGui,
	Size = collapsedSidebarWidth,
	BackgroundColor3 = colors.sidebar,
	BorderSizePixel = 0
})

Create("UIListLayout", {
	Parent = sidebar,
	FillDirection = Enum.FillDirection.Vertical,
	SortOrder = Enum.SortOrder.LayoutOrder,
	HorizontalAlignment = Enum.HorizontalAlignment.Center,
	Padding = UDim.new(0, 10)
})

Create("UIPadding", {
	Parent = sidebar,
	PaddingTop = UDim.new(0, 60), -- Отступ сверху для кнопки
	PaddingLeft = UDim.new(0, 10),
	PaddingRight = UDim.new(0, 10)
})

-- Update newChatButton size definitions
local collapsedButtonSize = UDim2.new(0, 32, 0, 32)
local expandedButtonHeight = 32

-- Adjust sizes in button creation
-- NewChatButton definition update:
local newChatButton = Create("TextButton", {
    Name = "NewChatButton",
    Parent = sidebar,
    Size = collapsedButtonSize,
    BackgroundColor3 = colors.input,
    BorderSizePixel = 0,
    Font = Enum.Font.SourceSans,
    Text = "+",
    TextColor3 = colors.text,
    TextSize = 22,
    TextXAlignment = Enum.TextXAlignment.Center,
    LayoutOrder = 1
})
Create("UICorner", { CornerRadius = UDim.new(0, 16), Parent = newChatButton })

-- After creating newChatButton, ensure we store its corner
local newChatButtonCorner = Create("UICorner", { CornerRadius = UDim.new(0, 16), Parent = newChatButton })

-- Adjust sizes
newChatButton.Size = UDim2.new(0, 36, 0, 36)
newChatButtonCorner.CornerRadius = UDim.new(0, 18)

-- Update collapsedButtonSize variable
local collapsedButtonSize = UDim2.new(0, 36, 0, 36)

-- Контейнер для истории чатов в сайдбаре
local chatHistoryContainer = Create("ScrollingFrame", {
	Name = "ChatHistoryContainer",
	Parent = sidebar,
	Size = UDim2.new(1, 0, 1, -110), -- Заполняем оставшееся место
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = colors.background,
	Visible = false, -- Скрыто по умолчанию
	LayoutOrder = 2
})
local chatHistoryLayout = Create("UIListLayout", {
	Parent = chatHistoryContainer,
	FillDirection = Enum.FillDirection.Vertical,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 5)
})
Create("UIPadding", {
	Parent = chatHistoryContainer,
	PaddingLeft = UDim.new(0, 0), -- Убираем лишний отступ
	PaddingRight = UDim.new(0.05, 0)
})


-- Основная область
local mainContent = Create("Frame", {
	Name = "MainContent",
	Parent = screenGui,
	Position = collapsedMainContentPos,
	Size = collapsedMainContentSize,
	BackgroundColor3 = colors.background,
	BorderSizePixel = 0
})

-- Приветственное сообщение
local welcomeText = Create("TextLabel", {
	Name = "WelcomeText",
	Parent = mainContent,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position  = UDim2.fromScale(0.5, 0.4),
	Size      = UDim2.fromScale(0.8, 0.2),
	BackgroundTransparency = 1,
	Font = Enum.Font.SourceSansBold,
	Text = "Здравствуйте, " .. player.Name .. "!",
	TextColor3 = colors.accent,
	TextSize   = 48,
	TextWrapped = true
})

-- Контейнер сообщений
local messageContainer = Create("ScrollingFrame", {
	Name = "MessageContainer",
	Parent = mainContent,
	Position = UDim2.new(0, 0, 0, 0),
	Size     = UDim2.new(1, 0, 1, -120),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(0, 0, 0, 0),
	ScrollBarThickness = 6,
	ScrollBarImageColor3 = colors.input
})

local messageListLayout = Create("UIListLayout", {
	Parent = messageContainer,
	FillDirection = Enum.FillDirection.Vertical,
	HorizontalAlignment = Enum.HorizontalAlignment.Left,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 10)
})

Create("UIPadding", {
	Parent = messageContainer,
	PaddingLeft   = UDim.new(0.05, 0),
	PaddingRight  = UDim.new(0.05, 0),
	PaddingTop    = UDim.new(0, 20)
})

-- Область ввода
local inputWrapper = Create("Frame", {
	Name = "InputWrapper",
	Parent = mainContent,
	AnchorPoint = Vector2.new(0.5, 1),
	Position  = UDim2.new(0.5, 0, 1, -40),
	Size      = UDim2.new(0.8, 0, 0, 70),
	BackgroundTransparency = 1
})

local inputFrame = Create("Frame", {
	Name = "InputFrame",
	Parent = inputWrapper,
	Size = UDim2.new(1, 0, 1, 0),
	BackgroundColor3 = colors.background,
	BorderSizePixel = 0
})
Create("UICorner", { CornerRadius = UDim.new(0, 28), Parent = inputFrame })
Create("UIListLayout", {
	Parent = inputFrame,
	FillDirection = Enum.FillDirection.Horizontal,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	SortOrder = Enum.SortOrder.LayoutOrder,
	Padding = UDim.new(0, 10)
})
Create("UIPadding", {
	Parent = inputFrame,
	PaddingLeft  = UDim.new(0, 15),
	PaddingRight = UDim.new(0, 15)
})

-- After inputFrame creation ensure stroke
local inputFrameStroke = inputFrame:FindFirstChildWhichIsA("UIStroke")
if not inputFrameStroke then
    Create("UIStroke", {Parent = inputFrame, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = colors.stroke, Thickness = 1})
else
    inputFrameStroke.Color = colors.stroke
end

-- Кнопка "+"
local plusButton = Create("TextButton", {
	Name = "PlusButton",
	Parent = inputFrame,
	Size = UDim2.new(0, 34, 0, 34),
	BackgroundTransparency = 1,
	Font = Enum.Font.SourceSansBold,
	Text = "+",
	TextSize = 28,
	TextColor3 = colors.text_muted,
	LayoutOrder = 1
})

-- Поле ввода
local inputScroll = Create("ScrollingFrame", {
	Name = "InputScroll",
	Parent = inputFrame,
	Size = UDim2.new(1, -180, 1, 0),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	LayoutOrder = 2,
	ScrollBarThickness = 4,
	ScrollBarImageColor3 = colors.stroke,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	CanvasSize = UDim2.new(1, 0, 1, 0)
})

local inputBox = Create("TextBox", {
	Name = "InputBox",
	Parent = inputScroll,
	Size = UDim2.new(1, 0, 1, 0),
	AutomaticSize = Enum.AutomaticSize.Y,
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ClearTextOnFocus = false,
	Font = Enum.Font.SourceSans,
	PlaceholderText = "Спросить Gemini...",
	PlaceholderColor3 = colors.text_muted,
	Text = "",
	TextColor3 = colors.text,
	TextSize = 18,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextWrapped = true
})

-- Кнопка Canvas (по желанию)
local canvasButton = Create("TextButton", {
	Name = "CanvasButton",
	Parent = inputFrame,
	Size = UDim2.new(0, 34, 0, 34),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = colors.background,
	Font = Enum.Font.SourceSans,
	Text = "Canvas",
	TextColor3 = colors.text_muted,
	TextSize = 14,
	LayoutOrder = 3
})
Create("UICorner", { CornerRadius = UDim.new(0, 18), Parent = canvasButton })
Create("UIPadding", {
	Parent = canvasButton,
	PaddingLeft  = UDim.new(0, 12),
	PaddingRight = UDim.new(0, 12)
})
Create("UIStroke", {
	ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	Color = colors.stroke,
	Thickness = 1,
	Parent = canvasButton
})

-- Кнопка отправки
local sendButton = Create("TextButton", {
	Name = "SendButton",
	Parent = inputFrame,
	Size = UDim2.new(0, 40, 0, 40),
	BackgroundColor3 = colors.background,
	Font = Enum.Font.SourceSansBold,
	Text = "Send",
	TextSize = 14,
	TextColor3 = colors.text_muted,
	LayoutOrder = 4
})
Create("UICorner", { CornerRadius = UDim.new(1, 0), Parent = sendButton })
Create("UIStroke", {
	ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	Color = colors.stroke,
	Thickness = 1,
	Parent = sendButton
})

--// ШАБЛОН КНОПКИ ЧАТА В САЙДБАРЕ
local chatButtonTemplate = Create("Frame", {
	Name = "ChatButtonContainer",
	Parent = script, -- Скрыто
	Size = UDim2.new(1, 0, 0, 35),
	BackgroundColor3 = colors.input,
	BorderSizePixel = 0,
})
Create("UICorner", { CornerRadius = UDim.new(0, 5), Parent = chatButtonTemplate })
local chatButtonLayout = Create("UIListLayout", {
	Parent = chatButtonTemplate,
	FillDirection = Enum.FillDirection.Horizontal,
	SortOrder = Enum.SortOrder.LayoutOrder,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 5)
})
Create("UIPadding", { Parent = chatButtonTemplate, PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 5) })
local chatButtonStroke = Create("UIStroke", {
	Parent = chatButtonTemplate,
	ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	Color = colors.accent,
	Thickness = 1.5,
	Enabled = false -- Включается для закрепленных
})

local chatTitleButton = Create("TextButton", {
	Name = "ChatTitleButton",
	Parent = chatButtonTemplate,
	Size = UDim2.new(1, -30, 1, 0),
	BackgroundTransparency = 1,
	Font = Enum.Font.SourceSans,
	Text = "Chat History",
	TextColor3 = colors.text_muted,
	TextSize = 14,
	TextTruncate = Enum.TextTruncate.AtEnd,
	TextXAlignment = Enum.TextXAlignment.Left,
	LayoutOrder = 1
})

-- Redesign MoreOptionsButton
local moreOptionsButton = Create("TextButton", {
	Name = "MoreOptionsButton",
	Parent = chatButtonTemplate,
	Size = UDim2.new(0, 16, 0, 16),
	BackgroundTransparency = 1,
	Font = Enum.Font.SourceSansBold,
	Text = "...",
	TextColor3 = colors.text_muted,
	TextSize = 10,
	LayoutOrder = 2
})
Create("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = moreOptionsButton })

--// КОНТЕКСТНОЕ МЕНЮ ДЛЯ КНОПОК ЧАТА
local contextMenuTemplate = Create("Frame", {
	Name = "ContextMenu",
	Parent = script, -- Скрыто
	Size = UDim2.new(0, 90, 0, 30),
	BackgroundColor3 = colors.background,
	BorderSizePixel = 0,
	Active = true, -- Чтобы "съедать" клики и они не закрывали меню
})
Create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = contextMenuTemplate })
Create("UIStroke", { Parent = contextMenuTemplate, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Color = colors.stroke, Thickness = 1 })
local contextMenuLayout = Create("UIListLayout", {
	Parent = contextMenuTemplate,
	FillDirection = Enum.FillDirection.Vertical,
	Padding = UDim.new(0, 4)
})
Create("UIPadding", { Parent = contextMenuTemplate, PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5), PaddingTop = UDim.new(0, 5), PaddingBottom = UDim.new(0, 5) })

local deleteButton = Create("TextButton", { Name = "DeleteButton", Parent = contextMenuTemplate, Size = UDim2.new(1, 0, 0, 22), BackgroundColor3 = colors.input, Text = "Удалить", TextColor3 = colors.text, TextSize = 12 })
Create("UICorner", { CornerRadius = UDim.new(0, 4), Parent = deleteButton })

-- Переменная для отслеживания активного меню
local activeContextMenu = nil

--// АНИМАЦИИ САЙДБАРА //////////////////////////////////////////////////////
local function expandSidebar()
	TweenService:Create(sidebar, tweenInfo, {Size = expandedSidebarWidth}):Play()
	TweenService:Create(mainContent, tweenInfo, {Position = expandedMainContentPos, Size = expandedMainContentSize}):Play()
	TweenService:Create(newChatButton, tweenInfo, {Size = UDim2.new(1, 0, 0, expandedButtonHeight)}):Play()
	TweenService:Create(newChatButtonCorner, tweenInfo, {CornerRadius = UDim.new(0, 12)}):Play()

	task.wait(0.15) -- Немного ждем, чтобы текст не появился раньше анимации
	newChatButton.Text = "  +  Новый чат"
	newChatButton.TextSize = 16
	newChatButton.TextXAlignment = Enum.TextXAlignment.Left
	chatHistoryContainer.Visible = true
	isSidebarExpanded = true
end

local function collapseSidebar()
	TweenService:Create(sidebar, tweenInfo, {Size = collapsedSidebarWidth}):Play()
	TweenService:Create(mainContent, tweenInfo, {Position = collapsedMainContentPos, Size = collapsedMainContentSize}):Play()
	TweenService:Create(newChatButton, tweenInfo, {Size = collapsedButtonSize}):Play()
	TweenService:Create(newChatButtonCorner, tweenInfo, {CornerRadius = UDim.new(0, 18)}):Play()

	closeContextMenu()
	chatHistoryContainer.Visible = false
	newChatButton.Text = "+"
	newChatButton.TextSize = 22
	newChatButton.TextXAlignment = Enum.TextXAlignment.Center
	isSidebarExpanded = false
end

--// ШАБЛОН СООБЩЕНИЯ (в репозитории Script, чтобы не отображался сразу)
local messageTemplate = Create("Frame", {
	Name = "MessageRowFrame",
	AutomaticSize = Enum.AutomaticSize.Y,
	Size = UDim2.new(1, 0, 0, 0),
	BackgroundTransparency = 1,
	Parent = script  -- скрыто
})

local messageLabel = Create("TextLabel", {
	Name = "MessageLabel",
	Parent = messageTemplate,
	AutomaticSize = Enum.AutomaticSize.XY,
	Size = UDim2.new(0, 0, 0, 0),
	BackgroundColor3 = colors.player_message_bg,
	BackgroundTransparency = 1,
	Font = Enum.Font.SourceSans,
	Text = "Placeholder",
	TextColor3 = colors.text,
	TextSize = 16,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	LineHeight = 1.2,
})
Create("UICorner", { CornerRadius = UDim.new(0, 12), Parent = messageLabel })
Create("UIPadding", {
	Parent = messageLabel,
	PaddingTop    = UDim.new(0, 10),
	PaddingBottom = UDim.new(0, 10),
	PaddingLeft   = UDim.new(0, 12),
	PaddingRight  = UDim.new(0, 12)
})
Create("UISizeConstraint", {  -- ограничиваем ширину
	Parent = messageLabel,
	MaxSize = Vector2.new(500, 1000)
})

-- ФУНКЦИИ
--///////////////////////////////////////////////////////////////////////////

local function closeContextMenu()
	if activeContextMenu then
		activeContextMenu:Destroy()
		activeContextMenu = nil
	end
end

-- Update context menu logic
function openContextMenu(chatId, anchorButton)
    closeContextMenu()
    local chatData = chats[chatId]
    if not chatData then return end
    local newMenu = contextMenuTemplate:Clone()
    newMenu.Parent = screenGui
    newMenu.Position = UDim2.new(0, anchorButton.AbsolutePosition.X, 0, anchorButton.AbsolutePosition.Y + anchorButton.AbsoluteSize.Y)
    activeContextMenu = newMenu
    newMenu:FindFirstChild("DeleteButton").MouseButton1Click:Connect(function()
        local buttonToRemove = chatData.sidebarButton
        if buttonToRemove then buttonToRemove:Destroy() end
        deleteChatEvent:FireServer(chatId)
        chats[chatId] = nil
        closeContextMenu()
        if activeChatId == chatId then createNewChat() end
    end)
end

-- Simplify updateChatButtons sorting (timestamp only)
function updateChatButtons()
    local sorted = {}
    for _, data in pairs(chats) do table.insert(sorted, data) end
    table.sort(sorted, function(a,b) return (a.timestamp or 0) > (b.timestamp or 0) end)
    for i, data in ipairs(sorted) do
        if data.sidebarButton then
            data.sidebarButton.LayoutOrder = i
            local title = data.sidebarButton:FindFirstChild("ChatTitleButton")
            if data.id == activeChatId then
                data.sidebarButton.BackgroundColor3 = colors.accent
                title.TextColor3 = colors.background
            else
                data.sidebarButton.BackgroundColor3 = colors.input
                title.TextColor3 = colors.text_muted
            end
        end
    end
end

local function createMessageLabel(text, messageType)
	local newRow   = messageTemplate:Clone()
	local newLabel = newRow:FindFirstChild("MessageLabel")

	newLabel.Text = text

	if messageType == "Player" then
		-- Сообщение игрока: фон + выравнивание вправо
		newLabel.BackgroundTransparency = 0
		newLabel.TextXAlignment = Enum.TextXAlignment.Right

		newLabel.AnchorPoint = Vector2.new(1, 0)
		newLabel.Position    = UDim2.new(1, 0, 0, 0)
	else
		-- Сообщение ИИ: без фона + "иконка"
		newLabel.Text = "💎  " .. text
		newLabel.BackgroundTransparency = 1

		newLabel.TextXAlignment = Enum.TextXAlignment.Left
		newLabel.AnchorPoint = Vector2.new(0, 0)
		newLabel.Position    = UDim2.new(0, 0, 0, 0)
	end

	newRow.Parent = messageContainer
	return newRow
end

local function displayChat(chatId)
	-- Очищаем контейнер безопасным способом
	local messagesToClear = {}
	for _, child in ipairs(messageContainer:GetChildren()) do
		if child.Name == "MessageRowFrame" then
			table.insert(messagesToClear, child)
		end
	end
	for _, msg in ipairs(messagesToClear) do
		msg:Destroy()
	end

	activeChatId = chatId
	local chatData = chats[chatId]

	-- Загружаем сообщения из истории пачками, чтобы не было фризов
	if chatData and chatData.messages then
		for i, msgData in ipairs(chatData.messages) do
			createMessageLabel(msgData.text, msgData.type)
			if i % 50 == 0 then -- Делаем паузу каждые 50 сообщений
				task.wait()
			end
		end
	end

	-- Обновляем UI один раз после всех изменений
	task.wait()
	messageContainer.CanvasSize = UDim2.new(
		0, 0,
		0, messageListLayout.AbsoluteContentSize.Y + 20
	)

	updateWelcomeVisibility()
	scrollToBottom()
	updateChatButtons()
end

local function createNewChat()
	local newId = "chat" .. nextChatId
	nextChatId += 1
	
	chats[newId] = {
		id = newId,
		messages = {},
		isSaved = false,
		sidebarButton = nil,
		timestamp = os.time()
	}
	
	displayChat(newId)
end

local function createChatHistoryButton(chatId, text)
	local chatData = chats[chatId]
	if chatData.sidebarButton then return end -- Уже создана

	local newButtonContainer = chatButtonTemplate:Clone()
	local titleButton = newButtonContainer:FindFirstChild("ChatTitleButton")
	local optionsButton = newButtonContainer:FindFirstChild("MoreOptionsButton")
	
	titleButton.Text = text
	newButtonContainer.Parent = chatHistoryContainer
	chatData.sidebarButton = newButtonContainer
	
	titleButton.MouseButton1Click:Connect(function()
		displayChat(chatId)
	end)
	
	optionsButton.MouseButton1Click:Connect(function()
		openContextMenu(chatId, newButtonContainer)
	end)

	updateChatButtons()
end

local function updateWelcomeVisibility()
	if not activeChatId or not chats[activeChatId] then
		welcomeText.Visible = true
		return
	end
	welcomeText.Visible = #chats[activeChatId].messages == 0
end

local function scrollToBottom()
	messageContainer.CanvasPosition = Vector2.new(
		0,
		math.max(0, messageContainer.CanvasSize.Y.Offset - messageContainer.AbsoluteWindowSize.Y)
	)
end

-- Создание и добавление нового сообщения
local function sendMessage()
	local text = inputBox.Text
	if text and text:gsub("%s*", "") ~= "" then
		inputBox.Text = ""
		sendButton.TextColor3 = colors.text_muted

		local currentChat = chats[activeChatId]
		if not currentChat.isSaved then
			currentChat.isSaved = true
			createChatHistoryButton(activeChatId, text)
		end
		
		table.insert(currentChat.messages, { type = "Player", text = text })
		createMessageLabel(text, "Player")
		
		task.wait()
		messageContainer.CanvasSize = UDim2.new(0, 0, 0, messageListLayout.AbsoluteContentSize.Y + 20)
		updateWelcomeVisibility()
		scrollToBottom()

		currentChat.timestamp = os.time()
		updateChatMetadataEvent:FireServer(activeChatId, { timestamp = currentChat.timestamp })
		sendMessageEvent:FireServer(activeChatId, text)
	end
end

local function onReceiveMessage(chatId, aiText)
	if chatId == activeChatId then
		local currentChat = chats[activeChatId]
		if currentChat then
			table.insert(currentChat.messages, { type = "AI", text = aiText })
			createMessageLabel(aiText, "AI")
			
			task.wait()
			messageContainer.CanvasSize = UDim2.new(0, 0, 0, messageListLayout.AbsoluteContentSize.Y + 20)
			updateWelcomeVisibility()
			scrollToBottom()
		end
	end
end

--///////////////////////////////////////////////////////////////////////////
-- ПОДКЛЮЧЕНИЕ СОБЫТИЙ
--///////////////////////////////////////////////////////////////////////////
-- Helper to check if screen pos inside gui element
local function isInside(gui, position)
    if not gui or not gui:IsA("GuiObject") then return false end
    local absPos = gui.AbsolutePosition
    local absSize = gui.AbsoluteSize
    return position.X >= absPos.X and position.X <= absPos.X + absSize.X and position.Y >= absPos.Y and position.Y <= absPos.Y + absSize.Y
end

-- adjust global click handler
UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    local clickPos = input.Position

    -- close context menu if needed
    if activeContextMenu and not isInside(activeContextMenu, clickPos) then
        closeContextMenu()
    end

    local insideSidebar = isInside(sidebar, clickPos)

    -- Expand when collapsed and click inside sidebar area (including newChatButton)
    if not isSidebarExpanded and insideSidebar then
        expandSidebar()
        return
    end

    -- Collapse when expanded and click outside sidebar
    if isSidebarExpanded and not insideSidebar and not (activeContextMenu and isInside(activeContextMenu, clickPos)) then
        collapseSidebar()
    end
end)

-- Ensure expandSidebar uses correct corner
function expandSidebar()
    TweenService:Create(sidebar, tweenInfo, {Size = expandedSidebarWidth}):Play()
    TweenService:Create(mainContent, tweenInfo, {Position = expandedMainContentPos, Size = expandedMainContentSize}):Play()
    TweenService:Create(newChatButton, tweenInfo, {Size = UDim2.new(1, 0, 0, expandedButtonHeight)}):Play()
    TweenService:Create(newChatButtonCorner, tweenInfo, {CornerRadius = UDim.new(0, 12)}):Play()
    task.wait(0.15)
    newChatButton.Text = "  +  Новый чат"
    newChatButton.TextSize = 16
    newChatButton.TextXAlignment = Enum.TextXAlignment.Left
    chatHistoryContainer.Visible = true
    isSidebarExpanded = true
end

function collapseSidebar()
    TweenService:Create(sidebar, tweenInfo, {Size = collapsedSidebarWidth}):Play()
    TweenService:Create(mainContent, tweenInfo, {Position = collapsedMainContentPos, Size = collapsedMainContentSize}):Play()
    TweenService:Create(newChatButton, tweenInfo, {Size = collapsedButtonSize}):Play()
    TweenService:Create(newChatButtonCorner, tweenInfo, {CornerRadius = UDim.new(0, 18)}):Play()
    closeContextMenu()
    chatHistoryContainer.Visible = false
    newChatButton.Text = "+"
    newChatButton.TextSize = 22
    newChatButton.TextXAlignment = Enum.TextXAlignment.Center
    isSidebarExpanded = false
end

-- Remove sidebar.InputBegan handler duplicate and newChatButton MouseButton1Click previously changed, ensure new version
sidebar.Active = false -- no need separate handler now

newChatButton.MouseButton1Click:Connect(function()
    if not isSidebarExpanded then
        expandSidebar()
    else
        createNewChat()
    end
end)

sendButton.MouseButton1Click:Connect(sendMessage)

inputBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		sendMessage()
	end
end)

-- adjust inputFrame corner radius
local frameCorner = inputFrame:FindFirstChildWhichIsA("UICorner")
if frameCorner then frameCorner.CornerRadius = UDim.new(0,24) end

-- auto-grow input field
-- adjust constants
local MIN_INPUT_HEIGHT = 40
local NORMAL_MAX_HEIGHT = 150
local EXPANDED_FIXED_HEIGHT = 350

-- reference to layout inside inputFrame
local inputLayout = inputFrame:FindFirstChildWhichIsA("UIListLayout")

-- new constants
local MAX_EXPANDED_HEIGHT = 250

local function updateInputHeight()
	local text = inputBox.Text ~= "" and inputBox.Text or inputBox.PlaceholderText
	local sizeVec = TextService:GetTextSize(text, inputBox.TextSize, inputBox.Font, Vector2.new(inputBox.AbsoluteSize.X, math.huge))
	
	local neededHeight = math.max(MIN_INPUT_HEIGHT, sizeVec.Y + 10)
	
	local isExpanded = neededHeight > NORMAL_MAX_HEIGHT
	
	local targetWrapperHeight = isExpanded and EXPANDED_FIXED_HEIGHT or (neededHeight + 20)
	
	inputWrapper.Size = UDim2.new(0.8, 0, 0, targetWrapperHeight)
	
	if isExpanded then
		inputScroll.CanvasSize = UDim2.new(1, 0, 0, sizeVec.Y + 10)
	else
		inputScroll.CanvasSize = UDim2.new(1, 0, 1, 0)
		inputBox.Size = UDim2.new(1, 0, 1, 0) -- Сбрасываем авто-размер
	end

	if inputLayout then inputLayout.VerticalAlignment = Enum.VerticalAlignment.Center end
	
	local offset = inputWrapper.Size.Y.Offset + 50
	messageContainer.Size = UDim2.new(1, 0, 1, -offset)
end

inputBox:GetPropertyChangedSignal("Text"):Connect(function()
    updateInputHeight()
    if inputBox.Text and inputBox.Text:gsub("%s*", "") ~= "" then
        sendButton.TextColor3 = colors.accent
    else
        sendButton.TextColor3 = colors.text_muted
    end
end)

-- call once
updateInputHeight()

receiveMessageEvent.OnClientEvent:Connect(onReceiveMessage)

--///////////////////////////////////////////////////////////////////////////
-- ИНИЦИАЛИЗАЦИЯ
--///////////////////////////////////////////////////////////////////////////
local function loadHistory()
	if not getChatHistoryFunction then
		warn("Не удалось найти RemoteFunction 'GetChatHistory'. Работаем в оффлайн режиме.")
		createNewChat()
		updateWelcomeVisibility()
		return
	end

	local success, result = pcall(function()
		return getChatHistoryFunction:InvokeServer()
	end)
	
	if success then
		if result then
			chats = result
			
			local hasChats = false
			local latestChatId = nil
			local latestTimestamp = 0

			for id, data in pairs(chats) do
				hasChats = true
				-- Убеждаемся, что messages существует и является таблицей
				if data.messages and type(data.messages) == "table" and #data.messages > 0 then
					data.isSaved = true
					createChatHistoryButton(id, data.messages[1].text)
					
					-- Определяем самый новый чат для отображения
					if data.timestamp and data.timestamp > latestTimestamp then
						latestTimestamp = data.timestamp
						latestChatId = id
					end
				else
					data.messages = {} -- исправляем поврежденные данные
					data.isSaved = false
					data.isPinned = data.isPinned or false
					data.timestamp = data.timestamp or 0
				end
				
				-- Обновляем nextChatId
				local num = tonumber(id:match("%d+"))
				if num and num >= nextChatId then
					nextChatId = num + 1
				end
			end
			
			if latestChatId then
				displayChat(latestChatId)
			else
				createNewChat()
			end
		else
			createNewChat()
		end
	else
		warn("Не удалось загрузить историю чата: " .. tostring(result))
		createNewChat() -- Начинаем с чистого листа
	end
	
	updateWelcomeVisibility()
end


loadHistory()
print("Клиентский скрипт (v3, с меню) загружен и готов.") 