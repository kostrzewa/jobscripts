#!/bin/bash

DEBUG=""
if [ ! -z "$1" ]; then
  DEBUG=1
fi


kappas=(0.139986 0.140026 0.140046 0.140056 0.140066 0.140076 0.140086 0.140106 0.140146 0.140186)
trajs=(400       400      200      100      100      100      100      200      400      400)

traj_per_job=25

maxidx=$(( ${#kappas[@]} - 1 ))

mu=0.0009
mubar=0.1408
mudel=0.1521

input_template=hmc.input.template
job_template=jureca.template.job
basename=thermalcycle
baseseed=1741726

PRETEND=0

JNAME=iwa_b1.726-L24T48-csw1.74-mul0.0009-musigma0.1408-mudelta0.1521_thermalcycle
RUNDIR=$WORK/runs/nf211/${JNAME}
JDIR=$HOME/jobscripts/jureca/runs/nf211/${JNAME}/jobscripts
ODIR=$HOME/jobscripts/jureca/runs/nf211/${JNAME}/outputs

if [ ! -d $JDIR ]; then
  mkdir -p $JDIR
fi
if [ ! -d $ODIR ]; then
  mkdir -p $ODIR
fi

jobid=0
prevWDIR=""

for direction in 0 1; do
  idcs=$(seq 0 $maxidx)
  if [ ${direction} -eq 1 ]; then
    idcs=$(seq $(( $maxidx - 1 )) -1 0)
  fi

  for idx in ${idcs}; do
    job4id=$( printf %04d $jobid )
  
    kappa=${kappas[idx]}
    kappa2mu=0$(echo "2 * $mu * $kappa" | bc -l)
    kappa2mubar=0$(echo "2 * $mubar * $kappa" | bc -l)
    kappa2mudel=0$(echo "2 * $mudel * $kappa" | bc -l)

    WDIR=${RUNDIR}/${kappa}_${direction}
    if [ ! -d ${WDIR} ]; then
      mkdir -p ${WDIR}
    fi

    njobs=$(( ${trajs[idx]} / $traj_per_job )) 
    for kjobid in $(seq 0 $(( $njobs - 1 )) ); do
      seed=$(( $baseseed + $jobid ))
      job4id=$( printf %04d $jobid )
      kjob4id=$( printf %02d $kjobid )
      jidstring=${basename}_${job4id}_k${kappa}_d${direction}_${kjob4id}
      jfile=${JDIR}/${jidstring}.job
      ifile=${WDIR}/${jidstring}_hmc.input
      ofile=${ODIR}/out.${jidstring}.out

      if [ ! -z "${DEBUG}" ]; then
        echo kappa=$kappa 2kappamu=$kappa2mu 2kappamubar=$kappa2mubar 2kappamudel=$kappa2mudel traj=${trajs[idx]} njobs=$njobs
        echo m0= $( echo "1.0 / (2 * $kappa)" | bc -l ) 
        echo jfile=${jfile} 
        echo ifile=${ifile} 
        echo
      fi
      
      if [ ! $PRETEND -eq 1 ]; then
        cp $job_template $jfile
        sed -i "s@SLJOBNAME@${jidstring}@g" $jfile
        sed -i "s@SLIFILE@${ifile}@g" $jfile
        sed -i "s@SLOFILE@${ofile}@g" $jfile
        sed -i "s@SLWDIR@${WDIR}@g" $jfile
        if [ ${jobid} -gt 0 -a ${kjobid} -eq 0 ]; then
          sed -i "s@prevWDIR=@prevWDIR=${prevWDIR}@g" $jfile
        fi

        cp $input_template $ifile
        sed -i "s/SEED/${seed}/g" $ifile
        sed -i "s/NMEAS/${traj_per_job}/g" $ifile
        sed -i "s/KAPPAONLY/${kappa}/g" $ifile
        sed -i "s/KAPPAMU2/${kappa2mu}/g" $ifile
        sed -i "s/KAPPAMUBAR2/${kappa2mubar}/g" $ifile
        sed -i "s/KAPPAMUDEL2/${kappa2mudel}/g" $ifile
      fi

      jobid=$(( $jobid + 1 ))
    done
    prevWDIR=${WDIR}

  done
done
