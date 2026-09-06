--!strict
-- Authoritative editor session: permissions, revisions, rate limits and explicit AI approval.
local Util = require(script.Parent:WaitForChild("Util"))
local Project = require(script.Parent:WaitForChild("Project"))
local Planner = require(script.Parent:WaitForChild("Planner"))
local Runtime = require(script.Parent:WaitForChild("Runtime"))
local Schema = require(script.Parent:WaitForChild("Schema"))
local Session = {}
Session.__index = Session

function Session.new(options)
	options=options or {}
	return setmetatable({project=options.project or Project.example(),authorize=options.authorize or function() return false end,
		clock=options.clock or os.clock,token=options.token or function() return tostring(os.clock()) end,
		emit=options.emit or function() end,storage=options.storage,provider=options.provider,
		mode="edit",epoch=0,runtime=nil,buckets={},plans={},busy={},storageVersion=0,maxDynamics=options.maxDynamics or 128},Session)
end

function Session:guard(userId, action)
	assert(self.authorize(userId),"Sem permissão para este projeto")
	local now=self.clock()
	local bucket=self.buckets[userId] or {tokens=20,at=now}
	bucket.tokens=math.min(20,bucket.tokens+(now-bucket.at)*10);bucket.at=now
	self.buckets[userId]=bucket
	local cost=if action=="plan" then 5 else 1
	assert(bucket.tokens>=cost,"Muitos pedidos; aguarde um instante")
	bucket.tokens-=cost
end

function Session:snapshot()
	return {kind="snapshot",state=self.project:snapshot(),mode=self.mode,epoch=self.epoch,
		canUndo=#self.project.undoStack>0,canRedo=#self.project.redoStack>0,
		persistenceConfigured=self.storage~=nil,providerConfigured=self.provider~=nil,
		storageVersion=self.storageVersion}
end

function Session:notify()
	self.emit(self:snapshot())
end

function Session:handle(userId, action, payload)
	self:guard(userId,action)
	payload=payload or {};Util.data(payload,action=="replace" and 600000 or 30000)
	if action=="state" then return self:snapshot() end
	if action=="export" then return {state=self.project:snapshot()} end
	if action=="stop" then
		assert(payload.epoch==self.epoch,"Execução mudou; atualize")
		self.mode="edit";self.runtime=nil;self.epoch+=1;self:notify();return self:snapshot()
	end
	assert(self.mode=="edit","Pare a simulação antes de editar o projeto")
	assert(payload.revision==self.project.state.revision,"Projeto mudou; atualize a revisão")
	if action=="execute" then
		local receipt=self.project:execute(payload.operations,payload.revision)
		self:notify();return {receipt=receipt,snapshot=self:snapshot()}
	elseif action=="undo" then self.project:undo(payload.revision);self:notify();return self:snapshot()
	elseif action=="redo" then self.project:redo(payload.revision);self:notify();return self:snapshot()
	elseif action=="play" then
		local runtime=Runtime.new(self.project.state,{maxDynamics=self.maxDynamics})
		self.runtime=runtime;self.mode="play";self.epoch+=1;self:notify();return self:snapshot()
	elseif action=="replace" then self.project:replace(payload.state,payload.revision);self:notify();return self:snapshot()
	elseif action=="new" then self.project:replace(Schema.empty("Novo projeto"),payload.revision);self:notify();return self:snapshot()
	elseif action=="export" then return {state=self.project:snapshot()}
	elseif action=="save" then
		assert(self.storage,"DataStore não configurado; use Exportar JSON para preservar o projeto")
		assert(not self.busy.storage,"Operação de armazenamento em andamento")
		self.busy.storage=true
		local snapshot=self.project:snapshot()
		local ok,result=pcall(function() return self.storage:save(snapshot,self.storageVersion,userId) end)
		self.busy.storage=nil
		assert(ok,tostring(result));self.storageVersion=result
		return {savedRevision=snapshot.revision,storageVersion=result}
	elseif action=="load" then
		assert(self.storage,"DataStore não configurado")
		assert(not self.busy.storage,"Operação de armazenamento em andamento")
		self.busy.storage=true
		local epoch=self.epoch
		local ok,result=pcall(function()
			local stored=self.storage:load()
			assert(stored,"Nenhum projeto salvo")
			assert(self.mode=="edit" and self.epoch==epoch,"Execução mudou durante o carregamento")
			self.project:replace(stored.state,payload.revision)
			return stored
		end)
		self.busy.storage=nil
		assert(ok,tostring(result));self.storageVersion=result.version;self:notify();return self:snapshot()
	elseif action=="plan" then
		assert(not self.busy[userId],"Já existe um planejamento em andamento")
		local prompt=Util.text(payload.prompt,"",2000)
		local capturedRevision,capturedEpoch=self.project.state.revision,self.epoch
		local concurrent=0
		for key,value in pairs(self.busy) do if type(key)=="number" and value then concurrent+=1 end end
		assert(concurrent<4,"Limite de planejamentos concorrentes; aguarde")
		local started=self.clock()
		local requestToken=self.token()
		self.busy[userId]=requestToken
		local ok,result=pcall(function()
			local plan
			if payload.provider=="remote" then
				assert(self.provider,"Provider externo não configurado")
				plan=self.provider(prompt,self.project:snapshot())
				plan.origin="configured-provider"
			else plan=Planner.localPlan(prompt,self.project.state) end
			assert(self.clock()-started<=60,"Planejamento excedeu orçamento de tempo; nenhuma ação executada")
			assert(self.busy[userId]==requestToken and self.authorize(userId),"Solicitação cancelada ou usuário desconectado")
			assert(self.mode=="edit" and self.epoch==capturedEpoch and self.project.state.revision==capturedRevision,"Projeto mudou durante o planejamento; gere uma nova prévia")
			local proof=Planner.validate(plan,self.project)
			local token=self.token()
			self.plans[userId]={token=token,plan=Util.freeze(Util.copy(plan)),revision=capturedRevision,epoch=capturedEpoch,expires=self.clock()+90}
			return {token=token,plan=plan,proof=proof,expiresIn=90}
		end)
		if self.busy[userId]==requestToken then self.busy[userId]=nil end
		assert(ok,tostring(result));return result
	elseif action=="applyPlan" then
		local pending=assert(self.plans[userId],"Nenhuma prévia aprovada disponível")
		assert(payload.confirm==true and payload.token==pending.token,"Confirmação explícita da prévia obrigatória")
		assert(self.clock()<=pending.expires,"Prévia expirada")
		assert(pending.revision==self.project.state.revision and pending.epoch==self.epoch,"Prévia desatualizada")
		self.plans[userId]=nil
		local receipt=self.project:execute(pending.plan.operations,pending.revision)
		self:notify();return {receipt=receipt,snapshot=self:snapshot()}
	end
	error("Pedido não suportado: "..tostring(action))
end

function Session:step(dt)
	if self.runtime then
		local started=self.clock()
		local frame=self.runtime:step(dt)
		frame.cpuMs=(self.clock()-started)*1000
		frame.kind="frame";frame.epoch=self.epoch
		self.emit(frame)
	end
end

function Session:removeUser(userId)
	self.buckets[userId],self.plans[userId],self.busy[userId]=nil,nil,nil
end

return Session
