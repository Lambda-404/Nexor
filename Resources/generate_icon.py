#!/usr/bin/env python3
import os
import math
import subprocess
from PIL import Image, ImageDraw, ImageFilter

def create_master_icon(size=1024):
    # Render at 2x resolution (2048x2048) for ultra-sharp supersampling
    scale = 2
    canvas_size = size * scale
    img = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    
    # macOS squircle dimensions at 2x
    # Standard macOS squircle: 824x824 centered in 1024x1024, corner radius 185
    margin = 100 * scale
    sq_size = 824 * scale
    radius = int(185 * scale)
    x0, y0 = margin, margin
    x1, y1 = margin + sq_size, margin + sq_size
    
    # 1. Subtle drop shadow beneath squircle
    shadow_img = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow_img)
    shadow_offset_y = 20 * scale
    shadow_draw.rounded_rectangle(
        [x0, y0 + shadow_offset_y, x1, y1 + shadow_offset_y],
        radius=radius,
        fill=(0, 0, 0, 110)
    )
    shadow_img = shadow_img.filter(ImageFilter.GaussianBlur(radius=28 * scale))
    img.paste(shadow_img, (0, 0), shadow_img)
    
    # 2. Base squircle with liquid dark glass gradient
    # Gradient: Midnight obsidian (#0d111e) to deep cosmic blue (#141e38)
    base_mask = Image.new("L", (canvas_size, canvas_size), 0)
    base_mask_draw = ImageDraw.Draw(base_mask)
    base_mask_draw.rounded_rectangle([x0, y0, x1, y1], radius=radius, fill=255)
    
    squircle_layer = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    for y in range(y0, y1):
        ratio = (y - y0) / sq_size
        # Dark celestial gradient: (12, 17, 30) -> (18, 28, 56) -> (8, 12, 22)
        if ratio < 0.5:
            r = int(14 + (22 - 14) * (ratio * 2))
            g = int(20 + (34 - 20) * (ratio * 2))
            b = int(38 + (64 - 38) * (ratio * 2))
        else:
            r = int(22 - (22 - 10) * ((ratio - 0.5) * 2))
            g = int(34 - (34 - 14) * ((ratio - 0.5) * 2))
            b = int(64 - (64 - 26) * ((ratio - 0.5) * 2))
        line_draw = ImageDraw.Draw(squircle_layer)
        line_draw.line([(x0, y), (x1, y)], fill=(r, g, b, 255))
        
    # Radial ambient backdrop glow in center
    glow_layer = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow_layer)
    cx, cy = canvas_size // 2, canvas_size // 2
    max_glow_r = int(sq_size * 0.45)
    for r in range(max_glow_r, 0, -6 * scale):
        alpha = int(45 * (1.0 - r / max_glow_r))
        glow_draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=(0, 180, 255, alpha))
    glow_layer = glow_layer.filter(ImageFilter.GaussianBlur(radius=20 * scale))
    squircle_layer.paste(glow_layer, (0, 0), glow_layer)
    
    # 3. Network Radar & Topology Vector Art
    art_layer = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    art_draw = ImageDraw.Draw(art_layer)
    
    # Concentric radar grid rings
    radar_radii = [int(r * scale) for r in [70, 140, 210, 280]]
    for r in radar_radii:
        # Subtle ring
        art_draw.ellipse(
            [cx - r, cy - r, cx + r, cy + r],
            outline=(0, 240, 255, 45),
            width=int(2.5 * scale)
        )
    
    # Radar sweep beam / sweep cone
    sweep_layer = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    sweep_draw = ImageDraw.Draw(sweep_layer)
    # 60-degree radar fan beam
    start_angle = -45
    span = 55
    outer_r = radar_radii[-1]
    poly_points = [(cx, cy)]
    for a in range(start_angle, start_angle + span, 2):
        rad = math.radians(a)
        px = cx + outer_r * math.cos(rad)
        py = cy + outer_r * math.sin(rad)
        poly_points.append((px, py))
    poly_points.append((cx, cy))
    sweep_draw.polygon(poly_points, fill=(0, 245, 255, 35))
    sweep_layer = sweep_layer.filter(ImageFilter.GaussianBlur(radius=8 * scale))
    art_layer.paste(sweep_layer, (0, 0), sweep_layer)
    
    # Crosshair grid axes
    art_draw.line([(cx - outer_r, cy), (cx + outer_r, cy)], fill=(0, 240, 255, 30), width=int(1.5 * scale))
    art_draw.line([(cx, cy - outer_r), (cx, cy + outer_r)], fill=(0, 240, 255, 30), width=int(1.5 * scale))
    
    # Network nodes & links
    nodes = [
        # (angle_deg, dist, radius, color, label)
        (0, 0, 32 * scale, (0, 245, 255, 255)),            # Center Hub
        (-60, 150 * scale, 16 * scale, (50, 180, 255, 240)),  # Node 1
        (-140, 180 * scale, 14 * scale, (140, 100, 255, 240)), # Node 2
        (45, 210 * scale, 18 * scale, (0, 255, 200, 240)),   # Node 3
        (130, 160 * scale, 15 * scale, (80, 160, 255, 240)),  # Node 4
        (-25, 260 * scale, 13 * scale, (0, 230, 255, 220)),   # Node 5
        (165, 250 * scale, 12 * scale, (180, 120, 255, 220)), # Node 6
    ]
    
    node_coords = []
    for deg, dist, r, col in nodes:
        if dist == 0:
            nx, ny = cx, cy
        else:
            rad = math.radians(deg)
            nx = cx + int(dist * math.cos(rad))
            ny = cy + int(dist * math.sin(rad))
        node_coords.append((nx, ny, r, col))
    
    # Draw laser connections between center and nodes
    for i in range(1, len(node_coords)):
        nx, ny, _, _ = node_coords[i]
        art_draw.line([(cx, cy), (nx, ny)], fill=(0, 230, 255, 90), width=int(2.5 * scale))
    # Some peer-to-peer interconnections
    art_draw.line([(node_coords[1][0], node_coords[1][1]), (node_coords[5][0], node_coords[5][1])], fill=(0, 200, 255, 60), width=int(1.5 * scale))
    art_draw.line([(node_coords[2][0], node_coords[2][1]), (node_coords[4][0], node_coords[4][1])], fill=(120, 120, 255, 60), width=int(1.5 * scale))
    art_draw.line([(node_coords[3][0], node_coords[3][1]), (node_coords[5][0], node_coords[5][1])], fill=(0, 240, 220, 60), width=int(1.5 * scale))
    
    # Draw nodes with multi-layer glowing halos
    for nx, ny, r, col in node_coords:
        # Outer glow
        glow_r = int(r * 2.2)
        halo = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
        halo_draw = ImageDraw.Draw(halo)
        halo_draw.ellipse([nx - glow_r, ny - glow_r, nx + glow_r, ny + glow_r], fill=(col[0], col[1], col[2], 80))
        halo = halo.filter(ImageFilter.GaussianBlur(radius=int(6 * scale)))
        art_layer.paste(halo, (0, 0), halo)
        
        # Solid core with inner gradient/sheen
        art_draw.ellipse([nx - r, ny - r, nx + r, ny + r], fill=col)
        # Specular glint on node
        glint_r = max(int(r * 0.35), 2)
        art_draw.ellipse([nx - r//3 - glint_r, ny - r//3 - glint_r, nx - r//3 + glint_r, ny - r//3 + glint_r], fill=(255, 255, 255, 200))
        
    # Central Hub special glass sphere treatment
    c_r = node_coords[0][2]
    art_draw.ellipse([cx - c_r, cy - c_r, cx + c_r, cy + c_r], fill=(0, 245, 255, 255))
    inner_r = int(c_r * 0.65)
    art_draw.ellipse([cx - inner_r, cy - inner_r, cx + inner_r, cy + inner_r], fill=(255, 255, 255, 230))
    
    squircle_layer.paste(art_layer, (0, 0), art_layer)
    
    # 4. Glass Specular Sheen (Apple Liquid Glass Diagonal Highlight)
    sheen_layer = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    sheen_draw = ImageDraw.Draw(sheen_layer)
    # Diagonal ellipse clip across top half
    sheen_draw.polygon([
        (x0, y0),
        (x1, y0),
        (x1, y0 + int(sq_size * 0.45)),
        (x0, y0 + int(sq_size * 0.20))
    ], fill=(255, 255, 255, 22))
    sheen_layer = sheen_layer.filter(ImageFilter.GaussianBlur(radius=int(18 * scale)))
    squircle_layer.paste(sheen_layer, (0, 0), sheen_layer)
    
    # 5. Inner Hairline Glass Border
    border_draw = ImageDraw.Draw(squircle_layer)
    border_draw.rounded_rectangle(
        [x0, y0, x1, y1],
        radius=radius,
        outline=(255, 255, 255, 45),
        width=int(2.5 * scale)
    )
    # Top highlight line
    border_draw.line(
        [(x0 + radius, y0 + 1), (x1 - radius, y0 + 1)],
        fill=(255, 255, 255, 110),
        width=int(2 * scale)
    )
    
    # Mask squircle_layer by base_mask to guarantee perfect rounded edges
    final_squircle = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    final_squircle.paste(squircle_layer, (0, 0), base_mask)
    
    # Composite squircle over drop shadow
    img.paste(final_squircle, (0, 0), final_squircle)
    
    # Downsample from 2048x2048 to 1024x1024 with high-quality Lanczos filter
    final_icon = img.resize((size, size), Image.Resampling.LANCZOS)
    return final_icon

def generate_iconset():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    iconset_dir = os.path.join(script_dir, "AppIcon.iconset")
    os.makedirs(iconset_dir, exist_ok=True)
    
    print("Generating 1024x1024 master icon with 2x supersampling...")
    master = create_master_icon(1024)
    
    sizes = [
        ("icon_16x16.png", 16),
        ("icon_16x16@2x.png", 32),
        ("icon_32x32.png", 32),
        ("icon_32x32@2x.png", 64),
        ("icon_128x128.png", 128),
        ("icon_128x128@2x.png", 256),
        ("icon_256x256.png", 256),
        ("icon_256x256@2x.png", 512),
        ("icon_512x512.png", 512),
        ("icon_512x512@2x.png", 1024),
    ]
    
    for filename, s in sizes:
        resized = master.resize((s, s), Image.Resampling.LANCZOS)
        out_path = os.path.join(iconset_dir, filename)
        resized.save(out_path, "PNG")
        print(f"  ✓ Saved {filename} ({s}x{s})")
        
    icns_path = os.path.join(script_dir, "AppIcon.icns")
    print(f"Compiling iconset to {icns_path} via iconutil...")
    cmd = ["iconutil", "-c", "icns", iconset_dir, "-o", icns_path]
    subprocess.check_call(cmd)
    print(f"✓ Successfully generated {icns_path} ({os.path.getsize(icns_path)} bytes)")

if __name__ == "__main__":
    generate_iconset()
