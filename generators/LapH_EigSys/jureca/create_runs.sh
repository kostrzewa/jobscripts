#!/bin/bash

#for cfg in {2652..2696..4}; do
for cfg in 2700; do
  echo creating run file for conf $cfg
  j=`printf %04d $cfg`
  cat submit.template | sed "s/=L=/${cfg}/" > conf${j}.submit
  #cat submitcheck.template | sed "s/=L=/${cfg}/" > conf${j}check.submit
done
