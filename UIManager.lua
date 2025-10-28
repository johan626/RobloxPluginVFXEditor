-- UIManager.lua (ModuleScript)
-- Path: ServerScriptService/VFXEditor/UIManager.lua

local UIStyler = require(script.Parent.UIStyler)

local UIManager = {}

function UIManager.createUI(widget)
	local ui = {}

	-- Main UI Structure
	ui.MainFrame = Instance.new("Frame")
	ui.MainFrame.Name = "MainFrame"
	ui.MainFrame.Size = UDim2.new(1, 0, 1, 0)
	UIStyler.styleFrame(ui.MainFrame, "DefaultFrame")
	ui.MainFrame.Parent = widget

	-- Top Bar for controls
	ui.TopBar = Instance.new("Frame")
	ui.TopBar.Name = "TopBar"
	ui.TopBar.Size = UDim2.new(1, 0, 0, 50)
	UIStyler.stylePanel(ui.TopBar, "DefaultPanel") -- Use Panel style for a border
	ui.TopBar.Parent = ui.MainFrame

	local topBarLayout = Instance.new("UIListLayout")
	topBarLayout.FillDirection = Enum.FillDirection.Horizontal
	topBarLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	topBarLayout.Padding = UDim.new(0, 10)
	topBarLayout.Parent = ui.TopBar

	local topBarPadding = Instance.new("UIPadding")
	topBarPadding.PaddingLeft = UDim.new(0, 10)
	topBarPadding.Parent = ui.TopBar

	-- Main Buttons
	ui.CreateVFXButton = Instance.new("TextButton")
	ui.CreateVFXButton.Name = "CreateNewVFXButton"
	ui.CreateVFXButton.Size = UDim2.new(0, 150, 1, -18)
	ui.CreateVFXButton.Text = "Create New VFX"
	UIStyler.styleButton(ui.CreateVFXButton, "DefaultButton")
	ui.CreateVFXButton.Parent = ui.TopBar

	ui.PlayButton = Instance.new("TextButton")
	ui.PlayButton.Name = "PlayButton"
	ui.PlayButton.Size = UDim2.new(0, 80, 1, -18)
	ui.PlayButton.Text = "Play"
	UIStyler.styleButton(ui.PlayButton, "DefaultButton")
	ui.PlayButton.Parent = ui.TopBar

	ui.StopButton = Instance.new("TextButton")
	ui.StopButton.Name = "StopButton"
	ui.StopButton.Size = UDim2.new(0, 80, 1, -18)
	ui.StopButton.Text = "Stop"
	UIStyler.styleButton(ui.StopButton, "DefaultButton")
	ui.StopButton.Parent = ui.TopBar

	ui.ExportButton = Instance.new("TextButton")
	ui.ExportButton.Name = "ExportButton"
	ui.ExportButton.Size = UDim2.new(0, 80, 1, -18)
	ui.ExportButton.Text = "Export"
	UIStyler.styleButton(ui.ExportButton, "PrimaryButton")
	ui.ExportButton.Parent = ui.TopBar

	-- Content Area
	local contentArea = Instance.new("Frame")
	contentArea.Name = "ContentArea"
	contentArea.Size = UDim2.new(1, 0, 1, -50)
	contentArea.Position = UDim2.new(0, 0, 0, 50)
	contentArea.BackgroundTransparency = 1
	contentArea.Parent = ui.MainFrame

	local contentPadding = Instance.new("UIPadding")
	contentPadding.PaddingTop = UDim.new(0, 10)
	contentPadding.PaddingBottom = UDim.new(0, 10)
	contentPadding.PaddingLeft = UDim.new(0, 10)
	contentPadding.PaddingRight = UDim.new(0, 10)
	contentPadding.Parent = contentArea

	-- Main Panels
	ui.PreviewWindow = Instance.new("ViewportFrame")
	ui.PreviewWindow.Name = "PreviewWindow"
	ui.PreviewWindow.Size = UDim2.new(0.7, -5, 0.6, -5) -- Add spacing
	UIStyler.stylePanel(ui.PreviewWindow, "DefaultPanel")
	ui.PreviewWindow.Parent = contentArea

	ui.ComponentLibrary = Instance.new("Frame")
	ui.ComponentLibrary.Name = "ComponentLibrary"
	ui.ComponentLibrary.Size = UDim2.new(0.15, -5, 0.6, -5)
	ui.ComponentLibrary.Position = UDim2.new(0.7, 5, 0, 0)
	UIStyler.stylePanel(ui.ComponentLibrary, "DefaultPanel")
	ui.ComponentLibrary.Parent = contentArea

	ui.PropertiesPanel = Instance.new("Frame")
	ui.PropertiesPanel.Name = "PropertiesPanel"
	ui.PropertiesPanel.Size = UDim2.new(0.15, 0, 0.6, -5)
	ui.PropertiesPanel.Position = UDim2.new(0.85, 5, 0, 0)
	UIStyler.stylePanel(ui.PropertiesPanel, "DefaultPanel")
	ui.PropertiesPanel.Parent = contentArea

	local propsPadding = Instance.new("UIPadding")
	propsPadding.PaddingTop = UDim.new(0, 10)
	propsPadding.PaddingBottom = UDim.new(0, 10)
	propsPadding.PaddingLeft = UDim.new(0, 10)
	propsPadding.PaddingRight = UDim.new(0, 10)
	propsPadding.Parent = ui.PropertiesPanel

	ui.Timeline = Instance.new("ScrollingFrame")
	ui.Timeline.Name = "Timeline"
	ui.Timeline.Size = UDim2.new(1, 0, 0.4, 0)
	ui.Timeline.Position = UDim2.new(0, 0, 0.6, 5)
	ui.Timeline.BackgroundColor3 = Color3.fromRGB(35, 35, 35) -- Overriding panel style for darker look
	UIStyler.stylePanel(ui.Timeline, "DefaultPanel")
	ui.Timeline.CanvasSize = UDim2.new(5, 0, 1, 0)
	ui.Timeline.ScrollBarThickness = 8
	ui.Timeline.Parent = contentArea

	local componentLayout = Instance.new("UIListLayout")
	componentLayout.Padding = UDim.new(0, 5)
	componentLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	componentLayout.Parent = ui.ComponentLibrary

	local componentPadding = Instance.new("UIPadding")
	componentPadding.PaddingTop = UDim.new(0, 10)
	componentPadding.PaddingBottom = UDim.new(0, 10)
	componentPadding.PaddingLeft = UDim.new(0, 10)
	componentPadding.PaddingRight = UDim.new(0, 10)
	componentPadding.Parent = ui.ComponentLibrary

	-- Component Library Buttons
	ui.AddLightButton = Instance.new("TextButton")
	ui.AddLightButton.Name = "AddLightButton"
	ui.AddLightButton.Size = UDim2.new(1, -20, 0, 32)
	ui.AddLightButton.Text = "+ Light"
	UIStyler.styleButton(ui.AddLightButton, "DefaultButton")
	ui.AddLightButton.Parent = ui.ComponentLibrary

	ui.AddSoundButton = Instance.new("TextButton")
	ui.AddSoundButton.Name = "AddSoundButton"
	ui.AddSoundButton.Size = UDim2.new(1, -20, 0, 32)
	ui.AddSoundButton.Text = "+ Sound"
	UIStyler.styleButton(ui.AddSoundButton, "DefaultButton")
	ui.AddSoundButton.Parent = ui.ComponentLibrary

	return ui
end

return UIManager
