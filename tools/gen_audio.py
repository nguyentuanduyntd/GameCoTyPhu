"""Tổng hợp toàn bộ âm thanh và nhạc nền của game bằng code (không dùng mẫu âm thanh bên ngoài).

Nhạc cụ mô phỏng:
  - Đàn tranh: thuật toán dây gảy Karplus-Strong
  - Đàn bầu: sóng sin có luyến cao độ và rung (vibrato)
  - Sáo trúc: sin + hoà âm bậc 2 + tiếng hơi
  - Mõ, trống, cồng chiêng: tổng hợp từ sin và nhiễu
Thang âm ngũ cung (Hò Xự Xang Xê Cống).

Chạy:  python tools/gen_audio.py      → ghi file .wav vào assets/audio/
Cần:   Python 3 + numpy
"""
import os
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(2026)


# ---------------------------------------------------------------- tiện ích

def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def exp_env(dur, decay, attack=0.005):
    t = t_axis(dur)
    env = np.exp(-t * decay)
    a = int(attack * SR)
    if a > 0:
        env[:a] *= np.linspace(0, 1, a)
    return env


def save(name, x, peak=0.85):
    x = np.asarray(x, dtype=np.float64)
    m = np.max(np.abs(x)) or 1.0
    x = x / m * peak
    data = (x * 32767).astype(np.int16)
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("  %-14s %5.1fs" % (name, len(x) / SR))


def mix(length, parts):
    """parts: [(start_seconds, signal)] — cộng vào bộ đệm, phần tràn quấn về đầu (để lặp liền mạch)."""
    buf = np.zeros(length)
    for start, sig in parts:
        s = int(start * SR) % length
        n = len(sig)
        end = s + n
        if end <= length:
            buf[s:end] += sig
        else:
            first = length - s
            buf[s:] += sig[:first]
            rest = sig[first:]
            while len(rest) > 0:
                k = min(len(rest), length)
                buf[:k] += rest[:k]
                rest = rest[k:]
    return buf


def add(*sigs):
    """Cộng các tín hiệu khác độ dài (đệm 0 vào cuối)."""
    n = max(len(x) for x in sigs)
    out = np.zeros(n)
    for x in sigs:
        out[: len(x)] += x
    return out


def lowpass(x, a=0.3):
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += a * (v - acc)
        y[i] = acc
    return y


# ---------------------------------------------------------------- nhạc cụ

def dan_tranh(freq, dur=1.6, bright=0.6, decay=0.996):
    """Dây gảy Karplus-Strong (tính theo khối để nhanh)."""
    n_total = int(dur * SR)
    period = max(2, int(SR / freq))
    y = np.zeros(n_total + period + 1)
    burst = rng.uniform(-1, 1, period + 1)
    burst = bright * burst + (1 - bright) * np.convolve(burst, np.ones(3) / 3, mode="same")
    y[: period + 1] = burst
    i = period + 1
    while i < len(y):
        k = min(period, len(y) - i)
        y[i : i + k] = decay * 0.5 * (y[i - period : i - period + k] + y[i - period - 1 : i - period - 1 + k])
        i += k
    out = y[: n_total]
    fade = int(0.05 * SR)
    out[-fade:] *= np.linspace(1, 0, fade)
    return out


def dan_bau(freq, dur=0.9, bend=0.0):
    """Đàn bầu: sin trong, luyến từ (freq * 2^(bend/12)) về freq, có rung."""
    t = t_axis(dur)
    start = freq * 2 ** (bend / 12)
    glide = np.minimum(t / 0.12, 1.0)
    f = start + (freq - start) * glide
    vib = 1 + 0.012 * np.sin(2 * np.pi * 5.5 * t) * np.minimum(t / 0.25, 1)
    phase = 2 * np.pi * np.cumsum(f * vib) / SR
    sig = np.sin(phase) + 0.25 * np.sin(2 * phase) + 0.08 * np.sin(3 * phase)
    return sig * exp_env(dur, 2.2, 0.015)


def sao(freq, dur=0.5):
    """Sáo trúc: sin + bậc 2 + tiếng hơi, rung nhẹ."""
    t = t_axis(dur)
    vib = 1 + 0.008 * np.sin(2 * np.pi * 6 * t)
    phase = 2 * np.pi * np.cumsum(freq * vib) / SR
    tone = np.sin(phase) + 0.18 * np.sin(2 * phase)
    breath = lowpass(rng.uniform(-1, 1, len(t)), 0.15) * 0.25
    env = np.minimum(t / 0.04, 1) * np.minimum((dur - t) / 0.08, 1).clip(0, 1)
    return (tone + breath) * env


def mo(pitch=900, dur=0.12):
    """Mõ gỗ."""
    t = t_axis(dur)
    return (np.sin(2 * np.pi * pitch * t) + 0.4 * np.sin(2 * np.pi * pitch * 2.7 * t)) * np.exp(-t * 45)


