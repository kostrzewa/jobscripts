#!/bin/bash

conf_start=0
conf_step=8
conf_end=1328

nts=24

issues=0

for cid in $( seq $conf_start $conf_step $conf_end ); do
  c4=$(printf %04d $cid)
  
  nh5=$(ls $c4/*.h5 | wc | awk '{print $1}')

  if [ $nh5 -ne $nts ]; then
    echo $cid does not have $nts h5 files
    issues=$(( $issues + 1 ))
  fi
done

if [ $issues -ne 0 ]; then
  echo there were $issues issues found
fi
