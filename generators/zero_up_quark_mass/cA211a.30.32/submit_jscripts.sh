#!/bin/bash

conf_start=4
conf_step=8
conf_end=1240

for cid in $( seq ${conf_start} ${conf_step} ${conf_end} ); do
  echo $cid
  c4=$(printf %04d ${cid})
  
  pushd ${c4}
  sbatch job_${c4}.cmd
  popd

done # cid
popd
