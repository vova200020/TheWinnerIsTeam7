"""Builds the two slide images from the screenshots in this folder.

    python3 -m pip install pillow
    python3 make_composites.py

Outputs (fixed names the deck builder expects):
  watch_face_green.png  1100 x 1100, round watch screen + #263140 12 px bezel, transparent outside
  demo_strip.png        3520 x 640, five panels: w1_face_green, p2_locked, w4_unlock, w5_take5, w6_summary
"""
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
BEZEL = (0x26, 0x31, 0x40, 255)
SS = 4  # supersampling for smooth circle / rounded-corner edges


def path(name):
    return os.path.join(HERE, name)


def circle_mask(size):
    big = Image.new("L", (size * SS, size * SS), 0)
    ImageDraw.Draw(big).ellipse((0, 0, size * SS - 1, size * SS - 1), fill=255)
    return big.resize((size, size), Image.LANCZOS)


def rounded_mask(w, h, radius):
    big = Image.new("L", (w * SS, h * SS), 0)
    ImageDraw.Draw(big).rounded_rectangle((0, 0, w * SS - 1, h * SS - 1), radius=radius * SS, fill=255)
    return big.resize((w, h), Image.LANCZOS)


def round_watch(src, diameter):
    """Watch screenshot → RGBA disc of `diameter` px."""
    im = Image.open(path(src)).convert("RGBA")
    im = im.resize((diameter, diameter), Image.NEAREST if diameter % im.width == 0 else Image.LANCZOS)
    out = Image.new("RGBA", (diameter, diameter), (0, 0, 0, 0))
    out.paste(im, (0, 0), circle_mask(diameter))
    return out


def watch_face_green():
    size, ring = 1100, 12
    disc = round_watch("w1_face_green@4x.png", 1040)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    outer = 1040 + 2 * ring
    bezel = Image.new("RGBA", (outer, outer), BEZEL)
    o = (size - outer) // 2
    canvas.paste(bezel, (o, o), circle_mask(outer))
    canvas.paste(disc, (o + ring, o + ring), disc)
    canvas.save(path("watch_face_green.png"))


def demo_strip():
    w, h, panel_h = 3520, 640, 600
    cell = w // 5
    canvas = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    order = ["w1_face_green@4x.png", "p2_locked.png", "w4_unlock@4x.png", "w5_take5@4x.png", "w6_summary@4x.png"]
    for i, name in enumerate(order):
        if name.startswith("w"):
            panel = round_watch(name, panel_h)
        else:
            im = Image.open(path(name)).convert("RGBA")
            pw = round(im.width * panel_h / im.height)
            im = im.resize((pw, panel_h), Image.LANCZOS)
            panel = Image.new("RGBA", (pw, panel_h), (0, 0, 0, 0))
            panel.paste(im, (0, 0), rounded_mask(pw, panel_h, 40))
        x = i * cell + (cell - panel.width) // 2
        y = (h - panel_h) // 2
        canvas.paste(panel, (x, y), panel)
    canvas.save(path("demo_strip.png"))


if __name__ == "__main__":
    watch_face_green()
    demo_strip()
    for n in ("watch_face_green.png", "demo_strip.png"):
        print(n, Image.open(path(n)).size, Image.open(path(n)).mode)
