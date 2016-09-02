#!/bin/bash

conf_start=0
conf_step=8
conf_end=800

rv_start=0
rv_end=5

seeds=(908843 9817123 1232187 8978721 8978721 4987237)

for rv in $( seq ${rv_start} ${rv_end} ); do
  seed=${seeds[${rv}]}
  rnd2=$( printf %02d ${rv} )
  for i in $( seq ${conf_start} ${conf_step} ${conf_end} ); do
    echo "creating config $i"
    j=`printf %04d $i`

    laphin=LapH_${j}_${rnd2}.in
    jscr=job_script_${j}_${rnd2}.pbs
    outfile=run_${j}_${rnd2}.out
  
    mkdir -p cnfg${j}/
    cd cnfg${j}/
  
    cp ../test/job_script.pbs ${jscr}
    perl -pe "s/.*/cd \/hiskp2\/bartek\/peram_generation\/cA2a.60.24\/cnfg"$j" / if $. == 10" < ${jscr} > ${jscr}_2
    perl -pe "s/jobname/cA2a.60.24_u_${j}_${rv} / if $. == 1" < ${jscr}_2 > ${jscr}
    perl -pe "s/INFILE/${laphin} / if $. == 12" < ${jscr} > ${jscr}_2
    perl -pe "s/OUTFILE/${outfile} / if $. == 12" < ${jscr}_2 > ${jscr}
    rm ${jscr}_2
  
    cp ../test/invert.input .
    perl -pe "s/.*/InitialStoreCounter = "$i"/ if $. == 8" < invert.input > invert.input2
    mv invert.input2 invert.input
  
    cp ../test/LapH.in ${laphin}
    perl -pe "s/.*/config = "$i"/ if $. == 3" < ${laphin} > ${laphin}_2
    perl -pe "s/.*/nb_rnd = "$rv"/ if $. == 12" < ${laphin}_2 > ${laphin}
    perl -pe "s/.*/seed = "$seed"/ if $. == 13" < ${laphin} > ${laphin}_2
    mv ${laphin}_2 ${laphin}
  
    cd ../
  done
done
