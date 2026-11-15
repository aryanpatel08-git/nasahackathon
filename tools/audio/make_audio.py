#!/usr/bin/env python3
"""Synthesises Lunar Life's ambience, music pad and heavier sound effects.

    python3 tools/audio/make_audio.py        # writes assets/audio/*.wav

Everything is made from sine waves and filtered noise with numpy: there are no samples
or recordings. Short bleeps (talk, confirm, step...) are still generated at run time in
scripts/autoload/sfx.gd; this script covers the sounds that need filters or long loops.

Loops are seamless by construction: tones use notes that are rendered "around the clock"
(a tail that runs past the end is folded back to the start) and noise is built in the
frequency domain, which makes it exactly periodic over the buffer.

Needs: Python 3, numpy.
"""
from __future__ import annotations

import wave
from pathlib import Path

import numpy as np

RATE = 22050
OUT = Path(__file__).resolve().parents[2] / "assets" / "audio"
rng = np.random.default_rng(20261115)


def save(name: str, samples: np.ndarray, peak: float):
    samples = samples / max(1e-9, np.max(np.abs(samples))) * peak
    data = np.clip(samples * 32767.0, -32767, 32767).astype("<i2")
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / name), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(data.tobytes())
    print(f"{name:24s} {len(samples) / RATE:5.2f}s  peak {peak:.2f}  rms {np.sqrt(np.mean((samples) ** 2)):.3f}")


def t(seconds: float) -> np.ndarray:
    return np.arange(int(seconds * RATE)) / RATE


def periodic_noise(seconds: float, low: float, high: float, slope: float = 1.0) -> np.ndarray:
    """Band-limited noise that repeats perfectly every `seconds`."""
    n = int(seconds * RATE)
    freqs = np.fft.rfftfreq(n, 1.0 / RATE)
    mag = np.zeros_like(freqs)
    band = (freqs >= low) & (freqs <= high)
    mag[band] = 1.0 / np.maximum(freqs[band], 1.0) ** (slope * 0.5)
    spectrum = mag * np.exp(1j * rng.uniform(0, 2 * np.pi, len(freqs)))
    out = np.fft.irfft(spectrum, n)
    return out / max(1e-9, np.max(np.abs(out)))


def lowpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    spectrum = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(len(x), 1.0 / RATE)
    spectrum *= 1.0 / np.sqrt(1.0 + (freqs / cutoff) ** 4)
    return np.fft.irfft(spectrum, len(x))


def fade(x: np.ndarray, attack: float, release: float) -> np.ndarray:
    env = np.ones(len(x))
    a, r = int(attack * RATE), int(release * RATE)
    if a > 0:
        env[:a] = np.linspace(0, 1, a)
    if r > 0:
        env[-r:] *= np.linspace(1, 0, r)
    return x * env


def add_wrapped(buffer: np.ndarray, start: float, note: np.ndarray):
    """Mix a note into a loop; whatever runs past the end continues from the start."""
    i = int(start * RATE) % len(buffer)
    idx = (i + np.arange(len(note))) % len(buffer)
    np.add.at(buffer, idx, note)


def tone(freq: float, seconds: float, harmonics=((1, 1.0),)) -> np.ndarray:
    tt = t(seconds)
    return sum(a * np.sin(2 * np.pi * freq * h * tt) for h, a in harmonics)


# --- loops ----------------------------------------------------------------------

def habitat_hum():
    """Air handlers and pumps: a low, steady hum with soft air noise. 8-second loop."""
    seconds = 8.0
    tt = t(seconds)
    hum = 0.55 * np.sin(2 * np.pi * 60 * tt) + 0.22 * np.sin(2 * np.pi * 120 * tt) + 0.07 * np.sin(2 * np.pi * 180 * tt)
    hum *= 1.0 + 0.08 * np.sin(2 * np.pi * 0.25 * tt)
    air = periodic_noise(seconds, 120, 2200, 1.6) * (1.0 + 0.25 * np.sin(2 * np.pi * 0.125 * tt))
    save("ambience_habitat.wav", 0.6 * hum + 0.5 * air, 0.32)


def pad_note(freq: float, seconds: float) -> np.ndarray:
    tt = t(seconds)
    body = (np.sin(2 * np.pi * freq * tt) + 0.35 * np.sin(2 * np.pi * freq * 2 * tt + 0.6)
            + 0.12 * np.sin(2 * np.pi * freq * 3 * tt + 1.1))
    detuned = np.sin(2 * np.pi * freq * 1.004 * tt + 2.0)
    env = np.sin(np.pi * np.clip(tt / seconds, 0, 1)) ** 1.5          # slow swell in and out
    return (body + 0.6 * detuned) * env


def bell(freq: float, seconds: float = 2.4) -> np.ndarray:
    tt = t(seconds)
    return (np.sin(2 * np.pi * freq * tt) + 0.3 * np.sin(2 * np.pi * freq * 2.01 * tt)) * np.exp(-tt * 2.2) * np.minimum(1.0, tt * 200)


