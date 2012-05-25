#!/bin/sh
#
#(otherwise the default shell would be used)
#$ -S /bin/sh
#
#(the running time for this job)
#$ -l s_rt=47:55:00
#$ -l h_rt=47:59:00
#
#(stderr and stdout are merged together to stdout) 
#$ -j y
#
#(send mail on job's end and abort)
#$ -m bae
#$ -pe mpi 4

BASENAME=hmc2
ADDON=_5.1.6_mpi

OUTPUT=/afs/ifh.de/group/nic/scratch/pool4/kostrzew/output/${BASENAME}${ADDON}

if [[ ! -d ${OUTPUT} ]]
then
  mkdir ${OUTPUT}
fi

if [[ ! -d ${OUTPUT} ]]
then
  echo "ouput directory ${OUTPUT} could not be created!"
  exit 1
fi

cd ${OUTPUT}
/usr/lib64/openmpi/1.4-icc/bin/mpirun -wd ${OUTPUT} -np 4 /afs/ifh.de/user/k/kostrzew/code/tmLQCD-5.1.6/build_mpi/hmc_tm -f /afs/ifh.de/user/k/kostrzew/code/tmLQCD-5.1.6/build_mpi/continue_sample-${BASENAME}.input

mv ${HOME}/*${JOB_ID} ${OUTPUT}

