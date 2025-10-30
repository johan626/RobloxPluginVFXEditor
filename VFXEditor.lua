-- VFXEditor.lua (Main Plugin Script) (Script)
-- Path: ServerScriptService/VFXEditor.lua

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Selection = game:GetService("Selection")
local UserInputService = game:GetService("UserInputService")

-- Load Modules
local UIManager = require(script.VFXEditorPlugin.UIManager)
local TimelineManager = require(script.VFXEditorPlugin.TimelineManager)
local PropertiesManager = require(script.VFXEditorPlugin.PropertiesManager)
local PreviewManager = require(script.VFXEditorPlugin.PreviewManager)
local Exporter = require(script.VFXEditorPlugin.Exporter)
local DataManager = require(script.VFXEditorPlugin.DataManager)
local HistoryManager = require(script.VFXEditorPlugin.HistoryManager)
local Config = require(script.VFXEditorPlugin.Config)

-- Plugin Initialization
local toolbar = plugin:CreateToolbar("VFX Editor")
local newScriptButton = toolbar:CreateButton("Open VFX Editor", "Open VFX Editor", "")
local widgetInfo = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, true, false, 800, 600, 600, 400)
local vfxEditorWidget = plugin:CreateDockWidgetPluginGui("VFXEditor", widgetInfo)
vfxEditorWidget.Title = "VFX Timeline Editor"

-- Create UI and Managers
local ui = UIManager.createUI(vfxEditorWidget)
local historyManager = HistoryManager.new()

-- Decoupled Initialization to prevent circular dependency
local previewManager = PreviewManager.new(ui)
local timelineManager = TimelineManager.new(ui, previewManager, historyManager)
previewManager:setTimelineManager(timelineManager) -- Now inject the dependency

local dataManager = DataManager.new(plugin, timelineManager)

-- State for confirmation dialog
local onConfirmAction = nil

-- Function to show the confirmation dialog
local function showConfirmation(title, message, onConfirm)
	ui.DialogTitle.Text = title
	ui.DialogMessage.Text = message
	onConfirmAction = onConfirm
	ui.ConfirmationDialog.Visible = true
	ui.ConfirmButton.BackgroundColor3 = (title == "Confirm Reset") and Config.Theme.AccentDestructive or Config.Theme.Accent
end

-- Function to update Undo/Redo button states
local function updateHistoryButtons()
	local theme = Config.Theme
	if #historyManager.undoStack > 0 then
		ui.UndoButton.Active = true; ui.UndoButton.AutoButtonColor = true; ui.UndoButton.BackgroundColor3 = theme.Button; ui.UndoButton.TextColor3 = theme.Text
	else
		ui.UndoButton.Active = false; ui.UndoButton.AutoButtonColor = false; ui.UndoButton.BackgroundColor3 = theme.ButtonDisabled; ui.UndoButton.TextColor3 = theme.TextDisabled
	end
	if #historyManager.redoStack > 0 then
		ui.RedoButton.Active = true; ui.RedoButton.AutoButtonColor = true; ui.RedoButton.BackgroundColor3 = theme.Button; ui.RedoButton.TextColor3 = theme.Text
	else
		ui.RedoButton.Active = false; ui.RedoButton.AutoButtonColor = false; ui.RedoButton.BackgroundColor3 = theme.ButtonDisabled; ui.RedoButton.TextColor3 = theme.TextDisabled
	end
end

-- Connect Modules and UI
historyManager.HistoryChanged:Connect(updateHistoryButtons)

timelineManager.TrackSelected:Connect(function(selectedTracks)
	PropertiesManager.populate(ui.PropertiesPanel, selectedTracks, timelineManager)
end)

timelineManager.TrackDeleted:Connect(function()
	PropertiesManager.clear(ui.PropertiesPanel)
end)

-- Top Bar Button Connections
ui.UndoButton.MouseButton1Click:Connect(function() historyManager:undo() end)
ui.RedoButton.MouseButton1Click:Connect(function() historyManager:redo() end)

ui.CreateVFXButton.MouseButton1Click:Connect(function()
	local vfxContainer = Instance.new("Folder"); vfxContainer.Name = "NewVFX"
	local config = Instance.new("Folder"); config.Name = "Configuration"; config.Parent = vfxContainer
	local assets = Instance.new("Folder"); assets.Name = "Assets"; assets.Parent = vfxContainer
	vfxContainer.Parent = ReplicatedStorage
	Selection:Set({vfxContainer})
end)

ui.ExportButton.MouseButton1Click:Connect(function()
	local selected = Selection:Get()
	if selected and #selected > 0 then Exporter.export(timelineManager.timeline, selected[1]) else warn("Please select a VFX Container to export to.") end
end)

ui.SaveButton.MouseButton1Click:Connect(function()
	if dataManager:saveTimeline() then
		if not ui.LoadButton.Active then
			ui.LoadButton.Active = true; ui.LoadButton.AutoButtonColor = true; ui.LoadButton.BackgroundColor3 = Config.Theme.Button; ui.LoadButton.TextColor3 = Config.Theme.Text
		end
	end
end)

ui.LoadButton.MouseButton1Click:Connect(function()
	showConfirmation("Confirm Load", "Are you sure you want to load the saved project? Any unsaved changes will be lost.", function()
		local tracksData = dataManager:loadTimeline()
		if tracksData then timelineManager:clearTimeline(); for _, trackData in ipairs(tracksData) do timelineManager:_createTrackUI(trackData) end end
	end)
end)

ui.ResetButton.MouseButton1Click:Connect(function()
	showConfirmation("Confirm Reset", "Are you sure you want to reset the entire timeline? This cannot be undone.", function()
		timelineManager:clearTimeline()
	end)
end)

ui.ConfirmButton.MouseButton1Click:Connect(function() if onConfirmAction then onConfirmAction() end; ui.ConfirmationDialog.Visible = false; onConfirmAction = nil end)
ui.CancelButton.MouseButton1Click:Connect(function() ui.ConfirmationDialog.Visible = false; onConfirmAction = nil end)

-- Keyboard Shortcuts
UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
	if gameProcessedEvent then return end
	local isCtrlDown = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
	if isCtrlDown then
		if input.KeyCode == Enum.KeyCode.Z then historyManager:undo()
		elseif input.KeyCode == Enum.KeyCode.Y then historyManager:redo()
		elseif input.KeyCode == Enum.KeyCode.C then timelineManager:copySelectedTracks()
		elseif input.KeyCode == Enum.KeyCode.V then
			local zoomedPixelsPerSecond = timelineManager.PIXELS_PER_SECOND * timelineManager.zoom
			local playheadTime = timelineManager.playhead.Position.X.Offset / zoomedPixelsPerSecond
			timelineManager:pasteTracksAtTime(playheadTime)
		end
	end
end)

-- Check for existing data on startup
if dataManager:hasSavedData() then
	ui.LoadButton.Active = true; ui.LoadButton.AutoButtonColor = true; ui.LoadButton.BackgroundColor3 = Config.Theme.Button; ui.LoadButton.TextColor3 = Config.Theme.Text
end

-- Toggle Widget Visibility
newScriptButton.Click:Connect(function() vfxEditorWidget.Enabled = not vfxEditorWidget.Enabled end)

print("VFX Editor Plugin (Modular with History) Loaded")
