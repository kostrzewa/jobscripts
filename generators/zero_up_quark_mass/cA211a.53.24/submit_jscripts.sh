#!/bin/bash

conf_start=0
conf_step=4
conf_end=1248

for cid in $( seq ${conf_start} ${conf_step} ${conf_end} ); do
  echo $cid
  c4=$(printf %04d ${cid})
  
  pushd ${c4}
  sbatch job_${c4}.cmd
  popd

done # cid
popd
