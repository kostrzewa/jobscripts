#!/bin/sh
#
#(otherwise the default shell would be used)
#$ -S /bin/sh
#
#(the running time for this job)
#$ -l h_rt=47:59:00
#$ -l s_rt=47:40:00
#
#(stderr and stdout are merged together to stdout) 
#$ -j y
#
#(send mail on job's end and abort)
#$ -m bae
#$ -pe mpi 8

BASENAME=hmc0
ADDON=_5.1.6_mpi_highstat

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

cd $TMPDIR
/usr/lib64/openmpi/1.4-icc/bin/mpirun -wd $TMPDIR -np 8 /afs/ifh.de/user/k/kostrzew/code/tmLQCD-5.1.6/build_mpi/hmc_tm -f /afs/ifh.de/user/k/kostrzew/code/tmLQCD-5.1.6/build_mpi/sample-${BASENAME}.input
cp ${TMPDIR}/* ${OUTPUT}

mv ${HOME}/*${JOB_ID} ${OUTPUT}

