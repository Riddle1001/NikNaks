return { groupName = "Source 2013 static props", cases = {
	{ name = "v10 flags follow the DX levels, and lightmap dimensions are shorts", func = function()
		local buffer = NikNaks.BitBuffer()
		local model = "models/test.mdl"
		buffer:WriteULong( 1 )
		buffer:WriteData( model .. string.rep( "\0", 128 - #model ) )
		buffer:WriteULong( 2 ) -- Leaf indices
		buffer:WriteUShort( 17 )
		buffer:WriteUShort( 42 )
		buffer:WriteULong( 1 )

		buffer:WriteVector( Vector( 1, 2, 3 ) )
		buffer:WriteAngle( Angle() )
		buffer:WriteUShort( 0 ) -- Model index
		buffer:WriteUShort( 1 ) -- First leaf reference
		buffer:WriteUShort( 1 ) -- Leaf reference count
		buffer:WriteByte( 6 )
		buffer:WriteByte( 0xA0 ) -- Padding may contain arbitrary bytes
		buffer:WriteULong( 0 )
		buffer:WriteFloat( 640 )
		buffer:WriteFloat( 896 )
		buffer:WriteVector( Vector( 4, 5, 6 ) )
		buffer:WriteFloat( 1 )
		buffer:WriteUShort( 90 )
		buffer:WriteUShort( 95 )
		buffer:WriteULong( 0x103 )
		buffer:WriteUShort( 16 )
		buffer:WriteUShort( 32 )
		buffer:Seek( 0 )

		local bsp = setmetatable( {
			GetGameLump = function() return { version = 10, buffer = buffer } end,
		}, { __index = NikNaks.__metatables.BSP } )
		local prop = bsp:GetStaticProp( 0 )
		assert( prop.PropType == model and prop.Flags == 0x103 )
		assert( prop.FadeMinDist == 640 and prop.FadeMaxDist == 896 )
		assert( prop.MinDXLevel == 90 and prop.MaxDXLevel == 95 )
		assert( prop.lightmapResolutionX == 16 and prop.lightmapResolutionY == 32 )
		local indices = bsp:GetStaticPropLeafIndices()
		assert( indices[0] == 17 and indices[prop.First_leaf] == 42 and prop.LeafCount == 1 )
	end },
} }
