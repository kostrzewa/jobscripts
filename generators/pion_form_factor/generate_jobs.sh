#!/bin/bash

DEBUG=1

if [ -z ${1} ]; then
  echo "You must specify an input file."
  echo "usage: ./generate_jobs.sh <inputfile>"
  exit 1
fi

if [ ! -f ${1} ]; then
  echo "Parameter file ${1} does not exist!"
  exit 11
fi

wd=$(pwd)

# default values for variables read from input file
ensemble='ensemble'
names=( fwdprop seqprop )
thetas=( 0 )
solverprecision=1.e-18
srcread="no"
conf_start=0
conf_end=0
conf_step=0
gauges_dir='.'
jdir='.'

invert_tmlqcd_rng_seed=123456
invert_itemplate='input.template'
invert_jtemplate='jscr.template'
invert_executable='invert'
invert_wtime=00:02:00

cntr_executable='vector_ff'
cntr_jtemplate='cntr.job.template'
cntr_wtime=00:02:00

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

if [ ! -f ${invert_jtemplate} ]; then
  echo "Job template ${invert_jtemplate} does not exist!"
  exit 2
fi

if [ ! -f ${cntr_jtemplate} ]; then
  echo "Job template ${cntr_jtemplate} does not exist!"
  exit 3
fi

if [ ! -f ${invert_itemplate} ]; then
  echo "Input file template ${invert_itemplate} does not exist!"
  exit 4
fi
  
cntrdir=${jdir}/correlators
mkdir ${cntrdir}

for conf in $(seq ${conf_start} ${conf_step} ${conf_end} ); do
  conf4=$(printf %04d ${conf})
  echo "Preparing conf.${conf4}"
  jdir_conf4=${jdir}/${conf4}
  inputdir_conf4=${jdir_conf4}/inputs
  logdir_conf4=${jdir_conf4}/logs
  mkdir ${jdir_conf4}
  mkdir ${logdir_conf4}
  mkdir ${inputdir_conf4}

  # this is now done via the input file
  # if the filename is too long, the links can be reinstated
  ## ln -s ${gauges_dir}/conf.${conf4} ${jdir_conf4}


  ## GENERATE INVERSION JOB SCRIPT
  jfile=${jdir}/jscr/invert.job.${conf4}.cmd
  cp ${invert_jtemplate} ${jfile}
  sed -i "s/JOBNAME/${ensemble}_tbc_pion_props_${conf4}/g" ${jfile}
  sed -i "s/WTIME/${invert_wtime}/g" ${jfile}
  # escape spaces in thetas arrays
  thetasub=$( echo ${thetas[@]} | sed 's/ /\\ /g' )
  sed -i "s/THETAS/${thetasub}/g" ${jfile}
  namesub=$( echo ${names[@]} | sed 's/ /\\ /g' )
  sed -i "s/NAMES/${namesub}/g" ${jfile}
  sed -i "s/NODES/${nodes}/g" ${jfile}
  sed -i "s/RPN/${rpn}/g" ${jfile}
  sed -i "s/OMPNUMTHREADS/${ompnumthreads}/g" ${jfile}
  sed -i "s@EXECUTABLE@${invert_executable}@g" ${jfile}
  sed -i "s@WDIR@${jdir_conf4}@g" ${jfile}
  sed -i "s@CONF4@${conf4}@g" ${jfile}

  ## GENERATE CONTRACTION JOB SCRIPT
  jfile=${jdir}/jscr/cntr.job.${conf4}.cmd
  cp ${cntr_jtemplate} ${jfile}
  sed -i "s/JOBNAME/${ensemble}_pionff_cntr_${conf4}/g" ${jfile}
  sed -i "s/WTIME/${cntr_wtime}/g" ${jfile}
  sed -i "s/SPACEEXTENT/${L}/g" ${jfile}
  sed -i "s/TIMEEXTENT/${T}/g" ${jfile}
  sed -i "s@EXECUTABLE@${cntr_executable}@g" ${jfile}
  sed -i "s@CONF4@${conf4}@g" ${jfile}
  sed -i "s@CNTRDIR@${cntrdir}@g" ${jfile}
  sed -i "s@PROPDIR@${jdir_conf4}@g" ${jfile}
  sed -i "s@NOSAMPLES@${nosamples}@g" ${jfile}
  sed -i "s@THETAS@${thetasub}@g" ${jfile}

  ## GENERATE INPUT FILES
  for itheta in $( seq 0 $(( ${#thetas[@]} - 1 )) ); do
    echo theta=${thetas[itheta]}
    for iname in $( seq 0 $(( ${#names[@]} - 1 )) ); do
      echo name=${names[iname]}
      
      flavour="u"
      musign=""
      # if the fwdprop is computed with +theta(-theta), the seqprop should be computed with -theta(+theta)
      theta=${thetas[itheta]}
      if [ "${names[iname]}" = "seqprop" ]; then
        # for the sequential propagator, invert the 'd' flavour
        flavour="du"
        musign="-"
        if [ "${theta}" != "0.0000" ]; then
          echo ${theta}
          theta=-${theta}
        fi
      fi

      texttheta=$( echo ${theta} | sed 's/-/m/g' )
      propagatorfilename=${flavour}_${names[iname]}_theta_${texttheta}

      echo propagatorfilename=${propagatorfilename}
      
      sourcefilename=${flavour}_${names[iname]}_theta_${texttheta}
      if [ "${names[iname]}" = "seqprop" ]; then
        sourcefilename=u_fwdprop_theta_0.0000
      fi
      
      ifile=${inputdir_conf4}/${propagatorfilename}.invert.input
      logfile=${jdir_conf4}/${propagatorfilename}.${conf4}.log

      cp ${invert_itemplate} ${ifile}.tmp
      
      sed -i "s/NSTORE/${conf}/g" ${ifile}.tmp
      sed -i "s/THETA/${theta}/g" ${ifile}.tmp
      sed -i "s/PROPFILE/${propagatorfilename}/g" ${ifile}.tmp
      sed -i "s/SRCFILE/${sourcefilename}/g" ${ifile}.tmp
      sed -i "s/SEED/${invert_tmlqcd_rng_seed}/g" ${ifile}.tmp
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
