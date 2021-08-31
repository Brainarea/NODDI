###################
NODDI ANALYSIS PART 1: PREPROCESSING
###################

*****************
CHEAHA
*****************

Connect to your CHEAHA account:

- Go to https://rc.uab.edu/ and login
- Click on **My interactive session** on top
- Click on **HPC Desktop** (If no session was previously created)
- Create a new session with following options: 100 hours / long / 20 CPU / 12GB
- Click on **Launch desktop in new Tab**
- Hurray, you are now in your own Linux session on CHEAHA!

Now let's do some magic.

*****************
GETTING ESSENTIAL FILES
*****************

- All you need is the script file and a config file!
- Both are available at: https://github.com/Brainarea/NODDI/tree/main/Preproc_Files
- Download both files and put them in a folder on Cheaha.

*****************
GETTING DOCKER IMAGE
*****************

- All the toolbox and packages analysis you need have been put into a Docker image (yeah!)
- Unfortunately, CHEAHA does not support Docker. However, we can use Singularity which is pretty much the same.
- First let's load Singularity on Cheaha. Open a terminal and type:

.. code:: bash

  module load Singularity

- Next let's convert the Docker image and put it in a folder of your choice (change /path/to/ ):

.. code:: bash

  singularity build /path/to/singularity/NODDI_docker.simg docker://orchid666/myneurodocker:NODDI

- You are now ready to preprocess your images!!

  *****************
  COPY MRI IMAGES
  *****************

- Create a folder for the NODDI analysis, for example : /Noddi_analysis/
- Within that folder, create a Raw_data folder: /Noddi_analysis/Raw_data/
- Put each subject T1 and DWI dicom folder in that Raw_data so you have:

  - /Noddi_analysis/Raw_data/Subject_001/T1/
  - /Noddi_analysis/Raw_data/Subject_001/dMRI/

- **Note: Name of subject folder folders does not matter. T1 folder name needs to start with 'T1' and DWI folder name needs to start with 'dMRI'**

  *****************
  LAUNCHING DOCKER SESSION
  *****************

- You are now ready to preprocess your diffusion images
- Let's go to where you put the Singularity image:

.. code:: bash

  cd /path/to/singularity/

- Now let's launch the Docker session and tell it where your stuff is:

.. code:: bash

  singularity shell \
  --bind /Noddi_analysis:/data \
  --bind /path/to/scripts:/myscripts \
  NODDI_docker.simg

- **Note: --bind command is like a mount. First is to tell where the data is, second where the scripts are.**
*****************
PREPROCESSING
*****************

- Your scripts folder has been mounted to /myscript on the Singularity session so let's go there:

.. code:: bash

  cd /myscripts

- Now in order to preprocess one subject, you just need to give its name to the script you have downloaded earlier:

.. code:: bash

  ./preproc_NODDI_Singularity.sh 'Subject_001'

- **Note 1: If you get a Permission denied error, please do a chmod +x on preproc_NODDI_Singularity.sh script**
- **Note 2: Preprocessing can be long so be patient!**
- A 'Preprocessed' folder will be created within your Data folder containing all preprocessed files for each subject.

*****************
PREPROCESSING WITH PARALLEL
*****************

- Now you may want to process several Subjects at once. Fortunately, the person who made the Docker image (me!) also put a nice tool to do so.
- Example of how to do parallel processing with a find command:

.. code:: bash

  raw_dir=/data/Raw_data
  TMPDIR=/tmp
  find ${raw_dir} -name "CBD*" | parallel --eta bash preproc_NODDI_Singularity.sh {/}

- **Note: Be sure to have enough time on your CHEAHA session, preprocessing of multiple subjects in parallel can take hours!!**

*****************
PREPROCESSING WITH SLURM (CHEAHA)
*****************
# Create JOB file

- Another possibility to do parallel multi-processing is to use SLURM on Cheaha. In order to do that we need to create a job file. Let's start with a simple job for one subject:

.. code:: bash

  #!/bin/bash

  #SBATCH --partition=short
  #SBATCH --cpus-per-task=10
  #SBATCH --mem-per-cpu=12000
  #SBATCH --time=10:00:00


  module load Singularity

  cd /data/user/rodolphe/Toolbox/Singularity_images/

  singularity exec \
  --bind /data/user/rodolphe/Data/MRST/NODDI:/data \
  --bind /data/user/rodolphe/Scripts/Origin/Szaflarski\ lab/MRST/NODDI/preprocessing:/myscripts \
  NODDI_docker.simg bash /myscripts/preproc_NODDI_Singularity.sh 'MRST5012'

- A job works exactly like creating an interactive session and running the preprocessing script through the Singularity container:

  - With #SBATCH options we ask for a type of partition (short, long, medium,...) with a certain number of CPUs, memory per CPU and a duration time.
  - Then the script will load Singularity module, go to directory where singularity image is then launch preprocessing script through singularity image ('singularity exec') with subject ID as argument

- Now we can modify this job in order to process several subject at once:

