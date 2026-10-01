"""Génère tous les effets sonores du jeu par synthèse (aucun fichier externe).
Sortie : assets/audio/*.wav (mono, 22 050 Hz, 16 bits).
Licence : sons créés pour ce projet → domaine public (CC0).
Lancer depuis la racine du projet :  python tools/audio/generate_sounds.py

Les mélodies (coffre, niveau, sauvegarde) sont des motifs originaux courts.
"""

import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "audio")
random.seed(1234)


# ------------------------------------------------------------------------ briques
def silence(seconds):
    return [0.0] * int(seconds * RATE)


def note(freq, seconds, wave_shape="sine", attack=0.005, release=0.08, volume=1.0, vibrato=0.0):
    out = []
    n = int(seconds * RATE)
    phase = 0.0
    for i in range(n):
        t = i / RATE
        f = freq * (1.0 + vibrato * math.sin(2 * math.pi * 6 * t))
        phase += 2 * math.pi * f / RATE
        if wave_shape == "sine":
            v = math.sin(phase)
        elif wave_shape == "triangle":
            v = 2 / math.pi * math.asin(math.sin(phase))
        elif wave_shape == "square":
            v = 0.6 if math.sin(phase) >= 0 else -0.6
        else:  # saw
            v = ((phase / (2 * math.pi)) % 1.0) * 2 - 1
        env = min(1.0, t / attack) if attack > 0 else 1.0
        env *= min(1.0, (seconds - t) / release) if release > 0 else 1.0
        out.append(v * env * volume)
    return out


def sweep(f_start, f_end, seconds, wave_shape="sine", volume=1.0, curve=1.0):
    out = []
    n = int(seconds * RATE)
    phase = 0.0
    for i in range(n):
        k = (i / n) ** curve
        f = f_start + (f_end - f_start) * k
        phase += 2 * math.pi * f / RATE
        if wave_shape == "sine":
            v = math.sin(phase)
        elif wave_shape == "square":
            v = 0.6 if math.sin(phase) >= 0 else -0.6
        else:
            v = ((phase / (2 * math.pi)) % 1.0) * 2 - 1
        out.append(v * volume)
    return out


def noise(seconds, volume=1.0):
    return [random.uniform(-1, 1) * volume for _ in range(int(seconds * RATE))]


def lowpass(samples, cutoff_start, cutoff_end=None):
    """Filtre passe-bas à un pôle, coupure éventuellement variable (balayage)."""
    cutoff_end = cutoff_start if cutoff_end is None else cutoff_end
    out, y, n = [], 0.0, max(1, len(samples))
    for i, x in enumerate(samples):
        fc = cutoff_start + (cutoff_end - cutoff_start) * i / n
        a = 1.0 - math.exp(-2 * math.pi * fc / RATE)
        y += a * (x - y)
        out.append(y)
    return out


def highpass(samples, cutoff):
    low = lowpass(samples, cutoff)
    return [x - l for x, l in zip(samples, low)]


def envelope(samples, attack=0.005, decay_power=1.0, hold=0.0):
    n = len(samples)
    out = []
    for i, x in enumerate(samples):
        t = i / RATE
        a = min(1.0, t / attack) if attack > 0 else 1.0
        k = max(0.0, (i / n - hold) / (1 - hold)) if hold < 1 else 0.0
        d = (1.0 - k) ** decay_power
        out.append(x * a * d)
    return out


def mix(*tracks, offsets=None):
    offsets = offsets or [0.0] * len(tracks)
    length = max(int(o * RATE) + len(t) for t, o in zip(tracks, offsets))
    out = [0.0] * length
    for track, offset in zip(tracks, offsets):
        start = int(offset * RATE)
        for i, v in enumerate(track):
            out[start + i] += v
    return out


def seq(*parts):
    out = []
    for p in parts:
        out += p
    return out


def gain(samples, g):
    return [s * g for s in samples]


def save(name, samples, peak=0.85):
    # Fondu de sortie (évite les clics) + normalisation.
    fade = min(len(samples), int(0.01 * RATE))
    for i in range(fade):
        samples[-1 - i] *= i / fade
    m = max(1e-6, max(abs(s) for s in samples))
    data = b"".join(struct.pack("<h", int(max(-1, min(1, s / m * peak)) * 32767)) for s in samples)
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(data)
    print(f"{name}.wav  {len(samples) / RATE:.2f} s")


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


# ------------------------------------------------------------------------ sons
# Pas dans l'herbe : bruit court, étouffé.
save("footstep", envelope(lowpass(noise(0.11), 1400, 500), attack=0.004, decay_power=2.5), peak=0.55)
# Épée qui fend l'air : souffle dont la coupure descend.
save("sword_swing", envelope(lowpass(highpass(noise(0.26), 300), 5200, 900), attack=0.06, decay_power=1.6), peak=0.6)
# Impact : choc sourd + claquement.
save("hit", mix(envelope(sweep(170, 55, 0.18), decay_power=2.0),
                envelope(lowpass(noise(0.06), 3500), decay_power=3.0, attack=0.001)), peak=0.8)
# Coup critique : impact + tintement aigu.
save("hit_critical", mix(envelope(sweep(190, 55, 0.2), decay_power=2.0),
                         envelope(lowpass(noise(0.07), 4000), decay_power=3.0, attack=0.001),
                         gain(note(midi(88), 0.35, "triangle", release=0.3), 0.5),
                         gain(note(midi(95), 0.3, "sine", release=0.25), 0.3), offsets=[0, 0, 0.01, 0.03]), peak=0.85)
