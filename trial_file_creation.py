'''
Creates trial file in the format spkid utterance target/nontarget.
Input : location of public_test_cohart.csv file
'''

import pandas as pd
csv_file = 'public_test_cohart.csv'

df = pd.read_csv (csv_file, usecols=['rand_ID','c1','c2','c3','c4','c5','Utterance_ID'])
#ID = df['id']
rand_ID_list = df['rand_ID'].tolist()
c1_list = df['c1'].tolist()
c2_list = df['c2'].tolist()
c3_list = df['c3'].tolist()
c4_list = df['c4'].tolist()
c5_list = df['c5'].tolist()
utt_id = df['Utterance_ID'].tolist()

f_trial=open("trial_file","w")

for uu ,m1,m2,m3,m4,m5, utt in zip(rand_ID_list,c1_list,c2_list,c3_list,c4_list,c5_list,utt_id):
    if m1 == int(utt.split("_")[0]):
       line = str(m1)+" "+ uu.split(".")[0] + " " + "target" 
       f_trial.write("%s\n"%line)
    else:
       line = str(m1)+" "+ uu.split(".")[0]  + " " + "nontarget" 
       f_trial.write("%s\n"%line)
       

    if m2 == int(utt.split("_")[0]):
       line = str(m2)+" "+ uu.split(".")[0]  + " " + "target" 
       f_trial.write("%s\n"%line)
    else:
       line = str(m2)+" "+ uu.split(".")[0]  + " " + "nontarget" 
       f_trial.write("%s\n"%line)

    if m3 == int(utt.split("_")[0]):
       line = str(m3)+" "+ uu.split(".")[0]  + " " + "target" 
       f_trial.write("%s\n"%line)
    else:
       line = str(m3)+" "+ uu.split(".")[0]  + " " + "nontarget" 
       f_trial.write("%s\n"%line)

    if m4 == int(utt.split("_")[0]):
       line = str(m4)+" "+ uu.split(".")[0]  + " " + "target" 
       f_trial.write("%s\n"%line)
    else:
       line = str(m4)+" "+ uu.split(".")[0]  + " " + "nontarget" 
       f_trial.write("%s\n"%line)

    if m5 == int(utt.split("_")[0]):
       line = str(m5)+" "+ uu.split(".")[0]  + " " + "target" 
       f_trial.write("%s\n"%line)
    else:
       line = str(m5)+" "+ uu.split(".")[0]  + " " + "nontarget" 
       f_trial.write("%s\n"%line)


