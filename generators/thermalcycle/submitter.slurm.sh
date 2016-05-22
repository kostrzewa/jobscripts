#!/bin/bash

if [ -z "$1" -o -z "$2" ]; then
  echo "submitter.sh usage:"
  echo "./submitter.sh <start> <end> [<dependency>]"
fi

state=$( cat ./Z_STATUS )

if [ "$( printf %04d $1 )" = "${state}" ]; then
  echo "Z_STATUS indicates that your starting job was alredy submitted, are you sure this is what you want?" 
fi

basename=thermalcycle

dependency=$3

for i in $(seq $1 $2); do
  i4=$( printf %04d $i )
  echo "Submitting $( ls ${basename}_${i4}_*.job ) depending on ${dependency}"
  echo ${i4} > Z_STATUS
  if [ -z "$dependency" ]; then
    dependency=$( sbatch ${basename}_${i4}_*.job | awk '{print $NF}' )
  else
    dependency=$( sbatch --dependency=afterok:${dependency} ${basename}_${i4}_*.job | awk '{print $NF}' )
  fi
  echo ${dependency} > Z_DEPEND
done