def music_pad():
    """A slow, hopeful four-chord pad with a few bell notes. 32-second loop."""
    seconds = 32.0
    buffer = np.zeros(int(seconds * RATE))
    # A minor 9 -> F major 7 -> C major (add 9) -> G sus: gentle, never fully resolved.
    chords = [
        (110.00, 164.81, 246.94, 261.63, 329.63),
        (87.31, 130.81, 220.00, 261.63, 329.63),
        (130.81, 196.00, 293.66, 329.63, 392.00),
        (98.00, 146.83, 261.63, 293.66, 392.00),
    ]
    for k, chord in enumerate(chords):
        for v, freq in enumerate(chord):
            add_wrapped(buffer, k * 8.0 - 2.0, pad_note(freq, 12.0) * (0.9 if v == 0 else 0.55))
    # Sparse bells from the A minor pentatonic scale.
    for start, freq in [(1.0, 659.25), (5.0, 880.0), (9.5, 783.99), (13.0, 523.25), (17.0, 587.33),
                        (21.5, 783.99), (25.0, 659.25), (29.0, 440.0)]:
        add_wrapped(buffer, start, bell(freq) * 0.5)
        add_wrapped(buffer, start + 0.45, bell(freq) * 0.2)             # soft echo
    save("music_pad.wav", lowpass(buffer, 2600), 0.42)


# --- one-shots --------------------------------------------------------------------

def servo(seconds: float, f0: float, f1: float) -> np.ndarray:
    tt = t(seconds)
    freq = f0 + (f1 - f0) * (tt / seconds)
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    whine = np.sin(phase) + 0.4 * np.sin(2 * phase) + 0.2 * np.sin(3 * phase)
    whine *= 1.0 + 0.2 * np.sin(2 * np.pi * 23 * tt)                      # motor chatter
    rumble = periodic_noise(seconds, 40, 500, 1.2)
    return fade(0.55 * whine + 0.6 * rumble, 0.05, 0.06)


def thud(freq: float = 62.0, seconds: float = 0.22) -> np.ndarray:
    tt = t(seconds)
    body = np.sin(2 * np.pi * freq * tt * (1.0 - 0.35 * tt / seconds)) * np.exp(-tt * 16)
    click = periodic_noise(seconds, 300, 3000, 1.0) * np.exp(-tt * 70)
    return body + 0.35 * click


def hatch_sounds():
    opening = np.concatenate([servo(0.5, 85, 150), thud(90, 0.16) * 0.8])
    save("hatch_open.wav", opening, 0.5)
    closing = np.concatenate([servo(0.36, 150, 80), thud(58, 0.26)])
    save("hatch_close.wav", closing, 0.55)
    # Seal: heavy bolts, a hiss of air, then a two-note "safe" tone.
    hiss_t = t(0.45)
    hiss = periodic_noise(0.45, 1800, 6000, 0.4) * np.exp(-hiss_t * 7)
    ok = np.concatenate([fade(tone(660, 0.09, ((1, 1.0), (2, 0.2))), 0.004, 0.03), fade(tone(990, 0.16, ((1, 1.0), (2, 0.2))), 0.004, 0.1)])
    seal = np.zeros(int(0.95 * RATE))
    for start, part, gain in [(0.0, thud(55, 0.25), 1.0), (0.09, thud(70, 0.18), 0.7), (0.16, hiss, 0.35), (0.58, ok, 0.3)]:
        i = int(start * RATE)
        seal[i:i + len(part)] += part[:len(seal) - i] * gain
    save("hatch_seal.wav", seal, 0.6)


def alarm():
    """Two-tone klaxon, softened so it warns without hurting."""
    parts = []
    for freq in (620, 465, 620, 465):
        tt = t(0.2)
        wave_ = np.sign(np.sin(2 * np.pi * freq * tt)) * 0.6 + np.sin(2 * np.pi * freq * tt)
        parts.append(fade(wave_, 0.012, 0.03))
    save("alarm.wav", lowpass(np.concatenate(parts), 2400), 0.36)


def chimes():
    note = sum(bell(f, 0.9) * g for f, g in ((880.0, 1.0), (1318.5, 0.6)))
    second = np.concatenate([np.zeros(int(0.09 * RATE)), bell(1760.0, 0.8) * 0.5])
    note = note[:len(second)] + second[:len(note)] if len(second) >= len(note) else note + np.pad(second, (0, len(note) - len(second)))
    save("note.wav", note, 0.34)
    # Mission success: rising arpeggio with a little echo.
    buffer = np.zeros(int(1.6 * RATE))
    for k, freq in enumerate((523.25, 659.25, 783.99, 1046.5)):
        part = bell(freq, 1.0)
        i = int(k * 0.1 * RATE)
        buffer[i:i + len(part)] += part[:len(buffer) - i]
        j = i + int(0.3 * RATE)
        buffer[j:j + len(part)] += part[:len(buffer) - j] * 0.3
    save("success.wav", buffer, 0.4)
    # Launch / arrival whoosh for scene changes.
    tt = t(0.5)
    whoosh = periodic_noise(0.5, 200, 3000, 1.0) * np.sin(np.pi * tt / 0.5) ** 2
    rise = np.sin(2 * np.pi * np.cumsum(180 + 520 * (tt / 0.5) ** 2) / RATE) * np.sin(np.pi * tt / 0.5)
    save("travel.wav", 0.7 * whoosh + 0.4 * rise, 0.3)


if __name__ == "__main__":
    habitat_hum()
    music_pad()
    hatch_sounds()
    alarm()
    chimes()
