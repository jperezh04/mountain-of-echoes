import os
import wave
import struct
import math
import random

AUDIO_DIR = r"c:\Users\Jeremy\Repos\mountain-of-echoes\moe_editable\minigames\catcade\assets\audio"
os.makedirs(AUDIO_DIR, exist_ok=True)

SAMPLE_RATE = 22050

def write_wav(filename, samples):
    filepath = os.path.join(AUDIO_DIR, filename)
    with wave.open(filepath, "w") as f:
        f.setnchannels(1)        # Mono
        f.setsampwidth(2)        # 16-bit
        f.setframerate(SAMPLE_RATE)
        data = bytearray()
        for s in samples:
            val = int(max(-32767, min(32767, s * 32767)))
            data.extend(struct.pack("<h", val))
        f.writeframes(data)
    print(f"Generated: {filename} ({len(samples)} samples)")

def gen_launch():
    # Goofy rising meow-whoosh: starts around 400Hz, sweeps up to 900Hz and drops
    duration = 0.35
    total = int(SAMPLE_RATE * duration)
    samples = []
    phase = 0.0
    for i in range(total):
        t = i / float(SAMPLE_RATE)
        progress = t / duration
        # Frequency envelope
        freq = 450 + 600 * math.sin(progress * math.pi * 0.9)
        phase += 2 * math.pi * freq / SAMPLE_RATE
        # Volume envelope
        env = math.sin(progress * math.pi) ** 0.5
        # Soft harmonics
        val = (math.sin(phase) + 0.3 * math.sin(phase * 2) + 0.1 * math.sin(phase * 3)) * 0.7 * env
        samples.append(val)
    write_wav("cat_launch.wav", samples)

def gen_stretch():
    # Rubber band stretching sound (rapid low freq modulation)
    duration = 0.25
    total = int(SAMPLE_RATE * duration)
    samples = []
    phase = 0.0
    for i in range(total):
        t = i / float(SAMPLE_RATE)
        progress = t / duration
        freq = 120 + 280 * progress
        phase += 2 * math.pi * freq / SAMPLE_RATE
        env = (1.0 - progress * 0.4) * math.sin(progress * math.pi * 0.5)
        # Triangular-ish sound
        val = (4 * abs((phase / (2 * math.pi)) % 1 - 0.5) - 1) * 0.6 * env
        samples.append(val)
    write_wav("sling_stretch.wav", samples)

def gen_wood_hit():
    # Wooden clack / thud
    duration = 0.18
    total = int(SAMPLE_RATE * duration)
    samples = []
    phase = 0.0
    for i in range(total):
        t = i / float(SAMPLE_RATE)
        freq = max(60, 320 * math.exp(-25 * t))
        phase += 2 * math.pi * freq / SAMPLE_RATE
        noise = (random.random() * 2 - 1) * 0.3 * math.exp(-35 * t)
        val = (math.sin(phase) * 0.7 + noise) * math.exp(-18 * t)
        samples.append(val)
    write_wav("impact_wood.wav", samples)

def gen_stone_hit():
    # Deeper rock crunch
    duration = 0.22
    total = int(SAMPLE_RATE * duration)
    samples = []
    phase = 0.0
    for i in range(total):
        t = i / float(SAMPLE_RATE)
        freq = max(40, 180 * math.exp(-15 * t))
        phase += 2 * math.pi * freq / SAMPLE_RATE
        noise = (random.random() * 2 - 1) * 0.5 * math.exp(-20 * t)
        val = (math.sin(phase) * 0.5 + noise) * math.exp(-15 * t)
        samples.append(val)
    write_wav("impact_stone.wav", samples)

