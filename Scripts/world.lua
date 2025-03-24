-- Copyright (C) 2006-2007  Cameron Kenneth Knight
-- 
-- This program is free software; you can redistribute it and/or
-- modify it under the terms of the GNU General Public License
-- as published by the Free Software Foundation; either version 2
-- of the License, or (at your option) any later version.
-- 
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
-- 
-- You should have received a copy of the GNU General Public License
-- along with this program; if not, write to the Free Software
-- Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

local f = io.open("md5translate.trs", "r")
if not f then
	error("Cannot find file: md5translate.trs")
end
local md5text = f:read("*all")
f:close()

local badTextures = {
	["e03ed5cdc1f9799345c73364d2aa861b"] = true,
	["67ba43d493e62a8fad5de319e6d4cb05"] = true,
	["1400fcdfe2ca0858409f60596de08065"] = true,
	["d922f6d7681bc0683c69d44591a0db4f"] = true,
	
	["7ec65c77541b5d6974ee1c0e3776be96"] = true,
	["e4ee35d9b650643d4a488037afea775c"] = true,
	["db7430ed563059e43760c0975ffcc364"] = true,
	["d365992628f09d92d5fc3c5c23e084de"] = true,
	["8292e8420a8a75862e0d609f15ec492c"] = true,
	["176b743029970ff500cde853ca95d416"] = true,
	["996cfc07a1e2ad7ad283c0d08db57d86"] = true,
	["1b2dcd51d99d37ef7e2e5d957d7eea7f"] = true,
	["cd6076102e0ab0faf8a740a74dd8b169"] = true,
	["210f6915022ef6dddb6b301f5d15de16"] = true,
	["647d2f8273c1f8b660000b14cb48b069"] = true,
	["81f0101bef923b46c2aba8cae581e7ca"] = true,
	["8ce6e92e83a1e79c4242a41b713a171d"] = true,
	["29a818170f29ad6f031adaaf2800b65a"] = true,
	["6487bc7a2b63f0eea182c818058369c5"] = true,
	["2078b67554da42fc17d719f4532b229c"] = true,
	["9802902870532e528e1b308a81d558c3"] = true,
	["4d3b38f904930e2d5ebb6f341684b3e1"] = true,
	["4c5b0c29cfa3cc311e744def037a73bb"] = true,
	["395770c18a89ca64327544a796fbb876"] = true,
	["38552f26faa98fe15db233fb396aac28"] = true,
	["56de9bdd39314a1ac30b575d8dfe5fd6"] = true,
	["070315ab3e2af9da7fa9212747ae4e23"] = true,
	["ebbd247d4e4af80284b60bd82daaeacb"] = true,
	["421bc7212944e75f6636ec4f69f5ddd8"] = true,
	["edc74a55375e9eae10fbb42383c81b0f"] = true,
	["51234e15d5fe742353c75bd84ee86a55"] = true,
	["8bfedde5833ba5e8662c359c20a320b5"] = true,
	["5eb28208a347f25d22a6f9323f34dbfe"] = true,
	["6f1d2f5f8de9e19dfd28a9235d2a8721"] = true,
	["1f4500a9c60e52ec24f99eac4d17158b"] = true,
	["d5ab776bd4d3e3127a68a75f5dd94406"] = true,
	["aaa05407a4fa1407042693af8d9a584f"] = true,
}
local zomg = {}

print("Cartographer3.SetTextureData {")
local data = {}
for _, mapName in ipairs { "Azeroth", "Kalimdor", "Expansion01", "Northrend" } do
	data[mapName] = {}
	for x, y, tex in md5text:gmatch(mapName .. "\\map(%d%d)_(%d%d)%.blp\t(%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x%x)%.blp") do
		x, y = x+0, y+0
		local good = true
		if badTextures[tex] then
			good = false
		elseif mapName == "Kalimdor" then
			if x < 22 then
				good = false
			elseif x < 25 and y < 20 then
				good = false
			end
		elseif mapName == "Azeroth" then
			if y < 25 then
				good = false
			elseif y < 26 and x > 38 then
				good = false
			end
		end
		
		if good then
			data[mapName][x*100 + y] = tex
			zomg[tex] = true
		end
	end
end
data["QuelThalas"] = {}
data["AzuremystIsles"] = {}
for pos, tex in pairs(data["Expansion01"]) do
	local x, y = math.floor(pos/100), pos%100
	if x > 48 then
		if y > 32 and y < 43 and x > 50 and x < 60 then
			data["AzuremystIsles"][pos] = tex
		end
		data["Expansion01"][pos] = nil
	elseif x > 38 then
		if y < 21 and (y < 20 or x > 42) and x > 41 and x < 48 then
			data["QuelThalas"][pos] = tex
		end
		data["Expansion01"][pos] = nil
	end
end
for _, mapName in ipairs { "Azeroth", "Kalimdor", "Expansion01", "Northrend", "AzuremystIsles", "QuelThalas" } do
	print("\t" .. mapName .. " = {")
	local keys = {}
	for pos in pairs(data[mapName]) do
		keys[#keys+1] = pos
	end
	table.sort(keys)
	for _, pos in ipairs(keys) do
		local tex = data[mapName][pos]
		print("\t\t[" .. pos .. "] = \"" .. tex .. "\",")
	end
	print("\t},")
end
print("}")
