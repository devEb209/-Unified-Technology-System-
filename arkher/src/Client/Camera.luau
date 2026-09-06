--!strict
-- Input/camera platform adapter: mouse, touch and gamepad. VR is not certified.
local Camera = {}
Camera.__index = Camera
function Camera.new(camera, input, viewport, onPick)
	local self=setmetatable({camera=camera,input=input,viewport=viewport,onPick=onPick,target=Vector3.new(25,4,0),yaw=.55,pitch=.48,distance=135,
		connections={},touches={},keys={},mode=nil,moved=0,rightStick=Vector2.zero,leftStick=Vector2.zero,savedType=camera.CameraType,savedCFrame=camera.CFrame},Camera)
	camera.CameraType=Enum.CameraType.Scriptable
	local function inside(position)
		local at,size=viewport.AbsolutePosition,viewport.AbsoluteSize
		return position.X>=at.X and position.X<=at.X+size.X and position.Y>=at.Y and position.Y<=at.Y+size.Y
	end
	self.inside=inside
	local function connect(signal,fn) table.insert(self.connections,signal:Connect(fn)) end
	connect(input.InputBegan,function(event,processed)
		if processed or self.blocked or input:GetFocusedTextBox() then return end
		self.keys[event.KeyCode]=true
		if event.UserInputType==Enum.UserInputType.MouseButton2 and inside(event.Position) then self.mode="orbit"
		elseif event.UserInputType==Enum.UserInputType.MouseButton3 and inside(event.Position) then self.mode="pan"
		elseif event.UserInputType==Enum.UserInputType.MouseButton1 and inside(event.Position) then self.start=Vector2.new(event.Position.X,event.Position.Y);self.moved=0
		elseif event.UserInputType==Enum.UserInputType.Touch and inside(event.Position) then
			self.touches[event]={position=Vector2.new(event.Position.X,event.Position.Y),start=Vector2.new(event.Position.X,event.Position.Y),moved=0,at=os.clock()}
		elseif event.KeyCode==Enum.KeyCode.ButtonA then
			local at,size=viewport.AbsolutePosition,viewport.AbsoluteSize
			onPick(at.X+size.X/2,at.Y+size.Y/2)
		end
	end)
	connect(input.InputChanged,function(event)
		if self.blocked then return end
		if event.UserInputType==Enum.UserInputType.MouseMovement then
			self.moved+=event.Delta.Magnitude
			if self.mode=="orbit" then self.yaw-=event.Delta.X*.006;self.pitch=math.clamp(self.pitch+event.Delta.Y*.006,.06,1.45)
			elseif self.mode=="pan" then self:pan(event.Delta.X,event.Delta.Y) end
		elseif event.UserInputType==Enum.UserInputType.MouseWheel then
			if inside(input:GetMouseLocation()) then self.distance=math.clamp(self.distance*(1-event.Position.Z*.1),5,1500) end
		elseif event.UserInputType==Enum.UserInputType.Touch and self.touches[event] then
			local touch=self.touches[event];local nextPosition=Vector2.new(event.Position.X,event.Position.Y)
			local delta=nextPosition-touch.position;touch.moved+=delta.Magnitude
			local other
			for key,value in pairs(self.touches) do if key~=event then other=value;break end end
			if other then
				local before=(touch.position-other.position).Magnitude
				local after=(nextPosition-other.position).Magnitude
				if before>5 and after>5 then self.distance=math.clamp(self.distance*before/after,5,1500) end
			else self.yaw-=delta.X*.006;self.pitch=math.clamp(self.pitch+delta.Y*.006,.06,1.45) end
			touch.position=nextPosition
		elseif event.KeyCode==Enum.KeyCode.Thumbstick2 then self.rightStick=Vector2.new(event.Position.X,event.Position.Y)
		elseif event.KeyCode==Enum.KeyCode.Thumbstick1 then self.leftStick=Vector2.new(event.Position.X,event.Position.Y) end
	end)
	connect(input.InputEnded,function(event)
		self.keys[event.KeyCode]=nil
		if event.UserInputType==Enum.UserInputType.MouseButton2 or event.UserInputType==Enum.UserInputType.MouseButton3 then self.mode=nil
		elseif event.UserInputType==Enum.UserInputType.MouseButton1 then
			if self.start and self.moved<5 and inside(event.Position) then onPick(event.Position.X,event.Position.Y) end
			self.start=nil
		elseif event.UserInputType==Enum.UserInputType.Touch then
			local touch=self.touches[event]
			if touch and touch.moved<9 and os.clock()-touch.at<.4 then onPick(event.Position.X,event.Position.Y) end
			self.touches[event]=nil
		end
	end)
	return self
end

function Camera:pan(dx,dy)
	self.target += (-self.camera.CFrame.RightVector*dx+self.camera.CFrame.UpVector*dy)*(self.distance*.0015)
end
function Camera:focus(position)
	self.target=Vector3.new(position.x,position.y,position.z);self.distance=math.min(self.distance,55)
end
function Camera:step(dt)
	if not self.blocked and not self.input:GetFocusedTextBox() then
		local amount=dt*self.distance*.5
		local forward=Vector3.new(-math.sin(self.yaw),0,-math.cos(self.yaw))
		local right=Vector3.new(math.cos(self.yaw),0,-math.sin(self.yaw))
		if self.inside(self.input:GetMouseLocation()) then
			if self.keys[Enum.KeyCode.W] then self.target+=forward*amount end
			if self.keys[Enum.KeyCode.S] then self.target-=forward*amount end
			if self.keys[Enum.KeyCode.A] then self.target-=right*amount end
			if self.keys[Enum.KeyCode.D] then self.target+=right*amount end
		end
		if self.rightStick.Magnitude>.15 then self.yaw-=self.rightStick.X*dt*2;self.pitch=math.clamp(self.pitch+self.rightStick.Y*dt*2,.06,1.45) end
		if self.leftStick.Magnitude>.15 then self.target+=(right*self.leftStick.X+forward*self.leftStick.Y)*amount end
		if self.keys[Enum.KeyCode.ButtonR2] then self.distance=math.max(5,self.distance*(1-dt)) end
		if self.keys[Enum.KeyCode.ButtonL2] then self.distance=math.min(1500,self.distance*(1+dt)) end
	end
	local offset=Vector3.new(math.sin(self.yaw)*math.cos(self.pitch),math.sin(self.pitch),math.cos(self.yaw)*math.cos(self.pitch))*self.distance
	self.camera.CFrame=CFrame.lookAt(self.target+offset,self.target)
end
function Camera:destroy()
	for _,connection in ipairs(self.connections) do connection:Disconnect() end
	self.camera.CameraType=self.savedType;self.camera.CFrame=self.savedCFrame
end
return Camera
