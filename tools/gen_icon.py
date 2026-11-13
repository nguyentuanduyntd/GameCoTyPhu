"""Vẽ icon game bằng code (không dùng tài sản bên ngoài): đồng xu vàng có ngôi nhà, trên nền đỏ son bo góc.
Tạo: icon.png (1024), icon.ico (Windows, nhiều cỡ), assets/icons/android_*.png (launcher Android),
assets/icons/splash.png (màn chờ khi mở game).
Chạy: python tools/gen_icon.py   (cần Pillow)"""
import math
import os
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SS = 2048  # vẽ ở độ phân giải gấp đôi rồi thu nhỏ để khử răng cưa

RED_TOP = (216, 74, 47)
RED_BOT = (142, 31, 23)
GOLD_HI = (255, 222, 110)
GOLD = (242, 179, 27)
GOLD_DK = (176, 112, 10)
INK = (120, 24, 18)


def vgrad(size, top, bot):
    g = Image.new("RGB", (1, size))
    for y in range(size):
        t = y / (size - 1)
        g.putpixel((0, y), tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)))
    return g.resize((size, size))


def rounded_mask(size, radius):
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    return m


def coin_house(size, with_bg=True):
    """Đồng xu + ngôi nhà. with_bg=False: chỉ tiền cảnh (lớp foreground của icon thích ứng Android)."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    s = size / SS
    if with_bg:
        bg = vgrad(size, RED_TOP, RED_BOT).convert("RGBA")
        img.paste(bg, (0, 0), rounded_mask(size, int(380 * s)))
        d = ImageDraw.Draw(img)
        d.rounded_rectangle([int(70 * s), int(70 * s), size - int(70 * s), size - int(70 * s)], radius=int(320 * s),
                            outline=GOLD + (200,), width=max(2, int(18 * s)))
    cx, cy, r = size / 2, size * 0.52, size * 0.33
    # bóng đổ của đồng xu
    sh = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(sh).ellipse([cx - r, cy - r + 40 * s, cx + r, cy + r + 40 * s], fill=(40, 0, 0, 120))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(30 * s)))
    d = ImageDraw.Draw(img)
    # vành xu + mặt xu (gradient tròn giả bằng các vòng)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=GOLD_DK)
    steps = 60
    for k in range(steps):
        t = k / steps
        rr = r * 0.92 * (1 - t)
        col = tuple(int(GOLD[i] + (GOLD_HI[i] - GOLD[i]) * t) for i in range(3))
        ox = -r * 0.18 * t
        oy = -r * 0.22 * t
        d.ellipse([cx - rr + ox, cy - rr + oy, cx + rr + ox, cy + rr + oy], fill=col)
    d.ellipse([cx - r * 0.8, cy - r * 0.8, cx + r * 0.8, cy + r * 0.8], outline=GOLD_DK, width=max(2, int(14 * s)))
    # ngôi nhà
    hw = r * 0.95
    base_y = cy + r * 0.42
    body_top = cy - r * 0.05
    d.rectangle([cx - hw * 0.42, body_top, cx + hw * 0.42, base_y], fill=INK)
    d.polygon([(cx - hw * 0.62, body_top + r * 0.04), (cx, cy - r * 0.55), (cx + hw * 0.62, body_top + r * 0.04)], fill=INK)
    # cửa + cửa sổ
    d.rounded_rectangle([cx - hw * 0.1, cy + r * 0.12, cx + hw * 0.1, base_y], radius=int(20 * s), fill=GOLD_HI)
    d.rectangle([cx - hw * 0.32, cy + r * 0.05, cx - hw * 0.18, cy + r * 0.19], fill=GOLD_HI)
    d.rectangle([cx + hw * 0.18, cy + r * 0.05, cx + hw * 0.32, cy + r * 0.19], fill=GOLD_HI)
    # ngôi sao nhỏ trên nóc
    star = []
    sr, sc = r * 0.13, (cx, cy - r * 0.68)
    for k in range(10):
        a = -math.pi / 2 + k * math.pi / 5
        rad = sr if k % 2 == 0 else sr * 0.45
        star.append((sc[0] + rad * math.cos(a), sc[1] + rad * math.sin(a)))
    d.polygon(star, fill=GOLD_HI)
    return img


def save(img, size, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.resize((size, size), Image.LANCZOS).save(path)


def main():
    full = coin_house(SS, True)
    save(full, 1024, os.path.join(ROOT, "icon.png"))
    ico = full.resize((256, 256), Image.LANCZOS)
    ico.save(os.path.join(ROOT, "icon.ico"), sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
    icons = os.path.join(ROOT, "assets", "icons")
    save(full, 192, os.path.join(icons, "android_192.png"))
    # icon thích ứng Android: tiền cảnh nằm trong vùng an toàn 66% giữa, nền đỏ riêng
    fg = Image.new("RGBA", (SS, SS), (0, 0, 0, 0))
    inner = coin_house(int(SS * 0.62), False)
    fg.alpha_composite(inner, (int(SS * 0.19), int(SS * 0.19)))
    save(fg, 432, os.path.join(icons, "android_fg_432.png"))
    save(vgrad(SS, RED_TOP, RED_BOT).convert("RGBA"), 432, os.path.join(icons, "android_bg_432.png"))
    # màn chờ: icon nhỏ ở giữa (nền màu đặt trong project.godot)
    splash = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    splash.alpha_composite(full.resize((360, 360), Image.LANCZOS), (76, 76))
    splash.save(os.path.join(icons, "splash.png"))
    print("ok")


if __name__ == "__main__":
    main()
