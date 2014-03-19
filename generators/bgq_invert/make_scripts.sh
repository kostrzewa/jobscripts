#!/bin/bash

if [ "$1" == "" ]; then
  echo "You need to provide a mass name!"
  echo "Usage: ./make_scripts.sh mass_name"
  exit 1
fi

grep $1 masses.txt > /dev/null

if [ ! $? -eq 0 ]; then
  echo "It seems that \"$1\" could not be found in masses.txt! Exiting."
  exit 1
fi

RUNDIR=iwa_b2.33-L32T64-k0.151064-mu0.0019-musigma0.0577-mudelta0.0663
GAUGEDIR=/work/hch02/hch028/confs_tmp
SOURCEDIR=/work/hch02/hch028/source_generation/${RUNDIR}
WDIR=/work/hch02/hch028/inversions/nf211/${RUNDIR}/$1
ARCHDIR=/arch/hch02/hch028/inversions/nf211/${RUNDIR}/$1
PROPDIR=${WDIR}/propagators
ODIR=${WDIR}/outputs

export TWOKAPPAMU=""
export TWOKAPPAMUSIGMA=""
export TWOKAPPAMUDELTA=""

# read variable parameters from text file

# if we're dealing with a non-degenerate doublet, the masses are given as musigma;mudelta
if [ -z `echo $1 | grep 'nd'` ]; then
  TWOKAPPAMU=`grep -w $1 masses.txt | cut -d ' ' -f 2`
else
  TWOKAPPAMUSIGMA=`grep -w $1 masses.txt | cut -d ' ' -f 2 | cut -d ';' -f 1`
  TWOKAPPAMUDELTA=`grep -w $1 masses.txt | cut -d ' ' -f 2 | cut -d ';' -f 2`
fi

BG_SIZE=`grep -w $1 masses.txt | cut -d ' ' -f 3`
WALLCLOCK_TIME=`grep -w $1 masses.txt | cut -d ' ' -f 4`
SOLVER_PRECISION=`grep -w $1 masses.txt | cut -d ' ' -f 5`
PROP_PRECISION=`grep -w $1 masses.txt | cut -d ' ' -f 6`

FROM=`grep -w $1 masses.txt | cut -d ' ' -f 7`
TO=`grep -w $1 masses.txt | cut -d ' ' -f 8`
INVERSIONS_PER_JOB=`grep -w $1 masses.txt | cut -d ' ' -f 9`
STEP=`grep -w $1 masses.txt | cut -d ' ' -f 10`

# choose parallellization based on bg_size
# note this only works for 32, 64, 128 and 512 currently!
NR_XYZ_PROCS=2
if [ ${BG_SIZE} -gt 128 ]; then
  NR_XYZ_PROCS=4
fi

for name in wdirs confs inputs outputs propagators sources jobscripts; do
  if [ ! -d ${WDIR}/${name} ]; then
    mkdir -p ${WDIR}/${name}
  fi
done

echo "Making scripts for ${1}..."

OUTER_LOOP_STEP=$(( INVERSIONS_PER_JOB * STEP ))