# Joueur touché : petite plainte descendante.
save("player_hurt", mix(envelope(sweep(520, 260, 0.28, "square", volume=0.5), decay_power=1.5),
                        envelope(lowpass(noise(0.1), 2000), decay_power=3.0)), peak=0.6)
# Slime touché : « splotch » gélatineux.
squish = [math.sin(2 * math.pi * (260 + 180 * math.sin(2 * math.pi * 28 * i / RATE)) * i / RATE) for i in range(int(0.24 * RATE))]
save("slime_hurt", envelope(mix(squish, lowpass(noise(0.24), 900)), attack=0.004, decay_power=2.0), peak=0.6)
# Gobelin touché : grognement.
save("goblin_hurt", envelope(lowpass(mix(sweep(190, 120, 0.26, "saw"), gain(noise(0.26), 0.4)), 1400), attack=0.01, decay_power=1.4), peak=0.6)
# Mort d'un ennemi : « pouf » de fumée + ton qui descend.
save("enemy_death", mix(envelope(lowpass(noise(0.55), 2500, 300), attack=0.005, decay_power=1.3),
                        gain(envelope(sweep(600, 150, 0.45, "square", volume=0.5), decay_power=1.5), 0.6)), peak=0.7)
# Alerte de l'ennemi (« ! ») : deux notes aiguës.
save("enemy_alert", seq(note(midi(84), 0.07, "square", release=0.02, volume=0.5), note(midi(91), 0.14, "square", release=0.08, volume=0.5)), peak=0.45)
# Rubis : deux notes cristallines rapides.
save("pickup_rupee", seq(note(midi(88), 0.07, "sine", release=0.03), note(midi(95), 0.2, "sine", release=0.17)), peak=0.55)
# Objet : petit arpège montant.
save("pickup_item", seq(*[note(midi(n), 0.08, "triangle", release=0.05) for n in (72, 76, 79)], note(midi(84), 0.25, "triangle", release=0.22)), peak=0.55)
# Cœur : deux notes douces.
save("pickup_heart", seq(note(midi(79), 0.1, "sine", release=0.05), note(midi(86), 0.3, "sine", release=0.25, vibrato=0.004)), peak=0.55)
# Coffre : grincement, puis courte fanfare originale.
creak = envelope(lowpass(sweep(90, 140, 0.45, "saw", volume=0.6), 900), attack=0.05, decay_power=0.8)
fanfare = seq(note(midi(67), 0.12, "square", volume=0.4), note(midi(71), 0.12, "square", volume=0.4),
              note(midi(74), 0.12, "square", volume=0.4), note(midi(79), 0.55, "square", volume=0.45, release=0.35, vibrato=0.003))
save("chest_open", mix(creak, lowpass(fanfare, 3000), offsets=[0, 0.4]), peak=0.6)
# Porte : grincement grave plus long.
save("door_open", envelope(lowpass(sweep(70, 110, 0.8, "saw", volume=0.6), 700), attack=0.05, hold=0.3, decay_power=1.2), peak=0.55)
# Porte verrouillée : « bzz-bzz ».
save("door_locked", seq(note(110, 0.1, "square", release=0.02), silence(0.04), note(98, 0.14, "square", release=0.06)), peak=0.45)
# Montée de niveau : arpège lumineux + scintillement.
arp = seq(*[note(midi(n), 0.09, "triangle", release=0.06) for n in (72, 76, 79, 84, 88)], note(midi(91), 0.5, "triangle", release=0.45, vibrato=0.004))
sparkle = mix(*[gain(note(midi(96 + (k % 3) * 3), 0.12, "sine", release=0.1), 0.3) for k in range(6)], offsets=[0.45 + 0.08 * k for k in range(6)])
save("level_up", mix(arp, sparkle), peak=0.6)
# Sauvegarde : accord arpégé apaisant.
save("save_game", mix(*[note(midi(n), 0.8 - 0.1 * k, "sine", release=0.5) for k, n in enumerate((67, 71, 74, 79))], offsets=[0, 0.1, 0.2, 0.3]), peak=0.55)
# Sort : chuintement montant scintillant.
save("magic_cast", mix(envelope(sweep(300, 1400, 0.45, "sine", curve=0.6), attack=0.02, decay_power=1.2),
                       gain(envelope(highpass(noise(0.45), 3000), attack=0.05, decay_power=1.0), 0.35)), peak=0.55)
# Impact magique.
save("magic_hit", mix(envelope(lowpass(noise(0.35), 5000, 800), decay_power=2.0),
                      gain(envelope(sweep(900, 300, 0.3), decay_power=1.5), 0.6)), peak=0.65)
# Saut et roulade.
save("jump", envelope(sweep(260, 520, 0.12, "sine"), attack=0.005, decay_power=1.5), peak=0.35)
save("roll", envelope(lowpass(noise(0.3), 1800, 400), attack=0.03, decay_power=1.5), peak=0.5)
# Interface.
save("ui_move", envelope(note(midi(84), 0.04, "sine", release=0.02), decay_power=2.0), peak=0.3)
save("ui_confirm", seq(note(midi(79), 0.05, "triangle", release=0.02), note(midi(86), 0.1, "triangle", release=0.07)), peak=0.4)
save("ui_open", seq(note(midi(72), 0.05, "sine", release=0.02), note(midi(79), 0.1, "sine", release=0.07)), peak=0.35)
save("ui_close", seq(note(midi(79), 0.05, "sine", release=0.02), note(midi(72), 0.1, "sine", release=0.07)), peak=0.35)
