#!/bin/bash

MU="0.003 0.012 0.048 0.192"
#PREC="1e-16 1e-20 1e-24 1e-28 1e-32"
PREC="1e-04 1e-08 1e-12"
cstart="1200 1800 2400 3000"
#kappa="0.141539 0.141499 0.141459 0.141419 0.141379 0.141339 0.141299 0.141259 0.141219 \
#0.141179 0.141139 0.141099 0.141060 0.141020 0.140980 0.140940 0.140901 0.140861 0.140821 \
#0.140782 0.140742"

kappa="0.1373"

for prec in $PREC; do
  mprec=`echo $prec | sed 's/-/m/g'`
  for mu in $MU; do
    NAME=cA2.60.24_${mu}_${mprec}
    GDIR=/work/hch02/hch028/runs/nf2/iwa_b2.1-L24T48-csw1.57551-k0.1373-mul0.006_xeonphi
    RUNDIR=pq_mpcac/nf2/${NAME}
    JDIR=${HOME}/${RUNDIR}
    WDIR=${WORK}/${RUNDIR}
    
    for k in $kappa; do
      kappa2mu=`perl -e "print 2.0 * $k * $mu"`
      m0=`perl -e "print sprintf '%.4f', 1.0 / ( 2.0 * $k )"`
      seed=`echo $k | cut -f 2  -d '.'``echo $mu | cut -f 2 -d '.'`
      
      wdir=${WDIR}/m${m0}
      jdir=${JDIR}/m${m0}
      if [ ! -d ${wdir} ]; then
        mkdir -p ${wdir}
      fi
      if [ ! -d ${jdir} ]; then
        mkdir -p ${jdir}
      fi
    
      ln -s ${GDIR}/conf.* ${wdir}
      
      for s in $cstart; do
        s=`printf %04d $s`
        echo $s
        jfile=s${s}_${m0}.cmd
        ifile=s${s}_${m0}.input
        cp job.cmd.template ${jdir}/${jfile}
        # sed one variable to use correct input file
        sed -i "s:JNAME:s${s}_m${m0}_${NAME}:g" ${jdir}/${jfile} 
        sed -i "s@WDIR@${wdir}@g" ${jdir}/${jfile}
        sed -i "s@IFILE@${ifile}@g" ${jdir}/${jfile}
        cp offline_measurement.input.template ${wdir}/${ifile}
        # sed the various input params
        sed -i "s@PREC@${prec}@g" ${wdir}/${ifile}
        sed -i "s@KAPPA@${k}@g" ${wdir}/${ifile}
        sed -i "s@2KMU@${kappa2mu}@g" ${wdir}/${ifile}
        sed -i "s@SEED@${seed}@g" ${wdir}/${ifile}
        sed -i "s@CSTART@${s}@g" ${wdir}/${ifile}
      done
    done
  done
done
