-- UIManager.lua (ModuleScript)
-- Path: ServerScriptService/VFXEditor/UIManager.lua

local Config = require(script.Parent.Config)
local UIManager = {}

-- Fungsi Bantuan untuk Gaya UI
local function styleButton(button)
	local theme = Config.Theme
	button.BackgroundColor3 = theme.Button
	button.TextColor3 = theme.Text
	button.Font = theme.Font
	button.TextSize = theme.FontSize
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = button

	button.MouseEnter:Connect(function()
		button.BackgroundColor3 = theme.ButtonHover
	end)
	button.MouseLeave:Connect(function()
		button.BackgroundColor3 = theme.Button
	end)
	button.MouseButton1Down:Connect(function()
		button.BackgroundColor3 = theme.ButtonPressed
	end)
	button.MouseButton1Up:Connect(function()
		button.BackgroundColor3 = theme.ButtonHover
	end)
end


-- Fungsi bantuan baru untuk membuat baris tombol komponen
local function createComponentButton(parent, name, yPos)
	local theme = Config.Theme
	local ui = {}
	local rowFrame = Instance.new("Frame")
	rowFrame.Size = UDim2.new(1, -10, 0, 30)
	rowFrame.Position = UDim2.new(0.5, -rowFrame.Size.X.Offset/2, 0, yPos)
	rowFrame.BackgroundTransparency = 1
	rowFrame.Parent = parent
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.Parent = rowFrame
	ui.DrawButton = Instance.new("TextButton")
	ui.DrawButton.Name = "Draw" .. name .. "Button"
	ui.DrawButton.Size = UDim2.new(1, -34, 1, 0)
	ui.DrawButton.Text = "+ " .. name
	ui.DrawButton.Parent = rowFrame
	styleButton(ui.DrawButton)
	ui.AddAtPlayheadButton = Instance.new("TextButton")
	ui.AddAtPlayheadButton.Name = "Add" .. name .. "AtPlayheadButton"
	ui.AddAtPlayheadButton.Size = UDim2.new(0, 30, 1, 0)
	ui.AddAtPlayheadButton.Text = "+>"
	ui.AddAtPlayheadButton.Parent = rowFrame
	styleButton(ui.AddAtPlayheadButton)
	return ui
end


