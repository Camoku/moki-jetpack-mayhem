# ==========================================================
#  gen_audio.py - procedurally generate the game's 8-bit audio
# ==========================================================
#  Synthesizes every SFX (square/triangle/noise + envelopes + pitch
#  sweeps = the classic chiptune toolkit) plus a looping music track,
#  and writes them as .wav into res://audio/. Re-run to tweak:
#     python tools/gen_audio.py
#  Beginner-friendly: each sound is a small function you can tune.
# ==========================================================
import os
import numpy as np
from scipy.io import wavfile

SR = 44100
HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SFX_DIR = os.path.join(HERE, "audio", "sfx")
MUS_DIR = os.path.join(HERE, "audio", "music")
os.makedirs(SFX_DIR, exist_ok=True)
os.makedirs(MUS_DIR, exist_ok=True)


# --- tiny synth toolkit -------------------------------------------------
def tarr(dur):
    return np.linspace(0, dur, int(SR * dur), endpoint=False)


def square(freq, dur, duty=0.5):
    t = tarr(dur)
    ph = (t * freq) % 1.0
    return np.where(ph < duty, 1.0, -1.0)


def sweep(f0, f1, dur, kind="square", duty=0.5):
    t = tarr(dur)
    # phase = integral of instantaneous frequency (linear sweep)
    f = np.linspace(f0, f1, t.size)
    ph = np.cumsum(f) / SR
    if kind == "square":
        return np.where((ph % 1.0) < duty, 1.0, -1.0)
    if kind == "tri":
        return 2.0 * np.abs(2.0 * (ph % 1.0) - 1.0) - 1.0
    return np.sin(2 * np.pi * ph)


def tri(freq, dur):
    t = tarr(dur)
    ph = (t * freq) % 1.0
    return 2.0 * np.abs(2.0 * ph - 1.0) - 1.0


def noise(dur):
    return np.random.uniform(-1, 1, int(SR * dur))


def lowpass(sig, a=0.05):
    # simple one-pole smoothing -> darker noise
    out = np.empty_like(sig)
    acc = 0.0
    for i in range(sig.size):
        acc = acc * (1 - a) + sig[i] * a
        out[i] = acc
    return out


def env(sig, attack=0.005, decay=None, hold=0.0):
    # fast attack ramp + exponential decay to silence over the rest
    n = sig.size
    e = np.ones(n)
    a = int(SR * attack)
    if a > 0:
        e[:a] = np.linspace(0, 1, a)
    start = a + int(SR * hold)
    if start < n:
        tail = np.linspace(0, 1, n - start)
        k = 5.0 if decay is None else decay
        e[start:] = np.exp(-k * tail)
    return sig * e


def nf(semis_from_a4):
    return 440.0 * (2.0 ** (semis_from_a4 / 12.0))


# note-name -> frequency (e.g. "C4", "A4", "F#5")
_BASE = {"C": -9, "C#": -8, "D": -7, "D#": -6, "E": -5, "F": -4,
         "F#": -3, "G": -2, "G#": -1, "A": 0, "A#": 1, "B": 2}
def note(name):
    acc = name[:-1]
    octv = int(name[-1])
    return nf(_BASE[acc] + (octv - 4) * 12)


def norm(sig, peak=0.6):
    m = np.max(np.abs(sig)) or 1.0
    return sig / m * peak


def write(name, sig, peak=0.6, directory=SFX_DIR):
    sig = norm(sig, peak)
    data = np.clip(sig, -1, 1)
    wavfile.write(os.path.join(directory, name + ".wav"),
                  SR, (data * 32767).astype(np.int16))


def cat(*parts):
    return np.concatenate(parts)


def mix(*sigs):
    n = max(s.size for s in sigs)
    out = np.zeros(n)
    for s in sigs:
        out[:s.size] += s
    return out


