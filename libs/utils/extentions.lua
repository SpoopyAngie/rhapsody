local extentions = {}

extentions.parseISO8601 = function(ISO8601)
	local ResultTable = {}
	
	for Value, Key in ISO8601:gmatch("([%d.,]+)(%u)") do ResultTable[Key] = tonumber(Value) end
	
	return ResultTable
end

extentions.ISO8601toSeconds = function(ISO8601)
	local Seconds = 0
	local ISO8601Table = extentions.parseISO8601(ISO8601)
	local ISO8601Enums = {D = 86400, H = 3600, M = 60, S = 1}
	
	for Key, Value in pairs(ISO8601Table) do
		if ISO8601Enums[Key] then
			Seconds = Seconds + (ISO8601Enums[Key] * Value)
		end
	end
	
	return Seconds
end

return extentions