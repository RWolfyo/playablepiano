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

local playablepiano_midi_hear = CreateClientConVar("playablepiano_midi_hear","0",true)
hook.Add( "MIDI", "gmt_instrument_base", function( time, command, note, velocity )
	local instrument = LocalPlayer()
	instrument = instrument and instrument:IsValid() and instrument
	instrument = instrument.Instrument 
	instrument = instrument and instrument:IsValid() and instrument
	
	if not instrument then return end
    
	// Zero velocity NOTE_ON substitutes NOTE_OFF
	
	-- bad argument #1 to 'GetCommandName' (number expected, got nil)
	if not command then ErrorNoHalt("MIDI: nil command??\n") return end
	
    if !midi || midi.GetCommandName( command ) != "NOTE_ON" || velocity == 0 || !instrument.MIDIKeys || !instrument.MIDIKeys[note] then return end
	
	if not instrument.OnRegisteredKeyPlayed then return end
	
    instrument:OnRegisteredKeyPlayed( instrument.MIDIKeys[note].Sound, not playablepiano_midi_hear:GetBool() )
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