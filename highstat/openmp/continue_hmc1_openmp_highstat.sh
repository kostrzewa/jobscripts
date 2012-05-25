#!/bin/sh
#
#(otherwise the default shell would be used)
#$ -S /bin/sh
#
#(the running time for this job)
#$ -l h_rt=24:00:00
#$ -l s_rt=23:45:00
#
#(stderr and stdout are merged together to stdout) 
#$ -j y
#
#(send mail on job's end and abort)
#$ -m bae

BASENAME=hmc1
ADDON=_serial_highstat

OUTPUT=/afs/ifh.de/group/nic/scratch/pool4/kostrzew/output/${BASENAME}${ADDON}

if [[ ! -d ${OUTPUT} ]]
then
  echo "output directory does not exist!"
  exit 1
fi

cp ${OUTPUT}/* ${TMPDIR}

cd $TMPDIR
/afs/ifh.de/user/k/kostrzew/code/tmLQCD.kost/build_wallclock-stop/hmc_tm -f /afs/ifh.de/user/k/kostrzew/code/tmLQCD.kost/build_wallclock-stop/continue-sample-${BASENAME}.input
cp -b ${TMPDIR}/* ${OUTPUT}
