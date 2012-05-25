#!/bin/sh
#
#(otherwise the default shell would be used)
#$ -S /bin/sh
#
#(the running time for this job)
#$ -l h_rt=07:15:00
#$ -l s_rt=07:00:00
#
#(stderr and stdout are merged together to stdout) 
#$ -j y
#
#(send mail on job's end and abort)
#$ -m bae
#$ -pe multicore 8

BASENAME=hmc4
ADDON=_openmp_highstat

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
/afs/ifh.de/user/k/kostrzew/code/tmLQCD.kost/build_openmp/hmc_tm -f /afs/ifh.de/user/k/kostrzew/code/tmLQCD.kost/build_openmp/sample-${BASENAME}.input
cp ${TMPDIR}/* ${OUTPUT}

