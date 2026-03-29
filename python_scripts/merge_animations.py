import sys
import os 
import argparse
import json 
# Create the parser
parser = argparse.ArgumentParser(description='Parses the wiki.')

# Add arguments
parser.add_argument('-s', '--src', type=str, required=True)
parser.add_argument('-d', '--dst', type=str, required=True)
args = parser.parse_args()

fname_info = {} 
for fname in os.listdir(args.src):
    path = f"{args.src}/{fname}"
    with open(path) as fin:
        print ("loading",fname)
        try:
            fname_info[fname] = json.load(fin)
        except json.JSONDecodeError as e:
            print(f"ERROR: Failed to parse {path}: {e}", file=sys.stderr)
            sys.exit(1)
    if fname_info[fname]:
        os.remove(path) 

for fname,info in fname_info.items(): 
    path = f"{args.dst}/{fname}"
    merged = " " 
    if os.path.exists(path): 
        with open(path) as fin:
            print ("loading",fname)
            try:
                old = json.load(fin)
            except json.JSONDecodeError as e:
                print(f"ERROR: Failed to parse destination {path}: {e}", file=sys.stderr)
                sys.exit(1)
            for key,value in old.items(): 
                if key not in info: 
                    merged = "M" 
                    info[key] = value 
    with open(path,"w") as fout: 
        json.dump(info,indent=4,fp=fout)