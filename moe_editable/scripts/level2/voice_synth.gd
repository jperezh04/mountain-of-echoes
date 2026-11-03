class_name AbyssVoiceSynth
extends RefCounted
## Sintetizador procedural PCM 16-bit para las "mini voces" en la oscuridad (estilo Undertale / Celeste),
## acordes psicológicos de los Ecos de Rencor, campanas de eco y ambiente estilo Pueblo Lavanda.

const MIX_RATE := 22050


static func _pack_pcm16(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		var v: int = clampi(int(samples[i] * 32767.0), -32768, 32767)
		bytes.encode_s16(i * 2, v)
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav


## Timbre frío, rasposo y ligeramente disonante para los murmullos acusadores del pueblo.
static func make_village_blip(base_hz: float = 148.0) -> AudioStreamWAV:
	var dur := 0.068
	var count := int(MIX_RATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(count)
	for i in range(count):
		var t := float(i) / float(MIX_RATE)
		var env := sin((float(i) / float(count)) * PI) * exp(-t * 14.0)
		var vibrato := sin(t * TAU * 28.0) * 4.5
		var f1 := base_hz + vibrato
		var f2 := base_hz * 1.414 # Intervalo tritono inquietante (estilo Pueblo Lavanda)
		var sq := 1.0 if sin(t * TAU * f1) >= 0.0 else -1.0
		var sub := sin(t * TAU * f2) * 0.45 + sin(t * TAU * (f1 * 0.5)) * 0.35
		buf[i] = (sq * 0.22 + sub * 0.28) * env
	return _pack_pcm16(buf)


## Timbre cálido, melódico y sereno para la voz del hermano en la oscuridad.
static func make_brother_blip(base_hz: float = 278.0) -> AudioStreamWAV:
	var dur := 0.075
	var count := int(MIX_RATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(count)
	for i in range(count):
		var t := float(i) / float(MIX_RATE)
		var env := sin((float(i) / float(count)) * PI) * exp(-t * 9.5)
		var fundamental := sin(t * TAU * base_hz)
		var fifth := sin(t * TAU * base_hz * 1.498) * 0.38
		var octave := sin(t * TAU * base_hz * 2.0) * 0.16
		buf[i] = (fundamental * 0.34 + fifth + octave) * env * 0.72
	return _pack_pcm16(buf)


## Golpe psicológico grave (sin grito estridente) al activar un Ítem Trampa / Eco de Rencor.
static func make_rancor_chord() -> AudioStreamWAV:
	var dur := 0.62
	var count := int(MIX_RATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(count)
	for i in range(count):
		var t := float(i) / float(MIX_RATE)
		var env := minf(1.0, t * 45.0) * exp(-t * 4.2)
		var w1 := sin(t * TAU * 110.0) * 0.42
		var w2 := sin(t * TAU * 155.56) * 0.32 # Tritono sombrío
		var w3 := sin(t * TAU * 233.08 + sin(t * 24.0) * 0.6) * 0.22
		buf[i] = (w1 + w2 + w3) * env * 0.75
	return _pack_pcm16(buf)


## Campana / cristal resonante para distraer al algoritmo A* de la Sombra.
static func make_bell_chime() -> AudioStreamWAV:
	var dur := 0.78
	var count := int(MIX_RATE * dur)
	var buf := PackedFloat32Array()
	buf.resize(count)
	for i in range(count):
		var t := float(i) / float(MIX_RATE)
		var env := minf(1.0, t * 80.0) * exp(-t * 4.8)
		var c1 := sin(t * TAU * 587.33) * 0.38
		var c2 := sin(t * TAU * 880.0) * 0.25
		var c3 := sin(t * TAU * 1244.5) * 0.14
		buf[i] = (c1 + c2 + c3) * env * 0.7
	return _pack_pcm16(buf)


## Ambiente en bucle estilo caja musical fantasmal (inspirado en Pueblo Lavanda + zumbido FNaF).
## El usuario puede reemplazarlo fácilmente en el nodo $Audio/Music desde el editor de Godot.
static func make_lavender_drone_loop() -> AudioStreamWAV:
	# 4 notas lentas misteriosas (C6 - G5 - B5 - F#5) de 1.2s cada una = 4.8s loop limpio
	var notes := [1046.5, 783.99, 987.77, 739.99]
	var note_dur := 1.2
	var total_dur := note_dur * notes.size()
	var count := int(MIX_RATE * total_dur)
	var buf := PackedFloat32Array()
	buf.resize(count)
	for i in range(count):
		var t := float(i) / float(MIX_RATE)
		var n_idx := mini(notes.size() - 1, int(t / note_dur))
		var local_t := t - float(n_idx) * note_dur
		var freq: float = notes[n_idx]
		# Envolvente suave de caja musical lejana en cueva
		var bell_env := minf(1.0, local_t * 30.0) * exp(-local_t * 2.9)
		var bell := (sin(local_t * TAU * freq) * 0.22 + sin(local_t * TAU * freq * 2.0) * 0.07) * bell_env
		# Zumbido grave continuo subterráneo (ciclo exacto para loop sin clic)
		var drone := sin(t * TAU * (55.0)) * 0.14 + sin(t * TAU * (82.5)) * 0.08
		var pulse := 0.8 + 0.2 * sin((t / total_dur) * TAU * 2.0)
		buf[i] = (bell + drone * pulse) * 0.55
	return _pack_pcm16(buf, true)