.. code:: bash

  #!/bin/bash

  #SBATCH --partition=short
  #SBATCH --cpus-per-task=10
  #SBATCH --mem-per-cpu=12000
  #SBATCH --time=10:00:00
  #SBATCH --array=0-4

  module load Singularity
  FILES=("CBDm7015_V1" "CBDm7015_V2" "CBDm7016_V1" "CBDm7017_V1" "CBDm7020_V2")
  cd /data/user/rodolphe/Toolbox/Singularity_images/

  srun singularity exec \
  --bind /data/user/rodolphe/Data/MRST/NODDI:/data \
  --bind /data/user/rodolphe/Scripts/Origin/Szaflarski\ lab/MRST/NODDI/preprocessing:/myscripts \
  NODDI_docker.simg bash /myscripts/preproc_NODDI_Singularity.sh ${FILES[$SLURM_ARRAY_TASK_ID]}

- The new #SBATCH array is telling the system how many jobs we want (It is a range , starting from zero!!). Then we create a list of subject ID (array named FILES). We use  ${FILES[$SLURM_ARRAY_TASK_ID]} in order to access each subject ID. This will create 5 jobs with $SLURM_ARRAY_TASK_ID having a different value in each one on them (from 0 to 4).


- Finally, is it possible to search for subject IDs within a folder instead of manually writing all the ID:

.. code:: bash

  #!/bin/bash

  #SBATCH --partition=short
  #SBATCH --cpus-per-task=10
  #SBATCH --mem-per-cpu=12000
  #SBATCH --time=10:00:00
  #SBATCH --array=0-4

  module load Singularity

  cd /data/user/rodolphe/Data/MRST/NODDI/Preprocessed/
  readarray -t FILES < <(find . -maxdepth 1 -type d -name 'CBDm7*' -printf '%P\n')

  cd /data/user/rodolphe/Toolbox/Singularity_images/

  srun singularity exec \
  --bind /data/user/rodolphe/Data/MRST/NODDI:/data \
  --bind /data/user/rodolphe/Scripts/Origin/Szaflarski\ lab/MRST/NODDI/preprocessing:/myscripts \
  NODDI_docker.simg bash /myscripts/preproc_NODDI_Singularity.sh ${FILES[$SLURM_ARRAY_TASK_ID]}

# Use Job files

- Now that you have your job save as a file let's use it. Go to rc.uab.edu then click on Jobs>Job composer.
- Create a new job by clicking on 'New job' then 'From Specified path'
- Fill as follow:

  - Path to source: Path to the folder where your script is
  - Name: Give a name to your job (' My Noddi job' for exemple.)
  - Script name: Put the name of your script.
  - Click save

- Your Job should be in the list with the code displayed on the bottom right.
- Click Submit to start your job, it will first be 'Queued' waiting for resource allocation, then it will be "Running".

###################
NODDI ANALYSIS PART 2 : NODDI COMPUTATION
###################

- **Note: Documentation for NODDI toolbox is available here: http://mig.cs.ucl.ac.uk/index.php?n=Tutorial.NODDImatlab**

*****************
GET THE TOOLBOX
*****************

- In order to compute NODDI files, you need the MATLAB Noddi toolbox, the Nifti Matlab toolbox and SPM12:

  - Download NODDI toolbox: https://www.nitrc.org/projects/noddi_toolbox
  - Download Nifti Matlab: https://github.com/NIFTI-Imaging/nifti_matlab
  - Download SPM12: https://www.fil.ion.ucl.ac.uk/spm/software/download/

- Next you need a Matlab script available at : https://github.com/Brainarea/NODDI/tree/main/Matlab_files

*****************
RUN THE SCRIPT
*****************
- Let's open Matlab on CHEAHA, open a new terminal and type:

.. code:: bash

  module load rc/matlab/R2020a

- **Note: Other matlab version are available on CHEAHA, R2020a is working fine but feel free to change if needed**
- Then type matlab in terminal to launch MATLAB
- Open the matlab script you previously downloaded.
- The part to change for your needs is highlighted at the beginning of the script but basically you need to change 3 things:
  - Where all the toolboxes are
  - Path to your data
  - Search for subjects ID
- Once everything is changed, just start the script and wait!!
- A Noddi_files folder will be created containing all NODDI files for each subject !

*****************
RUN THE SCRIPT ON SLURM (CHEAHA)
*****************

- See SLURM section on preprocessing to learn about Job creation and use.
- Here we use a single-subject version of the Matlab script.
- WARNING! The Noddi toolbox script needs to be modified for this method to work
- Two files are therefore needed to make this work:

  - MRST_NODDI_single_subject_SLURM.m: used in job's script below (modified matlab script used for signle subject)
  - batch_fitting.m: Modified file from Noddi toolbox. Replace one existing in toolbox folder with that one.
  - Both files are available in MAtlab_files_SLURM folder of the github repository ( https://github.com/Brainarea/NODDI/)

.. code:: bash

  #!/bin/bash

  #SBATCH --partition=medium
  #SBATCH --cpus-per-task=20
  #SBATCH --mem-per-cpu=12000
  #SBATCH --time=15:00:00
  #SBATCH --array=0-41

  module load rc/matlab/R2020a
  cd /data/user/rodolphe/Data/MRST/NODDI/Preprocessed/
  readarray -t FILES < <(find . -maxdepth 1 -type d -name 'CBDm7*' -printf '%P\n')

  cd /data/user/rodolphe/Scripts/Origin/Szaflarski\ lab/MRST/NODDI/Create_noddi_files/

  srun matlab -nodisplay -nodesktop -r \
  "MRST_NODDI_single_subject_SLURM('${FILES[$SLURM_ARRAY_TASK_ID]}',20); quit;"
