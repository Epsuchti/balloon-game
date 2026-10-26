extends Node
## 8-bit soundtrack, synthesized at startup like the sound effects (no audio files). Each track is
## written below as chords, a lead melody and a drum pattern, then rendered into a looping
## square/triangle/noise chiptune, one track per frame right after startup (well under a second each).
## Music is on by default; M mutes and unmutes it, and the choice is remembered.

const RATE := 22050
const VOLUME_DB := -5.0
const FADE := 0.6

## Note strings: one token per eighth note. "a4", "c#5", "bb4" play a note, "-" holds the previous
## one, "." is a rest. Drums: k = kick, s = snare, h = hi-hat, . = nothing.
const TRACKS := {
	"menu": {
		"bpm": 104, "drums": "k.h.s.h.", "lead_wave": 0.5,
		"chords": ["C", "Am", "F", "G", "C", "Am", "F", "G"],
		"lead": [
			"e5 - g5 - c6 - g5 -", "a5 - - - e5 - c5 -", "f5 - a5 - c6 - a5 -", "g5 - - - d5 - b4 -",
			"e5 - g5 - c6 - d6 -", "e6 - - - c6 - a5 -", "f5 - a5 - g5 - f5 -", "d5 - - - g5 - . .",
		],
	},
	"flight": {
		"bpm": 138, "drums": "k.hsk.hs", "lead_wave": 0.25,
		"chords": ["Am", "F", "C", "G", "Am", "F", "G", "E", "Am", "F", "C", "G", "Am", "F", "G", "E"],
		"lead": [
			"a4 - c5 e5 - d5 c5 -", "a4 - - - f4 - a4 -", "g4 - c5 e5 - g5 e5 -", "d5 - - - b4 - d5 -",
			"e5 - a5 - g5 e5 c5 -", "d5 - c5 a4 - c5 d5 -", "b4 - d5 g5 - f5 d5 b4", "g#4 - b4 - e5 - - -",
			"c6 - b5 a5 - e5 - -", "f5 - e5 f5 - a5 - -", "g5 - e5 c5 - e5 g5 -", "b5 - - a5 g5 - d5 -",
			"a5 - - g5 a5 - c6 -", "a5 - f5 - c5 - f5 a5", "g5 - d5 - b4 - d5 f5", "e5 - g#5 - b5 - e5 -",
		],
	},
	"danger": {
		"bpm": 160, "drums": "khshkhss", "lead_wave": 0.25,
		"chords": ["Dm", "Bb", "C", "A", "Dm", "Bb", "C", "A", "Dm", "Bb", "C", "A", "Dm", "Bb", "C", "A"],
		"lead": [
			"d5 f5 a5 f5 d5 f5 a5 f5", "d5 f5 bb5 f5 d5 f5 bb5 f5", "e5 g5 c6 g5 e5 g5 c6 g5", "c#5 e5 a5 e5 c#5 e5 g5 e5",
			"d6 - a5 - f5 - a5 -", "bb5 - f5 - d5 - f5 -", "c6 - g5 - e5 - g5 c6", "c#6 - - - a5 - e5 -",
		],
	},
}
const CHORDS := {
	"C": [0, 4, 7], "Am": [9, 12, 16], "F": [5, 9, 12], "G": [7, 11, 14], "E": [4, 8, 11],
	"Dm": [2, 5, 9], "Bb": [-2, 2, 5], "A": [9, 13, 16],
}
const NOTE_INDEX := {"c": 0, "d": 2, "e": 4, "f": 5, "g": 7, "a": 9, "b": 11}

var muted := false
var _streams := {}
var _player: AudioStreamPlayer
var _want := ""
var _playing := ""
var _to_render: Array[String] = []
var _settings := ConfigFile.new()

const SETTINGS_PATH := "user://settings.cfg"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.volume_db = -80.0
	add_child(_player)
	_settings.load(SETTINGS_PATH)
	muted = _settings.get_value("audio", "music_muted", false)
	if DisplayServer.get_name() != "headless":
		_to_render = ["menu", "flight", "danger"]


## Switch to a track ("" for silence). It fades in once it has been rendered.
func play(track: String) -> void:
	_want = track


func _process(dt: float) -> void:
	if not _to_render.is_empty():
		var track: String = _to_render.pop_front()
		_streams[track] = render(track)
	var target := "" if muted else _want
	if _playing != target:
		_player.volume_db = move_toward(_player.volume_db, -60.0, 60.0 / FADE * dt)
		if _player.volume_db <= -59.0 or not _player.playing:
			_player.stop()
			_playing = ""
			if target != "" and _streams.has(target):
				_player.stream = _streams[target]
				_player.volume_db = -40.0
				_player.play()
				_playing = target
	elif _playing != "":
		_player.volume_db = move_toward(_player.volume_db, VOLUME_DB, 40.0 / FADE * dt)


func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo and k.physical_keycode == KEY_M:
		set_muted(not muted)


