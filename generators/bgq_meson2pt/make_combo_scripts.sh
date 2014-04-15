# This script creates job scripts and input files for simultaneous inversions and
# contractions using tmLQCD and CVC (using the libcvcpp library)
# For customization details, see the README file.

START=554
END=554
STEP=2

NAME="iwa_b2.10-L48T96-csw1.57551-k0.137290-mu0.0009"
TASKNAME="meson_2pt_test"

# for compatibility to fermi, set $scratch to $CINECA_SCRATCH
# on JuQueen, work==scratch
work=${WORK}
scratch=${WORK}

RUNDIR=${TASKNAME}/nf2/${NAME}
WDIR=${scratch}/${RUNDIR}
GAUGEDIR=${work}/confs_tmp/nf2/${NAME}
SOURCEDIR=${scratch}/sources/conn_meson/fuzzed/nf2/${NAME}
JOBDIR=${WDIR}/jobscripts
IDIR=${WDIR}/inputs
ODIR=${WDIR}/outputs
ARCHDIR=/arch/hch02/hch028/${RUNDIR}/propagators

DEBUG=0
DO_ARCHIVAL=1

CONTRACTIONS_BG_SIZE=128
CONTRACTIONS_WC_LIMIT="00:30:00"

ARCHIVAL_WC_LIMIT="00:30:00"

if [ -z "$1" ]; then
  echo "You need to provide a filename with a list of inversions to prepare scripts for!"
  echo "Usage: ./make_combo_scripts.sh filename"
  exit 1
fi

CONTRACTION_ONLY=0
if [ ! -z "$2" ]; then
  echo "Creating jobs for contraction only!"
  CONTRACTION_ONLY=1
  TASKNAME="contraction"
fi

for name in inputs outputs jobscripts; do
  if [ ! -d ${WDIR}/${name} ]; then
    mkdir -p ${WDIR}/${name}
  fi
done

