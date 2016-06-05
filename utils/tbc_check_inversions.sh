#!/bin/bash

# utility sript for inversions with twisted boundary conditions, specifically for fwd/seq propagator pairs
# checks if all inversions for all thetas for a given range of gauge configurations in a given
# diretory have gone through sucessfully
# if not, a log file is written with the missing configurations

thetas=( 0 )
names=( fwdprop seqprop )
conf_start=0
conf_end=1072
step=16

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
  
      lsout=$( ls -1 ${conf4}/${flavour}_${names[iname]}_theta_${texttheta}.${conf4}.?????.??.inverted )

      if [ -z "${lsout}" ]; then
        echo ${flavour}_${names[iname]}_theta_${texttheta}.${conf4} >> missing_${names[iname]}.txt
      fi
      
    done
  done
done

