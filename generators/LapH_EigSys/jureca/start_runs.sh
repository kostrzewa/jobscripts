#!/bin/bash

# missing configs
#for cfg in {2652..2696..4}; do
for cfg in 2700; do
  echo starting conf $cfg
  j=`printf %04d $cfg`
  sbatch conf${j}.submit
done
