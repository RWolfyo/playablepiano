include("shared.lua")
include("cl_midi.lua")

ENT.DEBUG = false

ENT.KeysDown = {}
ENT.KeysWasDown = {}

ENT.AllowAdvancedMode = false
ENT.AdvancedMode = false
ENT.ShiftMode = false

ENT.PageTurnSound = Sound( "GModTower/inventory/move_paper.wav" )
surface.CreateFont( "InstrumentKeyLabel", {
	size = 22, weight = 400, antialias = true, font = "Impact"
} )
surface.CreateFont( "InstrumentNotice", {
	size = 30, weight = 400, antialias = true, font = "Impact"
} )

--  For drawing purposes
--  Override by adding MatWidth/MatHeight to key data
ENT.DefaultMatWidth = 128
ENT.DefaultMatHeight = 128
--  Override by adding TextX/TextY to key data
ENT.DefaultTextX = 5
ENT.DefaultTextY = 10
ENT.DefaultTextColor = Color( 150, 150, 150, 255 )
ENT.DefaultTextColorActive = Color( 80, 80, 80, 255 )
ENT.DefaultTextInfoColor = Color( 120, 120, 120, 150 )

ENT.MaterialDir	= ""
ENT.KeyMaterials = {}

ENT.MainHUD = {
	Material = nil,
	X = 0,
	Y = 0,
	TextureWidth = 128,
	TextureHeight = 128,
	Width = 128,
	Height = 128,
}

ENT.AdvMainHUD = {
	Material = nil,
	X = 0,
	Y = 0,
	TextureWidth = 128,
	TextureHeight = 128,
	Width = 128,
	Height = 128,
}

ENT.BrowserHUD = {
	URL = "https://www.google.com",
	Show = true, --  display the sheet music?
	X = 0,
	Y = 0,
	Width = 1024,
	Height = 768,
}

function ENT:Initialize()
	self:PrecacheMaterials()
end

function ENT:Think()

	if not IsValid( LocalPlayer().Instrument ) or LocalPlayer().Instrument == not self then return end

	if self.DelayKey and self.DelayKey > CurTime() then return end

	--  Update last pressed
	for keylast, keyData in pairs( self.KeysDown ) do
		self.KeysWasDown[ keylast ] = self.KeysDown[ keylast ]
	end

	--  Get keys
	for key, keyData in pairs( self.Keys ) do

		--  Update key status
		self.KeysDown[ key ] = input.IsKeyDown( key )

		--  Check for note keys
		if self:IsKeyTriggered( key ) then

			if self.ShiftMode and keyData.Shift then
				self:OnRegisteredKeyPlayed( keyData.Shift.Sound )
			elseif not self.ShiftMode then
				self:OnRegisteredKeyPlayed( keyData.Sound )
			end

		end

	end

	--  Get control keys
	for key, keyData in pairs( self.ControlKeys ) do

		--  Update key status
		self.KeysDown[ key ] = input.IsKeyDown( key )

		--  Check for control keys
		if self:IsKeyTriggered( key ) then
			keyData( self, true )
		end

		--  was a control key released?
		if self:IsKeyReleased( key ) then
			keyData( self, false )
		end

	end

	--  Send da keys to everyone
	-- self:SendKeys()

end

function ENT:PlayKey(key, velocity)
	local sound = self:GetSound( key )
	if sound then
		self:EmitSound(sound, 80, nil, velocity or 1)
	end

end

function ENT:IsKeyTriggered( key )
	return self.KeysDown[ key ] and not self.KeysWasDown[ key ]
end

function ENT:IsKeyReleased( key )
	return self.KeysWasDown[ key ] and not self.KeysDown[ key ]
end

