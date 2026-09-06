--!strict
-- Real DataStore adapter with compare-and-swap; never blindly overwrites a saved project.
local Store = {}
Store.__index = Store
function Store.new(dataStore, key, encode)
	return setmetatable({dataStore=dataStore,key=key,encode=encode},Store)
end
function Store:load()
	local stored=self.dataStore:GetAsync(self.key)
	if stored==nil then return nil end
	assert(type(stored)=="table" and stored.format=="arkher.save/1" and type(stored.version)=="number" and stored.version%1==0 and stored.version>=1,"Save incompatível ou corrompido")
	assert(type(stored.state)=="table","Estado salvo ausente")
	return stored
end
function Store:save(state, expectedVersion, userId)
	local bytes=#self.encode(state)
	assert(bytes<=3000000,"Projeto excede orçamento deste adapter DataStore; exporte JSON")
	local conflict=false
	local nextVersion=expectedVersion+1
	local result=self.dataStore:UpdateAsync(self.key,function(old)
		local version=if old==nil then 0 else old.version
		if old~=nil and (type(old)~="table" or old.format~="arkher.save/1") then error("Save existente incompatível; não sobrescrito") end
		if version~=expectedVersion then conflict=true;return nil end
		return {format="arkher.save/1",version=nextVersion,state=state,savedBy=userId,savedAt=os.time()}
	end)
	assert(not conflict and result and result.version==nextVersion,"Conflito de versão salva; carregue a versão atual antes de salvar")
	return nextVersion
end
return Store
