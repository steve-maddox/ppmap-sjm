# sets up scratch directory with all the files needed to run
# ppmap in a series of tiles for a given field, writes the scripts
# and then runs them

# identifier for this run 
export NAME=m100

# multiprocessing scheduler and number of cpus 
export SCHED=NONE
export NCPUS=40

# location of premap and ppmap 
PP_PATH=${HOME}/Desktop/ppmap/ppmap-master
PPMAP=${PP_PATH}/bin/ppmap
PREMAP=${PP_PATH}/bin/premap

# location of working directory and results
WORK=${HOME}/Desktop/ppmap/scratch/${NAME}_work
rm -rf ${WORK}
mkdir ${WORK}
mkdir ${WORK}/${NAME}_results

# put files in working directory

# input parameters for premap - set up field size, position, data files etc
cp -f ${NAME}_premap.inp ${WORK}

# fits files all the bands
cp -rf dataset ${WORK}

# psfs for all the bands
cp -rf psfset  ${WORK}

# colour corrections 
cp -f colourcorr_beta2.txt ${WORK}

# template script to run ppmap - depends on which scheduler you use
if [ -e template_run_ppmap_${SCHED}.sh ] ;  then
   # use local version if it exists
   cp -f template_run_ppmap_${SCHED}.sh ${WORK}
   echo using local script
else
   # use default version if there is no local version
   cp -f ${PP_PATH}/etc/template_run_ppmap_${SCHED}.sh ${WORK}
   echo using default script
fi

cd ${WORK}
${PREMAP} ${NAME} ${SCHED} ${NCPUS}
export code=${PPMAP}
bash run_${NAME}.sh
echo Results are in ${WORK}

