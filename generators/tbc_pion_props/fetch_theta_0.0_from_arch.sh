#!/usr/bin/bash

if [ -z ${1} -o -z ${2} -o -z ${3} ]; then
  echo "usage: ./fetch.sh <conf.start> <step> <conf.end>"
fi

adir=/arch2/hbn28/hbn288/pionff/tbc_pion_props/cA2.09.48/
tname=_set2.tar
confs="${1} ${2} ${3}"

for conf in $( seq $confs ); do
  c4=$( printf %04d $conf )
  echo "getting $c4 from archive"
  files=$( tar -tf ${adir}/${c4}${tname} | grep u_fwdprop_theta_0\.${c4} | grep inverted )
  for f in ${files}; do
    echo $f
    tar -xf ${adir}/${c4}${tname} ${f}
  done
done
