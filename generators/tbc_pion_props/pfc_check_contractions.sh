#!/bin/bash

# utility sript for inversions with twisted boundary conditions, specifically for fwd/seq propagator pairs
# checks if all inversions for all thetas for a given range of gauge configurations in a given
# diretory have gone through sucessfully
# if not, a log file is written with the missing configurations

nothetas=6
names=( ppcor vector_ff )
conf_start=1808
conf_end=2280
step=8
cdir=/work/hch02/hch028/pionff/cA2.09.48_extend_test


for iname in $( seq 0 $(( ${#names[@]} - 1 )) ); do
  date > missing_${names[iname]}.txt
done

missing=0

for conf in $( seq $conf_start $step $conf_end ); do
  conf4=$( printf %04d $conf )
  for iname in $( seq 0 $(( ${#names[@]} - 1 )) ); do
  
    lsout=$( ls -1 ${cdir}/${names[iname]}.??.${conf4} | wc | awk '{print $1}' )

    if [ ${lsout} -lt ${nothetas} ]; then
      missing=$(( $missing + 1 ))
      echo ${names[iname]}.${conf4} >> missing_${names[iname]}.txt
    fi
    
  done
done

echo missing=${missing}

