extends Node
## Tiny synthesized sound effects, so the game needs no audio files yet.

const RATE := 22050
const VOICES := 12

var _streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_streams["pop"] = _tone(900.0, 0.09, -5000.0, "square", 0.25)
	_streams["coin"] = _arp([988.0, 1319.0], 0.06, "square", 0.2)
	_streams["shoot"] = _tone(600.0, 0.07, -4000.0, "noise", 0.25)
	_streams["hit"] = _tone(180.0, 0.15, -500.0, "square", 0.3)
	_streams["boom"] = _tone(120.0, 0.5, -150.0, "noise", 0.45)
	_streams["join"] = _arp([523.0, 659.0, 784.0], 0.07, "square", 0.2)
	_streams["unlock"] = _arp([392.0, 523.0, 659.0, 1047.0], 0.08, "tri", 0.3)
	_streams["catch"] = _tone(400.0, 0.18, 2500.0, "tri", 0.3)
	_streams["cast"] = _tone(700.0, 0.12, -2500.0, "noise", 0.12)
	_streams["land"] = _arp([523.0, 659.0, 784.0, 1047.0, 784.0, 1047.0], 0.1, "square", 0.25)
	_streams["crash"] = _tone(90.0, 0.8, -60.0, "noise", 0.5)
	_streams["jump"] = _tone(300.0, 0.08, 2500.0, "square", 0.12)
	_streams["refill"] = _arp([330.0, 440.0], 0.07, "tri", 0.3)
	_streams["shove"] = _tone(220.0, 0.1, -900.0, "noise", 0.3)
	_streams["tick"] = _tone(1200.0, 0.03, 0.0, "square", 0.12)
	_streams["burn"] = _tone(200.0, 0.25, -200.0, "noise", 0.15)
	_streams["empty"] = _tone(150.0, 0.06, 0.0, "square", 0.15)
	_streams["break"] = _tone(260.0, 0.1, -1200.0, "noise", 0.25)
	_streams["fall"] = _tone(800.0, 0.5, -1300.0, "tri", 0.25)


func play(sound: String, pitch := 1.0, volume_db := -8.0) -> void:
	if not _streams.has(sound):
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = _streams[sound]
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


func _tone(freq: float, dur: float, sweep: float, wave: String, vol: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var noise_val := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := maxf(20.0, freq + sweep * t)
		var prev := phase
		phase += f / RATE
		var v := 0.0
		match wave:
			"square":
				v = 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
			"tri":
				v = absf(fmod(phase, 1.0) * 4.0 - 2.0) - 1.0
			"noise":
				if int(phase) != int(prev):
					noise_val = randf() * 2.0 - 1.0
				v = noise_val
		var env := minf(1.0, t / 0.005) * (1.0 - float(i) / n)
		data.encode_s16(i * 2, int(clampf(v * env * vol, -1.0, 1.0) * 32767.0))
	return _wav(data)


func _arp(notes: Array[float], step: float, wave: String, vol: float) -> AudioStreamWAV:
	var data := PackedByteArray()
	for f in notes:
		data.append_array(_tone(f, step, 0.0, wave, vol).data)
	return _wav(data)


func _wav(data: PackedByteArray) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
