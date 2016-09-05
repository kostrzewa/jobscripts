#!/bin/bash

conf_start=2000
conf_end=2200
conf_step=8

rnd_start=0
rnd_end=5

for i in $(seq ${conf_start} ${conf_step} ${conf_end}); do
  echo "starting job on config $i"
  j=`printf %04d ${i}`
  cd cnfg${j}
  for rnd in $(seq ${rnd_start} ${rnd_end}); do
    rnd2=$( printf %02d $rnd )
    sbatch job.slurm.${j}_${rnd2}.cmd
  done
  cd ..
  
  rm Z_*
  touch Z_${j} 
done
