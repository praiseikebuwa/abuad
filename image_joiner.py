#!/usr/bin/env python3
"""
Image Joiner & App Icon Compositor Utility
==========================================
A flexible Python tool to join images either by overlaying/compositing (e.g., placing a logo onto a background for app icons) or stitching (horizontally, vertically, grid).

Modes:
  1. Overlay / App Icon Mode ("overlay", "icon"):
     Overlays a logo/foreground image centered on top of a background image or canvas.
     Scales the logo gracefully to fit inside safe icon margins.
  2. Stitching Modes ("horizontal", "vertical", "grid"):
     Stitches multiple images side-by-side, stacked, or in a matrix grid.

Dependencies:
  - Pillow (`pip install Pillow`)

CLI Usage Examples:
  # App Icon Overlay Mode (Join logo 'pi.png' centered on background 'f.png'):
  python image_joiner.py pi.png f.png -o joined.png -d overlay --scale 0.65

  # App Icon Mode with solid color canvas:
  python image_joiner.py logo.png -o app_icon.png -d overlay --bg "#101726" --canvas-size 1024x1024 --scale 0.6

  # Horizontal Side-by-Side Stitch:
  python image_joiner.py img1.png img2.png -o stitched.png -d horizontal -s 10

  # 2x2 Grid Stitch:
  python image_joiner.py img1.png img2.png img3.png img4.png -o grid.png --cols 2 -s 15
"""

import os
import sys
import argparse
from typing import List, Tuple, Union, Optional

try:
    from PIL import Image, ImageColor, ImageDraw, ImageFilter
except ImportError:
    print("Error: The 'Pillow' library is required to run image_joiner.py.")
    print("Please install it using: pip install Pillow")
    sys.exit(1)


def parse_color(color_str: str) -> Tuple[int, int, int, int]:
    """Parse color string (hex, named color, transparent) into RGBA tuple."""
    color_str = color_str.strip().lower()
    if color_str in ("transparent", "none", "alpha"):
        return (0, 0, 0, 0)
    try:
        if color_str.startswith("#"):
            rgb = ImageColor.getrgb(color_str)
            return (*rgb, 255) if len(rgb) == 3 else rgb
        rgb = ImageColor.getrgb(color_str)
        return (*rgb, 255) if len(rgb) == 3 else rgb
    except ValueError:
        return (255, 255, 255, 255)


def create_rounded_mask(size: Tuple[int, int], radius: int) -> Image.Image:
    """Create a high-quality anti-aliased rounded rectangle mask."""
    w, h = size
    scale = 4  # 4x super-sampling for anti-aliasing
    mask_large = Image.new("L", (w * scale, h * scale), 0)
    draw = ImageDraw.Draw(mask_large)
    draw.rounded_rectangle((0, 0, w * scale - 1, h * scale - 1), radius=radius * scale, fill=255)
    return mask_large.resize(size, Image.Resampling.LANCZOS)


def create_circle_mask(size: Tuple[int, int]) -> Image.Image:
    """Create an anti-aliased circular mask."""
    w, h = size
    scale = 4
    mask_large = Image.new("L", (w * scale, h * scale), 0)
    draw = ImageDraw.Draw(mask_large)
    draw.ellipse((0, 0, w * scale - 1, h * scale - 1), fill=255)
    return mask_large.resize(size, Image.Resampling.LANCZOS)


def apply_drop_shadow(
    image: Image.Image,
    offset: Tuple[int, int] = (0, 8),
    blur_radius: int = 15,
    shadow_color: Tuple[int, int, int, int] = (0, 0, 0, 90)
) -> Image.Image:
    """Add a soft drop shadow around a transparent PNG/RGBA logo."""
    if image.mode != "RGBA":
        image = image.convert("RGBA")

    # Extract alpha channel as mask
    alpha = image.split()[3]
    shadow_mask = alpha.filter(ImageFilter.GaussianBlur(blur_radius))

    # Create shadow canvas
    w = image.width + abs(offset[0]) + blur_radius * 2
    h = image.height + abs(offset[1]) + blur_radius * 2

    shadow_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    shadow_layer = Image.new("RGBA", (w, h), shadow_color)

    # Paste shadow mask
    paste_x = blur_radius + max(0, offset[0])
    paste_y = blur_radius + max(0, offset[1])
    shadow_img.paste(shadow_layer, (0, 0), mask=shadow_mask)

    # Paste original image on top
    img_x = blur_radius + max(0, -offset[0])
    img_y = blur_radius + max(0, -offset[1])
    shadow_img.paste(image, (img_x, img_y), mask=image)

    return shadow_img