def trong(dur=0.35, f0=140, f1=55):
    """Trống: sin quét xuống + nhiễu."""
    t = t_axis(dur)
    f = f1 + (f0 - f1) * np.exp(-t * 18)
    phase = 2 * np.pi * np.cumsum(f) / SR
    body = np.sin(phase) * np.exp(-t * 9)
    hit = rng.uniform(-1, 1, len(t)) * np.exp(-t * 60) * 0.4
    return body + hit


def chieng(freq=180, dur=3.0):
    """Cồng chiêng: hoà âm không nguyên, tắt chậm, có phách."""
    t = t_axis(dur)
    ratios = [1.0, 1.007, 2.41, 3.92, 5.4]
    amps = [1.0, 0.7, 0.45, 0.25, 0.12]
    decays = [1.1, 1.2, 1.8, 2.6, 3.5]
    sig = sum(a * np.sin(2 * np.pi * freq * r * t) * np.exp(-t * d) for r, a, d in zip(ratios, amps, decays))
    return sig * np.minimum(t / 0.01, 1)


def noise(dur):
    return rng.uniform(-1, 1, int(dur * SR))


# ---------------------------------------------------------------- hiệu ứng âm thanh

def gen_sfx():
    print("Hiệu ứng:")
    # Xúc xắc lăn: chuỗi tiếng gỗ lách cách thưa dần
    parts = []
    tt = 0.0
    for k in range(9):
        parts.append((tt, mo(rng.uniform(1300, 2200), 0.05) * (1 - k * 0.07)))
        tt += 0.04 + k * 0.012
    save("dice", mix(int((tt + 0.1) * SR), parts))
    save("step", mo(620, 0.09) * 0.8)
    # Tiền vào: ting ting
    t = t_axis(0.5)
    coin = np.sin(2 * np.pi * 1975 * t) * np.exp(-t * 9) + 0.6 * np.sin(2 * np.pi * 2637 * t) * np.exp(-t * 11)
    save("coin", mix(len(t) + int(0.09 * SR), [(0, coin * 0.7), (0.09, coin)]))
    # Trả tiền: tiếng tạch trầm
    t = t_axis(0.25)
    save("pay", add(np.sin(2 * np.pi * 330 * t) * np.exp(-t * 18), 0.5 * mo(480, 0.25)))
    # Mua đất: mõ + chuông
    t = t_axis(0.8)
    bell = sum(np.sin(2 * np.pi * f * t) * np.exp(-t * d) for f, d in [(1568, 5), (2349, 6), (3136, 8)])
    save("buy", mix(len(t) + int(0.1 * SR), [(0, mo(1000, 0.1)), (0.08, bell)]))
    # Xây nhà: 3 nhát búa
    hammer = add(trong(0.15, 420, 180) * 0.6, mo(1500, 0.06) * 0.5)
    save("build", mix(int(0.6 * SR), [(0, hammer), (0.16, hammer), (0.32, hammer * 1.2)]))
    # Danh thắng: cồng chiêng
    save("landmark", add(chieng(196, 3.0), 0.5 * chieng(294, 2.5)))
    # Rút thẻ: tiếng giấy lật (nhiễu quét)
    t = t_axis(0.3)
    sweep = lowpass(noise(0.3), 0.5) * np.sin(np.pi * t / 0.3) ** 2
    save("card", sweep, 0.6)
    # Kẹt xe: còi xe pin-pin
    t = t_axis(0.18)
    horn = np.sign(np.sin(2 * np.pi * 440 * t)) * 0.5 + np.sign(np.sin(2 * np.pi * 554 * t)) * 0.5
    horn = lowpass(horn * np.minimum((0.18 - t) / 0.02, 1).clip(0, 1), 0.25)
    save("horn", mix(int(0.5 * SR), [(0, horn), (0.24, horn)]), 0.6)
    # Đụng độ: 2 tiếng trống
    save("duel", mix(int(0.7 * SR), [(0, trong(0.35)), (0.2, trong(0.4, 160, 60))]))
    # Phá sản: 4 nốt đàn bầu đi xuống
    notes = [62, 60, 57, 55]
    save("bankrupt", mix(int(2.2 * SR), [(i * 0.32, dan_bau(midi(n), 1.0, 1.5 if i else 0)) for i, n in enumerate(notes)]))
    # Chiến thắng: đàn tranh rải ngũ cung đi lên + chiêng
    asc = [62, 64, 67, 69, 71, 74, 76, 79]
    parts = [(i * 0.09, dan_tranh(midi(n), 1.2)) for i, n in enumerate(asc)]
    parts.append((0.75, chieng(147, 2.5) * 0.8))
    save("win", mix(int(3.4 * SR), parts))
    save("click", mo(1800, 0.05) * 0.7)
    # Qua trạm BOT: bíp
    t = t_axis(0.15)
    save("toll", np.sin(2 * np.pi * 1200 * t) * np.minimum((0.15 - t) / 0.03, 1).clip(0, 1), 0.5)
    # Sấm
    t = t_axis(2.5)
    rumble = lowpass(noise(2.5), 0.02) * np.exp(-t * 1.5)
    crack = lowpass(noise(2.5), 0.4) * np.exp(-t * 12)
    save("thunder", rumble * 3 + crack)
    # Pháo hoa: bùm + lép bép
    t = t_axis(1.2)
    boom = trong(1.2, 90, 40)
    crackle = np.zeros(len(t))
    for _ in range(25):
        p = int(rng.uniform(0.15, 1.0) * SR)
        crackle[p : p + 200] += rng.uniform(-1, 1, 200) * np.exp(-np.arange(200) / 40)
    save("firework", add(boom, crackle * 0.8))
    # Tới lượt bạn: 2 nốt đàn tranh
    save("turn", mix(int(1.0 * SR), [(0, dan_tranh(midi(74), 0.9)), (0.12, dan_tranh(midi(79), 0.9))]))
    # Thâu tóm: trống + đàn bầu luyến lên
    save("takeover", mix(int(1.2 * SR), [(0, trong(0.4, 180, 70)), (0.1, dan_bau(midi(67), 1.0, -3))]))


