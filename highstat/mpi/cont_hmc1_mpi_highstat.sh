#!/bin/sh
#
#(otherwise the default shell would be used)
#$ -S /bin/sh
#
#(the running time for this job)
#$ -l h_rt=23:59:00
#$ -l s_rt=23:45:00
#
#(stderr and stdout are merged together to stdout) 
#$ -j y
#
#(send mail on job's end and abort)
#$ -m bae
#$ -pe mpi 8

BASENAME=hmc1
ADDON=_mpi

OUTPUT=/afs/ifh.de/group/nic/scratch/pool4/kostrzew/output/${BASENAME}${ADDON}

if [[ ! -d ${OUTPUT} ]]
then
  echo "output directory ${OUTPUT} does not exist!"
  exit 1
fi

cd $OUTPUT
/usr/lib64/openmpi/1.4-icc/bin/mpirun -wd ${OUTPUT} -np 8 /afs/ifh.de/user/k/kostrzew/code/tmLQCD.kost/build_mpi_etmc/hmc_tm -f /afs/ifh.de/user/k/kostrzew/code/tmLQCD.kost/build_mpi_etmc/continue_sample-${BASENAME}.input

mv ${HOME}/*${JOB_ID} ${OUTPUT}

