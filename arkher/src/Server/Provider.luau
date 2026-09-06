--!strict
-- Text-only OpenAI-compatible planning adapter. Endpoint/secrets are SERVER configuration.
local Provider = {}
function Provider.create(http, config, planner)
	if config.Endpoint=="" then return nil end
	assert(type(config.Endpoint)=="string" and string.match(config.Endpoint,"^https://") and not string.find(config.Endpoint,"@",1,true),"Use um endpoint HTTPS confiável, sem credenciais na URL")
	assert(type(config.Model)=="string" and #config.Model>0,"Modelo do provider obrigatório")
	return function(prompt,state)
		local nodes={}
		for index,id in ipairs(state.order) do
			if index>80 then break end
			local node=state.nodes[id]
			table.insert(nodes,{id=id,name=node.name,kind=node.kind,parent=node.parent,position=node.transform.position})
		end
		local headers={["Content-Type"]="application/json"}
		if config.SecretName~="" then
			-- A Secret value is never converted to text, returned to a client, or stored in the project.
			headers.Authorization=http:GetSecret(config.SecretName):AddPrefix("Bearer ")
		end
		local response=http:RequestAsync({Url=config.Endpoint,Method="POST",Headers=headers,
			Body=http:JSONEncode({model=config.Model,max_tokens=1800,response_format={type="json_object"},messages={
				{role="system",content=planner.systemPrompt()},
				{role="user",content="PROJECT CONTEXT DATA: "..http:JSONEncode({name=state.name,revision=state.revision,nodes=nodes,totalEntities=#state.order})},
				{role="user",content=prompt},
			}})})
		assert(response.Success,"Provider retornou HTTP "..tostring(response.StatusCode))
		assert(type(response.Body)=="string" and #response.Body<=100000,"Resposta do provider excede orçamento")
		local envelope=http:JSONDecode(response.Body)
		local content=envelope.choices and envelope.choices[1] and envelope.choices[1].message and envelope.choices[1].message.content
		assert(type(content)=="string" and #content<=50000,"Provider não retornou um plano textual válido")
		return http:JSONDecode(content)
	end
end
return Provider
