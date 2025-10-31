-- ComponentDragger.lua (ModuleScript)
-- Path: ServerScriptService/VFXEditor/ComponentDragger.lua

local UserInputService = game:GetService("UserInputService")

local ComponentDragger = {}
ComponentDragger.__index = ComponentDragger

function ComponentDragger.new(ui)
	local self = setmetatable({}, ComponentDragger)

	self.ui = ui
	self.isDragging = false
	self.ghostFrame = nil
	self.draggedComponentType = nil
	self.isPreset = false

	self.ComponentDropped = {}
	function self.ComponentDropped:Connect(callback) table.insert(self, callback) end
	function self.ComponentDropped:Fire(...) for _, cb in ipairs(self) do cb(...) end end

	self:_connectEvents()

	return self
end

function ComponentDragger:_createGhostFrame(sourceButton)
	self.ghostFrame = Instance.new("TextLabel")
	self.ghostFrame.Name = "GhostComponent"
	self.ghostFrame.Size = UDim2.new(0, 100, 0, 25)
	self.ghostFrame.BackgroundColor3 = sourceButton.BackgroundColor3
	self.ghostFrame.BackgroundTransparency = 0.4
	self.ghostFrame.TextColor3 = sourceButton.TextColor3
	self.ghostFrame.Text = sourceButton.Text
	self.ghostFrame.ZIndex = 100
	self.ghostFrame.Parent = self.ui.MainFrame
end

function ComponentDragger:_connectEvents()
	-- Handle starting the drag
	for _, button in ipairs(self.ui.ComponentLibrary:GetChildren()) do
		if button.Name == "ComponentDraggable" then
			button.InputBegan:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					self.isDragging = true
					self.draggedComponentType = button:GetAttribute("ComponentType")
					self.isPreset = button:GetAttribute("IsPreset")
					self:_createGhostFrame(button)
				end
			end)
		end
	end

	-- Handle mouse movement to update ghost frame position
	UserInputService.InputChanged:Connect(function(input)
		if self.isDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			if self.ghostFrame then
				local relativePos = input.Position - self.ui.MainFrame.AbsolutePosition
				self.ghostFrame.Position = UDim2.new(0, relativePos.X + 5, 0, relativePos.Y + 5)
			end
		end
	end)

	-- Handle ending the drag (dropping)
	UserInputService.InputEnded:Connect(function(input)
		if self.isDragging and input.UserInputType == Enum.UserInputType.MouseButton1 then
			if self.ghostFrame then
				local timeline = self.ui.Timeline
				local mousePos = Vector2.new(input.Position.X, input.Position.Y)

				local tlTopLeft = timeline.AbsolutePosition
				local tlBottomRight = tlTopLeft + timeline.AbsoluteSize

				if mousePos.X >= tlTopLeft.X and mousePos.X <= tlBottomRight.X and
					mousePos.Y >= tlTopLeft.Y and mousePos.Y <= tlBottomRight.Y then

					self.ComponentDropped:Fire(self.draggedComponentType, self.isPreset, mousePos)
				end

				self.ghostFrame:Destroy()
				self.ghostFrame = nil
			end

			self.isDragging = false
			self.draggedComponentType = nil
			self.isPreset = false
		end
	end)
end

return ComponentDragger
