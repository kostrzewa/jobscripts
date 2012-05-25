#!/bin/sh
#
#(otherwise the default shell would be used)
#$ -S /bin/sh
#
#(the running time for this job)
#$ -l h_rt=30:15:00
#$ -l s_rt=30:00:00
#
#(stderr and stdout are merged together to stdout) 
#$ -j y
#
#(send mail on job's end and abort)
#$ -m bae
#$ -pe multicore 8

BASENAME=hmc2
ADDON=_openmp_noreduct_highstat

OUTPUT=/afs/ifh.de/group/nic/scratch/pool4/kostrzew/output/${BASENAME}${ADDON}

# write stdout and stderr into tmp dir, will be copied to output at the end
exec > ${TMPDIR}/stdout.txt${JOB_ID} 2> ${TMPDIR}/stderr.txt${JOB_ID}

if [[ ! -d ${OUTPUT} ]]
then
  mkdir ${OUTPUT}
fi

if [[ ! -d ${OUTPUT} ]]
then
  echo "ouput directory ${OUTPUT} could not be created!"
  exit 1
fi

cp /afs/ifh.de/user/k/kostrzew/code/tmLQCD.kost/sample-input/normierungLocal.dat ${TMPDIR}
cp /afs/ifh.de/user/k/kostrzew/code/tmLQCD.kost/sample-input/Square_root_BR_roots.dat ${TMPDIR}

cd $TMPDIR
/afs/ifh.de/user/k/kostrzew/code/tmLQCD.kost/build_openmp_noreduct/hmc_tm -f /afs/ifh.de/user/k/kostrzew/code/tmLQCD.kost/build_openmp_noreduct/sample-${BASENAME}.input
cp ${TMPDIR}/* ${OUTPUT}