for outer_ctr in `seq ${FROM} ${OUTER_LOOP_STEP} ${TO}`; do
  jobref=""
  inner_to=$((outer_ctr + OUTER_LOOP_STEP - STEP))
  if [ ${inner_to} -gt ${TO} ]; then
    inner_to=${TO}
  fi
  inner_from=${outer_ctr}

  if [ ${INVERSIONS_PER_JOB} -eq 1 ]; then
    echo "Processing gauge configuration ${inner_from}..."
    jobref=`printf %04d ${inner_from}`
  else
    echo "Processing gauge configurations ${inner_from} to ${inner_to} in steps of ${STEP}"
    echo "Doing ${INVERSIONS_PER_JOB} configurations per job script."  
    jobref=`printf "%04d_%02d_%04d" ${inner_from} ${STEP} ${inner_to}`
  fi

  # create a working directory for each job
  jobwdir=${WDIR}/wdirs/${jobref}
  if [ ! -d ${jobwdir} ]; then
    mkdir -p ${jobwdir}
  fi
 
  # list of configurations for a given job
  confs="\""
  for inner_ctr in `seq ${inner_from} ${STEP} ${inner_to}`; do
    
    number=`printf %04d ${inner_ctr}`
    confs="${confs} ${number}"

    # create links for gauge configuration
    ln -sf ${GAUGEDIR}/conf.${number} ${WDIR}/confs
    # this is for the given job to use 
    ln -sf ${WDIR}/confs/conf.${number} ${jobwdir}
  
    # determne timeslice of source and create links to sources
    ts=""
    if [ -z `echo $1 | grep '^disc'` ]; then
      ln -sf ${SOURCEDIR}/source.${number}.??.?? ${WDIR}/sources
      ln -sf ${WDIR}/sources/source.${number}.??.?? ${jobwdir}
      ts=`ls ${WDIR}/sources/source.${number}.*.03 | awk -F '/' '{print $NF}' | cut -d '.' -f 3`
      echo "Timeslice: ${ts}"
    fi

    # generate input file
    input=${WDIR}/inputs/invert.${number}.input
  
    # the input file templates are different depending on whether we are doing
    # degenerate doublet (resp. Osterwalder-Seiler) or non-degenerate doublet
    # inversions
    # a further differentiation comes from the calculation for disconnected loops
    # using volume sources  
    if [ -z `echo $1 | grep '^nd'` ]; then
      if [ -z `echo $1 | grep '^disc'` ]; then
        echo "OS inversions"
        cp invert.OS.input.template ${input}
      else
        echo "DISC inversions"
        cp invert.DISC.input.template ${input}
      fi
      sed -i -e "s/2kappamu=/2kappamu=${TWOKAPPAMU}/g" ${input}
    else
      echo "ND inversions"
      cp invert.ND.input.template ${input}
      sed -i -e "s/2kappamubar=/2kappamubar=${TWOKAPPAMUSIGMA}/g" ${input}
      sed -i -e "s/2kappaepsbar=/2kappaepsbar=${TWOKAPPAMUDELTA}/g" ${input}
    fi
  
    if [ -z `echo $1 | grep '^disc'` ]; then
      sed -i -e "s/sourcetimeslice=/sourcetimeslice=${ts}/g" ${input}
    fi

    sed -i -e "s/initialstorecounter=/initialstorecounter=${number}/g" ${input}
    sed -i -e "s/propagatorprecision=/propagatorprecision=${PROP_PRECISION}/g" ${input}
    sed -i -e "s/solverprecision=/solverprecision=${SOLVER_PRECISION}/g" ${input}
  
    for direction in x y z; do
      sed -i -e "s/nr${direction}procs=/nr${direction}procs=${NR_XYZ_PROCS}/g" ${input}
    done

    cp ${input} ${jobwdir}
  done # inner_ctr
  confs="${confs}\""

  inputprefix=${WDIR}/inputs/invert

  # generate job script
  jobscript=${WDIR}/jobscripts/invert.${jobref}.job
  cp invert.job.template ${jobscript}

  sed -i -e "s@INPUTPREFIX=@INPUTPREFIX=${inputprefix}@g" ${jobscript}
  sed -i -e "s@ODIR=@ODIR=${ODIR}@g" ${jobscript}
  sed -i -e "s@WDIR=@WDIR=${jobwdir}@g" ${jobscript}
  sed -i -e "s@ARCHDIR=@ARCHDIR=${ARCHDIR}@g" ${jobscript}
  sed -i -e "s/CONFS=/CONFS=${confs}/g" ${jobscript}
  sed -i -e "s/job_name =/job_name = invert.${1}.${jobref}/g" ${jobscript}
  sed -i -e "s/bg_size =/bg_size = ${BG_SIZE}/g" ${jobscript}
done # outer_ctr  
