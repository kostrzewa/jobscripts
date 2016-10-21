#!/bin/bash

DEBUG=1

if [ -z ${1} ]; then
  echo "You must specify an input file."
  echo "usage: ./generate_jobs.sh <inputfile>"
  exit 1
fi

wd=$(pwd)

# default values for variables read from input file
ensemble='ensemble'
names=( fwdprop seqprop )
thetas=( 0 )
solverprecision=1.e-18
conf_start=0
conf_end=0
conf_step=0
gauges_dir='.'
jdir='.'
tmlqcd_rng_seed=123456
itemplate='input.template'
jtemplate='jscr.template'
executable='invert'
srcread="no"
kappa=0.125
kappa2mu=0.00250
csw=1.0
nodes=1
rpn=1
L=24
T=48
ompnumthreads=1
nrxprocs=1
nryprocs=1
nrzprocs=1
wtime=00:02:00
skiptheta0=0
nosamples=1

# read the input file
. ${wd}/${1}

if [ $DEBUG -eq 1 ]; then
  cat ${wd}/${1}
fi

# create job directory
if [ ! -d ${jdir}/jscr/outputs ]; then
  mkdir -p ${jdir}/jscr/outputs
fi

if [ ! -f ${jtemplate} ]; then
  echo "Job template ${jtemplate} does not exist!"
  exit 2
fi

if [ ! -f ${itemplate} ]; then
  echo "Input file template ${itemplate} does not exist!"
  exit 3
fi