signal muted_changed(muted: bool)


func set_muted(on: bool) -> void:
	muted = on
	_settings.set_value("audio", "music_muted", muted)
	_settings.save(SETTINGS_PATH)
	muted_changed.emit(muted)


# --- Synthesis ---

static func _note_freq(token: String) -> float:
	var name := token.substr(0, token.length() - 1)
	var octave := int(token.substr(token.length() - 1))
	var semi: int = NOTE_INDEX[name[0]]
	if name.length() > 1:
		semi += 1 if name[1] == "#" else -1
	return _midi_freq(12 * (octave + 1) + semi)


static func _midi_freq(midi: int) -> float:
	return 440.0 * pow(2.0, (midi - 69) / 12.0)


## Renders one track to a looping stream.
static func render(track: String) -> AudioStreamWAV:
	var t: Dictionary = TRACKS[track]
	var step := 60.0 / float(t["bpm"]) / 2.0            # one eighth note, in seconds
	var bars: int = t["chords"].size()
	var n := int(step * 8 * bars * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	# Lead melody.
	for bar in bars:
		var tokens: PackedStringArray = t["lead"][bar % t["lead"].size()].split(" ")
		var i := 0
		while i < tokens.size():
			var tok := tokens[i]
			if tok == "-" or tok == ".":
				i += 1
				continue
			var len := 1
			while i + len < tokens.size() and tokens[i + len] == "-":
				len += 1
			_voice(buf, (bar * 8 + i) * step, len * step, _note_freq(tok), t["lead_wave"], 0.13, true)
			i += len
	# Bass (triangle, root with octave jumps) and a quiet 16th-note arpeggio.
	for bar in bars:
		var chord: Array = CHORDS[t["chords"][bar]]
		var root: int = 36 + (chord[0] % 12 + 12) % 12
		for s in 8:
			if s % 4 == 1:
				continue
			var m := root + (12 if s % 2 == 1 else 0)
			_voice(buf, (bar * 8 + s) * step, step * 0.9, _midi_freq(m), -1.0, 0.2, false)
		for s in 16:
			var m: int = 60 + chord[s % 3] + (12 if (s / 3) % 2 == 1 else 0)
			_voice(buf, (bar * 8 + s * 0.5) * step, step * 0.45, _midi_freq(m), 0.125, 0.035, false)
	# Drums.
	var pattern: String = t["drums"]
	for bar in bars:
		for s in 8:
			var at := (bar * 8 + s) * step
			match pattern[s]:
				"k":
					_kick(buf, at)
				"s":
					_snare(buf, at)
				"h":
					_hat(buf, at)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w


## A pulse wave with this duty cycle (or a triangle for duty < 0), with a short attack and decay.
static func _voice(buf: PackedFloat32Array, start: float, dur: float, freq: float, duty: float, vol: float, vibrato: bool) -> void:
	var i0 := int(start * RATE)
	var len := int(dur * RATE)
	var phase := 0.0
	for j in len:
		var i := i0 + j
		if i >= buf.size():
			return
		var tt := float(j) / RATE
		var f := freq
		if vibrato and tt > 0.18:
			f *= 1.0 + 0.006 * sin(tt * 34.0)
		phase = fmod(phase + f / RATE, 1.0)
		var v := 0.0
		if duty < 0.0:
			v = absf(phase * 4.0 - 2.0) - 1.0
		else:
			v = 1.0 if phase < duty else -1.0
		var env := minf(1.0, tt / 0.004) * lerpf(1.0, 0.65, minf(1.0, tt / 0.12))
		env *= minf(1.0, float(len - j) / (RATE * 0.015))
		buf[i] += v * env * vol


static func _kick(buf: PackedFloat32Array, start: float) -> void:
	var i0 := int(start * RATE)
	var len := int(0.13 * RATE)
	var phase := 0.0
	for j in len:
		var i := i0 + j
		if i >= buf.size():
			return
		var tt := float(j) / RATE
		phase = fmod(phase + lerpf(150.0, 40.0, tt / 0.13) / RATE, 1.0)
		buf[i] += (absf(phase * 4.0 - 2.0) - 1.0) * (1.0 - tt / 0.13) * 0.4


static func _snare(buf: PackedFloat32Array, start: float) -> void:
	var i0 := int(start * RATE)
	var len := int(0.12 * RATE)
	var noise := 0.0
	for j in len:
		var i := i0 + j
		if i >= buf.size():
			return
		if j % 2 == 0:
			noise = randf() * 2.0 - 1.0
		buf[i] += noise * pow(1.0 - float(j) / len, 2.0) * 0.16


static func _hat(buf: PackedFloat32Array, start: float) -> void:
	var i0 := int(start * RATE)
	var len := int(0.03 * RATE)
	for j in len:
		var i := i0 + j
		if i >= buf.size():
			return
		buf[i] += (randf() * 2.0 - 1.0) * (1.0 - float(j) / len) * 0.05