# --- the SFX ------------------------------------------------------------
def gen_sfx():
    # coin: quick two-step rising blip
    write("coin", cat(env(square(note("E6"), 0.05), decay=6),
                      env(square(note("B6"), 0.10), decay=7)), 0.5)

    # ding: single bright note (multiplier / small reward)
    write("ding", env(square(note("C6"), 0.16), decay=6), 0.45)

    # powerup: bright ascending arpeggio
    write("powerup", cat(env(square(note("C5"), 0.06), decay=8),
                         env(square(note("E5"), 0.06), decay=8),
                         env(square(note("G5"), 0.06), decay=8),
                         env(square(note("C6"), 0.18), decay=6)), 0.5)

    # chest: warm open chime
    write("chest", cat(env(tri(note("G5"), 0.08), decay=6),
                       env(tri(note("C6"), 0.08), decay=6),
                       env(tri(note("E6"), 0.22), decay=5)), 0.5)

    # crash: noise burst + descending square = explosion
    cr = mix(env(lowpass(noise(0.5), 0.5), attack=0.001, decay=5),
             env(sweep(note("A3"), note("A2"), 0.5), attack=0.001, decay=4) * 0.7)
    write("crash", cr, 0.7)

    # bounce: upward "boing" pitch bend
    write("bounce", env(sweep(note("C4"), note("C5"), 0.14, "tri"),
                        attack=0.002, decay=5), 0.5)

    # ring / boost gate: rising zap-whoosh
    rg = mix(env(sweep(note("C5"), note("C6"), 0.22), attack=0.002, decay=4),
             env(lowpass(noise(0.22), 0.3), attack=0.01, decay=4) * 0.3)
    write("ring", rg, 0.55)

    # dash / speed gate: bigger whoosh
    ds = mix(env(sweep(note("G4"), note("G6"), 0.35), attack=0.005, decay=3),
             env(lowpass(noise(0.35), 0.2), attack=0.02, decay=3) * 0.4)
    write("dash", ds, 0.6)

    # laser: descending "pew"
    write("laser", env(sweep(note("A6"), note("A4"), 0.18, "square", 0.3),
                       attack=0.001, decay=6), 0.5)

    # missile: noisy whoosh + low beep
    ms = mix(env(lowpass(noise(0.3), 0.25), attack=0.02, decay=4) * 0.6,
             env(sweep(note("E4"), note("E3"), 0.3), attack=0.005, decay=4) * 0.6)
    write("missile", ms, 0.55)

    # boss alarm: two-tone warning
    write("boss_alarm", cat(env(square(note("E5"), 0.18), decay=2),
                            env(square(note("B4"), 0.18), decay=2),
                            env(square(note("E5"), 0.18), decay=2),
                            env(square(note("B4"), 0.22), decay=3)), 0.55)

    # boss hit: short noisy thud
    write("boss_hit", mix(env(lowpass(noise(0.18), 0.4), attack=0.001, decay=7),
                          env(square(note("A3"), 0.18), attack=0.001, decay=7) * 0.6), 0.6)

    # boss defeat: big layered explosion + descending
    bd = mix(env(lowpass(noise(0.8), 0.5), attack=0.001, decay=3.5),
             env(sweep(note("A4"), note("A2"), 0.8), attack=0.001, decay=3) * 0.7)
    write("boss_defeat", bd, 0.75)

    # event clear: pleasant chime arpeggio
    write("event", cat(env(square(note("G5"), 0.07), decay=7),
                       env(square(note("C6"), 0.07), decay=7),
                       env(square(note("E6"), 0.18), decay=5)), 0.5)

    # jackpot / slot win: longer ascending jingle
    js = []
    for nm in ["C5", "E5", "G5", "C6", "E6", "G6", "C7"]:
        js.append(env(square(note(nm), 0.09), decay=6))
    write("jackpot", cat(*js), 0.55)

    # slot tick: tiny click
    write("slot_tick", env(square(note("C6"), 0.04), attack=0.001, decay=12), 0.4)

    # sparkle (spin token): quick high shimmer
    write("sparkle", cat(env(square(note("C7"), 0.05), decay=9),
                         env(square(note("E7"), 0.05), decay=9),
                         env(square(note("G7"), 0.10), decay=8)), 0.4)

    # shield: metallic clang
    sh = mix(env(square(note("C6"), 0.25, 0.25), attack=0.001, decay=5),
             env(square(note("G6"), 0.25, 0.33), attack=0.001, decay=5) * 0.7,
             env(lowpass(noise(0.25), 0.6), attack=0.001, decay=6) * 0.3)
    write("shield", sh, 0.55)

    # revive: warm rising chime
    write("revive", cat(env(tri(note("C5"), 0.1), decay=4),
                        env(tri(note("G5"), 0.1), decay=4),
                        env(tri(note("C6"), 0.1), decay=4),
                        env(tri(note("E6"), 0.3), decay=3)), 0.55)

    # game over: sad descending tones
    write("gameover", cat(env(tri(note("E5"), 0.2), decay=3),
                          env(tri(note("C5"), 0.2), decay=3),
                          env(tri(note("A4"), 0.2), decay=3),
                          env(tri(note("E4"), 0.5), decay=2.5)), 0.55)

    # ui select: short blip
    write("select", env(square(note("A5"), 0.08), decay=7), 0.45)

    # boost loop: steady dark-noise thruster (no fade -> loops seamlessly)
    bl = lowpass(noise(0.5), 0.04)
    bl = bl / (np.max(np.abs(bl)) or 1.0)
    rumble = 0.3 * np.sin(2 * np.pi * 70 * tarr(0.5))
    write("boost_loop", bl * 0.7 + rumble, 0.5)