# loop over configurations
for cnum in `seq ${START} ${STEP} ${END}`; do
  echo "Preparing scripts and input files for configuration ${cnum}"

  c4num=`printf "%04d" ${cnum}`
  cname="conf.${c4num}"

  if [ ! -f ${WDIR}/${cname} ]; then
    echo "Making link ${WDIR}/${cname} to ${GAUGEDIR}/${cname}"
    ln -s ${GAUGEDIR}/${cname} ${WDIR}/${cname}
  fi

  # create job command file ("jobscript")
  jcf=${JOBDIR}/meson_2pt_${c4num}.job
  if [ $CONTRACTION_ONLY -eq 1 ]; then
    jcf=${JOBDIR}/contraction_${c4num}.job
  fi
  cp common.header.template ${jcf}
  sed -i "s/job_name=/job_name=${TASKNAME}_${NAME}_${c4num}/g" ${jcf}

  # create the temporary file for the job body
  touch job.body.tmp

  source_ts=`ls ${SOURCEDIR}/source.${c4num}.??.00 | awk -F '/' '{print $NF}' | cut -d '.' -f 3`
  echo "Source Timeslice: ${source_ts}"

  # 
  if [ $CONTRACTION_ONLY -ne 1 ]; then
    # read the inversions to be done one by one
    # keep in mind that there will be changes when CGMMS for nf2clover is ready!
    contraction_dependencies="("
    archival_dependencies="("
    first_archival_dependency=1
    first_contraction_dependency=1
    while read line; do
      # skip empty lines
      [ -z "${line}" ] && continue
      # and comments
      if [ -n "`echo ${line} | grep '^#'`" ]; then
        continue
      fi

      # read parameters from line

      step_name=`echo ${line} | cut -d ' ' -f 1`
      
      # we build the dependency chain for the archival and contraction steps bit by bit
      # the contraction step should not depend on any disconnected inversions that we do
      # whereas the archival step should 
      if [ -z "`echo ${line} | grep '^disc'`" ]; then
        if [ ${first_contraction_dependency} -eq 1 ]; then
          contraction_dependencies="${contraction_dependencies} ${step_name} == 0"
          first_contraction_dependency=0
        else
          # ampersand escaping for sed below
          contraction_dependencies="${contraction_dependencies} \\&\\& ${step_name} == 0"
        fi
        if [ ${first_archival_dependency} -eq 1 ]; then
          archival_dependencies="${archival_dependencies} ${step_name} == 0"
          first_archival_dependency=0
        else
          archival_dependencies="${archival_dependencies} \\&\\& ${step_name} == 0"
        fi
      else
        if [ ${first_archival_dependency} -eq 1 ]; then
          archival_dependencies="${archival_dependencies} ${step_name} == 0"
          first_archival_dependency=0
        else
          archival_dependencies="${archival_dependencies} \\&\\& ${step_name} == 0"
        fi
      fi

      bg_size=`echo ${line} | cut -d ' ' -f 3`
      wall_clock_limit=`echo ${line} | cut -d ' ' -f 4`
      solver_prec=`echo ${line} | cut -d ' ' -f 5`
      prop_prec=`echo ${line} | cut -d ' ' -f 6`
      coll_name=`echo ${line} | cut -d ' ' -f 7`

      twokappamu=0
      twokappamubar=0
      twokappaepsbar=0
      if [ -z "`echo ${line} | grep '^nd'`" ]; then
        twokappamu=`echo ${line} | cut -d ' ' -f 2`
      else
        twokappamusigma=`echo ${line} | cut -d ' ' -f 2 | cut -d ';' -f 1`
        twokappamudelta=`echo ${line} | cut -d ' ' -f 2 | cut -d ';' -f 2`      
      fi

      # choose parallelization based on bg_size 
      # note that this currently only works for 32, 64, 128, 512 and 1024 and NOT for 256
      nr_xyz_procs=2
      if [ ${bg_size} -gt 128 ]; then
        nr_xyz_procs=4
      fi
      
      if [ ${DEBUG} -eq 1 ]; then
        echo $line
        echo $step_name $bg_size $wall_clock_limit $solver_prec $prop_prec $coll_name $nr_xyz_procs $twokappamu $twokappamusigma $twokappamudelta 
      fi

      # create working directory for this inversion
      inv_wdir=${WDIR}/${coll_name}/${step_name}
      if [ ! -d ${inv_wdir} ]; then
        mkdir -p ${inv_wdir}
      fi
      
      if [ ! -e ${inv_wdir}/${cname} ]; then
        ln -s ${GAUGEDIR}/${cname} ${inv_wdir}
      fi

      for source in ${SOURCEDIR}/source.${c4num}.??.??; do
        source_link=${inv_wdir}/`echo ${source} | awk -F '/' '{print $NF}'`
        if [ ! -e ${source_link} ]; then
          ln -s ${source} ${source_link}
        fi
      done

      # create jobscript header for this inversion
      cp inversion.header.template inversion.header.template.tmp
      sed -i "s/step_name=/step_name=${step_name}/g" inversion.header.template.tmp
      sed -i "s/wall_clock_limit=/wall_clock_limit=${wall_clock_limit}/g" inversion.header.template.tmp
      sed -i "s/bg_size=/bg_size=${bg_size}/g" inversion.header.template.tmp
      cat inversion.header.template.tmp >> ${jcf}
      rm inversion.header.template.tmp
    
      # create input file for this inversion
      ifile="${IDIR}/${step_name}.${c4num}.invert.input"

      # create job body for this inversion
      echo "${step_name} )" >> inversion.job.template.tmp
      cat inversion.job.template >> inversion.job.template.tmp
      # use @ as command separator because we're dealing with paths which contain '/'
      sed -i "s@IFILE=@IFILE=${ifile}@g" inversion.job.template.tmp
      sed -i "s@ODIR=@ODIR=${ODIR}@g" inversion.job.template.tmp
      sed -i "s@WDIR=@WDIR=${inv_wdir}@g" inversion.job.template.tmp
      sed -i "s@OUTPUTID=@OUTPUTID=${c4num}@g" inversion.job.template.tmp
      # attach this case statement to the final job body
      cat inversion.job.template.tmp >> job.body.tmp
      rm inversion.job.template.tmp

      # the input file templates are different depending on whether we are doing
      # degenerate doublet (resp. Osterwalder-Seiler) or non-degenerate doublet
      # inversions
      # a further differentiation comes from the calculation for disconnected loops
      # using volume sources  
      if [ -z "`echo ${line} | grep '^nd'`" ]; then
        if [ -z "`echo ${line} | grep '^disc'`" ]; then
          echo "OS inversions"
          cp invert.OS.input.template ${ifile}
        else
          echo "DISC inversions"
          cp invert.DISC.input.template ${ifile}
        fi
        sed -i -e "s/2kappamu=/2kappamu=${twokappamu}/g" ${ifile}
      else
        echo "ND inversions"
        cp invert.ND.input.template ${ifile}
        sed -i -e "s/2kappamubar=/2kappamubar=${twokappamusigma}/g" ${ifile}
        sed -i -e "s/2kappaepsbar=/2kappaepsbar=${twokappamudelta}/g" ${ifile}
      fi

      if [ -z `echo $1 | grep '^disc'` ]; then
        sed -i -e "s/sourcetimeslice=/sourcetimeslice=${source_ts}/g" ${ifile}
      fi

      sed -i -e "s/initialstorecounter=/initialstorecounter=${cnum}/g" ${ifile}
      sed -i -e "s/propagatorprecision=/propagatorprecision=${prop_prec}/g" ${ifile}
      sed -i -e "s/solverprecision=/solverprecision=${solver_prec}/g" ${ifile}
  
      for direction in x y z; do
        sed -i -e "s/nr${direction}procs=/nr${direction}procs=${nr_xyz_procs}/g" ${ifile}
      done

    done < ${1} # loop through file, see while read above
    contraction_dependencies="${contraction_dependencies} )"
    archival_dependencies="${archival_dependencies} )"

    # create jobscript header for archival
    if [ $DO_ARCHIVAL -ne 0 ]; then
      cp archival.header.template archival.header.template.tmp
      sed -i "s/wall_clock_limit=/wall_clock_limit=${ARCHIVAL_WC_LIMIT}/g" archival.header.template.tmp
      sed -i "s/dependency=/dependency=\ ${archival_dependencies}/g" archival.header.template.tmp
      cat archival.header.template.tmp >> ${jcf}
      rm archival.header.template.tmp

      # archival job body
      cp archival.job.template archival.job.template.tmp

      # using @ as a separator because the filenames contain slashes and would otherwise confuse sed
      sed -i "s@ODIR=@ODIR=${ODIR}@g" archival.job.template.tmp
      sed -i "s@WDIR=@WDIR=${WDIR}@g" archival.job.template.tmp
      sed -i "s@ARCHDIR=@ARCHDIR=${ARCHDIR}@g" archival.job.template.tmp
      sed -i "s@C4NUM=@C4NUM=${c4num}@g" archival.job.template.tmp

      cat archival.job.template.tmp >> job.body.tmp
      rm archival.job.template.tmp
    fi # DO_ARCHIVAL

  fi # CONTRACTION_ONLY

  # create jobscript header for contraction
  cp contraction.header.template contraction.header.template.tmp
  sed -i "s/bg_size=/bg_size=${CONTRACTIONS_BG_SIZE}/g" contraction.header.template.tmp
  sed -i "s/wall_clock_limit=/wall_clock_limit=${CONTRACTIONS_WC_LIMIT}/g" contraction.header.template.tmp
  # if CONTRACTION_ONLY == 1; then contraction_dependencies is empty, but this is not a problem!
  sed -i "s/dependency=/dependency=\ ${contraction_dependencies}/g" contraction.header.template.tmp
  cat contraction.header.template.tmp >> ${jcf}
  rm contraction.header.template.tmp
  
  ## contraction job template and input file
  # contraction input file
  cvc_ifile=${IDIR}/cvc.${c4num}.input
  cp cvc.input.template ${cvc_ifile}

  sed -i "s/_NC/${cnum}/g" ${cvc_ifile}
  sed -i "s/_TS/${source_ts}/g" ${cvc_ifile}
  # contraction job body
  cp contraction.job.template contraction.job.template.tmp

  sed -i "s@IFILE=@IFILE=${cvc_ifile}@g" contraction.job.template.tmp
  sed -i "s@ODIR=@ODIR=${ODIR}@g" contraction.job.template.tmp
  sed -i "s@WDIR=@WDIR=${WDIR}@g" contraction.job.template.tmp
  sed -i "s@OUTPUTID=@OUTPUTID=${c4num}@g" contraction.job.template.tmp

  cat contraction.job.template.tmp >> job.body.tmp
  rm contraction.job.template.tmp

  # attach common portion to job command file, including case statement
  cat common.job.template >> ${jcf}
  # attach concatenation of job bodies
  cat job.body.tmp >> ${jcf}
  rm job.body.tmp

  echo >> ${jcf}
  echo esac >> ${jcf}

done # loop over configurations
