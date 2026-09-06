--!strict
-- Client materialization controller. Frame time is measured, not a quality score.
local Budget = {}
Budget.__index = Budget
function Budget.new(maximum, targetMs)
	return setmetatable({maximum=maximum,current=maximum,targetMs=targetMs,ema=targetMs,samples=0,cooldown=0},Budget)
end
function Budget:sample(frameMs, dt)
	if frameMs~=frameMs or frameMs<=0 or frameMs>1000 then return self.current end
	self.ema += (frameMs-self.ema)*.08
	self.samples += 1;self.cooldown=math.max(0,self.cooldown-dt)
	if self.samples>=30 and self.cooldown<=0 then
		if self.ema>self.targetMs*1.18 then self.current=math.max(64,math.floor(self.current*.88));self.cooldown=1
		elseif self.ema<self.targetMs*.78 then self.current=math.min(self.maximum,self.current+16);self.cooldown=1 end
	end
	return self.current
end
return Budget
