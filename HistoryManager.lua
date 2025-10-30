-- HistoryManager.lua (ModuleScript)
-- Path: ServerScriptService/VFXEditor/HistoryManager.lua
-- Manages the undo/redo command stack for the editor.

local HistoryManager = {}
HistoryManager.__index = HistoryManager

local MAX_HISTORY_SIZE = 50 -- Limits the number of undoable actions

function HistoryManager.new()
	local self = setmetatable({}, HistoryManager)

	self.undoStack = {}
	self.redoStack = {}

	-- Signal to notify UI about history changes
	self.HistoryChanged = {}
	function self.HistoryChanged:Connect(callback) table.insert(self, callback) end
	function self.HistoryChanged:Fire(...) for _, cb in ipairs(self) do cb(...) end end

	return self
end

--[[
	Registers and executes an action.
	An action is a table with 'execute' and 'undo' functions.
	- execute(): Performs the action.
	- undo(): Reverts the action.
]]
function HistoryManager:registerAction(action)
	-- Execute the action for the first time
	action:execute()

	-- Add it to the undo stack
	table.insert(self.undoStack, action)

	-- Trim the undo stack if it exceeds the max size
	if #self.undoStack > MAX_HISTORY_SIZE then
		table.remove(self.undoStack, 1)
	end

	-- Clear the redo stack, as a new action invalidates the old redo path
	self.redoStack = {}

	-- Fire signal to update UI (e.g., enable/disable undo/redo buttons)
	self.HistoryChanged:Fire(self)
end

function HistoryManager:undo()
	if #self.undoStack == 0 then
		print("Nothing to undo.")
		return
	end

	-- Move the action from the undo stack to the redo stack
	local action = table.remove(self.undoStack)
	table.insert(self.redoStack, action)

	-- Perform the undo
	action:undo()

	self.HistoryChanged:Fire(self)
end

function HistoryManager:redo()
	if #self.redoStack == 0 then
		print("Nothing to redo.")
		return
	end

	-- Move the action from the redo stack back to the undo stack
	local action = table.remove(self.redoStack)
	table.insert(self.undoStack, action)

	-- Re-execute the action
	action:execute()

	self.HistoryChanged:Fire(self)
end

return HistoryManager
