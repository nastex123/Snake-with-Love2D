"""
generate_ui_sprites.py
Genera los sprites PNG para la UI de botones (Opción A):
- ui_button_base.png (Normal)
- ui_button_hover.png (Hover)
- ui_button_press.png (Pressed)
- ui_gear_node.png (Engranaje giratorio)
- ui_reticle_corner.png (Corchete HUD)
- ui_eye_iris.png (Iris del ojo de víbora)
"""

import os
import math
from PIL import Image, ImageDraw, ImageFilter

ASSETS_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets")
os.makedirs(ASSETS_DIR, exist_ok=True)

BW = 270
BH = 42

def create_cyberstep_polygon(x, y, w, h, s_off_x=0, s_off_y=0):
    px = x + s_off_x
    py = y + s_off_y
    return [
        (px + 8, py),
        (px + w - 8, py),
        (px + w - 8, py + 4),
        (px + w - 4, py + 4),
        (px + w - 4, py + 8),
        (px + w, py + 8),
        (px + w, py + h - 8),
        (px + w - 4, py + h - 8),
        (px + w - 4, py + h - 4),
        (px + w - 8, py + h - 4),
        (px + w - 8, py + h),
        (px + 8, py + h),
        (px + 8, py + h - 4),
        (px + 4, py + h - 4),
        (px + 4, py + h - 8),
        (px, py + h - 8),
        (px, py + 8),
        (px + 4, py + 8),
        (px + 4, py + 4),
        (px + 8, py + 4)
    ]

def draw_hydra_claws(draw, bx, by, bw, bh, is_hover):
    # Tres hendiduras en flanco izquierdo y derecho
    claw_color = (0, 240, 255, 100) if is_hover else (0, 240, 255, 30)
    shadow_color = (0, 0, 0, 180)
    
    # Flanco izquierdo
    for z in range(3):
        x1 = bx + 32 + z * 7
        y1 = by + 5
        x2 = bx + 40 + z * 7
        y2 = by + bh - 5
        # Sombra profunda
        draw.line([(x1 + 1, y1 + 1), (x2 + 1, y2 + 1)], fill=shadow_color, width=2)
        # Línea de luz
        draw.line([(x1, y1), (x2, y2)], fill=claw_color, width=2)
        
    # Flanco derecho
    for z in range(3):
        x1 = bx + bw - 54 + z * 7
        y1 = by + 5
        x2 = bx + bw - 46 + z * 7
        y2 = by + bh - 5
        draw.line([(x1 + 1, y1 + 1), (x2 + 1, y2 + 1)], fill=shadow_color, width=2)
        draw.line([(x1, y1), (x2, y2)], fill=claw_color, width=2)

def generate_button_plates():
    states = [
        ('normal', (8, 13, 22, 245), (0, 240, 255, 120), False, 0),
        ('hover', (16, 30, 48, 255), (0, 240, 255, 230), True, 0),
        ('press', (5, 7, 13, 255), (0, 180, 200, 160), False, 2)
    ]
    
    for state_name, body_color, border_color, is_hover, y_off in states:
        img = Image.new("RGBA", (BW + 6, BH + 6), (0, 0, 0, 0))
        draw = ImageDraw.Draw(img)
        
        bx = 2
        by = 2 + y_off
        
        # 1. Sombra sólida proyectada
        shadow_poly = create_cyberstep_polygon(bx, by, BW, BH, 2, 3)
        draw.polygon(shadow_poly, fill=(0, 0, 0, 190))
        
        # 2. Cuerpo del botón
        body_poly = create_cyberstep_polygon(bx, by, BW, BH, 0, 0)
        draw.polygon(body_poly, fill=body_color)
        
        # 3. Zarpazos de Hidra
        draw_hydra_claws(draw, bx, by, BW, BH, is_hover)
        
        # 4. Highlight superior de 1px
        if not (state_name == 'press'):
            sheen_alpha = 200 if is_hover else 90
            draw.line([(bx + 10, by + 1), (bx + BW - 10, by + 1)], fill=(255, 255, 255, sheen_alpha), width=1)
            
        # 5. Borde Cyber-Step
        draw.polygon(body_poly, outline=border_color)
        
        # 6. Cuadros decorativos en esquinas
        corner_c = (0, 240, 255, 255 if is_hover else 180)
        draw.rectangle([bx + 7, by + 1, bx + 9, by + 3], fill=corner_c)
        draw.rectangle([bx + BW - 10, by + 1, bx + BW - 8, by + 3], fill=corner_c)
        draw.rectangle([bx + 7, by + BH - 4, bx + 9, by + BH - 2], fill=corner_c)
        draw.rectangle([bx + BW - 10, by + BH - 4, bx + BW - 8, by + BH - 2], fill=corner_c)
        
        filepath = os.path.join(ASSETS_DIR, f"ui_button_{state_name}.png")
        img.save(filepath, "PNG")
        print(f"Generated: {filepath} ({BW+6}x{BH+6})")