# ---------------------------------------------------------------- nhạc nền

def compose(seed, scale, lead, bpm=96, bars=16, tonic=62, density=0.75, sad=False):
    """Soạn một bản nhạc lặp: giai điệu ngũ cung + đàn tranh rải + bass + mõ/trống."""
    r = np.random.default_rng(seed)
    beat = 60.0 / bpm
    eighth = beat / 2
    length = int(bars * 4 * beat * SR)
    parts = []
    # Thang âm 2 quãng tám
    notes = [tonic + s for s in scale] + [tonic + 12 + s for s in scale] + [tonic + 24]
    # Giai điệu: bước liền bậc là chính, kết câu về chủ âm
    idx = 5
    phrase_len = 4
    for bar in range(bars):
        in_phrase = bar % phrase_len
        for e in range(8):
            if bar < 2:
                continue  # 2 ô nhịp dạo đầu chỉ có đệm
            t0 = (bar * 8 + e) * eighth
            last = in_phrase == phrase_len - 1 and e >= 4
            if last:
                if e == 4:
                    target = 5 if bar % 8 == 7 else 7
                    n = notes[target]
                    parts.append((t0, _lead(lead, midi(n), eighth * 4, sad) * 0.9))
                continue
            if r.random() > density and e % 2 == 1:
                continue
            step = int(r.choice([-2, -1, 0, 1, 2], p=[0.1, 0.35, 0.1, 0.35, 0.1]))
            idx = int(np.clip(idx + step, 2, len(notes) - 2))
            dur = eighth * (2 if e % 2 == 0 and r.random() < 0.35 else 1)
            bend = (1.0 if r.random() < 0.3 else 0.0) if lead == "bau" else 0.0
            parts.append((t0, _lead(lead, midi(notes[idx]), dur * 1.6, sad, bend) * 0.75))
    # Đệm đàn tranh rải: chủ – át – quãng tám
    chords = [0, 0, 7, 5] if not sad else [0, 5, 3, 7]
    for bar in range(bars):
        root = tonic - 12 + chords[bar % 4]
        pattern = [0, 7, 12, 7, 0, 7, 12, 14]
        for e, iv in enumerate(pattern):
            parts.append(((bar * 8 + e) * eighth, dan_tranh(midi(root + iv), 1.0, 0.5, 0.994) * 0.32))
        # Bass
        parts.append((bar * 4 * beat, dan_tranh(midi(root - 12), 1.8, 0.3, 0.997) * 0.5))
        parts.append(((bar * 4 + 2) * beat, dan_tranh(midi(root - 5), 1.5, 0.3, 0.997) * 0.35))
        # Mõ nhịp phách, trống đầu ô nhịp
        for b in range(4):
            parts.append(((bar * 4 + b + 0.5) * beat, mo(950, 0.1) * 0.22))
        parts.append((bar * 4 * beat, trong(0.3, 110, 50) * (0.35 if bar % 2 == 0 else 0.2)))
    return mix(length, parts)


def _lead(kind, f, dur, sad, bend=0.0):
    if kind == "sao":
        return sao(f, max(dur, 0.25))
    if kind == "bau":
        return dan_bau(f, max(dur * 1.4, 0.5), bend)
    return dan_tranh(f, max(dur * 2, 0.8), 0.7)


def gen_music():
    print("Nhạc nền:")
    bac = [0, 2, 5, 7, 9]        # Hò Xự Xang Xê Cống (điệu Bắc, tươi sáng)
    oan = [0, 3, 5, 7, 10]       # điệu Oán (buồn, trầm lắng)
    save("music_lobby", compose(7, bac, "sao", bpm=100, tonic=67), 0.7)
    save("music_game_a", compose(21, bac, "tranh", bpm=96, tonic=62), 0.7)
    save("music_game_b", compose(33, oan, "bau", bpm=84, tonic=62, density=0.6, sad=True), 0.7)


if __name__ == "__main__":
    gen_sfx()
    gen_music()
    print("Xong →", os.path.abspath(OUT))
