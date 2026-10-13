import os
from PIL import Image

def main():
    dir_path = os.path.dirname(os.path.realpath(__file__))
    img_path = os.path.join(dir_path, 'C:\\Users\pikeb\\Desktop\\abuad\\assets\\images\\logo.png')
    output_path = os.path.join(dir_path, 'splash_padded.png')
    
    # Load original splash image
    img = Image.open(img_path)
    
    # Canvas size for Android 12 without background: 1152x1152 px
    canvas_size = 1024
    canvas = Image.new('RGBA', (canvas_size, canvas_size), (0, 0, 0, 0))
    
    # Scale the logo so it fits comfortably inside the safe circle zone (diameter: 768px).
    # 460px is a standard premium size that prevents the logo from being cut off or looking too big.
    target_size = 640
    
    # Scale image maintaining aspect ratio
    w, h = img.size
    ratio = min(target_size / w, target_size / h)
    new_w = int(w * ratio)
    new_h = int(h * ratio)
    resized_img = img.resize((new_w, new_h), Image.Resampling.LANCZOS)
    
    # Paste centered
    x = (canvas_size - new_w) // 2
    y = (canvas_size - new_h) // 2
    canvas.paste(resized_img, (x, y), resized_img)
    
    canvas.save(output_path)
    print(f"Padded splash icon created at {output_path} with size 1152x1152 and centered logo of {new_w}x{new_h}")

if __name__ == '__main__':
    main()
