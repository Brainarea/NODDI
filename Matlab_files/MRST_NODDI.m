% NODDI matlab toolbox processing
% Tutorial: http://mig.cs.ucl.ac.uk/index.php?n=Tutorial.NODDImatlab
%%% MRST DATA processing

restoredefaultpath
clearvars
clc


%%%%%%%%%%% PART TO CHANGE %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
addpath(genpath('/data/user/rodolphe/Toolbox/NODDI/NODDI_toolbox_v1.04/'));
addpath(genpath('/data/user/rodolphe/Toolbox/nifti_matlab/'));
addpath(genpath('/data/user/rodolphe/Toolbox/spm12'));
rmpath(genpath('/data/user/rodolphe/Toolbox/spm12/external/fieldtrip/compat/'));

% Where the Data is
data_path = '/data/user/rodolphe/Data/MRST/NODDI/';

% List of subjects
list_subj = dir(strcat(data_path,'NIFTI',filesep,'M*'));

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Just to check the number of _new files created (accessory)
%list_done = dir(strcat(data_path,'NIFTI',filesep,'M*/Noddi_files/*_new.nii'));


%Create a pool for parallel processing
nproc=feature('numcores');
if  isempty(gcp('nocreate'))
    parpool('local',nproc);
end

% Loop on subjects
for ii=22%length(list_subj)

    %Convert the raw DWI volume into the required format with the function CreateROI:
    % First, copy files rom preprocessing
    save_path = strcat(list_subj(ii).folder,filesep,list_subj(ii).name,filesep,'Noddi_files');

    if ~exist(save_path,'dir')
        mkdir(save_path)

        myDWI = strcat(list_subj(ii).folder,filesep,list_subj(ii).name,filesep,'DWI',filesep,list_subj(ii).name,'_Denoised',filesep,list_subj(ii).name,'_Denoised_Final_abs.nii');
        %myMask = strcat(list_subj(ii).folder,filesep,list_subj(ii).name,filesep,'DWI',filesep,filesep,list_subj(ii).name,'_Denoised',filesep,list_subj(ii).name,'_Denoised_Final_mask.nii');
        myMask = strcat(list_subj(ii).folder,filesep,list_subj(ii).name,filesep,'T1',filesep,list_subj(ii).name,'_T1_ns_deob_acpc_mask_rs.nii');
        myBval = strcat(list_subj(ii).folder,filesep,list_subj(ii).name,filesep,'DWI',filesep,list_subj(ii).name,'_Denoised',filesep,list_subj(ii).name,'_Denoised_Final.bvals');
        myBvec  = strcat(list_subj(ii).folder,filesep,list_subj(ii).name,filesep,'DWI',filesep,list_subj(ii).name,'_Denoised',filesep,list_subj(ii).name,'_Denoised_Final.bvecs');
        mynewDWI = strcat(save_path,filesep,list_subj(ii).name,'_DWI.nii');
        mynewMask = strcat(save_path,filesep,list_subj(ii).name,'_mask.nii');
        mynewBvec = strcat(save_path,filesep,list_subj(ii).name,'.bvec');
        mynewBval = strcat(save_path,filesep,list_subj(ii).name,'.bval');
        copyfile(myDWI,mynewDWI);
        copyfile(myMask,mynewMask);
        copyfile(myBval,mynewBval);
        copyfile(myBvec,mynewBvec);

    end

    % Create ROI for NODDI analysis
    myNoddi_roi = strcat(save_path,filesep,'NODDI_roi.mat');
    CreateROI(mynewDWI, mynewMask, myNoddi_roi);

    % Create protocl variable based on BVEC and BVAL files
    protocol = FSL2Protocol(mynewBval, mynewBvec,5);


    % Create the NODDI model structure with the function MakeModel
    % watsonSHStickTortIsoV_B0' is the internal name for the NODDI model.
    % The structure noddi holds the details of the NODDI model relevant for the subsequent fitting.
    % For most users, the default setting should suffice.
    noddi = MakeModel('WatsonSHStickTortIsoV_B0');

    % Run the NODDI fitting with the function batch_fitting (with parallel
    % toolbbox)
    myFitted_params = strcat(save_path,filesep,'FittedParams.mat');
    batch_fitting(myNoddi_roi, protocol, noddi, myFitted_params, nproc);

    % Convert the estimated NODDI parameters into volumetric parameter maps
    SaveParamsAsNIfTI(myFitted_params, myNoddi_roi, mynewMask, strcat(save_path,filesep,list_subj(ii).name,'_NODDI'));


    Run1=cellstr(spm_select('ExtFPList',fullfile(save_path), strcat(list_subj(ii).name,'_NODDI_ficvf.nii')));
    Run2=cellstr(spm_select('ExtFPList',fullfile(save_path), strcat(list_subj(ii).name,'_NODDI_fiso.nii')));

    matlabbatch = [];
    matlabbatch{1}.spm.util.imcalc.input = cellstr([Run1 ;Run2]);
    matlabbatch{1}.spm.util.imcalc.output = strcat(list_subj(ii).name,'_NODDI_ficvf_new.nii');
    matlabbatch{1}.spm.util.imcalc.outdir = {save_path};
    matlabbatch{1}.spm.util.imcalc.expression = 'i1.*(1-i2)';
    matlabbatch{1}.spm.util.imcalc.var = struct('name', {}, 'value', {});
    matlabbatch{1}.spm.util.imcalc.options.dmtx = 0;
    matlabbatch{1}.spm.util.imcalc.options.mask = 0;
    matlabbatch{1}.spm.util.imcalc.options.interp = 1;
    matlabbatch{1}.spm.util.imcalc.options.dtype = 4;
    spm_jobman('run',matlabbatch);
end