function ENT:OnRegisteredKeyPlayed( key, suppressSound, velocity )
	velocity = math.Clamp(velocity or 0.8, 0, 1)

	if ( not suppressSound ) then
		-- Play on local client
		self:PlayKey(key, velocity)
	end

	--  Network it
	net.Start( "InstrumentNetwork" )

		net.WriteEntity( self )
		net.WriteInt( INSTNET_PLAY, 3 )
		net.WriteString( key )
		net.WriteFloat( velocity )

	net.SendToServer()

	--  Add the notes (limit to max notes)
	/*if #self.KeysToSend < self.MaxKeys then

		if not table.HasValue( self.KeysToSend, key ) then --  only different notes, please
			table.insert( self.KeysToSend, key )
		end

	end*/

end

--  Network it up, yo
function ENT:SendKeys()

	if not self.KeysToSend then return end

	--  Send the queue of notes to everyone

	--  Play on the client first
	for _, key in ipairs( self.KeysToSend ) do

		local sound = self:GetSound( key )

		if sound then
			self:EmitSound( sound, 100 )
		end

	end

	--  Clear queue
	self.KeysToSend = nil

end

function ENT:IsKeyDown(key, shift)
	shift = not not shift -- make sure it's bool

	if input.IsKeyDown(key) and input.IsShiftDown() == shift then
		return true
	end

	if self.MIDIKeys then
		for midiKey, data in pairs(self.MIDIKeys) do
			if data.Key == key and (not not data.Shift) == shift then
				if self:IsMIDIKeyDown(midiKey) then
					return true
				else
					break
				end
			end
		end
	end

	return false
end

function ENT:DrawKey( mainX, mainY, key, keyData, bShiftMode )

	local keyDown = self:IsKeyDown(key, bShiftMode)

	if keyData.Material and keyDown then
		surface.SetTexture( self.KeyMaterialIDs[ keyData.Material ] )
		surface.DrawTexturedRect( mainX + keyData.X, mainY + keyData.Y,
									self.DefaultMatWidth, self.DefaultMatHeight )
	end

	--  Draw keys
	if keyData.Label then

		local offsetX = self.DefaultTextX
		local offsetY = self.DefaultTextY
		local color = self.DefaultTextColor

		if keyDown then
			color = self.DefaultTextColorActive
			if keyData.AColor then color = keyData.AColor end
		else
			if keyData.Color then color = keyData.Color end
		end

		--  Override positions, if needed
		if keyData.TextX then offsetX = keyData.TextX end
		if keyData.TextY then offsetY = keyData.TextY end

		draw.DrawText( keyData.Label, "InstrumentKeyLabel",
						mainX + keyData.X + offsetX,
						mainY + keyData.Y + offsetY,
						color, TEXT_ALIGN_CENTER )
	end
end

