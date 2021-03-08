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

  module load Singularity::

- Next let's convert the Docker image and put it in a folder:

.. code:: bash

  singularity build /home/rodolphe/Desktop/rodolphe/Toolbox/Singularity_images/NODDI_docker.simg docker://orchid666/myneurodocker:NODDI
