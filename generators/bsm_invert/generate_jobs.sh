#!/bin/sh

DEBUG=1

if [ -z ${1} ]; then
  echo "You must specify an input file."
  echo "usage: ./generate_jobs.sh <inputfile>"
  exit 1
fi

wd=$(pwd)

# default values for variables read from input file
name='inversion'
conf_start=0
conf_end=0
conf_step=0
npergauge=0
resuse_scalars=0
scalars_dir='.'
gauges_dir='.'
jdir='.'
scalar_rng_seed=123456
tmlqcd_rng_seed=123456
genjscr='NULL'
ifile='template.input'
executable='invert'

# read the input file
. ${wd}/${1}

if [ $DEBUG -eq 1 ]; then
  cat ${wd}/${1}
fi

# create job directory
if [ ! -d ${jdir}/jscr ]; then
  mkdir -p ${jdir}/jscr
fi


# generate the scalar mappings
echo "Executing " ${wd}/scalar_combinator.py -d ${scalars_dir} -i ${conf_start} -f ${conf_end} -s ${conf_step} -n ${npergauge} -S ${scalar_rng_seed} -r ${reuse_scalars}
${wd}/scalar_combinator.py -d ${scalars_dir} -i ${conf_start} -f ${conf_end} -s ${conf_step} -n ${npergauge} -S ${scalar_rng_seed} -r ${reuse_scalars}

for i in $(seq ${conf_start} ${conf_step} $(( ${conf_end} - ${conf_step} )) ); do
  i4=$(printf %04d ${i})
  echo "Preparing conf.${i4}"
  jdir_i4=${jdir}/${i4}
  mkdir -p ${jdir_i4}

  # create directory and back up mapping of scalar configurations to gauge configurations
  mkdir -p ${jdir}/scalarmap
  cp scalarmap.${i4} ${jdir}/scalarmap/ 
  
  # make links
  ln -s ${gauges_dir}/conf.${i4} ${jdir_i4}
  
  # make links for the scalar configurations from the scalar mappings
  nscalar=0
  while read line; do
  ln -s ${line} ${jdir_i4}/scalar.${nscalar}
    nscalar=$(( ${nscalar} + 1 ))
  done < scalarmap.${i4}
  
  # delete the local copy
  rm scalarmap.${i4}
  
  # generate input file
  ifile_i4=${jdir_i4}/invert.input
  cp input_templates/${ifile} ${ifile_i4}
  sed -i "s/SEED/${tmlqcd_rng_seed}/g" ${ifile_i4}
  sed -i "s/NSTORE/${i}/g" ${ifile_i4}
  sed -i "s/NPERGAUGE/${npergauge}/g" ${ifile_i4}
  
  # generate job script
  jscr_i4=${jdir}/jscr/jscr.${i4}.sh
  cp jscr_templates/${jscr} ${jscr_i4}
  sed -i "s@JDIR@${jdir_i4}@g" ${jscr_i4}
  sed -i "s@EXEC@${executable}@g" ${jscr_i4}
  sed -i "s@NAME@${name}_${i4}@g" ${jscr_i4}

done
