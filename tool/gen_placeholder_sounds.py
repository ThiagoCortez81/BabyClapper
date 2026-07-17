import wave, struct, random, math, os

SR = 44100
os.makedirs("assets/sounds", exist_ok=True)


def write_wav(path, samples):
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        data = b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples
        )
        w.writeframes(data)


def bead(dur=0.08, seed=0):
    rnd = random.Random(seed)
    n = int(SR * dur)
    return [rnd.uniform(-1, 1) * math.exp(-i / (SR * 0.015)) * 0.7 for i in range(n)]


def rattle(dur=0.5, beads=7, seed=42):
    rnd = random.Random(seed)
    n = int(SR * dur)
    out = [0.0] * n
    for _ in range(beads):
        start = rnd.randint(0, n - 1)
        for j, s in enumerate(bead(0.05, seed=rnd.randint(0, 9999))):
            if start + j < n:
                out[start + j] += s * 0.6
    return [max(-1.0, min(1.0, s)) for s in out]


write_wav("assets/sounds/bead.wav", bead())
write_wav("assets/sounds/rattle.wav", rattle())
print("wrote assets/sounds/bead.wav and assets/sounds/rattle.wav")