def gen_metal_hit():
    # High metallic ping / ring
    duration = 0.4
    total = int(SAMPLE_RATE * duration)
    samples = []
    p1, p2, p3 = 0.0, 0.0, 0.0
    for i in range(total):
        t = i / float(SAMPLE_RATE)
        p1 += 2 * math.pi * 920 / SAMPLE_RATE
        p2 += 2 * math.pi * 1840 / SAMPLE_RATE
        p3 += 2 * math.pi * 2760 / SAMPLE_RATE
        val = (0.5 * math.sin(p1) + 0.3 * math.sin(p2) + 0.15 * math.sin(p3)) * math.exp(-10 * t)
        samples.append(val)
    write_wav("impact_metal.wav", samples)

def gen_explosion():
    # Punchy explosion boom
    duration = 0.6
    total = int(SAMPLE_RATE * duration)
    samples = []
    phase = 0.0
    for i in range(total):
        t = i / float(SAMPLE_RATE)
        freq = max(35, 140 * (1.0 - t / duration))
        phase += 2 * math.pi * freq / SAMPLE_RATE
        noise = (random.random() * 2 - 1) * 0.8
        val = (math.sin(phase) * 0.5 + noise * 0.5) * math.exp(-6 * t)
        samples.append(val)
    write_wav("explosion.wav", samples)

def gen_enemy_hit():
    # Comical cartoon squeak/yelp
    duration = 0.2
    total = int(SAMPLE_RATE * duration)
    samples = []
    phase = 0.0
    for i in range(total):
        t = i / float(SAMPLE_RATE)
        freq = 300 + 700 * math.exp(-12 * t)
        phase += 2 * math.pi * freq / SAMPLE_RATE
        val = math.sin(phase) * 0.8 * (1.0 - t / duration)
        samples.append(val)
    write_wav("enemy_hit.wav", samples)

def gen_boost():
    # Rocket boost whoosh
    duration = 0.35
    total = int(SAMPLE_RATE * duration)
    samples = []
    phase = 0.0
    for i in range(total):
        t = i / float(SAMPLE_RATE)
        freq = 300 + 400 * (t / duration)
        phase += 2 * math.pi * freq / SAMPLE_RATE
        noise = (random.random() * 2 - 1) * 0.4
        val = (math.sin(phase) * 0.5 + noise * 0.5) * math.sin(math.pi * t / duration)
        samples.append(val)
    write_wav("cat_boost.wav", samples)

def gen_win_fanfare():
    # Bright cheerful victory notes (C5, E5, G5, C6)
    notes = [523.25, 659.25, 783.99, 1046.50]
    durations = [0.12, 0.12, 0.12, 0.45]
    samples = []
    for f, d in zip(notes, durations):
        n_samples = int(SAMPLE_RATE * d)
        phase = 0.0
        for i in range(n_samples):
            t = i / float(SAMPLE_RATE)
            phase += 2 * math.pi * f / SAMPLE_RATE
            env = math.exp(-2.5 * (t / d))
            # 8-bit square/triangle blend
            sq = 1.0 if (phase % (2 * math.pi)) < math.pi else -1.0
            tri = 4 * abs((phase / (2 * math.pi)) % 1 - 0.5) - 1
            val = (0.6 * tri + 0.4 * sq) * 0.6 * env
            samples.append(val)
    write_wav("level_win.wav", samples)

def gen_fail_sound():
    # Wah-wah sad game over
    notes = [440.0, 415.3, 392.0, 369.99]
    durations = [0.18, 0.18, 0.18, 0.4]
    samples = []
    for f, d in zip(notes, durations):
        n_samples = int(SAMPLE_RATE * d)
        phase = 0.0
        for i in range(n_samples):
            t = i / float(SAMPLE_RATE)
            phase += 2 * math.pi * f / SAMPLE_RATE
            env = math.exp(-2.0 * (t / d))
            val = math.sin(phase) * 0.6 * env
            samples.append(val)
    write_wav("level_fail.wav", samples)

if __name__ == "__main__":
    gen_launch()
    gen_stretch()
    gen_wood_hit()
    gen_stone_hit()
    gen_metal_hit()
    gen_explosion()
    gen_enemy_hit()
    gen_boost()
    gen_win_fanfare()
    gen_fail_sound()
    print("All audio files generated successfully!")