for conf in $(seq ${conf_start} ${conf_step} ${conf_end} ); do
  conf4=$(printf %04d ${conf})
  echo "Preparing conf.${conf4}"
  jdir_conf4=${jdir}/${conf4}
  mkdir ${jdir_conf4}
  mkdir ${jdir_conf4}/logs
  mkdir ${jdir_conf4}/inputs

  # this is now done via the input file
  # if the filename is too long, the links can be reinstated
  ## ln -s ${gauges_dir}/conf.${conf4} ${jdir_conf4}

  jfile=${jdir}/jscr/job.${conf4}.cmd

  ## GENERATE JOB SCRIPT
  cp ${jtemplate} ${jfile}
  sed -i "s/JOBNAME/${ensemble}_tbc_pion_props_${conf4}/g" ${jfile}
  sed -i "s/WTIME/${wtime}/g" ${jfile}
  # escape spaces in thetas arrays
  thetasub=$( echo ${thetas[@]} | sed 's/ /\\ /g' )
  sed -i "s/THETAS/${thetasub}/g" ${jfile}
  namesub=$( echo ${names[@]} | sed 's/ /\\ /g' )
  sed -i "s/NAMES/${namesub}/g" ${jfile}
  sed -i "s/NODES/${nodes}/g" ${jfile}
  sed -i "s/RPN/${rpn}/g" ${jfile}
  sed -i "s/OMPNUMTHREADS/${ompnumthreads}/g" ${jfile}
  sed -i "s@EXECUTABLE@${executable}@g" ${jfile}
  sed -i "s@WDIR@${jdir_conf4}@g" ${jfile}
  sed -i "s@CONF4@${conf4}@g" ${jfile}
  sed -i "s/SKIPTHETA0/${skiptheta0}/g" ${jfile}

  ## GENERATE INPUT FILES
  for itheta in $( seq 0 $(( ${#thetas[@]} - 1 )) ); do
    if [ "${thetas[itheta]}" = "0" -a ${skiptheta0} -ne 0 ]; then
      continue
    fi
      
    echo theta=${thetas[itheta]}
    for iname in $( seq 0 $(( ${#names[@]} - 1 )) ); do
      echo name=${names[iname]}
      
      flavour="u"
      musign=""
      # if the fwdprop is computed with +theta(-theta), the seqprop should be computed with -theta(+theta)
      theta=${thetas[itheta]}
      if [ "${names[iname]}" = "seqprop" ]; then
        flavour="du"
        musign="-"
        if [ "${theta}" != "0" ]; then
          theta=-${theta}
        fi
      fi

      texttheta=$( echo ${theta} | sed 's/-/m/g' )
      propagatorfilename=${flavour}_${names[iname]}_theta_${texttheta}

      echo propagatorfilename=${propagatorfilename}
      
      sourcefilename=${flavour}_${names[iname]}_theta_${texttheta}
      if [ "${names[iname]}" = "seqprop" ]; then
        sourcefilename=u_fwdprop_theta_0
      fi
      
      ifile=${jdir_conf4}/inputs/${propagatorfilename}.invert.input
      logfile=${jdir_conf4}/${propagatorfilename}.${conf4}.log

      cp ${itemplate} ${ifile}.tmp
      
      sed -i "s/NSTORE/${conf}/g" ${ifile}.tmp
      sed -i "s/THETA/${theta}/g" ${ifile}.tmp
      sed -i "s/PROPFILE/${propagatorfilename}/g" ${ifile}.tmp
      sed -i "s/SRCFILE/${sourcefilename}/g" ${ifile}.tmp
      sed -i "s/SEED/${tmlqcd_rng_seed}/g" ${ifile}.tmp
      sed -i "s/NOSAMPLES/${nosamples}/g" ${ifile}.tmp
      sed -i "s@GCONF@${gauges_dir}\/conf@g" ${ifile}.tmp
      
      # choose appropriate source type for given job
      if [ "${names[iname]}" = "fwdprop" ]; then
        # for the forward propagator it may make sense to use "nobutsave" for the ReadSource input parameter
        # such that the random source is written to disk to a separate file (sanity check for different thetas, for instance)
        sed -i "s/SRCREAD/${srcread}/g" ${ifile}.tmp
        sed -i "s/SRCTYPE/PionTimeslice/g" ${ifile}.tmp
      elif [ "${names[iname]}" = "seqprop" ]; then
        # for the sequential propagator, the source (up to multiplication with gamma5) already exists, no need to "nobutsave"
        # it should be noted that the parameters here are really confusing: for the seqprop, the source is of course
        # ALWAYS read from file
        sed -i "s/SRCREAD/no/g" ${ifile}.tmp
        sed -i "s/SRCTYPE/GenPionTimeslice/g" ${ifile}.tmp
      else
        echo Unclear how to proceed with name = ${names[iname]}
        exit 1
      fi

      if [ -n "${csw}" -o "${csw}" != "0.0" ]; then
        sed -i "s/CSW/${csw}/g" ${ifile}.tmp
      fi

      sed -i "s/KAPPA/${kappa}/g" ${ifile}.tmp
      sed -i "s/MUSIGN/${musign}/g" ${ifile}.tmp
      sed -i "s/2KAPMU/${kappa2mu}/g" ${ifile}.tmp
      
      # for the sequential propagator it seems very difficult or impossible to reach relative precisions below 1e-20  
      if [ "${names[iname]}" = "seqprop" ]; then
        sed -i "s/SPREC/1e-20/g" ${ifile}.tmp
      else
        sed -i "s/SPREC/${solverprecision}/g" ${ifile}.tmp
      fi


      echo L=${L} > ${ifile}.header
      echo T=${T} >> ${ifile}.header
      echo nrxprocs=${nrxprocs} >> ${ifile}.header
      echo nryprocs=${nryprocs} >> ${ifile}.header
      echo nrzprocs=${nrzprocs} >> ${ifile}.header
      if [ -n "${ompnumthreads}" -a ${ompnumthreads} -gt 1 ]; then
        echo ompnumthreads=${ompnumthreads} >> ${ifile}.header
      fi

      cat ${ifile}.header ${ifile}.tmp > ${ifile}
      rm ${ifile}.header ${ifile}.tmp
    done
  done
done
