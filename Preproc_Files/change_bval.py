import sys
import os

mybval_file = sys.argv[1]
mybvec_file = sys.argv[2]

f=open(mybval_file,'r')
bvals=f.read()
newbvals = "0"+bvals[1:len(bvals)]
bvals_path = os.path.dirname(mybval_file)
new_bval_file = bvals_path + "/newbval.txt"
f=open(new_bval_file,'w')
f.write(newbvals)
f.close()

newbvecs=""
with open (mybvec_file, 'r') as myfile:
    for myline in myfile:
        newbvecs = newbvecs + "0 "
        newbvecs = newbvecs + myline[1:len(myline)]
bvecs_path = os.path.dirname(mybvec_file)
new_bvec_file = bvecs_path + "/newbvec.txt"
f=open(new_bvec_file,'w')
f.write(newbvecs)
f.close()
