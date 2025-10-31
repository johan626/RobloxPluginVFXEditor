-- VFXEditor.lua (Main Plugin Script) (Script)
-- Path: ServerScriptService/VFXEditor.lua

if not plugin then
	warn("This script is intended to be run as a Roblox Studio plugin.")
	return
end

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
local ComponentDragger = require(script.VFXEditorPlugin.ComponentDragger)

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
local timelineManager = TimelineManager.new(ui, previewManager.playhead, historyManager) -- Pass the playhead UI object, not the manager
previewManager:setTimelineManager(timelineManager) -- Now inject the dependency

local dataManager = DataManager.new(plugin, timelineManager, ui) -- Pass UI to DataManager
local componentDragger = ComponentDragger.new(ui)

-- Connection tracking for global inputs
local userInputConnection = nil

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

-- Connect the new drag-and-drop component creation
componentDragger.ComponentDropped:Connect(function(componentType, isPreset, mousePos)
	local timeline = ui.Timeline
	local relativeX = mousePos.X - timeline.AbsolutePosition.X + timeline.CanvasPosition.X
	local dropTime = relativeX / (timelineManager.PIXELS_PER_SECOND * timelineManager.zoom)

	if isPreset then
		timelineManager:createTrackFromPreset(componentType, dropTime)
	else
		local trackData = {
			ComponentType = componentType,
			StartTime = dropTime,
			Duration = 1 -- Default duration
		}
		timelineManager:addDefaultAttributes(trackData)
		timelineManager:createTracks({trackData})
	end
end)


-- From right-click context menu
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
	dataManager:loadTimeline(function(tracksData)
		if tracksData then
			timelineManager:clearTimeline()
			for _, trackData in ipairs(tracksData) do
				-- This is a private method, but it's the only way to bypass history for loading
				timelineManager:_createTrackUI(trackData)
			end
		end
	end)
end)

-- The ClearAll button logic is now inside TimelineManager's connectEvents

-- Keyboard Shortcuts Handler
local function onInputBegan(input, gameProcessedEvent)
	if not vfxEditorWidget.Enabled or gameProcessedEvent then return end

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
end

-- Check for existing data on startup
if dataManager:hasSavedData() then
	ui.LoadButton.Active = true; ui.LoadButton.AutoButtonColor = true; ui.LoadButton.BackgroundColor3 = Config.Theme.Button; ui.LoadButton.TextColor3 = Config.Theme.Text
end

-- Toggle Widget Visibility and connect/disconnect global inputs
vfxEditorWidget:GetPropertyChangedSignal("Enabled"):Connect(function()
	if vfxEditorWidget.Enabled then
		if not userInputConnection then
			userInputConnection = UserInputService.InputBegan:Connect(onInputBegan)
		end
	else
		if userInputConnection then
			userInputConnection:Disconnect()
			userInputConnection = nil
		end
	end
end)

-- Initial connection if widget is already enabled
if vfxEditorWidget.Enabled then
	userInputConnection = UserInputService.InputBegan:Connect(onInputBegan)
end


newScriptButton.Click:Connect(function() vfxEditorWidget.Enabled = not vfxEditorWidget.Enabled end)

print("VFX Editor Plugin (Modular with History) Loaded")
