-- ARKHER standalone experience bootstrap. Server owns projects, commands and simulation.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local HttpService=game:GetService("HttpService")
local DataStoreService=game:GetService("DataStoreService")
local Config=require(script.Parent.Config)
local package=ReplicatedStorage:WaitForChild("ARKHER")
local Session=require(package.Core.Session)
local Planner=require(package.Core.Planner)
local Store=require(script.Parent.DataStoreStore)
local Provider=require(script.Parent.Provider)
local requests=package.Remotes.Request
local events=package.Remotes.Event
local alive=true
local incoming={}

-- This is an editor experience, not an extension injected into another game.
-- Existing Characters are never destroyed by this bootstrap.
if Config.DisableAvatar ~= false then Players.CharacterAutoLoads=false end

local function authorized(userId)
	local player=Players:GetPlayerByUserId(userId)
	if not player then return false end
	return RunService:IsStudio() or Config.EditorUserIds[userId]==true
		or (game.CreatorType==Enum.CreatorType.User and game.CreatorId==userId)
end
local storage
if Config.PersistenceEnabled then
	storage=Store.new(DataStoreService:GetDataStore(Config.DataStoreName),Config.DataStoreKey,function(value) return HttpService:JSONEncode(value) end)
end
local configured,provider=pcall(Provider.create,HttpService,Config.Provider,Planner)
if not configured then warn("[ARKHER] Provider não inicializado; revise a configuração do servidor.");provider=nil end
local accumulated=0
local session=Session.new({authorize=authorized,storage=storage,provider=provider,maxDynamics=Config.MaxDynamics,
	token=function() return HttpService:GenerateGUID(false) end,
	emit=function(packet)
		packet.pendingSimulationSeconds=accumulated
		for _,player in ipairs(Players:GetPlayers()) do
			if authorized(player.UserId) then events:FireClient(player,packet) end
		end
	end})

requests.OnServerInvoke=function(player,action,payload)
	if not alive then return {ok=false,error="Sessão encerrada"} end
	if not authorized(player.UserId) then return {ok=false,error="Sem acesso: configure seu UserId em ARKHER_SERVER.Config. O criador de experiência pessoal e testes Studio já são permitidos."} end
	local now=os.clock()
	local window=incoming[player.UserId]
	if not window or now-window.at>=1 then window={at=now,count=0};incoming[player.UserId]=window end
	if window.count>=20 then return {ok=false,error="Muitos pedidos; aguarde"} end
	window.count+=1
	local ok,result=pcall(function()
		assert(type(action)=="string" and #action<40,"Pedido inválido")
		assert(type(payload)=="table","Payload de dados obrigatório")
		local encoded=HttpService:JSONEncode(payload)
		assert(#encoded<=1000000,"Pedido excede orçamento de transporte")
		return session:handle(player.UserId,action,payload)
	end)
	if not ok then
		return {ok=false,error=string.sub(tostring(result),1,500),snapshot=session:snapshot()}
	end
	return {ok=true,result=result}
end

local removing=Players.PlayerRemoving:Connect(function(player) session:removeUser(player.UserId);incoming[player.UserId]=nil end)
local heartbeat=RunService.Heartbeat:Connect(function(dt)
	if not alive then return end
	if session.mode~="play" then accumulated=0;return end
	accumulated+=dt
	local steps=0
	while accumulated>=.05 and steps<2 do
		accumulated-=.05;steps+=1
		local ok,message=pcall(session.step,session,.05)
		if not ok then
			warn("[ARKHER] Simulação interrompida: "..tostring(message))
			session.mode="edit";session.runtime=nil;session.epoch+=1;session:notify();accumulated=0;break
		end
	end
end)
script.Destroying:Connect(function()
	alive=false;heartbeat:Disconnect();removing:Disconnect();requests.OnServerInvoke=nil
end)
print("[ARKHER] Engine/editor G1 inicializado. Dados autoritativos próprios; V1 completa ainda não certificada.")
