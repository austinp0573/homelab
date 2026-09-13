import os
import json
import urllib.request

os.makedirs("images", exist_ok=True)

# Custom headers to emulate standard browser requests
headers = {
    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    "Referer": "https://pointerpointer.com/"
}

with open("new-positions.json", "r") as f:
    positions = json.load(f)

print(f"Downloading {len(positions)} images...")

for idx in range(len(positions)):
    img_url = f"https://pointerpointer.com/images/{idx}.jpg"
    target_path = f"images/{idx}.jpg"
    
    if not os.path.exists(target_path):
        try:
            req = urllib.request.Request(img_url, headers=headers)
            with urllib.request.urlopen(req) as response, open(target_path, "wb") as out_file:
                out_file.write(response.read())
        except Exception as e:
            print(f"Failed {idx}: {e}")

print("Dataset capture complete.")
