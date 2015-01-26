# This script creates job scripts and input files for simultaneous inversions and
# contractions using tmLQCD and CVC (using the libcvcpp library)
# For customization details, see the README file.

START=1078
END=1078
STEP=2
CONFS_PER_BUNCH=8

NAME="iwa_b2.1-L24T48-csw1.57551-k0.1373-mul0.006_xeonphi"
TASKNAME="meson_2pt"

# for compatibility to fermi, set $scratch to $CINECA_SCRATCH
# on JuQueen, work==scratch
work=${WORK}
scratch=${WORK}

RUNDIR=${TASKNAME}/nf2/${NAME}
WDIR=${scratch}/${RUNDIR}
GAUGEDIR=${work}/confs_tmp/nf2/${NAME}
SOURCEDIR=${WDIR}/sources
JOBDIR=${WDIR}/jobscripts
# IDIR=${WDIR}/inputs
ODIR=${WDIR}/outputs
ARCHDIR=/arch/hch02/hch028/${RUNDIR}/propagators

DEBUG=1
DO_ARCHIVAL=1
DO_INVERSION=0
DO_CONTRACTION=0

if [[ $DO_INVERSION -eq 0 && $DO_ARCHIVAL -eq 0 && $DO_CONTRACTION -eq 0 ]]; then
  echo "You need to select at least one mode of operation from the DO_* variables in make_combo_scripts.sh"
  exit 1
fi

CONTRACTIONS_BG_SIZE=32
CONTRACTIONS_WC_LIMIT="00:30:00"

ARCHIVAL_WC_LIMIT="00:45:00"

if [ -z "$1" ]; then
  echo "You need to provide a filename with a list of inversions to prepare scripts for!"
  echo "Usage: ./make_combo_scripts.sh filename"
  exit 1
fi

OPECHO="Preparing job scripts and input files for"
 
# indicate in task name which steps are to be taken
if [ $DO_INVERSION -eq 1 ]; then
  TASKNAME="${TASKNAME}_inv"
  OPECHO="${OPECHO} inversions"
fi
if [ $DO_ARCHIVAL -eq 1 ]; then
  TASKNAME="${TASKNAME}_ar"
  OPECHO="${OPECHO} archival"
fi
if [ $DO_CONTRACTION -eq 1 ]; then
  TASKNAME="${TASKNAME}_con"
  OPECHO="${OPECHO} contractions"
fi

for name in inputs outputs jobscripts; do
  if [ ! -d ${WDIR}/${name} ]; then
    mkdir -p ${WDIR}/${name}
  fi
done

echo $OPECHO

