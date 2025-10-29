-- VFXEditor.lua (Main Plugin Script) (Script)
-- Path: ServerScriptService/VFXEditor.lua

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Selection = game:GetService("Selection")

-- Load Modules (All modules are siblings to this script)
local UIManager = require(script.VFXEditorPlugin.UIManager)
local TimelineManager = require(script.VFXEditorPlugin.TimelineManager)
local PropertiesManager = require(script.VFXEditorPlugin.PropertiesManager)
local PreviewManager = require(script.VFXEditorPlugin.PreviewManager)
local Exporter = require(script.VFXEditorPlugin.Exporter)
local DataManager = require(script.VFXEditorPlugin.DataManager)

-- Plugin Initialization
local toolbar = plugin:CreateToolbar("VFX Editor")
local newScriptButton = toolbar:CreateButton("Open VFX Editor", "Open VFX Editor", "")

local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Float, true, false, 800, 600, 600, 400
)
local vfxEditorWidget = plugin:CreateDockWidgetPluginGui("VFXEditor", widgetInfo)
vfxEditorWidget.Title = "VFX Timeline Editor"

-- Create UI and Managers
local ui = UIManager.createUI(vfxEditorWidget)
local previewManager = PreviewManager.new(ui, ui.Timeline)
local timelineManager = TimelineManager.new(ui, previewManager.playhead)
local dataManager = DataManager.new(timelineManager)

-- Connect Modules
timelineManager.TrackSelected:Connect(function(track)
	PropertiesManager.populate(ui.PropertiesPanel, track, timelineManager)
end)

timelineManager.TrackDeleted:Connect(function()
	PropertiesManager.clear(ui.PropertiesPanel)
end)

ui.CreateVFXButton.MouseButton1Click:Connect(function()
	-- Logic to create VFX container
	local vfxContainer = Instance.new("Folder")
	vfxContainer.Name = "NewVFX"
	local config = Instance.new("Folder")
	config.Name = "Configuration"
	config.Parent = vfxContainer
	local assets = Instance.new("Folder")
	assets.Name = "Assets"
	assets.Parent = vfxContainer
	vfxContainer.Parent = ReplicatedStorage
	Selection:Set({vfxContainer})
end)

ui.ExportButton.MouseButton1Click:Connect(function()
	local selected = Selection:Get()[1]
	Exporter.export(ui.Timeline, selected)
end)

ui.SaveButton.MouseButton1Click:Connect(function()
	dataManager:saveProject(plugin)
end)

ui.LoadButton.MouseButton1Click:Connect(function()
	dataManager:loadProject(plugin)
end)

ui.ResetButton.MouseButton1Click:Connect(function()
	ui.ConfirmationDialog.Visible = true
end)

ui.ConfirmButton.MouseButton1Click:Connect(function()
	timelineManager:clearTimeline()
	ui.ConfirmationDialog.Visible = false
end)

ui.CancelButton.MouseButton1Click:Connect(function()
	ui.ConfirmationDialog.Visible = false
end)

-- Toggle Widget Visibility
newScriptButton.Click:Connect(function()
	vfxEditorWidget.Enabled = not vfxEditorWidget.Enabled
end)

print("VFX Editor Plugin (Modular) Loaded")
