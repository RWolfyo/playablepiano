// Load the MIDI module if it exists
if ( file.Exists("lua/bin/gmcl_midi_win32.dll", "MOD") or
	 file.Exists("lua/bin/gmcl_midi_linux.dll", "MOD") or
	 file.Exists("lua/bin/gmcl_midi_osx.dll", "MOD") ) then
	
	require("midi")
end

local playablepiano_midi_port = CreateClientConVar("playablepiano_midi_port","0",true)
concommand.Add("playablepiano_midi_ports",function()
	local ports = midi.GetPorts()
	
	if not next(ports) then return end
	
	local port = ports[playablepiano_midi_port:GetInt()] or next(ports)
	
	for k,v in next,midi.GetPorts() do
		MsgN(k==port and "> " or "  ",k,"=",v)
	end
end)

local function GetActiveMIDIDevice()
	local ports = midi.GetPorts()
	
	if not next(ports) then return end
	
	return ports[playablepiano_midi_port:GetInt()] or next(ports)
end

function ENT:IsMIDIAvailable()
	return not not midi
end
function ENT:IsMIDIEnabled()
	return self:IsMIDIAvailable() and midi.IsOpened()
end
function ENT:GetActiveMIDIDevice()
	return GetActiveMIDIDevice()
end

function ENT:OpenMIDIHelp()
	gui.OpenURL("https://wyozi.github.io/playablepiano/#enabling-midi-support")
end

-- Number 128 obtained scientifically by smashing MIDI keys as hard as possible and recording the numbers.
-- Highest number obtained using this method was 127, and almost broke testing equipment, so it is deemed
-- to be the maximum achievable velocity.
--
-- However, we don't want equipment to break so this number is set to 100
local playablepiano_midi_maxvelocity = CreateClientConVar("playablepiano_midi_maxvelocity", "100", true)

local playablepiano_midi_hear = CreateClientConVar("playablepiano_midi_hear","0",true)
function ENT:OnMIDIKeyPressed(note, velocity)

	local normalizedVelocity = velocity / (playablepiano_midi_maxvelocity:GetFloat() or 100)

	self:OnRegisteredKeyPlayed( self.MIDIKeys[note].Sound, not playablepiano_midi_hear:GetBool(), normalizedVelocity )
	
	self.PressedMIDIKeys = self.PressedMIDIKeys or {}
	self.PressedMIDIKeys[note] = true
end
function ENT:OnMIDIKeyReleased(note, velocity)
	if self.PressedMIDIKeys then
		self.PressedMIDIKeys[note] = false
	end
end
function ENT:IsMIDIKeyDown(midiKey)
	return self.PressedMIDIKeys and self.PressedMIDIKeys[midiKey]
end

hook.Add( "MIDI", "gmt_instrument_base", function( time, command, note, velocity )
	if not command then ErrorNoHalt("MIDI: nil command??\n") return end

	local instrument = LocalPlayer()
	instrument = instrument and instrument:IsValid() and instrument
	instrument = instrument.Instrument 
	instrument = instrument and instrument:IsValid() and instrument
	
	if not instrument or not instrument.OnMIDIKeyPressed or not instrument.MIDIKeys or not instrument.MIDIKeys[note] then return end

	local commandName = midi.GetCommandName(command)

	if commandName == "NOTE_ON" and velocity > 0 then
    	instrument:OnMIDIKeyPressed(note, velocity)
	elseif commandName == "NOTE_OFF" or (commandName == "NOTE_ON" and velocity == 0) then
    	instrument:OnMIDIKeyReleased(note, velocity)
	end
end)

local g_port
local function OpenMIDI()
	
	if not midi then return end
	if midi.IsOpened() then return end
	
	local device = GetActiveMIDIDevice()
	if not device then return end

	midi.Open(device)
	
	g_port = port
end
hook.Add("OnInstrumentEntered", "OpenMIDI", OpenMIDI)

local function CloseMIDI()
	
	if not midi then return end
	if not midi.IsOpened() then return end
	local ports = midi.GetPorts()
	
	if not next(ports) then return end
	if not g_port or not ports[g_port] then return end
	local port = g_port
	g_port = nil
	midi.Close( port )
end
hook.Add("OnInstrumentExited", "CloseMIDI", CloseMIDI)