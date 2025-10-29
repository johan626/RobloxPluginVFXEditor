-- UIManager.lua (ModuleScript)
-- Path: ServerScriptService/VFXEditor/UIManager.lua

local UIManager = {}

function UIManager.createUI(widget)
	local ui = {}

	-- Main UI Structure
	ui.MainFrame = Instance.new("Frame")
	ui.MainFrame.Name = "MainFrame"
	ui.MainFrame.Size = UDim2.new(1, 0, 1, 0)
	ui.MainFrame.BackgroundColor3 = Color3.fromRGB(31, 31, 31)
	ui.MainFrame.Parent = widget

	-- Top Bar for controls
	ui.TopBar = Instance.new("Frame")
	ui.TopBar.Name = "TopBar"
	ui.TopBar.Size = UDim2.new(1, 0, 0, 40)
	ui.TopBar.BackgroundColor3 = Color3.fromRGB(41, 41, 41)
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

	ui.CreateVFXButton = Instance.new("TextButton")
	ui.CreateVFXButton.Name = "CreateNewVFXButton"
	ui.CreateVFXButton.Size = UDim2.new(0, 150, 0, 30)
	ui.CreateVFXButton.Text = "Create New VFX"
	ui.CreateVFXButton.Parent = leftFrame

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

	ui.StopButton = Instance.new("TextButton")
	ui.StopButton.Name = "StopButton"
	ui.StopButton.Size = UDim2.new(0, 80, 0, 30)
	ui.StopButton.Text = "Stop"
	ui.StopButton.Parent = centerFrame

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

	ui.LoadButton = Instance.new("TextButton")
	ui.LoadButton.Name = "LoadButton"
	ui.LoadButton.Size = UDim2.new(0, 80, 0, 30)
	ui.LoadButton.Text = "Load"
	ui.LoadButton.Parent = rightFrame

	ui.ExportButton = Instance.new("TextButton")
	ui.ExportButton.Name = "ExportButton"
	ui.ExportButton.Size = UDim2.new(0, 80, 0, 30)
	ui.ExportButton.Text = "Export"
	ui.ExportButton.Parent = rightFrame

	ui.ResetButton = Instance.new("TextButton")
	ui.ResetButton.Name = "ResetButton"
	ui.ResetButton.Size = UDim2.new(0, 80, 0, 30)
	ui.ResetButton.Text = "Reset"
	ui.ResetButton.Parent = rightFrame

	-- Content Area
	local contentArea = Instance.new("Frame")
	contentArea.Name = "ContentArea"
	contentArea.Size = UDim2.new(1, 0, 1, -40)
	contentArea.Position = UDim2.new(0, 0, 0, 40)
	contentArea.Parent = ui.MainFrame

	-- Main Panels

	ui.ComponentLibrary = Instance.new("Frame")
	ui.ComponentLibrary.Name = "ComponentLibrary"
	ui.ComponentLibrary.Size = UDim2.new(0.15, 0, 1, 0)
	ui.ComponentLibrary.Position = UDim2.new(0, 0, 0, 0)
	ui.ComponentLibrary.Parent = contentArea

	ui.PropertiesPanel = Instance.new("Frame")
	ui.PropertiesPanel.Name = "PropertiesPanel"
	ui.PropertiesPanel.Size = UDim2.new(0.15, 0, 1, 0)
	ui.PropertiesPanel.Position = UDim2.new(0.85, 0, 0, 0)
	ui.PropertiesPanel.Parent = contentArea

	ui.Timeline = Instance.new("ScrollingFrame")
	ui.Timeline.Name = "Timeline"
	ui.Timeline.Size = UDim2.new(0.7, 0, 1, 0)
	ui.Timeline.Position = UDim2.new(0.15, 0, 0, 0)
	ui.Timeline.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
	ui.Timeline.CanvasSize = UDim2.new(5, 0, 1, 0)
	ui.Timeline.ScrollBarThickness = 6
	ui.Timeline.Parent = contentArea

	-- Component Library Buttons
	ui.AddLightButton = Instance.new("TextButton")
	ui.AddLightButton.Name = "AddLightButton"
	ui.AddLightButton.Size = UDim2.new(1, -10, 0, 30)
	ui.AddLightButton.Position = UDim2.new(0.5, -ui.AddLightButton.Size.X.Offset/2, 0, 10)
	ui.AddLightButton.Text = "+ Light"
	ui.AddLightButton.Parent = ui.ComponentLibrary

	ui.AddSoundButton = Instance.new("TextButton")
	ui.AddSoundButton.Name = "AddSoundButton"
	ui.AddSoundButton.Size = UDim2.new(1, -10, 0, 30)
	ui.AddSoundButton.Position = UDim2.new(0.5, -ui.AddSoundButton.Size.X.Offset/2, 0, 50)
	ui.AddSoundButton.Text = "+ Sound"
	ui.AddSoundButton.Parent = ui.ComponentLibrary

	ui.AddParticleButton = Instance.new("TextButton")
	ui.AddParticleButton.Name = "AddParticleButton"
	ui.AddParticleButton.Size = UDim2.new(1, -10, 0, 30)
	ui.AddParticleButton.Position = UDim2.new(0.5, -ui.AddParticleButton.Size.X.Offset/2, 0, 90)
	ui.AddParticleButton.Text = "+ Particle"
	ui.AddParticleButton.Parent = ui.ComponentLibrary

	ui.AddSpotLightButton = Instance.new("TextButton")
	ui.AddSpotLightButton.Name = "AddSpotLightButton"
	ui.AddSpotLightButton.Size = UDim2.new(1, -10, 0, 30)
	ui.AddSpotLightButton.Position = UDim2.new(0.5, -ui.AddSpotLightButton.Size.X.Offset/2, 0, 130)
	ui.AddSpotLightButton.Text = "+ SpotLight"
	ui.AddSpotLightButton.Parent = ui.ComponentLibrary

	ui.AddSurfaceLightButton = Instance.new("TextButton")
	ui.AddSurfaceLightButton.Name = "AddSurfaceLightButton"
	ui.AddSurfaceLightButton.Size = UDim2.new(1, -10, 0, 30)
	ui.AddSurfaceLightButton.Position = UDim2.new(0.5, -ui.AddSurfaceLightButton.Size.X.Offset/2, 0, 170)
	ui.AddSurfaceLightButton.Text = "+ SurfaceLight"
	ui.AddSurfaceLightButton.Parent = ui.ComponentLibrary

	ui.AddBeamButton = Instance.new("TextButton")
	ui.AddBeamButton.Name = "AddBeamButton"
	ui.AddBeamButton.Size = UDim2.new(1, -10, 0, 30)
	ui.AddBeamButton.Position = UDim2.new(0.5, -ui.AddBeamButton.Size.X.Offset/2, 0, 210)
	ui.AddBeamButton.Text = "+ Beam"
	ui.AddBeamButton.Parent = ui.ComponentLibrary

	ui.AddTrailButton = Instance.new("TextButton")
	ui.AddTrailButton.Name = "AddTrailButton"
	ui.AddTrailButton.Size = UDim2.new(1, -10, 0, 30)
	ui.AddTrailButton.Position = UDim2.new(0.5, -ui.AddTrailButton.Size.X.Offset/2, 0, 250)
	ui.AddTrailButton.Text = "+ Trail"
	ui.AddTrailButton.Parent = ui.ComponentLibrary

	-- Confirmation Dialog
	ui.ConfirmationDialog = Instance.new("Frame")
	ui.ConfirmationDialog.Name = "ConfirmationDialog"
	ui.ConfirmationDialog.Size = UDim2.new(1, 0, 1, 0)
	ui.ConfirmationDialog.Position = UDim2.new(0, 0, 0, 0)
	ui.ConfirmationDialog.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	ui.ConfirmationDialog.BackgroundTransparency = 0.5
	ui.ConfirmationDialog.Visible = false
	ui.ConfirmationDialog.ZIndex = 10
	ui.ConfirmationDialog.Parent = ui.MainFrame

	local dialog = Instance.new("Frame")
	dialog.Name = "Dialog"
	dialog.Size = UDim2.new(0, 400, 0, 150)
	dialog.Position = UDim2.new(0.5, -200, 0.5, -75)
	dialog.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
	dialog.Parent = ui.ConfirmationDialog

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 40)
	title.Text = "Confirm Reset"
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	title.Parent = dialog

	local message = Instance.new("TextLabel")
	message.Name = "Message"
	message.Size = UDim2.new(1, -20, 0, 60)
	message.Position = UDim2.new(0, 10, 0, 40)
	message.Text = "Are you sure you want to reset the timeline? All unsaved work will be lost."
	message.TextColor3 = Color3.fromRGB(220, 220, 220)
	message.TextWrapped = true
	message.BackgroundTransparency = 1
	message.Parent = dialog

	ui.ConfirmButton = Instance.new("TextButton")
	ui.ConfirmButton.Name = "ConfirmButton"
	ui.ConfirmButton.Size = UDim2.new(0, 100, 0, 30)
	ui.ConfirmButton.Position = UDim2.new(0.5, -110, 1, -40)
	ui.ConfirmButton.Text = "Confirm"
	ui.ConfirmButton.Parent = dialog

	ui.CancelButton = Instance.new("TextButton")
	ui.CancelButton.Name = "CancelButton"
	ui.CancelButton.Size = UDim2.new(0, 100, 0, 30)
	ui.CancelButton.Position = UDim2.new(0.5, 10, 1, -40)
	ui.CancelButton.Text = "Cancel"
	ui.CancelButton.Parent = dialog

	-- Context Menu
	ui.ContextMenu = Instance.new("Frame")
	ui.ContextMenu.Name = "ContextMenu"
	ui.ContextMenu.Size = UDim2.new(0, 120, 0, 60)
	ui.ContextMenu.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
	ui.ContextMenu.BorderSizePixel = 1
	ui.ContextMenu.BorderColor3 = Color3.fromRGB(100,100,100)
	ui.ContextMenu.Visible = false
	ui.ContextMenu.ZIndex = 20
	ui.ContextMenu.Parent = ui.MainFrame

	local contextLayout = Instance.new("UIListLayout")
	contextLayout.Padding = UDim.new(0, 2)
	contextLayout.Parent = ui.ContextMenu

	ui.CopyButton = Instance.new("TextButton")
	ui.CopyButton.Name = "CopyButton"
	ui.CopyButton.Size = UDim2.new(1, -4, 0, 28)
	ui.CopyButton.Text = "Copy"
	ui.CopyButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
	ui.CopyButton.TextColor3 = Color3.fromRGB(220, 220, 220)
	ui.CopyButton.Parent = ui.ContextMenu

	ui.PasteButton = Instance.new("TextButton")
	ui.PasteButton.Name = "PasteButton"
	ui.PasteButton.Size = UDim2.new(1, -4, 0, 28)
	ui.PasteButton.Text = "Paste"
	ui.PasteButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
	ui.PasteButton.TextColor3 = Color3.fromRGB(220, 220, 220)
	ui.PasteButton.Parent = ui.ContextMenu

	return ui
end

return UIManager
