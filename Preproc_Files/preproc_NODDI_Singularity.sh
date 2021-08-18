#!/bin/bash

## Preprocessing of NIFTI NODDI files with singularity image
## module load Singularity
## singularity build /home/rodolphe/Desktop/rodolphe/Toolbox/Singularity_images/NODDI_docker.simg docker://orchid666/myneurodocker:NODDI

#########################################################

# singularity shell \
# --bind /data/user/rodolphe/Data/MRST/NODDI:/data \
# --bind /data/user/rodolphe/Scripts/Origin/Szaflarski\ lab/MRST/NODDI:/myscripts \
# NODDI_docker.simg

#########################################################

## Preprocessing of MRST DTI scans

## Base variables. Change if needed
subject=$1
basedir=/data/NIFTI/${subject}
raw_dir=/data/Raw_data


## Check if DIFF_PREP_WORK folder exist (Required to exist for DIFFPREP)
template_dir=/template
myname=$(whoami)
pref_dir=/home/${myname}/DIFF_PREP_WORK

if [ -d $pref_dir ]
then
    echo -e " \e[7mSTARTING PREPROCESSING SUBJECT:\e[31m$subject.\e[0m"
else
  mkdir -p $pref_dir
  echo -e " \e[7mSTARTING PREPROCESSING SUBJECT:\e[31m$subject.\e[0m"
    #echo "Error: Directory $pref_dir MUST be created.Create folder and restart Singularity"
    #exit 0
fi

### DICOM import to NIFTI
SUBJ_T1=$basedir/T1
SUBJ_DWI=$basedir/DWI
mkdir -p $basedir $SUBJ_T1 $SUBJ_DWI

T1_dir=$(find ${raw_dir}/${subject} -name "T1*")
DWI_dir=$(find ${raw_dir}/${subject} -name "dMRI*")

dcm2niix -x y -b y -z n -v y -o $SUBJ_T1 -f ${subject}_T1 $T1_dir
dcm2niix -x y -b y -z n -v y -o $SUBJ_DWI -f ${subject}_DWI $DWI_dir


## Modifies B0 values in bval and bvec file with a python script
mybval_file=$(find ${SUBJ_DWI} -name "*.bval")
mybvec_file=$(find ${SUBJ_DWI} -name "*.bvec")

python /myscripts/change_bval.py $mybval_file $mybvec_file

## Skull removal from T1 (Unifize is possible although gave worse results)
#3dUnifize -input ${basedir}/T1/${subject}_T1.nii -prefix ${basedir}/T1/${subject}_T1_uni.nii
3dSkullStrip -input ${basedir}/T1/${subject}_T1.nii -prefix ${basedir}/T1/${subject}_T1_ns.nii

## Deoblique T1 with no skull
3dWarp -deoblique -prefix ${basedir}/T1/${subject}_T1_ns_deob.nii ${basedir}/T1/${subject}_T1_ns.nii


## Co-register T1 with some ACPC template (makes it easier for T1 to T2 conversion)
fat_proc_axialize_anat \
-inset  ${basedir}/T1/${subject}_T1_ns_deob.nii \
-prefix ${basedir}/T1/${subject}_T1_ns_deob_acpc \
-mode_t1w \
-refset ${template_dir}/mni_icbm152_t1_tal_nlin_sym_09a_MSKD_ACPCE.nii.gz \
-extra_al_wtmask ${template_dir}/mni_icbm152_t1_tal_nlin_sym_09a_MSKD_ACPCE_wtell.nii.gz \
-out_match_ref

## Co-register DWI with NEW T1 aligned with acpc

3dAllineate -input ${basedir}/DWI/${subject}_DWI.nii \
-base ${basedir}/T1/${subject}_T1_ns_deob_acpc.nii.gz \
-prefix ${basedir}/DWI/${subject}_DWI_acpc.nii \
-mast_dxyz 1.5 \
-overwrite

## Decompress result file from previous step
gunzip ${basedir}/T1/${subject}_T1_ns_deob_acpc.nii.gz

## Create a full brain binary mask based on T1 image
3dAutomask -prefix ${basedir}/T1/${subject}_T1_ns_deob_acpc_mask.nii -dilate 2 -eclip ${basedir}/T1/${subject}_T1_ns_deob_acpc.nii

