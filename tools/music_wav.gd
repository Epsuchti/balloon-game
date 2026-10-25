extends SceneTree
## Renders the soundtrack to WAV files for listening:  godot --headless --path . -s tools/music_wav.gd -- out_dir
func _init() -> void:
	var M = load("res://scripts/autoload/music.gd")
	for track in M.TRACKS:
		var t0 := Time.get_ticks_msec()
		var s: AudioStreamWAV = M.render(track)
		print(track, " rendered in ", Time.get_ticks_msec() - t0, " ms")
		s.save_to_wav(OS.get_cmdline_user_args()[0] + "/" + track + ".wav")
	quit()