# loop over configurations in bunches
for start_bunch in `seq ${START} $(( STEP * CONFS_PER_BUNCH )) ${END}`; do
  echo "Starting configuration for this bunch: ${start_bunch}"

  # create list of configurations for this bunch
  start_bunch4=`printf %04d ${start_bunch}`
  end_bunch=$(( cnum + STEP * CONFS_PER_BUNCH ))
  confs_in_bunch4=""
  for conf in `seq ${start_bunch} ${step} ${ens_bunch}`; do
    confs_in_bunch4="${confs_in_bunch4} `printf %04d ${conf}`"
  done

  # make links to gauge configurations
  for c4num in ${confs_in_bunch4}; do
    cname="conf.${c4num}"
    if [ ! -f ${WDIR}/${cname} ]; then
      echo "Making link ${WDIR}/${cname} to ${GAUGEDIR}/${cname}"
      ln -s ${GAUGEDIR}/${cname} ${WDIR}/${cname}
    fi
  done

  # create job command file ("jobscript")
  jcf=${JOBDIR}/${TASKNAME}_${start_bunch4}.job
  cp common.header.template ${jcf}
  sed -i "s/job_name=/job_name=${TASKNAME}_${NAME}_${start_bunch4}/g" ${jcf}

  # create the temporary file for the job body
  touch job.body.tmp



  if [ $DO_INVERSION -eq 1 ]; then
    # read the inversions to be done one by one
    # keep in mind that there will be changes when CGMMS for nf2clover is ready!
    contraction_dependencies="("
    archival_dependencies="("
    first_archival_dependency=1
    first_contraction_dependency=1
    new_dependency=0
    new_job_step=0
    current_flavour=""
    in_case_statement=0
    while read line; do
      # skip empty lines
      [ -z "${line}" ] && continue
      # and comments
      if [ -n "`echo ${line} | grep '^#'`" ]; then
        continue
      fi

      # read parameters from line

      mass_index=`echo ${line} | cut -d ' ' -f 1`
      
      bg_size=`echo ${line} | cut -d ' ' -f 3`
      wall_clock_limit=`echo ${line} | cut -d ' ' -f 4`
      solver_prec=`echo ${line} | cut -d ' ' -f 5`
      prop_prec=`echo ${line} | cut -d ' ' -f 6`
      flavour=`echo ${line} | cut -d ' ' -f 7`

      twokappamu=0
      twokappamubar=0
      twokappaepsbar=0
      if [ -z "`echo ${line} | grep '^nd'`" ]; then
        twokappamu=`echo ${line} | cut -d ' ' -f 2`
      else
        twokappamusigma=`echo ${line} | cut -d ' ' -f 2 | cut -d ';' -f 1`
        twokappamudelta=`echo ${line} | cut -d ' ' -f 2 | cut -d ';' -f 2`      
      fi

      if [ ${DEBUG} -ne 0 ]; then
        echo "mass_index = $mass_index"
        echo "bg_size   = $bg_size"
        echo "wall_clock_limit = $wall_clock_limit"
        echo "solver_prec = $solver_prec"
        echo "prop_prec = $prop_prec"
        echo "flavour = $flavour"
        echo "twokappamu = $twokappamu"
        echo "twokappamusigma = $twokappamusigma"
        echo "twokappamudelta = $twokappamudelta"
      fi
      
      if [ "${flavour}" != "${current_flavour}" ]; then
        current_flavour="${flavour}"
        # if we are dealing with a new flavour, we need to add a new dependency
        new_dependency=1
        # a new header, case statement and footer for the previous case statement 
        new_job_step=1
      fi
 
      # we build the dependency chain for the archival and contraction steps bit by bit
      # the contraction step should not depend on any disconnected inversions that we do
      # whereas the archival step should 
      if [ -z "`echo ${line} | grep '^disc'`" ]; then
        if [ ${new_dependency} -eq 1 ]; then
          if [ ${first_contraction_dependency} -eq 1 ]; then
            contraction_dependencies="${contraction_dependencies} ${flavour} == 0"
            first_contraction_dependency=0
          else
            # ampersand escaping for sed below
            contraction_dependencies="${contraction_dependencies} \\&\\& ${flavour} == 0"
          fi
          if [ ${first_archival_dependency} -eq 1 ]; then
            archival_dependencies="${archival_dependencies} ${flavour} == 0"
            first_archival_dependency=0
          else
            archival_dependencies="${archival_dependencies} \\&\\& ${flavour} == 0"
          fi
          new_dependency=0
        fi
      else # this is disconnected now -> no contraction dependency
        if [ ${new_dependency} -eq 1 ]; then
          if [ ${first_archival_dependency} -eq 1 ]; then
            archival_dependencies="${archival_dependencies} ${flavour} == 0"
            first_archival_dependency=0
          else
            archival_dependencies="${archival_dependencies} \\&\\& ${flavour} == 0"
          fi
          new_dependency=0
        fi
      fi # if "disc"

      # choose parallelization based on bg_size 
      # note that this currently only works for 32, 64, 128, 512 and 1024 and NOT for 256
      nr_xyz_procs=2
      if [ ${bg_size} -gt 128 ]; then
        nr_xyz_procs=4
      fi
      
      if [ ${DEBUG} -eq 1 ]; then
        echo $line
        echo '$mass_index $bg_size $wall_clock_limit $solver_prec $prop_prec $flavour $nr_xyz_procs $twokappamu $twokappamusigma $twokappamudelta'
        echo $mass_index $bg_size $wall_clock_limit $solver_prec $prop_prec $flavour $nr_xyz_procs $twokappamu $twokappamusigma $twokappamudelta 
      fi

      # create working directory for this inversion
      inv_wdir=${WDIR}/${flavour}/${mass_index}
      if [ ! -d ${inv_wdir} ]; then
        mkdir -p ${inv_wdir}
      fi
      
      if [ ! -e ${inv_wdir}/${cname} ]; then
        ln -s ${GAUGEDIR}/${cname} ${inv_wdir}
      fi

      # create links to the sources unless we're doing disconnected inversions
      if [ -z "`echo ${line} | grep '^disc'`" ]; then 
        if [ ${DEBUG} -ne 0 ]; then
          echo "Creating links to sources in ${inv_wdir}"
        fi
        for c4num in ${confs_in_bunch4}; do
          for source in ${SOURCEDIR}/source.${c4num}.??.??; do
            source_link=${inv_wdir}/`echo ${source} | awk -F '/' '{print $NF}'`
            if [ ! -e ${source_link} ]; then
              ln -s ${source} ${source_link}
            fi
          done
      fi

      # create jobscript header for this job step if it is new
      if [ ${new_job_step} -eq 1 ]; then
        if [ ${DEBUG} -ne 0 ]; then
          echo "Creating inversion header for ${flavour}"
        fi
        cp inversion.header.template inversion.header.template.tmp
        sed -i "s/step_name=/step_name=${flavour}/g" inversion.header.template.tmp
        sed -i "s/wall_clock_limit=/wall_clock_limit=${wall_clock_limit}/g" inversion.header.template.tmp
        sed -i "s/bg_size=/bg_size=${bg_size}/g" inversion.header.template.tmp
        cat inversion.header.template.tmp >> ${jcf}
        rm inversion.header.template.tmp

        # besides the header, we also need to take care of the case statement in the job body
        if [ ${DEBUG} -ne 0 ]; then
          echo "Adding case statement for ${flavour}"
        fi
        # if we're currently in the case statement of the previous step,
        # so we need to add ";;" to the job body and have the output file of the previous step
        # copied to the "outputs" directory
        if [ ${in_case_statement} -eq 1 ]; then
          echo '  cp -v ${OFILE} ${ODIR}/${LOADL_STEP_NAME}.${OUTPUTID}.out' >> job.body.tmp
          echo '  exit $RETVAL' >> job.body.tmp
          echo ";;" >> job.body.tmp
          in_case_statement=0
        fi
        # and now we start and a new job step
        echo "${flavour} )" >> job.body.tmp
        in_case_statement=1
        new_job_step=0
      fi # new_job_step

      for c4num in ${confs_in_bunch4}; do
        # create input file for this inversion
        ifile="${IDIR}/${mass_index}.${c4num}.invert.input"
        # create job body for this inversion
        if [ ${DEBUG} -ne 0 ]; then
          echo "Creating job body for ${mass_index}"
        fi
        cat inversion.job.template >> inversion.job.template.tmp
        # use @ as command separator because we're dealing with paths which contain '/'
        sed -i "s@IFILE=@IFILE=${ifile}@g" inversion.job.template.tmp
        sed -i "s@ODIR=@ODIR=${ODIR}@g" inversion.job.template.tmp
        sed -i "s@WDIR=@WDIR=${inv_wdir}@g" inversion.job.template.tmp
        sed -i "s@OUTPUTID=@OUTPUTID=${c4num}@g" inversion.job.template.tmp
        # attach this case statement to the final job body
        cat inversion.job.template.tmp >> job.body.tmp
        rm inversion.job.template.tmp

        source_ts=`ls ${SOURCEDIR}/source.${c4num}.??.00 | awk -F '/' '{print $NF}' | cut -d '.' -f 3`
        echo "Source Timeslice for conf ${c4num}: ${source_ts}"

        # the input file templates are different depending on whether we are doing
        # degenerate doublet (resp. Osterwalder-Seiler) or non-degenerate doublet
        # inversions
        # a further differentiation comes from the calculation for disconnected loops
        # using volume sources
        if [ ${DEBUG} -ne 0 ]; then
          echo "Creating input file for ${mass_index}"
        fi
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

      done # loop over configurations in bunch

    done < ${1} # loop through file, see "while read" above
    contraction_dependencies="${contraction_dependencies} )"
    archival_dependencies="${archival_dependencies} )"

    # for the last inversion in the list we need to complete the case statement
    if [ ${in_case_statement} -eq 1 ]; then
      echo '  cp -v ${OFILE} ${ODIR}/${LOADL_STEP_NAME}.${OUTPUTID}.out' >> job.body.tmp
      echo '  exit $RETVAL' >> job.body.tmp
      echo ";;" >> job.body.tmp
      in_case_statement=0
    fi
  fi # DO_INVERSION

  if [ $DO_ARCHIVAL -eq 1 ]; then
    # create jobscript header for archival
    if [ ${DEBUG} -ne 0 ]; then
      echo "Creating header for archival"
    fi

    cp archival.header.template archival.header.template.tmp
    sed -i "s/wall_clock_limit=/wall_clock_limit=${ARCHIVAL_WC_LIMIT}/g" archival.header.template.tmp
    # in case there were no inversions the list of dependencies will be empty, this is fine
    # because LoadLeveler knows how to deal with that
    sed -i "s/dependency=/dependency=\ ${archival_dependencies}/g" archival.header.template.tmp
    cat archival.header.template.tmp >> ${jcf}
    rm archival.header.template.tmp

    if [ ${DEBUG} -ne 0 ]; then
      echo "Creating job body for archival"
    fi

    # add archival case label to job body
    echo "archival )" >> job.body.tmp

    for c4num in ${confs_in_bunch4}; do
      # archival job body
      cp archival.job.template archival.job.template.tmp

      # using @ as a separator because the filenames contain slashes and would otherwise confuse sed
      sed -i "s@ODIR=@ODIR=${ODIR}@g" archival.job.template.tmp
      sed -i "s@WDIR=@WDIR=${WDIR}@g" archival.job.template.tmp
      sed -i "s@ARCHDIR=@ARCHDIR=${ARCHDIR}@g" archival.job.template.tmp
      sed -i "s@C4NUM=@C4NUM=${c4num}@g" archival.job.template.tmp

      cat archival.job.template.tmp >> job.body.tmp
      rm archival.job.template.tmp
    done

    # and finish up case statement
    echo '  date' >> job.body.tmp
    echo '  cp -v ${OFILE} ${ODIR}/${LOADL_STEP_NAME}.${C4NUM}.out' >> job.body.tmp
    echo '  exit $RETVAL' >> job.body.tmp
    echo ';;' >> job.body.tmp

  fi # DO_ARCHIVAL

  # in addition to the job script, the contraction code requires input files..

  if [ $DO_CONTRACTION -eq 1 ]; then
    # create jobscript header for contraction
    if [ ${DEBUG} -ne 0 ]; then
      echo "Creating header for contraction"
    fi
    cp contraction.header.template contraction.header.template.tmp
    sed -i "s/bg_size=/bg_size=${CONTRACTIONS_BG_SIZE}/g" contraction.header.template.tmp
    sed -i "s/wall_clock_limit=/wall_clock_limit=${CONTRACTIONS_WC_LIMIT}/g" contraction.header.template.tmp
    # if there were no inversions then $contraction_dependencies is empty, but this is not a problem!
    # LoadLeveler still knows how to deal with the job 
    sed -i "s/dependency=/dependency=\ ${contraction_dependencies}/g" contraction.header.template.tmp
    cat contraction.header.template.tmp >> ${jcf}
    rm contraction.header.template.tmp

    echo "contraction )" >> job.body.tmp
    for c4num in ${confs_in_bunch4}; do
      source_ts=`ls ${SOURCEDIR}/source.${c4num}.??.00 | awk -F '/' '{print $NF}' | cut -d '.' -f 3`
      echo "Source Timeslice for conf ${c4num}: ${source_ts}"

      ## contraction job template and input file
      # contraction input file
      if [ ${DEBUG} -ne 0 ]; then
        echo "Creating input file for contraction ${c4num}"
      fi
      cvc_ifile=${IDIR}/cvc.${c4num}.input
      cp cvc.input.template ${cvc_ifile}

      sed -i "s/_NC/${c4num}/g" ${cvc_ifile}
      sed -i "s/_TS/${source_ts}/g" ${cvc_ifile}

      # contraction job body
      if [ ${DEBUG} -ne 0 ]; then
        echo "Creating job body for contraction"
      fi
      cp contraction.job.template contraction.job.template.tmp

      sed -i "s@IFILE=@IFILE=${cvc_ifile}@g" contraction.job.template.tmp
      sed -i "s@ODIR=@ODIR=${ODIR}@g" contraction.job.template.tmp
      sed -i "s@WDIR=@WDIR=${WDIR}@g" contraction.job.template.tmp
      sed -i "s@OUTPUTID=@OUTPUTID=${c4num}@g" contraction.job.template.tmp

      cat contraction.job.template.tmp >> job.body.tmp
      rm contraction.job.template.tmp
    done # loop over configurations in bunch

    # finish up contraction job body
    echo '  date' >> job.body.tmp
    echo '  cp -v ${OFILE} ${ODIR}/${LOADL_STEP_NAME}.${OUTPUTID}.out' >> job.body.tmp
    echo '  exit $RETVAL' >> job.body.tmp
    echo ';;' >> job.body.tmp
  
  fi # DO_CONTRACTION

  # attach common portion to job command file, including case statement
  cat common.job.template >> ${jcf}
  # attach concatenation of job bodies
  cat job.body.tmp >> ${jcf}
  rm job.body.tmp
  echo >> ${jcf}
  echo esac >> ${jcf}

done # loop over configurations