def generate_gear_sprite():
    size = 24
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    cx = size // 2
    cy = size // 2
    r_body = 6
    r_teeth = 9
    
    # 6 dientes
    for k in range(6):
        ang = k * math.pi / 3
        tx = cx + math.cos(ang) * r_teeth
        ty = cy + math.sin(ang) * r_teeth
        draw.rectangle([tx - 1.5, ty - 1.5, tx + 1.5, ty + 1.5], fill=(0, 240, 255, 255), outline=(0, 100, 130, 255))
        
    # Cuerpo circular
    draw.ellipse([cx - r_body, cy - r_body, cx + r_body, cy + r_body], fill=(6, 11, 19, 255), outline=(0, 240, 255, 255))
    
    # Eje central
    draw.rectangle([cx - 1, cy - 1, cx + 1, cy + 1], fill=(255, 255, 255, 255))
    
    filepath = os.path.join(ASSETS_DIR, "ui_gear_node.png")
    img.save(filepath, "PNG")
    print(f"Generated: {filepath} ({size}x{size})")

def generate_reticle_corner():
    size = 12
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Corchete Top-Left: línea horizontal y vertical
    draw.line([(0, 0), (size - 1, 0)], fill=(0, 240, 255, 255), width=2)
    draw.line([(0, 0), (0, size - 1)], fill=(0, 240, 255, 255), width=2)
    
    filepath = os.path.join(ASSETS_DIR, "ui_reticle_corner.png")
    img.save(filepath, "PNG")
    print(f"Generated: {filepath} ({size}x{size})")

def generate_eye_iris():
    size = 28
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    cx = size // 2
    cy = size // 2
    r_iris = 11
    
    # Fondo circular oscuro del iris
    draw.ellipse([cx - r_iris, cy - r_iris, cx + r_iris, cy + r_iris], fill=(0, 90, 120, 255), outline=(0, 240, 255, 200))
    
    # Fibras del iris
    for a in range(12):
        ang = a * math.pi / 6
        x1 = cx + math.cos(ang) * 2.5
        y1 = cy + math.sin(ang) * 2.5
        x2 = cx + math.cos(ang) * (r_iris - 1)
        y2 = cy + math.sin(ang) * (r_iris - 1)
        draw.line([(x1, y1), (x2, y2)], fill=(128, 245, 255, 120), width=1)
        
    # Pupila vertical rasgada
    draw.ellipse([cx - 1.5, cy - 8, cx + 1.5, cy + 8], fill=(0, 0, 0, 255))
    
    # Reflejos especulares de córnea
    draw.ellipse([cx - 3, cy - 3, cx - 1, cy - 1], fill=(255, 255, 255, 255))
    draw.ellipse([cx + 2, cy + 2, cx + 3, cy + 3], fill=(255, 255, 255, 200))
    
    filepath = os.path.join(ASSETS_DIR, "ui_eye_iris.png")
    img.save(filepath, "PNG")
    print(f"Generated: {filepath} ({size}x{size})")

if __name__ == "__main__":
    generate_button_plates()
    generate_gear_sprite()
    generate_reticle_corner()
    generate_eye_iris()
    print("All sprites successfully baked to assets/!")