function ENT:DrawHUD()

	surface.SetDrawColor( 255, 255, 255, 255 )

	local mainX, mainY, mainWidth, mainHeight

	--  Draw main
	if self.MainHUD.Material and not self.AdvancedMode then

		mainX, mainY, mainWidth, mainHeight = self.MainHUD.X, self.MainHUD.Y, self.MainHUD.Width, self.MainHUD.Height

		surface.SetTexture( self.MainHUD.MatID )
		surface.DrawTexturedRect( mainX, mainY, self.MainHUD.TextureWidth, self.MainHUD.TextureHeight )

	end

	--  Advanced main
	if self.AdvMainHUD.Material and self.AdvancedMode then

		mainX, mainY, mainWidth, mainHeight = self.AdvMainHUD.X, self.AdvMainHUD.Y, self.AdvMainHUD.Width, self.AdvMainHUD.Height

		surface.SetTexture( self.AdvMainHUD.MatID )
		surface.DrawTexturedRect( mainX, mainY, self.AdvMainHUD.TextureWidth, self.AdvMainHUD.TextureHeight )

	end

	--  Draw keys (over top of main)
	for key, keyData in pairs( self.Keys ) do

		self:DrawKey( mainX, mainY, key, keyData, false )

		if keyData.Shift then
			self:DrawKey( mainX, mainY, key, keyData.Shift, true )
		end
	end

	--  Sheet music help
	if not IsValid( self.Browser ) and self.BrowserHUD.Show then

		draw.DrawText( "SPACE FOR SHEET MUSIC", "InstrumentKeyLabel",
						mainX + ( mainWidth / 2 ), mainY + 60,
						self.DefaultTextInfoColor, TEXT_ALIGN_CENTER )

	end

	--  Advanced mode
	if self.AllowAdvancedMode and not self.AdvancedMode then

		draw.DrawText( "CONTROL FOR ADVANCED MODE", "InstrumentKeyLabel",
						mainX + ( mainWidth / 2 ), mainY + mainHeight + 30,
						self.DefaultTextInfoColor, TEXT_ALIGN_CENTER )

	elseif self.AllowAdvancedMode and self.AdvancedMode then

		draw.DrawText( "CONTROL FOR BASIC MODE", "InstrumentKeyLabel",
						mainX + ( mainWidth / 2 ), mainY + mainHeight + 30,
						self.DefaultTextInfoColor, TEXT_ALIGN_CENTER )
	end

	if self.AdvancedMode then

		local text
		if self:IsMIDIEnabled() then
			text = "ON (" .. (self:GetActiveMIDIDevice() or "unknown") .. ")"
		else
			text = "OFF (PRESS F3 FOR HELP)"
		end

		draw.DrawText( "MIDI: " .. text, "InstrumentKeyLabel",
						mainX + 15, mainY + mainHeight + 30,
						self.DefaultTextInfoColor, TEXT_ALIGN_LEFT )

	end

end

--  This is so I dont have to do GetTextureID in the table EACH TIME, ugh
function ENT:PrecacheMaterials()

	if not self.Keys then return end

	self.KeyMaterialIDs = {}

	for name, keyMaterial in pairs( self.KeyMaterials ) do
		if type( keyMaterial ) == "string" then --  TODO: what the fuck, this table is randomly created
			self.KeyMaterialIDs[name] = surface.GetTextureID( keyMaterial )
		end
	end

	if self.MainHUD.Material then
		self.MainHUD.MatID = surface.GetTextureID( self.MainHUD.Material )
	end

	if self.AdvMainHUD.Material then
		self.AdvMainHUD.MatID = surface.GetTextureID( self.AdvMainHUD.Material )
	end

end

function ENT:OpenSheetMusic()

	if IsValid( self.Browser ) or not self.BrowserHUD.Show then return end

	self.Browser = vgui.Create( "HTML" )
	self.Browser:SetVisible( false )

	local width = self.BrowserHUD.Width

	if self.BrowserHUD.AdvWidth and self.AdvancedMode then
		width = self.BrowserHUD.AdvWidth
	end

	local url = self.BrowserHUD.URL

	local x = self.BrowserHUD.X - ( width / 2 )

	self.Browser:OpenURL( url )

	--  This is delayed because otherwise it wont load at all
	--  for some silly reason...
	timer.Simple( .1, function()

		if IsValid( self.Browser ) then
			self.Browser:SetVisible( true )
			self.Browser:SetPos( x, self.BrowserHUD.Y )
			self.Browser:SetSize( width, self.BrowserHUD.Height )
		end

	end )

	-- Loading JS context may take a bit longer
	timer.Simple( 0.5, function()
		if IsValid( self.Browser ) then
			self:UpdateSheetMusicState()
		end
	end)
end

function ENT:CloseSheetMusic()

	if not IsValid( self.Browser ) then return end

	self.Browser:Remove()
	self.Browser = nil

end

function ENT:ToggleSheetMusic()

	if IsValid( self.Browser ) then
		self:CloseSheetMusic()
	else
		self:OpenSheetMusic()
	end

end

function ENT:UpdateSheetMusicState()
	local level = self.AdvancedMode and "advanced" or "basic"
	self.Browser:Exec( "switchLevel('" .. level .. "')" )
end