function UIManager.createUI(widget)
	local ui = {}
	local theme = Config.Theme

	-- Signals
	ui.CreateTrackRequested = {}
	function ui.CreateTrackRequested:Connect(callback) table.insert(self, callback) end
	function ui.CreateTrackRequested:Fire(...) for _, cb in ipairs(self) do cb(...) end end

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
	ui.TopBar.Size = UDim2.new(1, 0, 0, 40)
	ui.TopBar.BackgroundColor3 = theme.TopBar
	ui.TopBar.Parent = ui.MainFrame

	local topBarLayout = Instance.new("UIListLayout")
	topBarLayout.FillDirection = Enum.FillDirection.Horizontal
	topBarLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	topBarLayout.Padding = UDim.new(0, 5)
	topBarLayout.Parent = ui.TopBar

	-- Left Aligned Buttons
	local leftFrame = Instance.new("Frame")
	leftFrame.BackgroundTransparency = 1
	leftFrame.Size = UDim2.new(0.33, 0, 1, 0)
	leftFrame.Parent = ui.TopBar
	local leftLayout = Instance.new("UIListLayout")
	leftLayout.FillDirection = Enum.FillDirection.Horizontal
	leftLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
	leftLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	leftLayout.Padding = UDim.new(0, 5)
	leftLayout.Parent = leftFrame

	-- Undo/Redo Buttons
	ui.UndoButton = Instance.new("TextButton")
	ui.UndoButton.Name = "UndoButton"
	ui.UndoButton.Size = UDim2.new(0, 70, 0, 30)
	ui.UndoButton.Text = "Undo"
	ui.UndoButton.Parent = leftFrame
	styleButton(ui.UndoButton)
	ui.UndoButton.AutoButtonColor = false
	ui.UndoButton.BackgroundColor3 = theme.ButtonDisabled
	ui.UndoButton.TextColor3 = theme.TextDisabled
	ui.UndoButton.Active = false

	ui.RedoButton = Instance.new("TextButton")
	ui.RedoButton.Name = "RedoButton"
	ui.RedoButton.Size = UDim2.new(0, 70, 0, 30)
	ui.RedoButton.Text = "Redo"
	ui.RedoButton.Parent = leftFrame
	styleButton(ui.RedoButton)
	ui.RedoButton.AutoButtonColor = false
	ui.RedoButton.BackgroundColor3 = theme.ButtonDisabled
	ui.RedoButton.TextColor3 = theme.TextDisabled
	ui.RedoButton.Active = false

	ui.CreateVFXButton = Instance.new("TextButton")
	ui.CreateVFXButton.Name = "CreateNewVFXButton"
	ui.CreateVFXButton.Size = UDim2.new(0, 150, 0, 30)
	ui.CreateVFXButton.Text = "Create New VFX"
	ui.CreateVFXButton.Parent = leftFrame
	styleButton(ui.CreateVFXButton)

	-- Center Aligned Buttons
	local centerFrame = Instance.new("Frame")
	centerFrame.BackgroundTransparency = 1
	centerFrame.Size = UDim2.new(0.33, 0, 1, 0)
	centerFrame.Parent = ui.TopBar
	local centerLayout = Instance.new("UIListLayout")
	centerLayout.FillDirection = Enum.FillDirection.Horizontal
	centerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	centerLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	centerLayout.Padding = UDim.new(0, 5)
	centerLayout.Parent = centerFrame

	ui.PlayButton = Instance.new("TextButton")
	ui.PlayButton.Name = "PlayButton"
	ui.PlayButton.Size = UDim2.new(0, 80, 0, 30)
	ui.PlayButton.Text = "Play"
	ui.PlayButton.Parent = centerFrame
	styleButton(ui.PlayButton)

	ui.StopButton = Instance.new("TextButton")
	ui.StopButton.Name = "StopButton"
	ui.StopButton.Size = UDim2.new(0, 80, 0, 30)
	ui.StopButton.Text = "Stop"
	ui.StopButton.Parent = centerFrame
	styleButton(ui.StopButton)

	-- Right Aligned Buttons
	local rightFrame = Instance.new("Frame")
	rightFrame.BackgroundTransparency = 1
	rightFrame.Size = UDim2.new(0.33, 0, 1, 0)
	rightFrame.Parent = ui.TopBar
	local rightLayout = Instance.new("UIListLayout")
	rightLayout.FillDirection = Enum.FillDirection.Horizontal
	rightLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	rightLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	rightLayout.Padding = UDim.new(0, 5)
	rightLayout.Parent = rightFrame

	ui.SaveButton = Instance.new("TextButton")
	ui.SaveButton.Name = "SaveButton"
	ui.SaveButton.Size = UDim2.new(0, 80, 0, 30)
	ui.SaveButton.Text = "Save"
	ui.SaveButton.Parent = rightFrame
	styleButton(ui.SaveButton)

	ui.LoadButton = Instance.new("TextButton")
	ui.LoadButton.Name = "LoadButton"
	ui.LoadButton.Size = UDim2.new(0, 80, 0, 30)
	ui.LoadButton.Text = "Load"
	ui.LoadButton.Parent = rightFrame
	styleButton(ui.LoadButton)
	ui.LoadButton.AutoButtonColor = false
	ui.LoadButton.BackgroundColor3 = theme.ButtonDisabled
	ui.LoadButton.TextColor3 = theme.TextDisabled
	ui.LoadButton.Active = false

	ui.ExportButton = Instance.new("TextButton")
	ui.ExportButton.Name = "ExportButton"
	ui.ExportButton.Size = UDim2.new(0, 80, 0, 30)
	ui.ExportButton.Text = "Export"
	ui.ExportButton.Parent = rightFrame
	styleButton(ui.ExportButton)

	ui.ResetButton = Instance.new("TextButton")
	ui.ResetButton.Name = "ResetButton"
	ui.ResetButton.Size = UDim2.new(0, 80, 0, 30)
	ui.ResetButton.Text = "Reset"
	ui.ResetButton.Parent = rightFrame
	styleButton(ui.ResetButton)
	ui.ResetButton.BackgroundColor3 = theme.AccentDestructive

	-- Content Area & Panels
	local contentArea = Instance.new("Frame")
	contentArea.Name = "ContentArea"; contentArea.Size = UDim2.new(1, 0, 1, -40); contentArea.Position = UDim2.new(0, 0, 0, 40); contentArea.Parent = ui.MainFrame
	ui.ComponentLibrary = Instance.new("Frame")
	ui.ComponentLibrary.Name = "ComponentLibrary"; ui.ComponentLibrary.Size = UDim2.new(0.15, 0, 1, 0); ui.ComponentLibrary.Position = UDim2.new(0, 0, 0, 0); ui.ComponentLibrary.BackgroundColor3 = theme.ComponentLibrary; ui.ComponentLibrary.Parent = contentArea
	ui.PropertiesPanel = Instance.new("ScrollingFrame")
	ui.PropertiesPanel.Name = "PropertiesPanel"; ui.PropertiesPanel.Size = UDim2.new(0.15, 0, 1, 0); ui.PropertiesPanel.Position = UDim2.new(0.85, 0, 0, 0); ui.PropertiesPanel.BackgroundColor3 = theme.Properties; ui.PropertiesPanel.BorderSizePixel = 0; ui.PropertiesPanel.ScrollBarThickness = 6; ui.PropertiesPanel.ScrollBarImageColor3 = theme.ButtonAccent; ui.PropertiesPanel.Parent = contentArea
	local padding = Instance.new("UIPadding"); padding.PaddingTop = UDim.new(0, 5); padding.PaddingLeft = UDim.new(0, 5); padding.Parent = ui.PropertiesPanel
	ui.Timeline = Instance.new("ScrollingFrame")
	ui.Timeline.Name = "Timeline"; ui.Timeline.Size = UDim2.new(0.7, 0, 1, 0); ui.Timeline.Position = UDim2.new(0.15, 0, 0, 0); ui.Timeline.BackgroundColor3 = theme.Timeline; ui.Timeline.CanvasSize = UDim2.new(5, 0, 1, 0); ui.Timeline.ScrollBarThickness = 6; ui.Timeline.Parent = contentArea
	ui.LightButtons = createComponentButton(ui.ComponentLibrary, "Light", 10)
	ui.SoundButtons = createComponentButton(ui.ComponentLibrary, "Sound", 50)
	ui.ParticleButtons = createComponentButton(ui.ComponentLibrary, "Particle", 90)
	ui.SpotLightButtons = createComponentButton(ui.ComponentLibrary, "SpotLight", 130)
	ui.SurfaceLightButtons = createComponentButton(ui.ComponentLibrary, "SurfaceLight", 170)
	ui.BeamButtons = createComponentButton(ui.ComponentLibrary, "Beam", 210)
	ui.TrailButtons = createComponentButton(ui.ComponentLibrary, "Trail", 250)
	ui.ConfirmationDialog = Instance.new("Frame")
	ui.ConfirmationDialog.Name = "ConfirmationDialog"; ui.ConfirmationDialog.Size = UDim2.new(1, 0, 1, 0); ui.ConfirmationDialog.Position = UDim2.new(0, 0, 0, 0); ui.ConfirmationDialog.BackgroundColor3 = Color3.fromRGB(0, 0, 0); ui.ConfirmationDialog.BackgroundTransparency = 0.5; ui.ConfirmationDialog.Visible = false; ui.ConfirmationDialog.ZIndex = 10; ui.ConfirmationDialog.Parent = ui.MainFrame
	local dialog = Instance.new("Frame"); dialog.Name = "Dialog"; dialog.Size = UDim2.new(0, 400, 0, 150); dialog.Position = UDim2.new(0.5, -200, 0.5, -75); dialog.BackgroundColor3 = Color3.fromRGB(50, 50, 50); dialog.Parent = ui.ConfirmationDialog
	ui.DialogTitle = Instance.new("TextLabel"); ui.DialogTitle.Name = "Title"; ui.DialogTitle.Size = UDim2.new(1, 0, 0, 40); ui.DialogTitle.Text = "Confirm Action"; ui.DialogTitle.TextColor3 = Color3.fromRGB(255, 255, 255); ui.DialogTitle.BackgroundColor3 = Color3.fromRGB(60, 60, 60); ui.DialogTitle.Parent = dialog
	ui.DialogMessage = Instance.new("TextLabel"); ui.DialogMessage.Name = "Message"; ui.DialogMessage.Size = UDim2.new(1, -20, 0, 60); ui.DialogMessage.Position = UDim2.new(0, 10, 0, 40); ui.DialogMessage.Text = "Are you sure?"; ui.DialogMessage.TextColor3 = Color3.fromRGB(220, 220, 220); ui.DialogMessage.TextWrapped = true; ui.DialogMessage.BackgroundTransparency = 1; ui.DialogMessage.Parent = dialog
	ui.ConfirmButton = Instance.new("TextButton"); ui.ConfirmButton.Name = "ConfirmButton"; ui.ConfirmButton.Size = UDim2.new(0, 100, 0, 30); ui.ConfirmButton.Position = UDim2.new(0.5, -110, 1, -40); ui.ConfirmButton.Text = "Confirm"; ui.ConfirmButton.Parent = dialog; styleButton(ui.ConfirmButton)
	ui.CancelButton = Instance.new("TextButton"); ui.CancelButton.Name = "CancelButton"; ui.CancelButton.Size = UDim2.new(0, 100, 0, 30); ui.CancelButton.Position = UDim2.new(0.5, 10, 1, -40); ui.CancelButton.Text = "Cancel"; ui.CancelButton.Parent = dialog; styleButton(ui.CancelButton)

	-- Context Menu
	ui.ContextMenu = Instance.new("Frame"); ui.ContextMenu.Name = "ContextMenu"; ui.ContextMenu.Size = UDim2.new(0, 150, 0, 90); ui.ContextMenu.BackgroundColor3 = Color3.fromRGB(45, 45, 45); ui.ContextMenu.BorderSizePixel = 1; ui.ContextMenu.BorderColor3 = Color3.fromRGB(100,100,100); ui.ContextMenu.Visible = false; ui.ContextMenu.ZIndex = 20; ui.ContextMenu.Parent = ui.MainFrame
	local contextLayout = Instance.new("UIListLayout"); contextLayout.Padding = UDim.new(0, 2); contextLayout.SortOrder = Enum.SortOrder.LayoutOrder; contextLayout.Parent = ui.ContextMenu

	ui.CreateTrackButton = Instance.new("TextButton"); ui.CreateTrackButton.Name = "CreateTrackButton"; ui.CreateTrackButton.LayoutOrder = 1; ui.CreateTrackButton.Size = UDim2.new(1, -4, 0, 28); ui.CreateTrackButton.Text = "Create New Track  >"; ui.CreateTrackButton.Parent = ui.ContextMenu; styleButton(ui.CreateTrackButton)
	ui.CopyButton = Instance.new("TextButton"); ui.CopyButton.Name = "CopyButton"; ui.CopyButton.LayoutOrder = 2; ui.CopyButton.Size = UDim2.new(1, -4, 0, 28); ui.CopyButton.Text = "Copy"; ui.CopyButton.Parent = ui.ContextMenu; styleButton(ui.CopyButton)
	ui.PasteButton = Instance.new("TextButton"); ui.PasteButton.Name = "PasteButton"; ui.PasteButton.LayoutOrder = 3; ui.PasteButton.Size = UDim2.new(1, -4, 0, 28); ui.PasteButton.Text = "Paste"; ui.PasteButton.Parent = ui.ContextMenu; styleButton(ui.PasteButton)
	ui.SetGroupColorButton = Instance.new("TextButton"); ui.SetGroupColorButton.Name = "SetGroupColorButton"; ui.SetGroupColorButton.LayoutOrder = 4; ui.SetGroupColorButton.Size = UDim2.new(1, -4, 0, 28); ui.SetGroupColorButton.Text = "Set Group Color  >"; ui.SetGroupColorButton.Parent = ui.ContextMenu; styleButton(ui.SetGroupColorButton)

	-- Sub-menu for creating tracks
	ui.CreateTrackSubMenu = Instance.new("ScrollingFrame")
	ui.CreateTrackSubMenu.Name = "CreateTrackSubMenu"
	ui.CreateTrackSubMenu.Size = UDim2.new(0, 150, 0, 220)
	ui.CreateTrackSubMenu.Position = UDim2.new(1, 2, 0, 0)
	ui.CreateTrackSubMenu.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
	ui.CreateTrackSubMenu.BorderSizePixel = 1
	ui.CreateTrackSubMenu.BorderColor3 = Color3.fromRGB(100,100,100)
	ui.CreateTrackSubMenu.Visible = false
	ui.CreateTrackSubMenu.ZIndex = 21
	ui.CreateTrackSubMenu.Parent = ui.ContextMenu
	local subMenuLayout = Instance.new("UIListLayout"); subMenuLayout.Padding = UDim.new(0, 2); subMenuLayout.Parent = ui.CreateTrackSubMenu

	ui.CreateTrackButtons = {}
	local componentTypes = {}
	for componentType, _ in pairs(Config.TrackColors) do
		table.insert(componentTypes, componentType)
	end
	table.sort(componentTypes)

	for _, componentType in ipairs(componentTypes) do
		local button = Instance.new("TextButton")
		button.Name = componentType .. "TrackButton"
		button.Size = UDim2.new(1, -4, 0, 28)
		button.Text = componentType
		button.Parent = ui.CreateTrackSubMenu
		styleButton(button)
		ui.CreateTrackButtons[componentType] = button

		button.MouseButton1Click:Connect(function()
			ui.CreateTrackRequested:Fire(componentType)
			ui.ContextMenu.Visible = false
		end)
	end

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

	ui.CreateTrackButton.MouseEnter:Connect(function() showSubMenu(ui.CreateTrackSubMenu) end)
	ui.SetGroupColorButton.MouseEnter:Connect(function() showSubMenu(ui.GroupColorSubMenu) end)
	ui.CreateTrackSubMenu.MouseEnter:Connect(cancelHide)
	ui.GroupColorSubMenu.MouseEnter:Connect(cancelHide)

	ui.ContextMenu.MouseLeave:Connect(scheduleHide)

	ui.CopyButton.MouseEnter:Connect(function() if activeSubMenu then activeSubMenu.Visible = false; activeSubMenu=nil end end)
	ui.PasteButton.MouseEnter:Connect(function() if activeSubMenu then activeSubMenu.Visible = false; activeSubMenu=nil end end)

	return ui
end

return UIManager
