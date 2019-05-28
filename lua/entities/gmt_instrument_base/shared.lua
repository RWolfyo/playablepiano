ENT.Base = "base_anim";
ENT.Type = "anim";
ENT.PrintName = "Instrument Base";
ENT.Model = Model( "models/fishy/furniture/piano.mdl" );
ENT.ChairModel = Model( "models/fishy/furniture/piano_seat.mdl" );
ENT.MaxKeys = 4; -- how many keys can be played at once
ENT.SoundDir = "GModTower/lobby/piano/note_";
ENT.SoundExt = ".wav";
INSTNET_USE = 1;
INSTNET_HEAR = 2;
INSTNET_PLAY = 3;

--ENT.Keys = {}
ENT.ControlKeys = {
	[ KEY_TAB ] = function( inst, bPressed )
		if ( not bPressed ) then return; end
		RunConsoleCommand( "instrument_leave", inst:EntIndex( ) );
	end,
	[ KEY_SPACE ] = function( inst, bPressed )
		if ( not bPressed ) then return; end
		inst:ToggleSheetMusic( );
	end,
	[ KEY_LEFT ] = function( inst, bPressed )
		if ( not bPressed ) then return; end
		inst:SheetMusicBack( );
	end,
	[ KEY_RIGHT ] = function( inst, bPressed )
		if ( not bPressed ) then return; end
		inst:SheetMusicForward( );
	end,
	[ KEY_LCONTROL ] = function( inst, bPressed )
		if ( not bPressed ) then return; end
		inst:CtrlMod( );
	end,
	[ KEY_RCONTROL ] = function( inst, bPressed )
		if ( not bPressed ) then return; end
		inst:CtrlMod( );
	end,
	[ KEY_LSHIFT ] = function( inst, bPressed )
		inst:ShiftMod( );
	end,
	[ KEY_F3 ] = function( inst, bPressed )
		if ( not bPressed ) then return; end
		inst:OpenMIDIHelp( );
	end
};

function ENT:GetSound( snd )
	if ( snd == nil or snd == "" ) then return nil; end

	return self.SoundDir .. snd .. self.SoundExt;
end

hook.Add( "PhysgunPickup", "NoPickupInsturmentChair", function( ply, ent )
	local inst = ent:GetOwner( );
	if IsValid( inst ) and inst.Base == "gmt_instrument_base" then return false; end
end );