function ENT:SheetMusicForward()

	if not IsValid( self.Browser ) then return end

	self.Browser:Exec( "pageForward()" )
	self:EmitSound( self.PageTurnSound, 100, math.random( 120, 150 ) )

end

function ENT:SheetMusicBack()

	if not IsValid( self.Browser ) then return end

	self.Browser:Exec( "pageBack()" )
	self:EmitSound( self.PageTurnSound, 100, math.random( 100, 120 ) )

end


local g_dummy
function ENT:CaptureAllKeys(capture)
	if capture == true then

		if g_dummy and g_dummy:IsValid() then return end

		g_dummy = vgui.Create("EditablePanel")

		g_dummy:Dock(FILL)
		function g_dummy:OnMouseReleased()
			self:Remove()

			local instrument = LocalPlayer().Instrument
			instrument = instrument and instrument:IsValid() and instrument

			RunConsoleCommand( "instrument_leave", instrument and instrument:EntIndex() )

		end
		g_dummy:MakePopup()
		g_dummy:SetMouseInputEnabled(false)
		g_dummy:SetKeyboardInputEnabled(true)

		return

	end

	if g_dummy and g_dummy:IsValid() then g_dummy:Remove() end

end

function ENT:OnRemove()

	self:CloseSheetMusic()
	self:CaptureAllKeys(false)

end

function ENT:Shutdown()

	self:CloseSheetMusic()

	self:CaptureAllKeys(false)

	self.AdvancedMode = false
	self.ShiftMode = false
end

function ENT:ToggleAdvancedMode()
	self.AdvancedMode = not self.AdvancedMode

	if not IsValid( self.Browser ) then return end

	self:UpdateSheetMusicState()
end

function ENT:ToggleShiftMode()
	self.ShiftMode = not self.ShiftMode
end

function ENT:ShiftMod() end --  Called when they press shift
function ENT:CtrlMod() end --  Called when they press cntrl

hook.Add( "HUDPaint", "InstrumentPaint", function()

	if IsValid( LocalPlayer().Instrument ) then

		--  HUD
		local inst = LocalPlayer().Instrument
		inst:DrawHUD()

		--  Notice bar
		local name = inst.PrintName or "INSTRUMENT"
		name = string.upper( name )

		surface.SetDrawColor( 0, 0, 0, 180 )
		surface.DrawRect( 0, ScrH() - 60, ScrW(), 60 )

		draw.SimpleText( "PRESS TAB TO LEAVE THE " .. name, "InstrumentNotice", ScrW() / 2, ScrH() - 35, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1 )

	end

end )

local playablepiano_hear = CreateClientConVar("playablepiano_hear", "1", true)

net.Receive( "InstrumentNetwork", function( length, client )

	local ent = net.ReadEntity()
	local enum = net.ReadInt( 3 )

	--  When the player uses it or leaves it
	if enum == INSTNET_USE then

		if IsValid( LocalPlayer().Instrument ) then
			hook.Run("OnInstrumentExited", LocalPlayer().Instrument)
			LocalPlayer().Instrument:Shutdown()
		end

		LocalPlayer().Instrument = ent

		if ent and ent:IsValid() then
			ent.DelayKey = CurTime() + .1 --  delay to the key a bit so they dont play on use key

			ent:CaptureAllKeys(true)
			hook.Run("OnInstrumentEntered", ent)
		end

	--  Play the notes for everyone else
	elseif enum == INSTNET_HEAR then

		--  Instrument doesnt exist
		if not IsValid( ent ) then return end

		if not ent.GetSound then return end

		--  Dont play for the owner, theyve already heard itnot 
		if IsValid( LocalPlayer().Instrument ) and LocalPlayer().Instrument == ent then
			return
		end

		if not playablepiano_hear:GetBool() then return end

		--  Gather note
		local key = net.ReadString()
		local velocity = net.ReadFloat()

		if sound then
			ent:PlayKey(key, velocity)
		end
	end
end )