## Converts T1 to T2. Add -no_qc_view for no Quality control images
fat_proc_imit2w_from_t1w  \
-inset ${basedir}/T1/${subject}_T1_ns_deob_acpc.nii \
-prefix ${basedir}/T1/${subject}_T2_ns_deob_acpc \
-mask ${basedir}/T1/${subject}_T1_ns_deob_acpc_mask.nii


## Unzip newly create T2 file
gunzip ${basedir}/T1/${subject}_T2_ns_deob_acpc.nii.gz

####### DIFFPREP PART ##########

## Copy dmc file in proper required folder
mypref=$(find /myscripts -name "*.dmc" | grep -v "temp")
cp $mypref $pref_dir/mypref.dmc

## Diff_prep import
ImportNIFTI \
-i ${basedir}/DWI/${subject}_DWI_acpc.nii \
-b ${basedir}/DWI/newbval.txt \
-v ${basedir}/DWI/newbvec.txt \
-o ${basedir}/DWI/${subject}_Denoised \
-p horizontal

## Denoising
DIFFPREP -i ${basedir}/DWI/${subject}_Denoised/${subject}_Denoised.list \
-s ${basedir}/T1/${subject}_T2_ns_deob_acpc.nii \
-o ${basedir}/DWI/${subject}_Denoised/${subject}_Denoised_Final \
--reg_settings mypref.dmc \
--will_be_drbuddied 0 \
--do_QC 0 \
--step 0 \
--upsampling all

## Create DWI mask (optional, T1 mask is usually better)
#3dAutomask -prefix ${basedir}/DWI/${subject}_Denoised/${subject}_Denoised_Final_mask.nii -dilate 2 -eclip ${basedir}/DWI/${subject}_Denoised/${subject}_Denoised_Final.nii

## Resample T1 mask to match DWI header informations
3dresample -master ${basedir}/DWI/${subject}_Denoised/${subject}_Denoised_Final.nii -prefix ${basedir}/T1/${subject}_T1_ns_deob_acpc_mask_rs.nii -input ${basedir}/T1/${subject}_T1_ns_deob_acpc_mask.nii

## Remove negative (and zero) values in denoised DWI potentially introduced by spline interpolation (https://fsl.fmrib.ox.ac.uk/fsl/fslwiki/topup/ApplyTopupUsersGuide)
#3dcalc -a ${basedir}/DWI/${subject}_Denoised/${subject}_Denoised_Final.nii -expr 'abs(a)' -prefix ${basedir}/DWI/${subject}_Denoised/${subject}_Denoised_Final_abs.nii
3dcalc -a ${basedir}/DWI/${subject}_Denoised/${subject}_Denoised_Final.nii \
-b  ${basedir}/T1/${subject}_T1_ns_deob_acpc_mask_rs.nii \
-expr '(abs(a)+5)*b' -prefix ${basedir}/DWI/${subject}_Denoised/${subject}_Denoised_Final_abs.nii

## Normalize DWI, by dividing every volume with b=0 average.
#1 -create mean
3dTstat -prefix ${basedir}/DWI/${subject}_Denoised/${subject}_Denoised_Final_abs_mean-b0.nii \
-mean ${basedir}/DWI/${subject}_Denoised/${subject}_Denoised_Final_abs.nii'[0,1,17,33,49,65,81]'

#2 - Divide all volumes by mean of b=0
3dcalc -a ${basedir}/DWI/${subject}_Denoised/${subject}_Denoised_Final_abs_mean-b0.nii \
-b ${basedir}/DWI/${subject}_Denoised/${subject}_Denoised_Final_abs.nii \
-expr 'b/a' \
-prefix ${basedir}/DWI/${subject}_Denoised/${subject}_Denoised_Final_abs_norm.nii


## Convert BMTRIX to BVECS/BVALS to get modified BVECS !
TORTOISEBmatrixToFSLBVecs ${basedir}/DWI/${subject}_Denoised/${subject}_Denoised_Final.bmtxt

###### REMARKS ###

# 1- Upsampling has to be specified in script, dmc file will always set it up to off for some reason
