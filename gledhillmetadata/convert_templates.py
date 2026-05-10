import json
import os

old_dir = os.path.expanduser("~/Documents/GitHub/Gledhill-Studio/Templates Old")
new_dir = os.path.expanduser("~/Documents/GitHub/Gledhill-Studio/Templates New")

# Ensure new dirs exist
os.makedirs(os.path.join(new_dir, "Metadata"), exist_ok=True)
os.makedirs(os.path.join(new_dir, "Naming Conventions"), exist_ok=True)

# Convert metadata
metadata_dir = os.path.join(old_dir, "Metadata")
for filename in os.listdir(metadata_dir):
    if filename.endswith('.json'):
        filepath = os.path.join(metadata_dir, filename)
        with open(filepath, 'r') as f:
            data = json.load(f)
        
        fields = {}
        
        # First, map exif
        if 'exif' in data:
            for key, value in data['exif'].items():
                if key == 'ImageDescription':
                    fields['XMP:Description'] = value
                elif key == 'Artist':
                    fields['XMP:Creator'] = value
                elif key == 'Copyright':
                    fields['XMP:Copyright'] = v  ue
        
        # Then, map xmp (overwrites)
        if 'xmp' in data:
            for            for            for            for            for            for                   for    XMP:K            for            for            for            for              for            for            for            for          des            fo                 for            for            for                for            for                          fields['XMP:Creator'] = value
                elif key == 'rights':
                                       ht'] = value
        
        new_data = {
            "name": data["name"],
            "isFavorite": False,
            "fields":             "fields":             "fields":       s.            "fields":             "fields"       with open(new_filepath, 'w') as f:
            json            json            json    er            json            json     path.join(old            json            json ilename in os.listdir(naming_dir):
    if filename.endswith('.json'):    if filename.endswith('.json'): ming_dir, filename)
                                                                                                                                                                                                                                                                                                                                                                                                                                te.")
