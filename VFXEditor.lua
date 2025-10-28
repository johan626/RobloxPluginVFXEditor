-- VFXEditor.lua (Main Plugin Script) (Script)
-- Path: ServerScriptService/VFXEditor.lua

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Selection = game:GetService("Selection")

-- Load Modules
local UIManager = require(script.VFXEditorPlugin.UIManager)
local TimelineManager = require(script.VFXEditorPlugin.TimelineManager)
local PropertiesManager = require(script.VFXEditorPlugin.PropertiesManager)
local PreviewManager = require(script.VFXEditorPlugin.PreviewManager)
local Exporter = require(script.VFXEditorPlugin.Exporter)

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
local timelineManager = TimelineManager.new(ui)
local previewManager = PreviewManager.new(ui, ui.Timeline)

-- Connect Modules
timelineManager.TrackSelected:Connect(function(track)
	PropertiesManager.populate(ui.PropertiesPanel, track)
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

-- Toggle Widget Visibility
newScriptButton.Click:Connect(function()
	vfxEditorWidget.Enabled = not vfxEditorWidget.Enabled
end)

print("VFX Editor Plugin (Modular) Loaded")
