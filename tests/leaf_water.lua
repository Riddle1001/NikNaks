-- GLuaTest: real BitBuffer reads must respect the BSP's 12-byte record stride.
local function bsp(bytes)
	return setmetatable({GetLump = function() return NikNaks.BitBuffer(bytes) end,
		ClearLump = function(self) self.cleared = true end,
		GetTexInfo = function() return {} end}, {__index = NikNaks.__metatables.BSP})
end
-- (-204.75, -210, 6654, padding), (-370, -386, 6732, padding).
local bytes = string.char(0,192,76,195,0,0,82,195,254,25,0,0,
	0,0,185,195,0,0,193,195,76,26,0,0)
return {groupName = "BSP leaf water alignment", cases = {
	{name = "successive padded records keep floats and texture IDs aligned", func = function()
		local map = bsp(bytes)
		local data = map:GetLeafWaterData()
		assert(data[0].surfaceZ == -204.75 and data[0].minZ == -210 and data[0].surfaceTexInfoID == 6654)
		assert(data[1].surfaceZ == -370 and data[1].minZ == -386 and data[1].surfaceTexInfoID == 6732)
		assert(data[2] == nil and map.cleared)
		assert(map:GetLeafWaterData() == data, "the parsed table must remain cached")
	end},
	{name = "empty and incomplete records do not produce bogus volumes", func = function()
		assert(next(bsp(""):GetLeafWaterData()) == nil)
		local data = bsp(bytes .. string.char(1,2,3)):GetLeafWaterData()
		assert(data[1].surfaceZ == -370 and data[2] == nil)
	end},
}}
