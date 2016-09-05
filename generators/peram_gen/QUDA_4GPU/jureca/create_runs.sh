#!/bin/bash

conf_start=2000
conf_step=8
conf_end=2000

rv_start=0
rv_end=5

seeds=(908843 9817123 1232187 8978721 8978721 4987237)

RUNDIR="\/work\/hbn28\/hbn288\/peram_generation\/cA2a.60.24\/cnfg"
EVDIR="\/work\/hbn28\/hbn288\/eigensystems\/cA2a.60.24"
GCONFBASE="\/work\/hch02\/hch028\/confs_tmp\/nf2\/cA2a.60.24\/conf"
EXEC="\/homec\/hbn28\/hbn288\/bin\/jureca\/peram_gen\/peram_gen.quda-develop-serial.4GPU"
JOBNAME="cA2a.60.24_u"

for i in $( seq ${conf_start} ${conf_step} ${conf_end} ); do
  echo "creating config $i"
  j=`printf %04d $i`

  mkdir -p cnfg${j}/
  mkdir -p cnfg${j}/outputs
  cd cnfg${j}/
  
  cp ../templates/invert.input .
  sed -i "s@NSTORE@${i}@g" invert.input
  sed -i "s@GCONFBASE@${GCONFBASE}@g" invert.input

  for rv in $( seq ${rv_start} ${rv_end} ); do
    seed=${seeds[${rv}]}
    rnd2=$( printf %02d ${rv} )
    
    laphin=LapH_${j}_${rnd2}.in
    jscr=job.slurm.${j}_${rnd2}.cmd
    outfile="outputs\/run_${j}_${rnd2}.out"
  
    cp ../templates/job.slurm.cmd ${jscr}
    sed -i "s@RUNDIR@${RUNDIR}${j}@g" ${jscr}
    sed -i "s@JOBNAME@${JOBNAME}_${j}_${rv}@g" ${jscr}
    sed -i "s@INFILE@${laphin}@g" ${jscr}
    sed -i "s@OUTFILE@${outfile}@g" ${jscr}
    sed -i "s@EXEC@${EXEC}@g" ${jscr}
  
    cp ../templates/LapH.in ${laphin}
    sed -i "s@NSTORE@${i}@g" ${laphin} 
    sed -i "s@NB_RND@${rv}@g" ${laphin}
    sed -i "s@SEED@${seed}@g" ${laphin}
    sed -i "s@EVDIR@${EVDIR}@g" ${laphin}
  
  done
  cd ..
done
