#!/bin/bash

# utility sript for inversions with twisted boundary conditions, specifically for fwd/seq propagator pairs
# checks if all inversions for all thetas for a given range of gauge configurations in a given
# diretory have gone through sucessfully
# if not, a log file is written with the missing configurations

thetas=( 0.8033 )
names=( fwdprop seqprop )
conf_start=240
conf_end=2280
step=8
nosamples=12

for iname in $( seq 0 $(( ${#names[@]} - 1 )) ); do
  date > missing_${names[iname]}.txt
done

missing=0

for conf in $( seq $conf_start $step $conf_end ); do
  conf4=$( printf %04d $conf )
  for itheta in $( seq 0 $(( ${#thetas[@]} - 1 )) ); do
    for iname in $( seq 0 $(( ${#names[@]} - 1 )) ); do
      theta=${thetas[itheta]}
      flavour="u"                                                                                                                                                        
      if [ "${names[iname]}" = "seqprop" ]; then
        flavour="du"
        if [ "${theta}" != "0" ]; then
          theta=-${theta}
        fi
      fi
      texttheta=$( echo ${theta} | sed 's/-/m/g' )
  
      lsout=$( ls -1 ${conf4}/${flavour}_${names[iname]}_theta_${texttheta}.${conf4}.?????.??.inverted | wc | awk '{print $1}' )

      if [ ${lsout} -lt ${nosamples} ]; then
        missing=$(( $missing + 1 ))
        echo ${flavour}_${names[iname]}_theta_${texttheta}.${conf4} >> missing_${names[iname]}.txt
      fi
      
    done
  done
done

echo missing=${missing}