def overlay_logo_on_background(
    logo_img: Image.Image,
    bg_img: Optional[Image.Image] = None,
    canvas_size: Tuple[int, int] = (1024, 1024),
    bg_color: str = "transparent",
    scale_ratio: float = 0.65,
    shape: str = "none",  # "none", "rounded", "circle", "squircle"
    corner_radius: int = 180,
    add_shadow: bool = False
) -> Image.Image:
    """
    Overlay a logo/foreground image centered on top of a background image or canvas.

    Args:
        logo_img: The logo or foreground PIL Image.
        bg_img: Optional background PIL Image. If None, canvas of canvas_size is created.
        canvas_size: Width x Height tuple if creating a new background canvas.
        bg_color: Background color for canvas or fill.
        scale_ratio: Size ratio of logo relative to background canvas (e.g., 0.65 = 65%).
        shape: Shape mask for app icon ("none", "rounded", "circle", "squircle").
        corner_radius: Radius for rounded corner app icons.
        add_shadow: If True, adds a subtle drop shadow under the logo.

    Returns:
        Combined PIL Image.
    """
    bg_rgba = parse_color(bg_color)

    if bg_img is not None:
        canvas = bg_img.convert("RGBA").copy()
        cw, ch = canvas.size
    else:
        cw, ch = canvas_size
        canvas = Image.new("RGBA", (cw, ch), bg_rgba)

    # Calculate target dimensions for logo
    max_logo_w = int(cw * scale_ratio)
    max_logo_h = int(ch * scale_ratio)

    lw, lh = logo_img.size
    ratio = min(max_logo_w / lw, max_logo_h / lh)
    new_lw = max(1, int(lw * ratio))
    new_lh = max(1, int(lh * ratio))

    resized_logo = logo_img.resize((new_lw, new_lh), Image.Resampling.LANCZOS)

    if add_shadow:
        resized_logo = apply_drop_shadow(resized_logo)
        new_lw, new_lh = resized_logo.size

    # Center position
    paste_x = (cw - new_lw) // 2
    paste_y = (ch - new_lh) // 2

    # Composite logo onto canvas
    canvas.paste(resized_logo, (paste_x, paste_y), mask=resized_logo if resized_logo.mode == "RGBA" else None)

    # Apply shape masking if requested for app icon output
    if shape in ("rounded", "squircle"):
        mask = create_rounded_mask((cw, ch), corner_radius)
        masked_canvas = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        masked_canvas.paste(canvas, (0, 0), mask=mask)
        return masked_canvas
    elif shape == "circle":
        mask = create_circle_mask((cw, ch))
        masked_canvas = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        masked_canvas.paste(canvas, (0, 0), mask=mask)
        return masked_canvas

    return canvas


def resize_image_aspect(img: Image.Image, target_width: Optional[int] = None, target_height: Optional[int] = None) -> Image.Image:
    """Resize an image preserving aspect ratio."""
    w, h = img.size
    if target_width and not target_height:
        new_h = int(h * (target_width / w))
        return img.resize((target_width, max(1, new_h)), Image.Resampling.LANCZOS)
    elif target_height and not target_width:
        new_w = int(w * (target_height / h))
        return img.resize((max(1, new_w), target_height), Image.Resampling.LANCZOS)
    elif target_width and target_height:
        return img.resize((target_width, target_height), Image.Resampling.LANCZOS)
    return img


