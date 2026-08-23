# scripts/extract_alchemy_circle.py
import math
from PIL import Image, ImageFilter

def extract_circle():
    img = Image.open("tools/assets/pixel_alchemy_circle_novice.jpg").convert("RGBA")
    w, h = img.size
    print(f"Original image size: {w}x{h}")

    # The circular emblem is roughly centered horizontally in the upper-mid area
    # Let's find the cyan/gold bright pixels to get the exact center and radius
    pixels = img.load()
    
    # Locate bounding box of glowing cyan/gold pixels
    min_x, max_x = w, 0
    min_y, max_y = h, 0
    
    for y in range(h):
        for x in range(w):
            r, g, b, a = pixels[x, y]
            # Cyan: high g and b, moderate r; Gold: high r and g, lower b
            is_cyan = (g > 150 and b > 180)
            is_gold = (r > 180 and g > 150 and b < 100)
            if is_cyan or is_gold:
                if x < min_x: min_x = x
                if x > max_x: max_x = x
                if y < min_y: min_y = y
                if y > max_y: max_y = y
                
    cx = (min_x + max_x) // 2
    cy = (min_y + max_y) // 2
    rx = (max_x - min_x) // 2
    ry = (max_y - min_y) // 2
    radius = max(rx, ry) + 4
    
    print(f"Detected emblem bounds: center=({cx}, {cy}), radius={radius}")
    
    # Create square crop around center
    size = radius * 2 + 10
    crop_x0 = cx - radius - 5
    crop_y0 = cy - radius - 5
    
    # Create transparent output image
    out_img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out_pixels = out_img.load()
    
    center_out = size // 2
    
    for dy in range(-radius - 5, radius + 6):
        for dx in range(-radius - 5, radius + 6):
            src_x = cx + dx
            src_y = cy + dy
            if 0 <= src_x < w and 0 <= src_y < h:
                dist = math.sqrt(dx*dx + dy*dy)
                if dist <= radius:
                    r, g, b, _ = pixels[src_x, src_y]
                    # Calculate luminance/brightness
                    # Cyan and Gold glow
                    is_cyan = (g > 100 and b > 120 and (g + b) > 2.2 * (r + 1))
                    is_gold = (r > 120 and g > 90 and b < 100 and (r + g) > 2.0 * (b + 1))
                    brightness = (r * 0.299 + g * 0.587 + b * 0.114) / 255.0
                    
                    # If it's the glowing runes/circles/serpents
                    if is_cyan or is_gold or brightness > 0.35:
                        # Keep pixel vibrant with alpha based on brightness
                        alpha = int(min(255, max(0, (brightness - 0.15) / 0.45 * 255)))
                        out_pixels[center_out + dx, center_out + dy] = (r, g, b, alpha)
                    elif dist <= radius - 4:
                        # Subtle semi-transparent dark center so it blends nicely
                        dark_alpha = int(max(0, min(140, (1.0 - (dist / radius)) * 120)))
                        out_pixels[center_out + dx, center_out + dy] = (5, 12, 24, dark_alpha)
                        
    # Resize to standard crisp 512x512 with nearest neighbor for pixel art crispness
    final_img = out_img.resize((512, 512), Image.Resampling.NEAREST)
    final_img.save("assets/alchemy_circle.png")
    print("Saved assets/alchemy_circle.png (512x512)")
    
    # Generate a glow-pass version for bloom shader
    glow_img = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    glow_pixels = glow_img.load()
    f_pixels = final_img.load()
    
    for y in range(512):
        for x in range(512):
            r, g, b, a = f_pixels[x, y]
            if a > 80 and (g > 120 or r > 150):
                glow_pixels[x, y] = (r, g, b, a)
                
    glow_img.save("assets/alchemy_circle_glow.png")
    print("Saved assets/alchemy_circle_glow.png (512x512)")

if __name__ == "__main__":
    extract_circle()
