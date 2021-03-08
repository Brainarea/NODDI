###################
NODDI ANALYSIS
###################

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
- Both are available at: https://github.com/Brainarea/NODDI/tree/main/Files
- Download both files and put them in a folder on Cheaha.

*****************
GETTING DOCKER IMAGE
*****************

- All the toolbox and packages analysis you need have been punt into a Docker image (yeah!)
- Unfortunately, CHEAHA does not support Docker. However, we can use Singularity which is pretty much the same.
- First let's load Singularity on Cheaha. Open a terminal and type:

.. code:: bash

  module load Singularity

- Next let's convert the Docker image and put it in a folder:

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

*****************
PREPROCESSING
*****************

- Now in order to preprocess one subject, you just need to give its name to the script you have downloaded earlier:

.. code:: bash

  preproc_NODDI_Singularity.sh 'Subject_001'

- **Note: Preprocessing can be extremely long (between 10h and 20h) so be patient!**

*****************
PREPROCESSING WITH PARALLEL
*****************

- Now you may want to process several Subject at once. Fortunately, the person who made the Docker image (me!) also put a nice tool to do so.
- Example of how to do parallel processing with a find command:

.. code:: bash

  raw_dir=/data/Raw_data
  TMPDIR=/tmp
  find ${raw_dir} -name "CBD*" | parallel --eta bash preproc_NODDI_Singularity.sh {/}

- **Note: Be sure to have enough time on your CHEAHA session, preprocessing of multiple subjects in parallel can take days!!**
