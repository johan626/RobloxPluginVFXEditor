-- UIManager.lua (ModuleScript)
-- Path: ServerScriptService/VFXEditor/UIManager.lua

local Config = require(script.Parent.Config)
local UIManager = {}

-- Fungsi Bantuan untuk Gaya UI
local function styleButton(button, isEnabled)
	if isEnabled == nil then isEnabled = true end
	local theme = Config.Theme

	button.Font = theme.Font
	button.TextSize = theme.FontSize
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = button

	if isEnabled then
		button.BackgroundColor3 = theme.Button
		button.TextColor3 = theme.Text
		button.AutoButtonColor = false
		button.MouseEnter:Connect(function() button.BackgroundColor3 = theme.ButtonHover end)
		button.MouseLeave:Connect(function() button.BackgroundColor3 = theme.Button end)
		button.MouseButton1Down:Connect(function() button.BackgroundColor3 = theme.ButtonPressed end)
		button.MouseButton1Up:Connect(function() button.BackgroundColor3 = theme.ButtonHover end)
	else
		button.BackgroundColor3 = theme.ButtonDisabled
		button.TextColor3 = theme.TextDisabled
		button.AutoButtonColor = false
	end
end

function UIManager.createUI(widget)
	local ui = {}
	local theme = Config.Theme

	-- Signals
	ui.GroupColorChanged = {}
	function ui.GroupColorChanged:Connect(callback) table.insert(self, callback) end
	function ui.GroupColorChanged:Fire(...) for _, cb in ipairs(self) do cb(...) end end

	-- Main UI Structure
	ui.MainFrame = Instance.new("Frame")
	ui.MainFrame.Name = "MainFrame"
	ui.MainFrame.Size = UDim2.new(1, 0, 1, 0)
	ui.MainFrame.BackgroundColor3 = theme.Background
	ui.MainFrame.Parent = widget

	-- Top Bar for controls
	ui.TopBar = Instance.new("Frame")
	ui.TopBar.Name = "TopBar"
	ui.TopBar.Size = UDim2.new(1, 0, 0, 36)
	ui.TopBar.BackgroundColor3 = theme.TopBar
	ui.TopBar.Parent = ui.MainFrame
	local topBarPadding = Instance.new("UIPadding")
	topBarPadding.PaddingLeft = UDim.new(0, 8)
	topBarPadding.PaddingRight = UDim.new(0, 8)
	topBarPadding.Parent = ui.TopBar

	local topBarLayout = Instance.new("UIListLayout")
	topBarLayout.FillDirection = Enum.FillDirection.Horizontal
	topBarLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	topBarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right -- Align container frames
	topBarLayout.SortOrder = Enum.SortOrder.LayoutOrder
	topBarLayout.Parent = ui.TopBar

	-- Left Aligned Buttons Container
	local leftFrame = Instance.new("Frame")
	leftFrame.Name = "LeftFrame"
	leftFrame.BackgroundTransparency = 1
	leftFrame.Size = UDim2.new(1, -368, 1, 0) -- Fill remaining space
	leftFrame.LayoutOrder = 1
	leftFrame.Parent = ui.TopBar
	local leftLayout = Instance.new("UIListLayout")
	leftLayout.FillDirection = Enum.FillDirection.Horizontal
	leftLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	leftLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	leftLayout.Padding = UDim.new(0, 6)
	leftLayout.Parent = leftFrame

	-- Center Aligned Buttons Container
	local centerFrame = Instance.new("Frame")
	centerFrame.Name = "CenterFrame"
	centerFrame.BackgroundTransparency = 1
	centerFrame.Size = UDim2.new(0, 120, 1, 0)
	centerFrame.LayoutOrder = 2
	centerFrame.Parent = ui.TopBar
	local centerLayout = Instance.new("UIListLayout")
	centerLayout.FillDirection = Enum.FillDirection.Horizontal
	centerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	centerLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	centerLayout.Padding = UDim.new(0, 6)
	centerLayout.Parent = centerFrame

	-- Right Aligned Buttons Container
	local rightFrame = Instance.new("Frame")
	rightFrame.Name = "RightFrame"
	rightFrame.BackgroundTransparency = 1
	rightFrame.Size = UDim2.new(0, 248, 1, 0)
	rightFrame.LayoutOrder = 3
	rightFrame.Parent = ui.TopBar
	local rightLayout = Instance.new("UIListLayout")
	rightLayout.FillDirection = Enum.FillDirection.Horizontal
	rightLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	rightLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	rightLayout.Padding = UDim.new(0, 6)
	rightLayout.Parent = rightFrame

	-- Shared Button Size
	local BTN_HEIGHT = 28

	-- Undo/Redo Buttons (Left Frame)
	ui.UndoButton = Instance.new("TextButton")
	ui.UndoButton.Name = "UndoButton"; ui.UndoButton.Size = UDim2.new(0, 60, 0, BTN_HEIGHT); ui.UndoButton.Text = "Undo"; ui.UndoButton.Parent = leftFrame
	styleButton(ui.UndoButton, false); ui.UndoButton.Active = false

	ui.RedoButton = Instance.new("TextButton")
	ui.RedoButton.Name = "RedoButton"; ui.RedoButton.Size = UDim2.new(0, 60, 0, BTN_HEIGHT); ui.RedoButton.Text = "Redo"; ui.RedoButton.Parent = leftFrame
	styleButton(ui.RedoButton, false); ui.RedoButton.Active = false

	ui.CreateVFXButton = Instance.new("TextButton")
	ui.CreateVFXButton.Name = "CreateNewVFXButton"; ui.CreateVFXButton.Size = UDim2.new(0, 120, 0, BTN_HEIGHT); ui.CreateVFXButton.Text = "Create New VFX"; ui.CreateVFXButton.Parent = leftFrame
	styleButton(ui.CreateVFXButton)

	-- Play/Stop Buttons (Center Frame)
	ui.PlayButton = Instance.new("TextButton")
	ui.PlayButton.Name = "PlayButton"; ui.PlayButton.Size = UDim2.new(0, 50, 0, BTN_HEIGHT); ui.PlayButton.Text = "Play"; ui.PlayButton.Parent = centerFrame
	styleButton(ui.PlayButton)

	ui.StopButton = Instance.new("TextButton")
	ui.StopButton.Name = "StopButton"; ui.StopButton.Size = UDim2.new(0, 50, 0, BTN_HEIGHT); ui.StopButton.Text = "Stop"; ui.StopButton.Parent = centerFrame
	styleButton(ui.StopButton)

	-- Save/Load/Export Buttons (Right Frame)
	ui.SaveButton = Instance.new("TextButton")
	ui.SaveButton.Name = "SaveButton"; ui.SaveButton.Size = UDim2.new(0, 50, 0, BTN_HEIGHT); ui.SaveButton.Text = "Save"; ui.SaveButton.Parent = rightFrame
	styleButton(ui.SaveButton)

	ui.LoadButton = Instance.new("TextButton")
	ui.LoadButton.Name = "LoadButton"; ui.LoadButton.Size = UDim2.new(0, 50, 0, BTN_HEIGHT); ui.LoadButton.Text = "Load"; ui.LoadButton.Parent = rightFrame
	styleButton(ui.LoadButton, false); ui.LoadButton.Active = false

	ui.ExportButton = Instance.new("TextButton")
	ui.ExportButton.Name = "ExportButton"; ui.ExportButton.Size = UDim2.new(0, 60, 0, BTN_HEIGHT); ui.ExportButton.Text = "Export"; ui.ExportButton.Parent = rightFrame
	styleButton(ui.ExportButton)

	ui.ClearAllButton = Instance.new("TextButton")
	ui.ClearAllButton.Name = "ClearAllButton"; ui.ClearAllButton.Size = UDim2.new(0, 70, 0, BTN_HEIGHT); ui.ClearAllButton.Text = "Clear All"; ui.ClearAllButton.Parent = rightFrame
	styleButton(ui.ClearAllButton); ui.ClearAllButton.BackgroundColor3 = theme.AccentDestructive

	-- Content Area & Panels
	local contentArea = Instance.new("Frame")
	contentArea.Name = "ContentArea"; contentArea.Size = UDim2.new(1, 0, 1, -36); contentArea.Position = UDim2.new(0, 0, 0, 36); contentArea.Parent = ui.MainFrame

	-- New Component Library Panel (Left)
	ui.ComponentLibrary = Instance.new("ScrollingFrame")
	ui.ComponentLibrary.Name = "ComponentLibrary"; ui.ComponentLibrary.Size = UDim2.new(0.15, 0, 1, 0); ui.ComponentLibrary.Position = UDim2.new(0, 0, 0, 0); ui.ComponentLibrary.BackgroundColor3 = theme.ComponentLibrary; ui.ComponentLibrary.BorderSizePixel = 0; ui.ComponentLibrary.ScrollBarThickness = 8; ui.ComponentLibrary.ScrollBarImageColor3 = theme.ButtonAccent; ui.ComponentLibrary.Parent = contentArea
	local libPadding = Instance.new("UIPadding"); libPadding.PaddingLeft = UDim.new(0, 8); libPadding.PaddingRight = UDim.new(0, 8); libPadding.PaddingTop = UDim.new(0, 8); libPadding.PaddingBottom = UDim.new(0, 8); libPadding.Parent = ui.ComponentLibrary
	local libLayout = Instance.new("UIListLayout"); libLayout.Padding = UDim.new(0, 5); libLayout.SortOrder = Enum.SortOrder.LayoutOrder; libLayout.Parent = ui.ComponentLibrary

	-- Timeline Panel (Center)
	ui.Timeline = Instance.new("ScrollingFrame")
	ui.Timeline.Name = "Timeline"; ui.Timeline.Size = UDim2.new(0.65, 0, 1, 0); ui.Timeline.Position = UDim2.new(0.15, 0, 0, 0); ui.Timeline.BackgroundColor3 = theme.Timeline; ui.Timeline.CanvasSize = UDim2.new(5, 0, 1, 0); ui.Timeline.ScrollBarThickness = 8; ui.Timeline.Parent = contentArea

	-- Properties Panel (Right)
	ui.PropertiesPanel = Instance.new("ScrollingFrame")
	ui.PropertiesPanel.Name = "PropertiesPanel"; ui.PropertiesPanel.Size = UDim2.new(0.2, 0, 1, 0); ui.PropertiesPanel.Position = UDim2.new(0.8, 0, 0, 0); ui.PropertiesPanel.BackgroundColor3 = theme.Properties; ui.PropertiesPanel.BorderSizePixel = 0; ui.PropertiesPanel.ScrollBarThickness = 8; ui.PropertiesPanel.ScrollBarImageColor3 = theme.ButtonAccent; ui.PropertiesPanel.Parent = contentArea
	local propsPadding = Instance.new("UIPadding"); propsPadding.PaddingLeft = UDim.new(0, 8); propsPadding.PaddingRight = UDim.new(0, 8); propsPadding.PaddingTop = UDim.new(0, 8); propsPadding.PaddingBottom = UDim.new(0, 8); propsPadding.Parent = ui.PropertiesPanel

	-- Populate Component Library
	local componentCategories = {
		{Name = "Lights", Items = {"Light", "SpotLight", "SurfaceLight"}},
		{Name = "Emitters", Items = {"Particle", "Beam", "Trail"}},
		{Name = "Audio", Items = {"Sound"}},
		{Name = "Presets", Items = {"Fire", "Smoke", "Explosion"}, Preset = true}
	}

	for _, category in ipairs(componentCategories) do
		local header = Instance.new("TextLabel")
		header.LayoutOrder = #ui.ComponentLibrary:GetChildren()
		header.Size = UDim2.new(1, 0, 0, 20)
		header.Text = category.Name
		header.BackgroundColor3 = theme.ButtonAccent
		header.TextColor3 = theme.Text
		header.Font = Enum.Font.SourceSansBold
		header.TextXAlignment = Enum.TextXAlignment.Left
		header.Parent = ui.ComponentLibrary

		for _, itemName in ipairs(category.Items) do
			local button = Instance.new("TextButton")
			button.Name = "ComponentDraggable"
			button.LayoutOrder = #ui.ComponentLibrary:GetChildren()
			button.Size = UDim2.new(1, 0, 0, 28)
			button.Text = "  " .. itemName
			button:SetAttribute("ComponentType", itemName)
			button:SetAttribute("IsPreset", category.Preset or false)
			button.Parent = ui.ComponentLibrary
			styleButton(button)
		end
	end

	ui.ConfirmationDialog = Instance.new("Frame")
	ui.ConfirmationDialog.Name = "ConfirmationDialog"; ui.ConfirmationDialog.Size = UDim2.new(1, 0, 1, 0); ui.ConfirmationDialog.Position = UDim2.new(0, 0, 0, 0); ui.ConfirmationDialog.BackgroundColor3 = Color3.fromRGB(0, 0, 0); ui.ConfirmationDialog.BackgroundTransparency = 0.5; ui.ConfirmationDialog.Visible = false; ui.ConfirmationDialog.ZIndex = 10; ui.ConfirmationDialog.Parent = ui.MainFrame
	local dialog = Instance.new("Frame"); dialog.Name = "Dialog"; dialog.Size = UDim2.new(0, 400, 0, 150); dialog.Position = UDim2.new(0.5, -200, 0.5, -75); dialog.BackgroundColor3 = theme.TopBar; dialog.Parent = ui.ConfirmationDialog
	local dialogCorner = Instance.new("UICorner"); dialogCorner.CornerRadius = UDim.new(0, 4); dialogCorner.Parent = dialog
	ui.DialogTitle = Instance.new("TextLabel"); ui.DialogTitle.Name = "Title"; ui.DialogTitle.Size = UDim2.new(1, 0, 0, 40); ui.DialogTitle.Text = "Confirm Action"; ui.DialogTitle.TextColor3 = theme.Text; ui.DialogTitle.Font = Enum.Font.SourceSansBold; ui.DialogTitle.TextSize = 16; ui.DialogTitle.BackgroundColor3 = theme.Background; ui.DialogTitle.Parent = dialog
	ui.DialogMessage = Instance.new("TextLabel"); ui.DialogMessage.Name = "Message"; ui.DialogMessage.Size = UDim2.new(1, -20, 0, 60); ui.DialogMessage.Position = UDim2.new(0, 10, 0, 40); ui.DialogMessage.Text = "Are you sure?"; ui.DialogMessage.TextColor3 = theme.Text; ui.DialogMessage.TextWrapped = true; ui.DialogMessage.BackgroundTransparency = 1; ui.DialogMessage.Parent = dialog
	ui.ConfirmButton = Instance.new("TextButton"); ui.ConfirmButton.Name = "ConfirmButton"; ui.ConfirmButton.Size = UDim2.new(0, 100, 0, 30); ui.ConfirmButton.Position = UDim2.new(0.5, -110, 1, -40); ui.ConfirmButton.Text = "Confirm"; ui.ConfirmButton.Parent = dialog; styleButton(ui.ConfirmButton)
	ui.CancelButton = Instance.new("TextButton"); ui.CancelButton.Name = "CancelButton"; ui.CancelButton.Size = UDim2.new(0, 100, 0, 30); ui.CancelButton.Position = UDim2.new(0.5, 10, 1, -40); ui.CancelButton.Text = "Cancel"; ui.CancelButton.Parent = dialog; styleButton(ui.CancelButton)

	-- Context Menu
	ui.ContextMenu = Instance.new("Frame"); ui.ContextMenu.Name = "ContextMenu"; ui.ContextMenu.Size = UDim2.new(0, 150, 0, 90); ui.ContextMenu.BackgroundColor3 = theme.TopBar; ui.ContextMenu.BorderSizePixel = 1; ui.ContextMenu.BorderColor3 = theme.Background; ui.ContextMenu.Visible = false; ui.ContextMenu.ZIndex = 20; ui.ContextMenu.Parent = ui.MainFrame
	local contextCorner = Instance.new("UICorner"); contextCorner.CornerRadius = UDim.new(0, 4); contextCorner.Parent = ui.ContextMenu
	local contextLayout = Instance.new("UIListLayout"); contextLayout.Padding = UDim.new(0, 4); contextLayout.SortOrder = Enum.SortOrder.LayoutOrder; contextLayout.Parent = ui.ContextMenu
	local contextPadding = Instance.new("UIPadding"); contextPadding.PaddingLeft = UDim.new(0, 4); contextPadding.PaddingRight = UDim.new(0, 4); contextPadding.PaddingTop = UDim.new(0, 4); contextPadding.PaddingBottom = UDim.new(0, 4); contextPadding.Parent = ui.ContextMenu

	ui.CopyButton = Instance.new("TextButton"); ui.CopyButton.Name = "CopyButton"; ui.CopyButton.LayoutOrder = 1; ui.CopyButton.Size = UDim2.new(1, 0, 0, 28); ui.CopyButton.Text = "Copy"; ui.CopyButton.Parent = ui.ContextMenu; styleButton(ui.CopyButton)
	ui.PasteButton = Instance.new("TextButton"); ui.PasteButton.Name = "PasteButton"; ui.PasteButton.LayoutOrder = 2; ui.PasteButton.Size = UDim2.new(1, 0, 0, 28); ui.PasteButton.Text = "Paste"; ui.PasteButton.Parent = ui.ContextMenu; styleButton(ui.PasteButton)
	ui.SetGroupColorButton = Instance.new("TextButton"); ui.SetGroupColorButton.Name = "SetGroupColorButton"; ui.SetGroupColorButton.LayoutOrder = 3; ui.SetGroupColorButton.Size = UDim2.new(1, 0, 0, 28); ui.SetGroupColorButton.Text = "Set Group Color  >"; ui.SetGroupColorButton.Parent = ui.ContextMenu; styleButton(ui.SetGroupColorButton)

	-- Sub-menu for group colors
	ui.GroupColorSubMenu = Instance.new("Frame")
	ui.GroupColorSubMenu.Name = "GroupColorSubMenu"
	ui.GroupColorSubMenu.Size = UDim2.new(0, 150, 0, 120)
	ui.GroupColorSubMenu.Position = UDim2.new(1, 2, 0, 0)
	ui.GroupColorSubMenu.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
	ui.GroupColorSubMenu.BorderSizePixel = 1
	ui.GroupColorSubMenu.BorderColor3 = Color3.fromRGB(100,100,100)
	ui.GroupColorSubMenu.Visible = false
	ui.GroupColorSubMenu.ZIndex = 21
	ui.GroupColorSubMenu.Parent = ui.ContextMenu
	local groupColorCorner = Instance.new("UICorner"); groupColorCorner.CornerRadius = UDim.new(0, 4); groupColorCorner.Parent = ui.GroupColorSubMenu
	local colorGridLayout = Instance.new("UIGridLayout")
	colorGridLayout.CellPadding = UDim2.new(0, 4, 0, 4)
	colorGridLayout.CellSize = UDim2.new(0, 24, 0, 24)
	colorGridLayout.Parent = ui.GroupColorSubMenu

	ui.GroupColorButtons = {}
	for colorName, colorValue in pairs(Config.GroupColors) do
		local button = Instance.new("TextButton")
		button.Name = colorName .. "ColorButton"
		button.Size = UDim2.new(0, 24, 0, 24)
		button.BackgroundColor3 = colorValue
		button.Text = ""
		button.Parent = ui.GroupColorSubMenu
		local corner = Instance.new("UICorner"); corner.Parent = button

		button.MouseButton1Click:Connect(function()
			ui.GroupColorChanged:Fire(colorValue)
			ui.ContextMenu.Visible = false
		end)
		ui.GroupColorButtons[colorName] = button
	end

	-- Logic to show/hide the sub-menus with debounce
	local activeSubMenu = nil
	local hideSubMenuTask = nil
	local function cancelHide()
		if hideSubMenuTask then
			task.cancel(hideSubMenuTask)
			hideSubMenuTask = nil
		end
	end
	local function scheduleHide()
		cancelHide()
		hideSubMenuTask = task.delay(0.1, function()
			if activeSubMenu then
				activeSubMenu.Visible = false
				activeSubMenu = nil
			end
			hideSubMenuTask = nil
		end)
	end

	local function showSubMenu(subMenu)
		cancelHide()
		if activeSubMenu and activeSubMenu ~= subMenu then
			activeSubMenu.Visible = false
		end
		activeSubMenu = subMenu
		activeSubMenu.Visible = true
	end

	ui.SetGroupColorButton.MouseEnter:Connect(function() showSubMenu(ui.GroupColorSubMenu) end)
	ui.GroupColorSubMenu.MouseEnter:Connect(cancelHide)

	ui.ContextMenu.MouseLeave:Connect(scheduleHide)

	ui.CopyButton.MouseEnter:Connect(function() if activeSubMenu then activeSubMenu.Visible = false; activeSubMenu=nil end end)
	ui.PasteButton.MouseEnter:Connect(function() if activeSubMenu then activeSubMenu.Visible = false; activeSubMenu=nil end end)

	return ui
end

return UIManager
