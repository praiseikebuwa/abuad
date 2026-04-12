import subprocess
import re

command = [
    "keytool", "-list", "-v", 
    "-keystore", r"C:\Users\pikeb\.android\debug.keystore", 
    "-alias", "androiddebugkey", 
    "-storepass", "android", 
    "-keypass", "android"
]

try:
    result = subprocess.run(command, capture_output=True, text=True, check=True)
    output = result.stdout
    sha256_match = re.search(r"SHA256: ([\s\S]+?)\n\s+Signature algorithm name", output)
    if sha256_match:
        sha256 = sha256_match.group(1).replace("\n", "").replace(" ", "")
        print(f"FULL_SHA256: {sha256}")
    else:
        print("SHA256 not found in output")
except Exception as e:
    print(f"Error: {e}")
