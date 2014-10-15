#!/bin/bash

if [ -z "${1}" ]; then
  echo "Usage: archive.sh xxxx-yyyy"
  echo "where xxxx-yyyy denotes the range of configurations"
  exit 1
fi

if [ "${1}" == "-h" ]; then
  echo "Usage: archive.sh xxxx-yyyy"
  echo "where xxxx-yyyy denotes the range of configurations"
  exit 1
fi

RUNDIR=meson_2pt/nf2/iwa_b2.1-L24T48-csw1.57551-k0.1373-mul0.003
WDIR=$WORK/$RUNDIR
ADIR=/arch/hch02/hch028/$RUNDIR
CORRELATORS="ll_c-ll_n-ls_c-ls_n-lc_c-lc_n-sc_c-ss_c-ss_n-cc_c-cc_n"

echo "removing output files from jobscripts directory"
rm -f $WDIR/jobscripts/*.out
cd $WDIR
#echo "compressing: inputs, outputs, jobscripts"
#tar -czf inputs-outputs-jobscripts.${1}.tar.gz inputs outputs jobscripts &
echo "compressing: correlators"
tar -czf ${CORRELATORS}.${1}.tar.gz llc* lln* ls_* lsn* lc_* lcn* sc_* ss_c* cc_c* ccn* ssn* &
cd $WDIR/sources
echo "compressing: sources"
tar -czf sources.${1}.tar.gz source.* &
tar -czf gen_sources.logs.${1}.tar.gz logs gen_fuzz_sources.sh timeslices.txt &
echo "waiting for compression jobs to finish"
wait

cd $WDIR
echo "rsynching to archive"
rsync -a inputs-outputs-jobscripts.${1}.tar.gz $ADIR &
rsync -a ${CORRELATORS}.${1}.tar.gz $ADIR/correlators &
rsync -a sources/sources.${1}.tar.gz $ADIR/sources &
rsync -a sources/gen_sources.logs.${1}.tar.gz $ADIR/sources &
echo "waiting for rsync background jobs to finish"
wait

echo "All done!"

