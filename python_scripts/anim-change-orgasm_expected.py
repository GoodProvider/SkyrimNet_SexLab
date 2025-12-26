import sys
import os 
import json 
# import argparse
# Create the parser
# parser = argparse.ArgumentParser(description='Parses the wiki.')

# Add arguments
# parser.add_argument('-s', '--src', type=str, required=True)
# parser.add_argument('-d', '--dst', type=str, required=True)
# args = parser.parse_args()

root = "SkyrimNet_SexLab/animations"
for dname in os.listdir(root):
    path = f"{root}/{dname}"
    for name in os.listdir(path):
        fname = f"{path}/{name}"
        fixed = None 
        with open(fname) as fin:
            info = json.load(fin)
            if "orgasm_denied" in info:
                no_orgasm_expected_found = False
                for i in (info['orgasm_denied']):
                    if i == 1: 
                        no_orgasm_expected_found = True
                if no_orgasm_expected_found:
                    info['orgasm_expected'] = info['orgasm_denied']
                    del info['orgasm_denied']
                    for i,j in enumerate(info['orgasm_expected']):
                        if j == 1:
                            info['orgasm_expected'][i] = 0
                        else:
                            info['orgasm_expected'][i] = 1
                    #print (json.dumps(info,indent=4))
                    fixed = info
        if fixed:
            print (fname)
            with open(fname,"w") as fout:
                json.dump(fixed,fp=fout,indent=4)

            #print ("loading",fname)
            #fname_info[fname] = json.load(fin) 
        #if fname_info[fname]:
            #os.remove(path) 