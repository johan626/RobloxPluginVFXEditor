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

	-- Main Buttons
	ui.CreateVFXButton = Instance.new("TextButton")
	ui.CreateVFXButton.Name = "CreateNewVFXButton"
	ui.CreateVFXButton.Size = UDim2.new(0, 150, 0, 30)
	ui.CreateVFXButton.Position = UDim2.new(0, 5, 0.5, -15)
	ui.CreateVFXButton.Text = "Create New VFX"
	ui.CreateVFXButton.Parent = ui.TopBar

	ui.PlayButton = Instance.new("TextButton")
	ui.PlayButton.Name = "PlayButton"
	ui.PlayButton.Size = UDim2.new(0, 80, 0, 30)
	ui.PlayButton.Position = UDim2.new(0, 160, 0.5, -15)
	ui.PlayButton.Text = "Play"
	ui.PlayButton.Parent = ui.TopBar

	ui.StopButton = Instance.new("TextButton")
	ui.StopButton.Name = "StopButton"
	ui.StopButton.Size = UDim2.new(0, 80, 0, 30)
	ui.StopButton.Position = UDim2.new(0, 250, 0.5, -15)
	ui.StopButton.Text = "Stop"
	ui.StopButton.Parent = ui.TopBar

	ui.ExportButton = Instance.new("TextButton")
	ui.ExportButton.Name = "ExportButton"
	ui.ExportButton.Size = UDim2.new(0, 80, 0, 30)
	ui.ExportButton.Position = UDim2.new(0, 340, 0.5, -15)
	ui.ExportButton.Text = "Export"
	ui.ExportButton.Parent = ui.TopBar

	ui.SaveButton = Instance.new("TextButton")
	ui.SaveButton.Name = "SaveButton"
	ui.SaveButton.Size = UDim2.new(0, 80, 0, 30)
	ui.SaveButton.Position = UDim2.new(0, 430, 0.5, -15)
	ui.SaveButton.Text = "Save"
	ui.SaveButton.Parent = ui.TopBar

	ui.LoadButton = Instance.new("TextButton")
	ui.LoadButton.Name = "LoadButton"
	ui.LoadButton.Size = UDim2.new(0, 80, 0, 30)
	ui.LoadButton.Position = UDim2.new(0, 520, 0.5, -15)
	ui.LoadButton.Text = "Load"
	ui.LoadButton.Parent = ui.TopBar

	-- Content Area
	local contentArea = Instance.new("Frame")
	contentArea.Name = "ContentArea"
	contentArea.Size = UDim2.new(1, 0, 1, -40)
	contentArea.Position = UDim2.new(0, 0, 0, 40)
	contentArea.Parent = ui.MainFrame

	-- Main Panels
	ui.PreviewWindow = Instance.new("ViewportFrame")
	ui.PreviewWindow.Name = "PreviewWindow"
	ui.PreviewWindow.Size = UDim2.new(0.7, 0, 0.6, 0)
	ui.PreviewWindow.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	ui.PreviewWindow.Parent = contentArea

	ui.ComponentLibrary = Instance.new("Frame")
	ui.ComponentLibrary.Name = "ComponentLibrary"
	ui.ComponentLibrary.Size = UDim2.new(0.15, 0, 0.6, 0)
	ui.ComponentLibrary.Position = UDim2.new(0.7, 0, 0, 0)
	ui.ComponentLibrary.Parent = contentArea

	ui.PropertiesPanel = Instance.new("Frame")
	ui.PropertiesPanel.Name = "PropertiesPanel"
	ui.PropertiesPanel.Size = UDim2.new(0.15, 0, 0.6, 0)
	ui.PropertiesPanel.Position = UDim2.new(0.85, 0, 0, 0)
	ui.PropertiesPanel.Parent = contentArea

	ui.Timeline = Instance.new("ScrollingFrame")
	ui.Timeline.Name = "Timeline"
	ui.Timeline.Size = UDim2.new(1, 0, 0.4, 0)
	ui.Timeline.Position = UDim2.new(0, 0, 0.6, 0)
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

	return ui
end

return UIManager