# --- the music loop -----------------------------------------------------
def gen_music():
    bpm = 132.0
    beat = 60.0 / bpm
    # I-V-vi-IV in C major, 4 beats each = a cheerful 16-beat arcade loop.
    chords = [("C", ["C4", "E4", "G4"]), ("G", ["G3", "B3", "D4"]),
              ("A", ["A3", "C4", "E4"]), ("F", ["F3", "A3", "C4"])]
    bass_root = {"C": "C2", "G": "G2", "A": "A2", "F": "F2"}

    total = np.zeros(int(SR * beat * 16))

    def place(buf, sig, at):
        i = int(SR * at)
        end = min(buf.size, i + sig.size)
        buf[i:end] += sig[:end - i]

    arp = np.zeros_like(total)
    bassline = np.zeros_like(total)
    lead = np.zeros_like(total)
    pad = np.zeros_like(total)

    for ci, (cname, tones) in enumerate(chords):
        base_t = ci * 4 * beat
        # arpeggio: eighth notes cycling through the chord
        for e in range(8):
            n = tones[e % 3]
            place(arp, env(square(note(n), beat * 0.5, 0.5), attack=0.003, decay=4),
                  base_t + e * (beat * 0.5))
        # bass: root on each beat (triangle), longer sustain for continuous low end
        for b in range(4):
            place(bassline, env(tri(note(bass_root[cname]), beat * 0.95), attack=0.004, decay=1.0),
                  base_t + b * beat)
        # sustained pad: root + third held the whole bar = music is always present
        for nm in [tones[0], tones[1]]:
            place(pad, env(tri(note(nm), 4 * beat, ), attack=0.03, decay=0.5),
                  base_t)
        # lead: a simple two-note motif per bar
        place(lead, env(square(note(tones[2]) * 2, beat * 0.9, 0.4), attack=0.004, decay=2.2),
              base_t + 1 * beat)
        place(lead, env(square(note(tones[1]) * 2, beat * 0.9, 0.4), attack=0.004, decay=2.2),
              base_t + 3 * beat)

    total = arp * 0.45 + bassline * 0.6 + lead * 0.26 + pad * 0.4
    # loud + present; no end-fade so it loops cleanly on the downbeat
    write("music_main", total, 0.85, directory=MUS_DIR)


if __name__ == "__main__":
    np.random.seed(7)   # deterministic noise so re-runs are identical
    gen_sfx()
    gen_music()
    print("wrote SFX ->", SFX_DIR)
    print("wrote music ->", MUS_DIR)
