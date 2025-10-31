-- TrackInteractor.lua (ModuleScript)
-- Handles all user input and interaction with individual tracks on the timeline.

local Config = require(script.Parent.Config)
local UserInputService = game:GetService("UserInputService")

local TrackInteractor = {}
TrackInteractor.__index = TrackInteractor

function TrackInteractor.new(timelineManager, ui, playhead, historyManager)
	local self = setmetatable({}, TrackInteractor)

	self.timelineManager = timelineManager
	self.ui = ui
	self.timeline = ui.Timeline
	self.playhead = playhead
	self.historyManager = historyManager

	-- Constants from timelineManager
	self.DOUBLE_CLICK_SPEED = 0.25
	self.PLAYHEAD_SNAP_DISTANCE = 10
	self.SNAP_INTERVAL = 0.1
	self.PIXELS_PER_SECOND = 200
	self.TRACK_HEIGHT = 20
	self.LANE_PADDING = 5

	self.lastClickTime = 0
	self.lastClickedTrack = nil

	return self
end

function TrackInteractor:makeTrackInteractive(track)
	local tm = self.timelineManager -- Alias for easier access

	local outline = Instance.new("UIStroke"); outline.Name = "SelectionOutline"; outline.Color = Color3.fromRGB(255, 255, 0); outline.Thickness = 2; outline.Enabled = false; outline.Parent = track
	local trackLabel = track:FindFirstChild("TrackLabel")
	local lockButton = track:FindFirstChild("LockButton")
	local muteButton = track:FindFirstChild("MuteButton")
	local soloButton = track:FindFirstChild("SoloButton")

	lockButton.MouseButton1Click:Connect(function()
		local isLocked = not track:GetAttribute("IsLocked")
		tm:setTrackLockState({track}, isLocked)
	end)

	muteButton.MouseButton1Click:Connect(function()
		tm:_toggleMute(track)
	end)

	soloButton.MouseButton1Click:Connect(function()
		tm:_toggleSolo(track)
	end)

	track.MouseButton1Down:Connect(function()
		-- Allow selection of locked tracks, but nothing else.
		local isLocked = track:GetAttribute("IsLocked")
		if isLocked then
			tm:deselectAllTracks()
			tm:addTrackToSelection(track)
			tm.TrackSelected:Fire(tm.selectedTracks)
			return
		end

		self.ui.ContextMenu.Visible = false
		local currentTime = tick()

		if (currentTime - self.lastClickTime) < self.DOUBLE_CLICK_SPEED and self.lastClickedTrack == track then
			-- Double click detected
			self.lastClickTime = 0 -- Reset to prevent triple-click

			local editBox = Instance.new("TextBox")
			editBox.Size = UDim2.new(1, 0, 1, 0)
			editBox.Position = UDim2.new(0, 0, 0, 0)
			editBox.BackgroundColor3 = Config.Theme.Background
			editBox.TextColor3 = Config.Theme.Text
			editBox.Font = Config.Theme.Font
			editBox.Text = trackLabel.Text
			editBox.TextXAlignment = Enum.TextXAlignment.Left
			editBox.Parent = trackLabel
			editBox:CaptureFocus()

			editBox.FocusLost:Connect(function(enterPressed)
				if enterPressed then
					tm:setTrackLabel(track, editBox.Text)
				end
				editBox:Destroy()
			end)
			return -- End early to not trigger selection
		end

		self.lastClickTime = currentTime
		self.lastClickedTrack = track

		local isCtrlDown = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
		if isCtrlDown then
			if tm.selectedTracks[track] then tm:removeTrackFromSelection(track) else tm:addTrackToSelection(track) end
		else
			if not tm.selectedTracks[track] then tm:deselectAllTracks(); tm:addTrackToSelection(track) end
		end
		tm.TrackSelected:Fire(tm.selectedTracks)
	end)

	track.MouseButton2Down:Connect(function(x, y)
		if track:GetAttribute("IsLocked") then return end
		if not tm.selectedTracks[track] then tm:deselectAllTracks(); tm:addTrackToSelection(track); tm.TrackSelected:Fire(tm.selectedTracks) end
		local relativeMouseX = x - self.timeline.AbsolutePosition.X + self.timeline.CanvasPosition.X
		tm.pasteTime = relativeMouseX / (self.PIXELS_PER_SECOND * tm.zoom)
		tm:showContextMenu(x, y, {showCopy = true, showPaste = tm.copiedTracksData ~= nil, showCreate = true})
	end)

	local dragging, dragStart, originalStates = false, 0, {}
	local dragMode = nil -- "Horizontal" or "Vertical"
	local dragThreshold = 5 -- pixels
	local dropIndicator = Instance.new("Frame")
	dropIndicator.Size = UDim2.new(1, 0, 0, 2)
	dropIndicator.BackgroundColor3 = Color3.fromRGB(255, 255, 0)
	dropIndicator.BorderSizePixel = 0
	dropIndicator.Visible = false
	dropIndicator.ZIndex = 100
	dropIndicator.Parent = self.timeline

	track.InputBegan:Connect(function(input)
		if track:GetAttribute("IsLocked") then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 and input.Position then
			-- Guard against clicks on the lock button starting a drag
			if input.UserInputState == Enum.UserInputState.Begin and input.Position.X < track.AbsolutePosition.X + 70 then return end

			dragging = true
			dragStart = input.Position
			originalStates = {}
			for t in pairs(tm.selectedTracks) do
				originalStates[t] = {
					Position = t.Position, 
					StartTime = t:GetAttribute("StartTime"),
					LayoutOrder = t.LayoutOrder
				}
			end
		end
	end)

	track.InputChanged:Connect(function(input)
		if not dragging or input.UserInputType ~= Enum.UserInputType.MouseMovement or not input.Position then return end

		local delta = input.Position - dragStart

		if not dragMode then
			if #tm:getSelectedTracksTable() == 1 and math.abs(delta.Y) > dragThreshold and math.abs(delta.Y) > math.abs(delta.X) then
				dragMode = "Vertical"
			elseif math.abs(delta.X) > dragThreshold then
				dragMode = "Horizontal"
			end
		end

		if dragMode == "Horizontal" then
			for t, state in pairs(originalStates) do
				t.Position = UDim2.new(0, state.Position.X.Offset + delta.X, 0, t.Position.Y.Offset)
			end
			if math.abs(track.Position.X.Offset - self.playhead.Position.X.Offset) < self.PLAYHEAD_SNAP_DISTANCE then
				self.playhead.BackgroundColor3 = Color3.fromRGB(255, 255, 0)
			else
				self.playhead.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
			end
		elseif dragMode == "Vertical" then
			local mouseY = input.Position.Y
			local targetTrack, targetY = nil, -1

			-- Find which track we are hovering over
			for _, child in ipairs(self.timeline:GetChildren()) do
				if child:IsA("GuiObject") and child.Name == "TimelineTrack" and child ~= track then
					local top = child.AbsolutePosition.Y
					local bottom = top + child.AbsoluteSize.Y
					if mouseY >= top and mouseY <= bottom then
						targetTrack = child
						-- Decide if we are above or below the midpoint
						if mouseY < top + child.AbsoluteSize.Y / 2 then
							targetY = top - self.LANE_PADDING / 2
						else
							targetY = bottom + self.LANE_PADDING / 2
						end
						break
					end
				end
			end

			if targetTrack then
				dropIndicator.Visible = true
				dropIndicator.Position = UDim2.fromOffset(0, targetY - self.timeline.AbsolutePosition.Y)

				-- Temporarily move the dragged tracks to visualize the drop
				local i = 0
				for t, _ in pairs(tm.selectedTracks) do
					t.Parent = nil -- This removes it from the UIListLayout's control
					local yOffset = input.Position.Y - self.timeline.AbsolutePosition.Y - track.AbsoluteSize.Y / 2 + (i * (self.TRACK_HEIGHT + self.LANE_PADDING))
					t.Position = UDim2.fromOffset(t.Position.X.Offset, yOffset)
					t.Parent = self.timeline
					i = i + 1
				end
			else
				dropIndicator.Visible = false
			end
		end
	end)

	track.InputEnded:Connect(function(input)
		if not dragging or input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		dragging = false
		dropIndicator.Visible = false

		if dragMode == "Vertical" then
			-- Finalize vertical reordering
			local mouseY = input.Position.Y
			local targetOrder = -1

			-- Find where to drop it
			for _, child in ipairs(self.timeline:GetChildren()) do
				if child:IsA("GuiObject") and child.Name == "TimelineTrack" and child ~= track then
					if mouseY < child.AbsolutePosition.Y + child.AbsoluteSize.Y / 2 then
						targetOrder = child.LayoutOrder
						break
					else
						targetOrder = child.LayoutOrder + 1
					end
				end
			end

			if targetOrder ~= -1 then
				local finalOrders = {}
				if targetOrder > track.LayoutOrder then
					targetOrder = targetOrder - 1
				end

				local otherTracks = {}
				for _, child in ipairs(self.timeline:GetChildren()) do
					if child:IsA("GuiObject") and child.Name == "TimelineTrack" and child ~= track then
						table.insert(otherTracks, child)
					end
				end
				table.sort(otherTracks, function(a, b) return a.LayoutOrder < b.LayoutOrder end)

				local newOrder = 1
				for _, otherTrack in ipairs(otherTracks) do
					if newOrder == targetOrder then
						newOrder = newOrder + 1
					end
					finalOrders[otherTrack] = newOrder
					newOrder = newOrder + 1
				end
				finalOrders[track] = targetOrder

				local action = {
					execute = function()
						for t, order in pairs(finalOrders) do
							t.LayoutOrder = order
							t:SetAttribute("LayoutOrder", order)
						end
					end,
					undo = function()
						for t, state in pairs(originalStates) do
							t.LayoutOrder = state.LayoutOrder
							t:SetAttribute("LayoutOrder", state.LayoutOrder)
						end
					end
				}
				self.historyManager:registerAction(action)
			end
			-- Restore position after drag ends
			for t, state in pairs(originalStates) do
				t.Position = UDim2.fromOffset(state.Position.X.Offset, t.Position.Y.Offset)
			end
		elseif dragMode == "Horizontal" then
			self.playhead.BackgroundColor3 = Color3.fromRGB(255, 50, 50)

			-- This is the existing horizontal move logic
			local finalStates = {}
			local zoomedPixelsPerSecond = self.PIXELS_PER_SECOND * tm.zoom
			local primaryTrackPos = track.Position.X.Offset
			local finalPrimaryPos

			if math.abs(primaryTrackPos - self.playhead.Position.X.Offset) < self.PLAYHEAD_SNAP_DISTANCE then
				finalPrimaryPos = self.playhead.Position.X.Offset
			else
				local snappedStart = math.floor((primaryTrackPos / zoomedPixelsPerSecond) / self.SNAP_INTERVAL + 0.5) * self.SNAP_INTERVAL
				finalPrimaryPos = snappedStart * zoomedPixelsPerSecond
			end

			local finalDelta = finalPrimaryPos - originalStates[track].Position.X.Offset
			for t, state in pairs(originalStates) do
				local newPos = state.Position.X.Offset + finalDelta
				finalStates[t] = {Position = UDim2.new(0, newPos, 0, t.Position.Y.Offset), StartTime = newPos / zoomedPixelsPerSecond}
			end

			local action = {
				execute = function() for t, s in pairs(finalStates) do t.Position = s.Position; t:SetAttribute("StartTime", s.StartTime) end end,
				undo = function() for t, s in pairs(originalStates) do t.Position = s.Position; t:SetAttribute("StartTime", s.StartTime) end end
			}
			self.historyManager:registerAction(action)
		end
		dragMode = nil
	end)

	local function createHandle(side)
		local handle = Instance.new("Frame"); handle.Size = UDim2.new(0, 8, 1, 0); handle.Position = (side == "Left") and UDim2.new(0, -4, 0, 0) or UDim2.new(1, -4, 0, 0); handle.BackgroundColor3 = Color3.fromRGB(255, 255, 0); handle.Parent = track; handle.Active = true
		local resizing, resizeStart, originalSize, originalPos = false, 0, 0, 0

		handle.InputBegan:Connect(function(input)
			if track:GetAttribute("IsLocked") then return end
			if input.UserInputType == Enum.UserInputType.MouseButton1 and input.Position then
				resizing = true; resizeStart = input.Position.X; originalSize = track.Size.X.Offset; originalPos = track.Position.X.Offset
			end
		end)

		handle.InputChanged:Connect(function(input)
			if resizing and input.UserInputType == Enum.UserInputType.MouseMovement and input.Position then
				local delta = input.Position.X - resizeStart
				local edgePos
				if side == "Left" then
					edgePos = originalPos + delta
					track.Position = UDim2.new(0, edgePos, 0, track.Position.Y.Offset)
					track.Size = UDim2.new(0, originalSize - delta, 0, track.Size.Y.Offset)
				else
					edgePos = originalPos + originalSize + delta
					track.Size = UDim2.new(0, originalSize + delta, 0, track.Size.Y.Offset)
				end
				if math.abs(edgePos - self.playhead.Position.X.Offset) < self.PLAYHEAD_SNAP_DISTANCE then self.playhead.BackgroundColor3 = Color3.fromRGB(255, 255, 0) else self.playhead.BackgroundColor3 = Color3.fromRGB(255, 50, 50) end
			end
		end)

		handle.InputEnded:Connect(function(input)
			if resizing and input.UserInputType == Enum.UserInputType.MouseButton1 then
				resizing = false
				self.playhead.BackgroundColor3 = Color3.fromRGB(255, 50, 50)

				local originalState = {Position = UDim2.new(0, originalPos, 0, track.Position.Y.Offset), Size = UDim2.new(0, originalSize, 0, track.Size.Y.Offset), StartTime = track:GetAttribute("StartTime"), Duration = track:GetAttribute("Duration")}
				local zoomedPixelsPerSecond = self.PIXELS_PER_SECOND * tm.zoom
				local finalPos, finalSize = track.Position.X.Offset, track.Size.X.Offset

				if side == "Left" and math.abs(finalPos - self.playhead.Position.X.Offset) < self.PLAYHEAD_SNAP_DISTANCE then
					local oldEndTime = (originalPos + originalSize) / zoomedPixelsPerSecond
					finalPos = self.playhead.Position.X.Offset
					track:SetAttribute("Duration", oldEndTime - (finalPos / zoomedPixelsPerSecond))
				elseif side == "Right" and math.abs(finalPos + finalSize - self.playhead.Position.X.Offset) < self.PLAYHEAD_SNAP_DISTANCE then
					finalSize = self.playhead.Position.X.Offset - finalPos
					track:SetAttribute("Duration", finalSize / zoomedPixelsPerSecond)
				else
					local snappedStart = math.floor((finalPos / zoomedPixelsPerSecond) / self.SNAP_INTERVAL + 0.5) * self.SNAP_INTERVAL
					local snappedEnd = math.floor(((finalPos + finalSize) / zoomedPixelsPerSecond) / self.SNAP_INTERVAL + 0.5) * self.SNAP_INTERVAL
					track:SetAttribute("StartTime", snappedStart)
					track:SetAttribute("Duration", snappedEnd - snappedStart)
				end

				tm:redrawTimeline()

				local finalState = {Position = track.Position, Size = track.Size, StartTime = track:GetAttribute("StartTime"), Duration = track:GetAttribute("Duration")}
				local action = {
					execute = function() track.Position = finalState.Position; track.Size = finalState.Size; track:SetAttribute("StartTime", finalState.StartTime); track:SetAttribute("Duration", finalState.Duration) end,
					undo = function() track.Position = originalState.Position; track.Size = originalState.Size; track:SetAttribute("StartTime", originalState.StartTime); track:SetAttribute("Duration", originalState.Duration) end
				}
				self.historyManager:registerAction(action)
			end
		end)
	end
	createHandle("Left"); createHandle("Right")
end


return TrackInteractor
