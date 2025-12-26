import sys 
import re 
import os 
import json 
import nltk


animations = [] 
for dirpath, dirnames, filenames in os.walk(sys.argv[1]+'/animations'): 
    for name in filenames: 
        path = os.path.join(dirpath, name) 
        print (path) 
        with open (path) as fin: 
            data = json.load(fin) 
            for anim in data['animations']: 
                animations.append({ 
                    "id":anim['id'],
                    "name":anim['name'],
                    "desc":{}
                })

line_re = re.compile(r"\"([^-]+)-(\d)\":\s*\"([^\"]+)")
for dirpath, dirnames, filenames in os.walk(sys.argv[1]+'/descriptions'): 
    for name in filenames: 
        path = os.path.join(dirpath, name) 
        with open (path) as fin: 
            for line in fin: 
                m = line_re.search(line) 
                if m: 
                    name, i, desc = m.groups() 
                    desc = desc.replace("sceneData","sl")
                    if "BakaFactor" in sys.argv[1]: 
                        name = "Babo_"+name[4:]
                    best_dist = None 
                    best_anim = None 
                    for anim in animations: 
                        dist = nltk.edit_distance(anim['id'].lower(), name.lower())
                        if best_dist is None or best_dist > dist: 
                            best_dist = dist 
                            best_anim = anim 
                    if best_dist is not None and best_dist < 5: 
                        best_anim["desc"]["Stage "+i] = {
                            "description":desc,
                            "version": "2.0"
                        }
                else: 
                    print ("ERROR",line.rstrip())

for anim in animations: 
    keys = anim["desc"].keys() 
    if len(keys) > 0: 
        fname = "SkyrimNet_SexLab/animations/Goncalo/"+anim['name']+".json"
        print (fname) 
        with open(fname,'w') as fout: 
            fout.write(json.dumps(anim['desc'],indent=4))