def join_images(
    images: List[Union[str, Image.Image]],
    direction: str = "overlay",
    cols: Optional[int] = None,
    spacing: int = 0,
    padding: int = 0,
    bg_color: str = "transparent",
    resize_mode: str = "none",
    align: str = "center",
    scale_ratio: float = 0.65,
    shape: str = "none",
    corner_radius: int = 180,
    canvas_size: Tuple[int, int] = (1024, 1024),
    shadow: bool = False
) -> Image.Image:
    """
    Main image joiner / compositor entry point.
    Supports both Overlay/App-Icon compositing and Stitching (horizontal, vertical, grid).
    """
    if not images:
        raise ValueError("At least one image must be provided.")

    loaded_imgs: List[Image.Image] = []
    for item in images:
        if isinstance(item, str):
            if not os.path.exists(item):
                raise FileNotFoundError(f"Image file not found: {item}")
            img = Image.open(item).convert("RGBA")
        elif isinstance(item, Image.Image):
            img = item.convert("RGBA")
        else:
            raise TypeError(f"Invalid image type: {type(item)}")
        loaded_imgs.append(img)

    dir_clean = direction.lower().strip()

    # --- OVERLAY / APP ICON MODE ---
    if dir_clean in ("overlay", "icon", "app-icon", "center"):
        logo = loaded_imgs[0]
        bg = loaded_imgs[1] if len(loaded_imgs) > 1 else None

        return overlay_logo_on_background(
            logo_img=logo,
            bg_img=bg,
            canvas_size=canvas_size,
            bg_color=bg_color,
            scale_ratio=scale_ratio,
            shape=shape,
            corner_radius=corner_radius,
            add_shadow=shadow
        )

    # --- STITCHING MODES ---
    bg_rgba = parse_color(bg_color)
    if cols is not None and cols > 0:
        dir_clean = "grid"

    # Resizing for stitching
    if resize_mode == "match_max":
        if dir_clean in ("horizontal", "h"):
            max_h = max(img.height for img in loaded_imgs)
            loaded_imgs = [resize_image_aspect(img, target_height=max_h) for img in loaded_imgs]
        elif dir_clean in ("vertical", "v"):
            max_w = max(img.width for img in loaded_imgs)
            loaded_imgs = [resize_image_aspect(img, target_width=max_w) for img in loaded_imgs]
    elif resize_mode == "match_min":
        if dir_clean in ("horizontal", "h"):
            min_h = min(img.height for img in loaded_imgs)
            loaded_imgs = [resize_image_aspect(img, target_height=min_h) for img in loaded_imgs]
        elif dir_clean in ("vertical", "v"):
            min_w = min(img.width for img in loaded_imgs)
            loaded_imgs = [resize_image_aspect(img, target_width=min_w) for img in loaded_imgs]

    # Horizontal Stitch
    if dir_clean in ("horizontal", "h"):
        total_width = sum(img.width for img in loaded_imgs) + spacing * (len(loaded_imgs) - 1) + (padding * 2)
        max_height = max(img.height for img in loaded_imgs) + (padding * 2)

        canvas = Image.new("RGBA", (total_width, max_height), bg_rgba)
        current_x = padding

        for img in loaded_imgs:
            if align == "start":
                y = padding
            elif align == "end":
                y = max_height - padding - img.height
            else:
                y = padding + (max_height - 2 * padding - img.height) // 2

            canvas.paste(img, (current_x, y), mask=img)
            current_x += img.width + spacing

        return canvas

    # Vertical Stitch
    elif dir_clean in ("vertical", "v"):
        max_width = max(img.width for img in loaded_imgs) + (padding * 2)
        total_height = sum(img.height for img in loaded_imgs) + spacing * (len(loaded_imgs) - 1) + (padding * 2)

        canvas = Image.new("RGBA", (max_width, total_height), bg_rgba)
        current_y = padding

        for img in loaded_imgs:
            if align == "start":
                x = padding
            elif align == "end":
                x = max_width - padding - img.width
            else:
                x = padding + (max_width - 2 * padding - img.width) // 2

            canvas.paste(img, (x, current_y), mask=img)
            current_y += img.height + spacing

        return canvas

    # Grid Stitch
    elif dir_clean in ("grid", "g"):
        num_imgs = len(loaded_imgs)
        num_cols = cols if cols and cols > 0 else int(num_imgs ** 0.5 + 0.999)
        num_rows = (num_imgs + num_cols - 1) // num_cols

        col_widths = [0] * num_cols
        row_heights = [0] * num_rows

        for idx, img in enumerate(loaded_imgs):
            r = idx // num_cols
            c = idx % num_cols
            col_widths[c] = max(col_widths[c], img.width)
            row_heights[r] = max(row_heights[r], img.height)

        total_w = sum(col_widths) + spacing * (num_cols - 1) + (padding * 2)
        total_h = sum(row_heights) + spacing * (num_rows - 1) + (padding * 2)

        canvas = Image.new("RGBA", (total_w, total_h), bg_rgba)

        for idx, img in enumerate(loaded_imgs):
            r = idx // num_cols
            c = idx % num_cols

            cell_x_offset = padding + sum(col_widths[:c]) + (c * spacing)
            cell_y_offset = padding + sum(row_heights[:r]) + (r * spacing)

            cell_w = col_widths[c]
            cell_h = row_heights[r]

            if align == "start":
                x = cell_x_offset
                y = cell_y_offset
            elif align == "end":
                x = cell_x_offset + (cell_w - img.width)
                y = cell_y_offset + (cell_h - img.height)
            else:
                x = cell_x_offset + (cell_w - img.width) // 2
                y = cell_y_offset + (cell_h - img.height) // 2

            canvas.paste(img, (x, y), mask=img)

        return canvas

    else:
        raise ValueError(f"Unknown direction '{direction}'. Choose 'overlay', 'horizontal', 'vertical', or 'grid'.")


