--!strict
-- FlyCamera — Studio fly (WASD + Q/E + Shift fast + RMB drag). Preserved from earlier, not changed per user.
local FlyCamera = {}
FlyCamera.__index = FlyCamera

function FlyCamera.new()
	local self=setmetatable({}, FlyCamera)
	self.Enabled=false
	self.Speed=16
	self.FastMult=3.5
	self.Conn=nil
	self.Cam=nil
	return self
end

function FlyCamera:Toggle()
	self.Enabled = not self.Enabled
	if self.Enabled then self:Start() else self:Stop() end
	return self.Enabled
end

function FlyCamera:Start()
	if self.Conn then return end
	local UIS=game:GetService("UserInputService")
	local RS=game:GetService("RunService")
	local cam=workspace.CurrentCamera
	self.Cam=cam
	local keys={} :: {[Enum.KeyCode]: boolean}
	local dragging=false
	local lastMouse: Vector2? = nil

	local function isDown(k: Enum.KeyCode) return keys[k]==true end

	UIS.InputBegan:Connect(function(input, gp)
		if input.UserInputType==Enum.UserInputType.MouseButton2 then dragging=true; lastMouse=input.Position; UIS.MouseBehavior=Enum.MouseBehavior.LockCurrentPosition end
		if input.UserInputType==Enum.UserInputType.Keyboard then keys[input.KeyCode]=true end
	end)
	UIS.InputEnded:Connect(function(input)
		if input.UserInputType==Enum.UserInputType.MouseButton2 then dragging=false; UIS.MouseBehavior=Enum.MouseBehavior.Default end
		if input.UserInputType==Enum.UserInputType.Keyboard then keys[input.KeyCode]=false end
	end)
	UIS.InputChanged:Connect(function(input)
		if dragging and input.UserInputType==Enum.UserInputType.MouseMovement and cam then
			local delta=input.Delta
			local sens=0.22
			local yaw = -delta.X*sens
			local pitch = -delta.Y*sens
			local cf=cam.CFrame
			cf = cf * CFrame.Angles(0, math.rad(yaw), 0)
			cf = CFrame.new(cf.Position) * CFrame.fromEulerAnglesYXZ(math.rad(pitch), cf:ToEulerAnglesYXZ())
			-- clamp pitch via simpler: apply pitch around right vector
			-- fallback simple
			cam.CFrame = cf
		end
	end)

	self.Conn = RS.Heartbeat:Connect(function(dt)
		if not self.Enabled or not cam then return end
		if not (isDown(Enum.KeyCode.W) or isDown(Enum.KeyCode.A) or isDown(Enum.KeyCode.S) or isDown(Enum.KeyCode.D) or isDown(Enum.KeyCode.Q) or isDown(Enum.KeyCode.E)) then return end
		local move=Vector3.new()
		if isDown(Enum.KeyCode.W) then move+=cam.CFrame.LookVector end
		if isDown(Enum.KeyCode.S) then move-=cam.CFrame.LookVector end
		if isDown(Enum.KeyCode.A) then move-=cam.CFrame.RightVector end
		if isDown(Enum.KeyCode.D) then move+=cam.CFrame.RightVector end
		if isDown(Enum.KeyCode.E) then move+=Vector3.new(0,1,0) end
		if isDown(Enum.KeyCode.Q) then move-=Vector3.new(0,1,0) end
		if move.Magnitude>0 then
			move=move.Unit * self.Speed * dt * (if isDown(Enum.KeyCode.LeftShift) or isDown(Enum.KeyCode.RightShift) then self.FastMult else 1)
			cam.CFrame = cam.CFrame + move
		end
	end)
end

function FlyCamera:Stop()
	if self.Conn then self.Conn:Disconnect(); self.Conn=nil end
	game:GetService("UserInputService").MouseBehavior=Enum.MouseBehavior.Default
end

return FlyCamera
