import os
import math
from PIL import Image, ImageDraw, ImageFont

BASE_DIR = r"c:\Users\Jeremy\Repos\mountain-of-echoes\moe_editable\minigames\catcade\assets"

def make_dirs():
    for sub in ["cats", "enemies", "structures", "environment", "ui", "effects"]:
        os.makedirs(os.path.join(BASE_DIR, sub), exist_ok=True)

def create_supersampled_image(size, draw_fn, scale=4):
    w, h = size
    sw, sh = w * scale, h * scale
    img = Image.new("RGBA", (sw, sh), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    draw_fn(draw, sw, sh, scale)
    return img.resize((w, h), Image.Resampling.LANCZOS)

# ----------------- CAT PROTAGONISTS -----------------
def draw_cat_base(draw, sw, sh, scale, expression="idle", variant="normal"):
    outline_color = (20, 20, 25, 255)
    body_color = (255, 255, 255, 255)
    inner_ear = (255, 215, 225, 255)
    outline_w = int(3.5 * scale)

    cx, cy = sw / 2, sh / 2
    
    if variant == "tank":
        # Tall rounded rectangle for Tank Cat
        bx0 = cx - 20 * scale
        by0 = cy - 34 * scale
        bx1 = cx + 20 * scale
        by1 = cy + 28 * scale
        r = 12 * scale

        # Ears
        ear_l = [(bx0 + 3*scale, by0 + 8*scale), (bx0 + 2*scale, by0 - 12*scale), (bx0 + 14*scale, by0 + 2*scale)]
        ear_r = [(bx1 - 3*scale, by0 + 8*scale), (bx1 - 2*scale, by0 - 12*scale), (bx1 - 14*scale, by0 + 2*scale)]
        for ear in [ear_l, ear_r]:
            draw.polygon(ear, fill=body_color, outline=outline_color)
            draw.line(ear + [ear[0]], fill=outline_color, width=outline_w)

        # Body
        draw.rounded_rectangle([bx0, by0, bx1, by1], radius=r, fill=body_color, outline=outline_color, width=outline_w)
        
        # Stubby feet
        draw.rounded_rectangle([cx - 15*scale, by1 - 4*scale, cx - 6*scale, by1 + 8*scale], radius=3*scale, fill=body_color, outline=outline_color, width=outline_w)
        draw.rounded_rectangle([cx + 6*scale, by1 - 4*scale, cx + 15*scale, by1 + 8*scale], radius=3*scale, fill=body_color, outline=outline_color, width=outline_w)

        # Stoic/unimpressed face
        eye_y = by0 + 22 * scale
        draw.ellipse([cx - 13*scale, eye_y - 3*scale, cx - 7*scale, eye_y + 3*scale], fill=outline_color)
        draw.ellipse([cx + 7*scale, eye_y - 3*scale, cx + 13*scale, eye_y + 3*scale], fill=outline_color)
        
        # Straight mouth
        draw.line([(cx - 8*scale, eye_y + 10*scale), (cx + 8*scale, eye_y + 10*scale)], fill=outline_color, width=int(2.5*scale))
        return

    # Normal & Rocket Cat body: round oval
    bw = 27 * scale
    bh = 22 * scale
    bx0, by0, bx1, by1 = cx - bw, cy - bh + 2*scale, cx + bw, cy + bh + 2*scale

    # Ears
    ear_l = [(cx - 21*scale, cy - 14*scale), (cx - 19*scale, cy - 30*scale), (cx - 6*scale, cy - 18*scale)]
    ear_r = [(cx + 21*scale, cy - 14*scale), (cx + 19*scale, cy - 30*scale), (cx + 6*scale, cy - 18*scale)]
    for ear in [ear_l, ear_r]:
        draw.polygon(ear, fill=body_color, outline=outline_color)
        draw.line(ear + [ear[0]], fill=outline_color, width=outline_w)
    
    # Inner ear detail
    draw.polygon([(cx - 18*scale, cy - 15*scale), (cx - 17*scale, cy - 26*scale), (cx - 9*scale, cy - 18*scale)], fill=inner_ear)
    draw.polygon([(cx + 18*scale, cy - 15*scale), (cx + 17*scale, cy - 26*scale), (cx + 9*scale, cy - 18*scale)], fill=inner_ear)

    # Feet
    foot_w = 4 * scale
    foot_h = 7 * scale
    draw.ellipse([cx - 16*scale, by1 - 5*scale, cx - 16*scale + foot_w*2, by1 - 5*scale + foot_h], fill=body_color, outline=outline_color, width=outline_w)
    draw.ellipse([cx + 16*scale - foot_w*2, by1 - 5*scale, cx + 16*scale, by1 - 5*scale + foot_h], fill=body_color, outline=outline_color, width=outline_w)

    # Main Body Oval
    draw.ellipse([bx0, by0, bx1, by1], fill=body_color, outline=outline_color, width=outline_w)

    if variant == "rocket":
        # Helmet / Goggles (like the red hero cat in user image!)
        h_color = (225, 45, 45, 255)
        visor_color = (50, 50, 60, 255)
        # Cap/Helmet on top
        draw.chord([bx0 - 1*scale, by0 - 8*scale, bx1 + 1*scale, cy + 2*scale], 180, 360, fill=h_color, outline=outline_color, width=outline_w)
        # Visor
        draw.rounded_rectangle([cx - 20*scale, cy - 10*scale, cx + 20*scale, cy + 2*scale], radius=4*scale, fill=visor_color, outline=outline_color, width=int(2*scale))
        # Visor shine
        draw.ellipse([cx - 16*scale, cy - 8*scale, cx - 6*scale, cy - 4*scale], fill=(200, 220, 255, 180))

    # Eyes & Mouth based on expression
    eye_y = cy - (2 * scale if variant != "rocket" else 3 * scale)
    if expression == "idle":
        # Dot eyes
        er = 3 * scale
        draw.ellipse([cx - 12*scale - er, eye_y - er, cx - 12*scale + er, eye_y + er], fill=outline_color)
        draw.ellipse([cx + 12*scale - er, eye_y - er, cx + 12*scale + er, eye_y + er], fill=outline_color)
        # Cat muzzle / mouth ':3'
        mw = 5 * scale
        my = eye_y + 8 * scale
        draw.polygon([(cx - 2*scale, my - 2*scale), (cx + 2*scale, my - 2*scale), (cx, my)], fill=outline_color)
        draw.arc([cx - mw, my - 2*scale, cx, my + 5*scale], 0, 180, fill=outline_color, width=int(2.5*scale))
        draw.arc([cx, my - 2*scale, cx + mw, my + 5*scale], 0, 180, fill=outline_color, width=int(2.5*scale))
        
    elif expression == "aim":
        # Focused/serious eyes (sharp squint)
        draw.line([(cx - 16*scale, eye_y - 2*scale), (cx - 8*scale, eye_y + 2*scale)], fill=outline_color, width=int(3*scale))
        draw.line([(cx + 16*scale, eye_y - 2*scale), (cx + 8*scale, eye_y + 2*scale)], fill=outline_color, width=int(3*scale))
        draw.ellipse([cx - 11*scale, eye_y, cx - 8*scale, eye_y + 3*scale], fill=outline_color)
        draw.ellipse([cx + 8*scale, eye_y, cx + 11*scale, eye_y + 3*scale], fill=outline_color)
        my = eye_y + 9 * scale
        draw.rounded_rectangle([cx - 8*scale, my - 2*scale, cx + 8*scale, my + 4*scale], radius=2*scale, fill=(240, 240, 240, 255), outline=outline_color, width=int(2*scale))
        draw.line([(cx - 3*scale, my - 2*scale), (cx - 3*scale, my + 4*scale)], fill=outline_color, width=int(1.5*scale))
        draw.line([(cx + 3*scale, my - 2*scale), (cx + 3*scale, my + 4*scale)], fill=outline_color, width=int(1.5*scale))

    elif expression == "fly":
        # Screaming open mouth, huge eyes
        er = 3.5 * scale
        draw.ellipse([cx - 12*scale - er, eye_y - 2*scale - er, cx - 12*scale + er, eye_y - 2*scale + er], fill=outline_color)
        draw.ellipse([cx + 12*scale - er, eye_y - 2*scale - er, cx + 12*scale + er, eye_y - 2*scale + er], fill=outline_color)
        my = eye_y + 8 * scale
        draw.ellipse([cx - 7*scale, my - 2*scale, cx + 7*scale, my + 11*scale], fill=(220, 60, 80, 255), outline=outline_color, width=int(2.5*scale))
        draw.ellipse([cx - 4*scale, my + 4*scale, cx + 4*scale, my + 9*scale], fill=(255, 130, 140, 255))

    elif expression == "hit":
        # X eyes
        draw.line([(cx - 15*scale, eye_y - 4*scale), (cx - 8*scale, eye_y + 3*scale)], fill=outline_color, width=int(3*scale))
        draw.line([(cx - 8*scale, eye_y - 4*scale), (cx - 15*scale, eye_y + 3*scale)], fill=outline_color, width=int(3*scale))
        draw.line([(cx + 8*scale, eye_y - 4*scale), (cx + 15*scale, eye_y + 3*scale)], fill=outline_color, width=int(3*scale))
        draw.line([(cx + 15*scale, eye_y - 4*scale), (cx + 8*scale, eye_y + 3*scale)], fill=outline_color, width=int(3*scale))
        my = eye_y + 9 * scale
        draw.arc([cx - 9*scale, my - 2*scale, cx, my + 4*scale], 180, 360, fill=outline_color, width=int(2.5*scale))
        draw.arc([cx, my - 4*scale, cx + 9*scale, my + 2*scale], 0, 180, fill=outline_color, width=int(2.5*scale))

    elif expression == "win":
        # Happy arched ^_^ eyes
        draw.arc([cx - 15*scale, eye_y - 5*scale, cx - 7*scale, eye_y + 3*scale], 190, 350, fill=outline_color, width=int(3*scale))
        draw.arc([cx + 7*scale, eye_y - 5*scale, cx + 15*scale, eye_y + 3*scale], 190, 350, fill=outline_color, width=int(3*scale))
        my = eye_y + 6 * scale
        draw.chord([cx - 8*scale, my, cx + 8*scale, my + 11*scale], 0, 180, fill=(230, 80, 90, 255), outline=outline_color, width=int(2*scale))

# ----------------- ENEMIES -----------------
def draw_enemy_doge(draw, sw, sh, scale):
    cx, cy = sw / 2, sh / 2
    outline = (20, 20, 25, 255)
    body_col = (245, 205, 140, 255)
    belly_col = (255, 240, 215, 255)
    helmet_col = (85, 125, 60, 255)
    width = int(3.5 * scale)

    # Ears
    draw.polygon([(cx - 20*scale, cy - 8*scale), (cx - 26*scale, cy - 28*scale), (cx - 8*scale, cy - 20*scale)], fill=body_col, outline=outline)
    draw.polygon([(cx + 20*scale, cy - 8*scale), (cx + 26*scale, cy - 28*scale), (cx + 8*scale, cy - 20*scale)], fill=body_col, outline=outline)

    # Body
    draw.ellipse([cx - 25*scale, cy - 20*scale, cx + 25*scale, cy + 24*scale], fill=body_col, outline=outline, width=width)
    draw.ellipse([cx - 15*scale, cy + 2*scale, cx + 15*scale, cy + 22*scale], fill=belly_col)
    
    # Army helmet
    draw.chord([cx - 26*scale, cy - 30*scale, cx + 26*scale, cy + 2*scale], 180, 360, fill=helmet_col, outline=outline, width=width)
    draw.line([(cx - 27*scale, cy - 14*scale), (cx + 27*scale, cy - 14*scale)], fill=outline, width=int(3*scale))
    
    # Star on helmet
    draw.polygon([(cx, cy - 25*scale), (cx + 2*scale, cy - 19*scale), (cx + 7*scale, cy - 19*scale), 
                  (cx + 3*scale, cy - 15*scale), (cx + 5*scale, cy - 9*scale), (cx, cy - 12*scale),
                  (cx - 5*scale, cy - 9*scale), (cx - 3*scale, cy - 15*scale), (cx - 7*scale, cy - 19*scale),
                  (cx - 2*scale, cy - 19*scale)], fill=(255, 220, 50, 255))

    # Eyes: suspicious/intense side-glance
    draw.ellipse([cx - 13*scale, cy - 5*scale, cx - 6*scale, cy + 2*scale], fill=(255, 255, 255, 255), outline=outline, width=int(2*scale))
    draw.ellipse([cx + 6*scale, cy - 5*scale, cx + 13*scale, cy + 2*scale], fill=(255, 255, 255, 255), outline=outline, width=int(2*scale))
    draw.ellipse([cx - 10*scale, cy - 3*scale, cx - 7*scale, cy + 1*scale], fill=outline)
    draw.ellipse([cx + 9*scale, cy - 3*scale, cx + 12*scale, cy + 1*scale], fill=outline)

    # Black snout & cute nose
    draw.ellipse([cx - 5*scale, cy + 5*scale, cx + 5*scale, cy + 11*scale], fill=outline)
    draw.line([(cx, cy + 11*scale), (cx, cy + 15*scale)], fill=outline, width=int(2*scale))
    draw.arc([cx - 6*scale, cy + 10*scale, cx, cy + 18*scale], 0, 180, fill=outline, width=int(2*scale))
    draw.arc([cx, cy + 10*scale, cx + 6*scale, cy + 18*scale], 0, 180, fill=outline, width=int(2*scale))

def draw_enemy_pigge(draw, sw, sh, scale):
    cx, cy = sw / 2, sh / 2
    outline = (20, 20, 25, 255)
    skin_col = (255, 140, 165, 255)
    snout_col = (255, 105, 135, 255)
    metal_col = (160, 175, 195, 255)
    width = int(3.5 * scale)

    # Body
    draw.ellipse([cx - 26*scale, cy - 21*scale, cx + 26*scale, cy + 24*scale], fill=skin_col, outline=outline, width=width)
    
    # Pig ears
    draw.polygon([(cx - 22*scale, cy - 18*scale), (cx - 29*scale, cy - 31*scale), (cx - 13*scale, cy - 22*scale)], fill=skin_col, outline=outline)
    draw.polygon([(cx + 22*scale, cy - 18*scale), (cx + 29*scale, cy - 31*scale), (cx + 13*scale, cy - 22*scale)], fill=skin_col, outline=outline)

    # Iron bucket helmet covering forehead
    draw.polygon([(cx - 21*scale, cy - 24*scale), (cx + 21*scale, cy - 24*scale),
                  (cx + 18*scale, cy - 5*scale), (cx - 18*scale, cy - 5*scale)], fill=metal_col, outline=outline)
    draw.line([(cx - 21*scale, cy - 24*scale), (cx + 21*scale, cy - 24*scale), (cx + 18*scale, cy - 5*scale), (cx - 18*scale, cy - 5*scale), (cx - 21*scale, cy - 24*scale)], fill=outline, width=width)
    draw.rectangle([cx - 11*scale, cy - 11*scale, cx + 11*scale, cy - 8*scale], fill=outline)

    # Beady eyes
    draw.ellipse([cx - 11*scale, cy - 3*scale, cx - 6*scale, cy + 2*scale], fill=outline)
    draw.ellipse([cx + 6*scale, cy - 3*scale, cx + 11*scale, cy + 2*scale], fill=outline)

    # Big snout
    draw.ellipse([cx - 13*scale, cy + 4*scale, cx + 13*scale, cy + 18*scale], fill=snout_col, outline=outline, width=width)
    draw.ellipse([cx - 8*scale, cy + 8*scale, cx - 3*scale, cy + 14*scale], fill=outline)
    draw.ellipse([cx + 3*scale, cy + 8*scale, cx + 8*scale, cy + 14*scale], fill=outline)

    # Trotters
    draw.rectangle([cx - 14*scale, cy + 21*scale, cx - 6*scale, cy + 27*scale], fill=skin_col, outline=outline, width=width)
    draw.rectangle([cx + 6*scale, cy + 21*scale, cx + 14*scale, cy + 27*scale], fill=skin_col, outline=outline, width=width)

def draw_enemy_duck(draw, sw, sh, scale):
    cx, cy = sw / 2, sh / 2
    outline = (20, 20, 25, 255)
    body_col = (255, 255, 255, 255)
    bill_col = (255, 165, 0, 255)
    width = int(3.5 * scale)

    # Crazy tuft of feathers
    draw.polygon([(cx - 6*scale, cy - 24*scale), (cx - 11*scale, cy - 38*scale), (cx - 2*scale, cy - 26*scale)], fill=body_col, outline=outline)
    draw.polygon([(cx + 2*scale, cy - 26*scale), (cx + 8*scale, cy - 39*scale), (cx + 6*scale, cy - 24*scale)], fill=body_col, outline=outline)

    # Body
    draw.ellipse([cx - 21*scale, cy - 23*scale, cx + 21*scale, cy + 21*scale], fill=body_col, outline=outline, width=width)

    # Big googly eyes
    draw.ellipse([cx - 16*scale, cy - 18*scale, cx - 1*scale, cy - 3*scale], fill=(255, 255, 255, 255), outline=outline, width=int(2*scale))
    draw.ellipse([cx + 1*scale, cy - 18*scale, cx + 16*scale, cy - 3*scale], fill=(255, 255, 255, 255), outline=outline, width=int(2*scale))
    draw.ellipse([cx - 12*scale, cy - 14*scale, cx - 7*scale, cy - 9*scale], fill=outline)
    draw.ellipse([cx + 4*scale, cy - 11*scale, cx + 9*scale, cy - 6*scale], fill=outline)

    # Orange duck bill
    draw.ellipse([cx - 18*scale, cy - 2*scale, cx + 18*scale, cy + 14*scale], fill=bill_col, outline=outline, width=width)
    draw.line([(cx - 14*scale, cy + 6*scale), (cx + 14*scale, cy + 6*scale)], fill=outline, width=int(2*scale))
    draw.ellipse([cx - 5*scale, cy + 1*scale, cx - 2*scale, cy + 4*scale], fill=outline)
    draw.ellipse([cx + 2*scale, cy + 1*scale, cx + 5*scale, cy + 4*scale], fill=outline)

def draw_enemy_boss_boar(draw, sw, sh, scale):
    cx, cy = sw / 2, sh / 2
    outline = (20, 20, 25, 255)
    fur_col = (235, 75, 40, 255)
    belly_col = (255, 170, 110, 255)
    tusk_col = (250, 245, 230, 255)
    crown_col = (255, 205, 30, 255)
    width = int(4 * scale)

    # Spikes
    for i in range(-3, 4):
        sx = cx + i * 11 * scale
        sy = cy - 28 * scale - abs(i)*3*scale
        draw.polygon([(sx - 6*scale, sy + 12*scale), (sx, sy), (sx + 6*scale, sy + 12*scale)], fill=(190, 40, 20, 255), outline=outline)

    # Body
    draw.ellipse([cx - 38*scale, cy - 30*scale, cx + 38*scale, cy + 35*scale], fill=fur_col, outline=outline, width=width)
    draw.ellipse([cx - 24*scale, cy + 3*scale, cx + 24*scale, cy + 30*scale], fill=belly_col)

    # Crown
    cr_w = 22 * scale
    crown_pts = [
        (cx - cr_w, cy - 28*scale),
        (cx - cr_w - 3*scale, cy - 44*scale),
        (cx - 8*scale, cy - 33*scale),
        (cx, cy - 46*scale),
        (cx + 8*scale, cy - 33*scale),
        (cx + cr_w + 3*scale, cy - 44*scale),
        (cx + cr_w, cy - 28*scale)
    ]
    draw.polygon(crown_pts, fill=crown_col, outline=outline)
    draw.line(crown_pts + [crown_pts[0]], fill=outline, width=width)
    draw.ellipse([cx - 12*scale, cy - 34*scale, cx - 8*scale, cy - 30*scale], fill=(230, 40, 40, 255))
    draw.ellipse([cx - 2*scale, cy - 37*scale, cx + 2*scale, cy - 33*scale], fill=(40, 180, 240, 255))
    draw.ellipse([cx + 8*scale, cy - 34*scale, cx + 12*scale, cy - 30*scale], fill=(80, 220, 80, 255))

    # Fierce eyes
    draw.polygon([(cx - 22*scale, cy - 11*scale), (cx - 8*scale, cy - 6*scale), (cx - 9*scale, cy + 2*scale), (cx - 21*scale, cy - 3*scale)], fill=(255, 255, 255, 255), outline=outline)
    draw.polygon([(cx + 22*scale, cy - 11*scale), (cx + 8*scale, cy - 6*scale), (cx + 9*scale, cy + 2*scale), (cx + 21*scale, cy - 3*scale)], fill=(255, 255, 255, 255), outline=outline)
    draw.ellipse([cx - 15*scale, cy - 6*scale, cx - 11*scale, cy - 2*scale], fill=(255, 0, 0, 255))
    draw.ellipse([cx + 11*scale, cy - 6*scale, cx + 15*scale, cy - 2*scale], fill=(255, 0, 0, 255))

    # Snout
    draw.ellipse([cx - 19*scale, cy - 2*scale, cx + 19*scale, cy + 21*scale], fill=(215, 60, 30, 255), outline=outline, width=width)
    draw.ellipse([cx - 11*scale, cy + 5*scale, cx - 3*scale, cy + 14*scale], fill=outline)
    draw.ellipse([cx + 3*scale, cy + 5*scale, cx + 11*scale, cy + 14*scale], fill=outline)

    # Tusks
    draw.polygon([(cx - 17*scale, cy + 10*scale), (cx - 32*scale, cy - 5*scale), (cx - 24*scale, cy + 14*scale)], fill=tusk_col, outline=outline)
    draw.line([(cx - 17*scale, cy + 10*scale), (cx - 32*scale, cy - 5*scale), (cx - 24*scale, cy + 14*scale)], fill=outline, width=int(2*scale))
    draw.polygon([(cx + 17*scale, cy + 10*scale), (cx + 32*scale, cy - 5*scale), (cx + 24*scale, cy + 14*scale)], fill=tusk_col, outline=outline)
    draw.line([(cx + 17*scale, cy + 10*scale), (cx + 32*scale, cy - 5*scale), (cx + 24*scale, cy + 14*scale)], fill=outline, width=int(2*scale))

# ----------------- STRUCTURE BLOCKS -----------------
def draw_wood_block(draw, sw, sh, scale, shape_type="beam_h"):
    outline = (20, 20, 25, 255)
    wood_base = (212, 148, 79, 255)
    wood_dark = (175, 114, 52, 255)
    wood_light = (235, 178, 112, 255)
    w = int(2.5 * scale)

    draw.rectangle([w, w, sw - w, sh - w], fill=wood_base, outline=outline, width=w)
    
    if shape_type in ["beam_h", "square"]:
        draw.line([(w + 3*scale, w + 3*scale), (sw - w - 3*scale, w + 3*scale)], fill=wood_light, width=int(1.5*scale))
        draw.line([(w + 3*scale, sh - w - 3*scale), (sw - w - 3*scale, sh - w - 3*scale)], fill=wood_dark, width=int(1.5*scale))
        for gy in [sh * 0.35, sh * 0.65]:
            draw.line([(w + 6*scale, gy), (sw - w - 6*scale, gy)], fill=wood_dark, width=int(1*scale))
    else:
        draw.line([(w + 3*scale, w + 3*scale), (w + 3*scale, sh - w - 3*scale)], fill=wood_light, width=int(1.5*scale))
        draw.line([(sw - w - 3*scale, w + 3*scale), (sw - w - 3*scale, sh - w - 3*scale)], fill=wood_dark, width=int(1.5*scale))
        for gx in [sw * 0.35, sw * 0.65]:
            draw.line([(gx, w + 6*scale), (gx, sh - w - 6*scale)], fill=wood_dark, width=int(1*scale))

    # Corner nails
    for nx, ny in [(w + 4*scale, w + 4*scale), (sw - w - 4*scale, w + 4*scale), 
                   (w + 4*scale, sh - w - 4*scale), (sw - w - 4*scale, sh - w - 4*scale)]:
        draw.ellipse([nx - 1.5*scale, ny - 1.5*scale, nx + 1.5*scale, ny + 1.5*scale], fill=(80, 50, 20, 255))

def draw_stone_block(draw, sw, sh, scale, shape_type="beam_h"):
    outline = (20, 20, 25, 255)
    stone_base = (160, 168, 178, 255)
    stone_dark = (118, 126, 138, 255)
    stone_light = (205, 212, 220, 255)
    w = int(2.5 * scale)

    draw.rectangle([w, w, sw - w, sh - w], fill=stone_base, outline=outline, width=w)
    draw.line([(w + 2*scale, w + 2*scale), (sw - w - 2*scale, w + 2*scale)], fill=stone_light, width=int(2*scale))
    draw.line([(w + 2*scale, w + 2*scale), (w + 2*scale, sh - w - 2*scale)], fill=stone_light, width=int(2*scale))
    draw.line([(sw - w - 2*scale, w + 2*scale), (sw - w - 2*scale, sh - w - 2*scale)], fill=stone_dark, width=int(2*scale))
    draw.line([(w + 2*scale, sh - w - 2*scale), (sw - w - 2*scale, sh - w - 2*scale)], fill=stone_dark, width=int(2*scale))

    if shape_type in ["beam_h", "square"]:
        draw.line([(sw * 0.33, w + 2*scale), (sw * 0.33, sh - w - 2*scale)], fill=stone_dark, width=int(1.5*scale))
        if sw > 80 * scale:
            draw.line([(sw * 0.66, w + 2*scale), (sw * 0.66, sh - w - 2*scale)], fill=stone_dark, width=int(1.5*scale))
    else:
        draw.line([(w + 2*scale, sh * 0.33), (sw - w - 2*scale, sh * 0.33)], fill=stone_dark, width=int(1.5*scale))
        if sh > 80 * scale:
            draw.line([(w + 2*scale, sh * 0.66), (sw - w - 2*scale, sh * 0.66)], fill=stone_dark, width=int(1.5*scale))

def draw_metal_block(draw, sw, sh, scale, shape_type="beam_h"):
    outline = (20, 20, 25, 255)
    metal_base = (130, 160, 195, 255)
    metal_dark = (90, 115, 145, 255)
    metal_shine = (220, 238, 255, 255)
    w = int(2.5 * scale)

    draw.rectangle([w, w, sw - w, sh - w], fill=metal_base, outline=outline, width=w)
    draw.line([(w + 2*scale, w + 2*scale), (sw - w - 2*scale, sh - w - 2*scale)], fill=metal_dark, width=int(1.5*scale))
    draw.line([(w + 2*scale, sh - w - 2*scale), (sw - w - 2*scale, w + 2*scale)], fill=metal_dark, width=int(1.5*scale))
    draw.line([(w + 2*scale, w + 2*scale), (sw - w - 2*scale, w + 2*scale)], fill=metal_shine, width=int(2*scale))

    for nx, ny in [(w + 4*scale, w + 4*scale), (sw - w - 4*scale, w + 4*scale), 
                   (w + 4*scale, sh - w - 4*scale), (sw - w - 4*scale, sh - w - 4*scale)]:
        draw.ellipse([nx - 2*scale, ny - 2*scale, nx + 2*scale, ny + 2*scale], fill=metal_shine, outline=outline, width=int(1*scale))

def draw_tnt_box(draw, sw, sh, scale):
    outline = (20, 20, 25, 255)
    red_col = (225, 45, 45, 255)
    yellow_col = (255, 220, 30, 255)
    w = int(2.5 * scale)

    draw.rectangle([w, w, sw - w, sh - w], fill=red_col, outline=outline, width=w)
    draw.rectangle([w, sh*0.28, sw - w, sh*0.72], fill=yellow_col, outline=outline, width=w)
    
    try:
        font = ImageFont.truetype("arialbd.ttf", int(15 * scale))
    except:
        font = ImageFont.load_default()
    
    draw.text((sw/2, sh/2), "TNT", fill=outline, font=font, anchor="mm")

# ----------------- SLINGSHOT -----------------
def draw_slingshot(draw, sw, sh, scale):
    outline = (20, 20, 25, 255)
    wood_col = (150, 90, 45, 255)
    w = int(2.5 * scale)

    cx, btm = sw / 2, sh - 2 * scale
    fork_y = sh * 0.45
    
    # Base pole
    draw.polygon([(cx - 7*scale, btm), (cx + 7*scale, btm), (cx + 5*scale, fork_y), (cx - 5*scale, fork_y)], fill=wood_col, outline=outline)
    # Left prong
    draw.polygon([(cx - 5*scale, fork_y + 4*scale), (cx - 18*scale, 8*scale), (cx - 8*scale, 6*scale), (cx, fork_y)], fill=wood_col, outline=outline)
    # Right prong
    draw.polygon([(cx + 5*scale, fork_y + 4*scale), (cx + 18*scale, 8*scale), (cx + 8*scale, 6*scale), (cx, fork_y)], fill=wood_col, outline=outline)
    
    # Red leather ties
    draw.rounded_rectangle([cx - 20*scale, 5*scale, cx - 7*scale, 13*scale], radius=2*scale, fill=(210, 40, 40, 255), outline=outline, width=w)
    draw.rounded_rectangle([cx + 7*scale, 5*scale, cx + 20*scale, 13*scale], radius=2*scale, fill=(210, 40, 40, 255), outline=outline, width=w)

# ----------------- ARCADE CABINET (60 x 90) -----------------
def draw_arcade_cabinet(draw, sw, sh, scale):
    outline = (15, 15, 20, 255)
    cab_body = (35, 45, 80, 255)
    screen_bg = (12, 28, 48, 255)
    screen_glow = (60, 210, 255, 255)
    marquee_col = (255, 215, 30, 255)
    w = int(2.5 * scale)

    # Main Cabinet Polygon
    poly = [
        (8*scale, 6*scale),
        (sw - 8*scale, 6*scale),
        (sw - 6*scale, 35*scale),
        (sw - 2*scale, 55*scale),
        (sw - 6*scale, 68*scale),
        (sw - 10*scale, sh - 6*scale),
        (10*scale, sh - 6*scale),
        (6*scale, 68*scale),
        (2*scale, 55*scale),
        (6*scale, 35*scale)
    ]
    draw.polygon(poly, fill=cab_body, outline=outline)
    draw.line(poly + [poly[0]], fill=outline, width=w)

    # Marquee (header)
    draw.rectangle([12*scale, 9*scale, sw - 12*scale, 24*scale], fill=(20, 20, 30, 255), outline=outline, width=w)
    draw.rectangle([14*scale, 11*scale, sw - 14*scale, 22*scale], fill=marquee_col)
    try:
        font = ImageFont.truetype("arialbd.ttf", int(7 * scale))
    except:
        font = ImageFont.load_default()
    draw.text((sw/2, 16.5*scale), "CAT-A-PULT", fill=outline, font=font, anchor="mm")

    # CRT Screen
    draw.rounded_rectangle([12*scale, 27*scale, sw - 12*scale, 53*scale], radius=4*scale, fill=screen_bg, outline=outline, width=w)
    draw.rounded_rectangle([14*scale, 29*scale, sw - 14*scale, 51*scale], radius=3*scale, fill=screen_bg, outline=screen_glow, width=int(1.5*scale))

    # Cat face on screen
    scx, scy = sw/2, 40*scale
    draw.ellipse([scx - 10*scale, scy - 7*scale, scx + 10*scale, scy + 7*scale], fill=(255, 255, 255, 255))
    draw.polygon([(scx - 8*scale, scy - 6*scale), (scx - 7*scale, scy - 12*scale), (scx - 2*scale, scy - 7*scale)], fill=(255, 255, 255, 255))
    draw.polygon([(scx + 8*scale, scy - 6*scale), (scx + 7*scale, scy - 12*scale), (scx + 2*scale, scy - 7*scale)], fill=(255, 255, 255, 255))
    draw.ellipse([scx - 4*scale, scy - 2*scale, scx - 2*scale, scy], fill=(0, 0, 0, 255))
    draw.ellipse([scx + 2*scale, scy - 2*scale, scx + 4*scale, scy], fill=(0, 0, 0, 255))
    draw.arc([scx - 2.5*scale, scy, scx, scy + 2.5*scale], 0, 180, fill=(0, 0, 0, 255), width=int(1*scale))
    draw.arc([scx, scy, scx + 2.5*scale, scy + 2.5*scale], 0, 180, fill=(0, 0, 0, 255), width=int(1*scale))

    # Control Deck (Joystick & buttons)
    draw.polygon([(6*scale, 56*scale), (sw - 6*scale, 56*scale), (sw - 4*scale, 68*scale), (4*scale, 68*scale)], fill=(48, 60, 95, 255), outline=outline)
    draw.line([(4*scale, 68*scale), (sw - 4*scale, 68*scale)], fill=outline, width=w)
    
    # Red Joystick ball
    draw.ellipse([16*scale, 61*scale, 22*scale, 67*scale], fill=(235, 45, 45, 255), outline=outline, width=int(1.5*scale))

    # Buttons
    draw.ellipse([sw - 23*scale, 61*scale, sw - 18*scale, 66*scale], fill=(50, 220, 80, 255))
    draw.ellipse([sw - 15*scale, 60*scale, sw - 10*scale, 65*scale], fill=(255, 210, 40, 255))

    # Coin door
    draw.rectangle([16*scale, 72*scale, sw - 16*scale, sh - 10*scale], fill=(22, 28, 45, 255), outline=outline, width=w)
    draw.rectangle([sw/2 - 5*scale, 76*scale, sw/2 - 2*scale, 82*scale], fill=(255, 175, 20, 255))
    draw.rectangle([sw/2 + 2*scale, 76*scale, sw/2 + 5*scale, 82*scale], fill=(255, 175, 20, 255))

# ----------------- VFX / PARTICLES -----------------
def draw_smoke_puff(draw, sw, sh, scale):
    cx, cy = sw / 2, sh / 2
    outline = (60, 60, 70, 255)
    fill = (245, 248, 255, 240)
    w = int(2.5 * scale)

    circles = [
        (cx, cy, 13*scale),
        (cx - 9*scale, cy + 3*scale, 9*scale),
        (cx + 9*scale, cy + 3*scale, 9*scale),
        (cx - 5*scale, cy - 7*scale, 8*scale),
        (cx + 5*scale, cy - 7*scale, 8*scale),
    ]
    for x, y, r in circles:
        draw.ellipse([x - r, y - r, x + r, y + r], fill=fill)
    for x, y, r in circles:
        draw.arc([x - r, y - r, x + r, y + r], 0, 360, fill=outline, width=w)

def draw_star_spark(draw, sw, sh, scale):
    cx, cy = sw / 2, sh / 2
    r_outer = 14 * scale
    r_inner = 5 * scale
    points = []
    for i in range(8):
        angle = i * math.pi / 4 - math.pi / 2
        r = r_outer if i % 2 == 0 else r_inner
        points.append((cx + r * math.cos(angle), cy + r * math.sin(angle)))
    draw.polygon(points, fill=(255, 235, 50, 255), outline=(40, 30, 0, 255))

def draw_environment_bg(draw, sw, sh, scale):
    # Bright cartoon sky with rolling green hill and cartoon clouds
    # Sky gradient
    for y in range(int(sh * 0.75)):
        ratio = y / (sh * 0.75)
        r = int(140 + ratio * 85)
        g = int(205 + ratio * 40)
        b = 255
        draw.line([(0, y), (sw, y)], fill=(r, g, b, 255))
    
    # Distant green hills
    draw.ellipse([-50*scale, sh*0.45, sw*0.6, sh*0.9], fill=(130, 210, 90, 255))
    draw.ellipse([sw*0.4, sh*0.48, sw + 60*scale, sh*0.95], fill=(110, 195, 75, 255))

    # Fluffy cute clouds
    def draw_cloud(cx, cy, cw):
        c_fill = (255, 255, 255, 240)
        draw.ellipse([cx - cw, cy - cw*0.4, cx + cw, cy + cw*0.4], fill=c_fill)
        draw.ellipse([cx - cw*0.6, cy - cw*0.6, cx, cy + cw*0.2], fill=c_fill)
        draw.ellipse([cx - cw*0.1, cy - cw*0.7, cx + cw*0.7, cy + cw*0.2], fill=c_fill)
        
    draw_cloud(120*scale, 50*scale, 40*scale)
    draw_cloud(320*scale, 35*scale, 55*scale)
    draw_cloud(520*scale, 65*scale, 35*scale)

    # Foreground grassy floor
    floor_y = sh * 0.78
    draw.rectangle([0, floor_y, sw, sh], fill=(100, 70, 45, 255)) # Dirt
    draw.rectangle([0, floor_y, sw, floor_y + 10*scale], fill=(105, 190, 40, 255)) # Grass top
    # Grass fringe
    draw.line([(0, floor_y + 10*scale), (sw, floor_y + 10*scale)], fill=(65, 140, 25, 255), width=int(2*scale))

def draw_star_gold(draw, sw, sh, scale):
    cx, cy = sw / 2, sh / 2
    r_outer = 13 * scale
    r_inner = 5.5 * scale
    points = []
    for i in range(10):
        angle = i * math.pi / 5 - math.pi / 2
        r = r_outer if i % 2 == 0 else r_inner
        points.append((cx + r * math.cos(angle), cy + r * math.sin(angle)))
    draw.polygon(points, fill=(255, 215, 0, 255), outline=(120, 80, 0, 255))

def draw_star_gray(draw, sw, sh, scale):
    cx, cy = sw / 2, sh / 2
    r_outer = 13 * scale
    r_inner = 5.5 * scale
    points = []
    for i in range(10):
        angle = i * math.pi / 5 - math.pi / 2
        r = r_outer if i % 2 == 0 else r_inner
        points.append((cx + r * math.cos(angle), cy + r * math.sin(angle)))
    draw.polygon(points, fill=(90, 100, 115, 255), outline=(50, 55, 65, 255))

# Main execution
def main():
    make_dirs()
    print("Generating assets...")
    
    # 1. Cats
    cats_dir = os.path.join(BASE_DIR, "cats")
    for exp in ["idle", "aim", "fly", "hit", "win"]:
        img = create_supersampled_image((64, 64), lambda d, w, h, s, e=exp: draw_cat_base(d, w, h, s, expression=e, variant="normal"))
        img.save(os.path.join(cats_dir, f"cat_normal_{exp}.png"))
    
    # Tank cat
    img = create_supersampled_image((64, 80), lambda d, w, h, s: draw_cat_base(d, w, h, s, expression="idle", variant="tank"))
    img.save(os.path.join(cats_dir, "cat_tank.png"))
    
    # Rocket cat
    for exp in ["idle", "fly"]:
        img = create_supersampled_image((64, 64), lambda d, w, h, s, e=exp: draw_cat_base(d, w, h, s, expression=e, variant="rocket"))
        img.save(os.path.join(cats_dir, f"cat_rocket_{exp}.png"))

    # 2. Enemies
    enemies_dir = os.path.join(BASE_DIR, "enemies")
    img = create_supersampled_image((64, 64), draw_enemy_doge)
    img.save(os.path.join(enemies_dir, "enemy_doge.png"))

    img = create_supersampled_image((64, 64), draw_enemy_pigge)
    img.save(os.path.join(enemies_dir, "enemy_pigge.png"))

    img = create_supersampled_image((64, 64), draw_enemy_duck)
    img.save(os.path.join(enemies_dir, "enemy_duck.png"))

    img = create_supersampled_image((96, 96), draw_enemy_boss_boar)
    img.save(os.path.join(enemies_dir, "enemy_boss_boar.png"))

    # 3. Structures
    struct_dir = os.path.join(BASE_DIR, "structures")
    # Wood
    create_supersampled_image((120, 24), lambda d, w, h, s: draw_wood_block(d, w, h, s, "beam_h")).save(os.path.join(struct_dir, "wood_beam_h.png"))
    create_supersampled_image((24, 120), lambda d, w, h, s: draw_wood_block(d, w, h, s, "beam_v")).save(os.path.join(struct_dir, "wood_beam_v.png"))
    create_supersampled_image((48, 48), lambda d, w, h, s: draw_wood_block(d, w, h, s, "square")).save(os.path.join(struct_dir, "wood_box.png"))

    # Stone
    create_supersampled_image((120, 24), lambda d, w, h, s: draw_stone_block(d, w, h, s, "beam_h")).save(os.path.join(struct_dir, "stone_beam_h.png"))
    create_supersampled_image((24, 120), lambda d, w, h, s: draw_stone_block(d, w, h, s, "beam_v")).save(os.path.join(struct_dir, "stone_beam_v.png"))
    create_supersampled_image((48, 48), lambda d, w, h, s: draw_stone_block(d, w, h, s, "square")).save(os.path.join(struct_dir, "stone_box.png"))

    # Metal
    create_supersampled_image((120, 24), lambda d, w, h, s: draw_metal_block(d, w, h, s, "beam_h")).save(os.path.join(struct_dir, "metal_beam_h.png"))
    create_supersampled_image((24, 120), lambda d, w, h, s: draw_metal_block(d, w, h, s, "beam_v")).save(os.path.join(struct_dir, "metal_beam_v.png"))
    create_supersampled_image((48, 48), lambda d, w, h, s: draw_metal_block(d, w, h, s, "square")).save(os.path.join(struct_dir, "metal_box.png"))

    # TNT
    create_supersampled_image((48, 48), draw_tnt_box).save(os.path.join(struct_dir, "tnt_box.png"))

    # 4. Slingshot & Arcade Cabinet
    create_supersampled_image((40, 80), draw_slingshot).save(os.path.join(struct_dir, "slingshot.png"))
    create_supersampled_image((60, 90), draw_arcade_cabinet).save(os.path.join(BASE_DIR, "environment", "arcade_cabinet.png"))

    # 5. Effects & UI
    fx_dir = os.path.join(BASE_DIR, "effects")
    create_supersampled_image((48, 48), draw_smoke_puff).save(os.path.join(fx_dir, "smoke_puff.png"))
    create_supersampled_image((32, 32), draw_star_spark).save(os.path.join(fx_dir, "star_spark.png"))

    ui_dir = os.path.join(BASE_DIR, "ui")
    create_supersampled_image((32, 32), draw_star_gold).save(os.path.join(ui_dir, "star_gold.png"))
    create_supersampled_image((32, 32), draw_star_gray).save(os.path.join(ui_dir, "star_gray.png"))

    # Background (640x360 matches the game resolution perfectly)
    env_dir = os.path.join(BASE_DIR, "environment")
    create_supersampled_image((640, 360), draw_environment_bg, scale=2).save(os.path.join(env_dir, "catcade_bg.png"))

    print("All assets successfully generated!")

if __name__ == "__main__":
    main()