def main():
    parser = argparse.ArgumentParser(
        description="Join or overlay images to create app icons, logos on backgrounds, or stitched grids."
    )
    parser.add_argument("inputs", nargs="+", help="Input image file paths (for overlay: logo.png [bg.png])")
    parser.add_argument("-o", "--output", required=True, help="Output image file path (e.g. joined.png, app_icon.png)")
    parser.add_argument(
        "-d", "--direction", "--mode",
        dest="direction",
        choices=["overlay", "icon", "horizontal", "vertical", "grid", "h", "v", "g"],
        default="overlay",
        help="Operation mode: 'overlay' (center logo on background for app icons) or stitch ('horizontal', 'vertical', 'grid')"
    )
    parser.add_argument(
        "--scale", type=float, default=0.65,
        help="Ratio size of logo relative to background canvas in overlay mode (default: 0.65 = 65%%)"
    )
    parser.add_argument(
        "--shape", choices=["none", "rounded", "circle", "squircle"], default="none",
        help="App icon mask shape ('none', 'rounded', 'circle', 'squircle')"
    )
    parser.add_argument("--corner-radius", type=int, default=180, help="Corner radius for rounded/squircle icons")
    parser.add_argument("--shadow", action="store_true", help="Add drop shadow behind logo in overlay mode")
    parser.add_argument("--canvas-size", default="1024x1024", help="Canvas dimensions WxH if no background image is given")

    # Stitch options
    parser.add_argument("-c", "--cols", type=int, default=None, help="Number of columns for grid layout")
    parser.add_argument("-s", "--spacing", type=int, default=0, help="Pixel gap spacing between images")
    parser.add_argument("-p", "--padding", type=int, default=0, help="Outer padding border in pixels")
    parser.add_argument(
        "-b", "--bg", "--bg-color",
        dest="bg_color",
        default="transparent",
        help="Background color ('transparent', 'white', 'black', '#1e293b')"
    )
    parser.add_argument(
        "-r", "--resize",
        choices=["none", "match_max", "match_min"],
        default="none",
        help="Resize strategy for stitching"
    )

    args = parser.parse_args()

    # Parse canvas size WxH
    try:
        cw_str, ch_str = args.canvas_size.lower().split("x")
        c_size = (int(cw_str), int(ch_str))
    except Exception:
        c_size = (1024, 1024)

    try:
        result_img = join_images(
            images=args.inputs,
            direction=args.direction,
            cols=args.cols,
            spacing=args.spacing,
            padding=args.padding,
            bg_color=args.bg_color,
            resize_mode=args.resize,
            scale_ratio=args.scale,
            shape=args.shape,
            corner_radius=args.corner_radius,
            canvas_size=c_size,
            shadow=args.shadow
        )

        output_path = args.output
        out_dir = os.path.dirname(output_path)
        if out_dir:
            os.makedirs(out_dir, exist_ok=True)

        if output_path.lower().endswith((".jpg", ".jpeg")):
            bg_rgb = parse_color(args.bg_color)
            if bg_rgb[3] == 0:
                bg_rgb = (255, 255, 255, 255)
            final_img = Image.new("RGB", result_img.size, bg_rgb[:3])
            final_img.paste(result_img, mask=result_img.split()[3])
            final_img.save(output_path, quality=95)
        else:
            result_img.save(output_path)

        print(f"Successfully processed {len(args.inputs)} images -> {output_path}")

    except Exception as e:
        print(f"Error processing images: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()