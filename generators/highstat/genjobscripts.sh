#! /bin/sh

DEBUG=1

# subdirectory in output and jobscript directory
SD="highstat_csw_full_06"

TEMPLATE="jobtemplate.sh"

# the samples should be named such that if any two samples share a part entirely enclosed in or preceded by
# underscores, such as _tmcloverdet or _ndclover, all further qualifications of this sample
# should be written in front of this shared part
#   e.g. : hmc_tmcloverdet   and   hmc_nocsw_tmcloverdet 
SAMPLES="hmc0 hmc1 hmc2 hmc3 hmc_ndclover hmc_nosplit_ndclover hmc_nocsw_ndclover \
          hmc_nosplit_nocsw_ndclover hmc_cloverdet hmc_tmcloverdet hmc_check_ndclover_tmcloverdet\
          hmc_check_ndclover_nocsw_tmcloverdet hmc_tmcloverdetratio"
EXECS="serial mpi_hs 4D_MPI_hs openmp hybrid_hs"
ODIR="/lustre/fs4/group/etmc/kostrzew/output/${SD}"
EDIR="${HOME}/tmLQCD/execs/hmc_tm_csw"
IDIR="${HOME}/tmLQCD/inputfiles/highstat/${SD}"
ITOPDIR="${HOME}/tmLQCD/inputfiles"
TIDIR="templates"
JDIR="${HOME}/jobscripts/${SD}"
JFILE=""

# table with reference time measurements for different runs of the various samples
# in columns and the various executables in rows
# note that the table colums must be ordered as the SAMPLES variable
# the rows can be in any order
REFTFILE="runtimes_csw.csv"

# PAX=1 -> use the pax cluster to run!
# all hybrid and openmp jobs will be sent to the "pax-2ppn" queue
# note that serial jobs will have to be submitted separately
# in the default farm
# mpi jobs always run on pax
PAX=1

JOBLENGTHPARTITIONS="1 2 5 8 11 14 17 20 23 26 29 32 35 38 41 44 47"
MAXJOBLENGTH=47

# whether to compute correlators or not (increases runtime by ~10%)
CORRELATORS=1

# a ratio REFMEAS = 100 means that the times in ${REFTFILE}
# refer to timings of runs with 100 trajectories
NMEAS=400000
REFMEAS=1000

# set the random_seed variable in the hmc
SEED=123123

if [[ ! -d ${IDIR} ]]; then
  mkdir -p ${IDIR}
fi

if [[ ! -d ${JDIR} ]]; then
  mkdir -p ${JDIR}
fi

# this function does the heavy lifting and creates the jobscript
# from a template file, editing it inline using sed as required
# $1 template file
# $2 destination
# $3 H_RT
# $4 S_RT
# $5 QUEUE
# $6 NCORES
# $7 NP (number of mpi processes)
# $8 BN (basename, such as "hmc0")
# $9 AN (addon, such as "hybrid_noreduct")
# $10 SD (subdir in output directory, e.g. highstat3)
# $11 ST (state, "c" or "s" for continue or start)
# $12 NP (no parallel environment, 0 or 1)
# $13 NC (number of continue script)
create_script ()
{
  if [[ ${DEBUG} -eq 1 ]]; then
    echo "CREATE_SCRIPT copying ${1} to ${2}"
  fi
  cp ${1} ${2}
  sed -i "s/H_RT/${3}/g" ${2}
  sed -i "s/S_RT/${4}/g" ${2}
  
  # remove the paralell environment when NOPE = 1 (e.g. serial jobs)
  if [[ ${12} -eq 1 ]]; then
    sed -i "s/#$ -pe QUEUE NCORES//g" ${2}
  else 
    sed -i "s/QUEUE/${5}/g" ${2}
    sed -i "s/NCORES/${6}/g" ${2}
  fi

  sed -i "s/NPROCS=NP/NPROCS=${7}/g" ${2}
  sed -i "s/BASENAME=BN/BASENAME=${8}/g" ${2}
  sed -i "s/ADDON=AN/ADDON=${9}/g" ${2}
  sed -i "s/SUBDIR=SD/SUBDIR=${10}/g" ${2}
  sed -i "s/STATE=ST/STATE=${11}/g" ${2}

  # need to escape slashes for passing to sed
  IN='\/'
  OUT='\\\/'

  TEMP=`echo ${ODIR}|sed "s/${IN}/${OUT}/g"`
  sed -i "s/ODIR=OD/ODIR=${TEMP}\/${BN}_${AN}/g" ${2}

  TEMP=`echo ${EDIR}|sed "s/${IN}/${OUT}/g"`
  sed -i "s/EFILE=EF/EFILE=${TEMP}\/${9}/g" ${2}

  NCONT=""
  if [[ ${11} = "c" ]]; then
    export NCONT=${13}
    if [[ $NCONT -le 9 ]]; then 
      export PREFIX="${11}0${13}"
    else
      export PREFIX=${11}${13}
    fi
  else
    export PREFIX=${11}
  fi
  sed -i "s/NCONT=NC/NCONT=${NCONT}/g" ${2}

  TEMP=`echo ${IDIR}|sed "s/${IN}/${OUT}/g"`
  sed -i "s/IFILE=IF/IFILE=${TEMP}\/${9}\/${PREFIX}_${8}_${9}.input/g" ${2}

  TEMP=`echo ${ITOPDIR}|sed "s/${IN}/${OUT}/g"`
  sed -i "s/ITOPDIR=ITD/ITOPDIR=${TEMP}/g" ${2}
}

# create input file from a given reference input
# $1 state
# $2 number of file if state = c
# $3 sample name
# $4 executable type (openmp, mpi, hybrid etc..)
# $5 how many measurements to do in this run
# $6 ompnumthreads for openmp
create_input ()
{
  TINPUT="${TIDIR}/sample-${3}.input"
  TEMP="/tmp/Xo321sdTEMP"

  # when we continue we set InitialStoreCounter to a random number
  # to make sure we don't repeat the sequence ofrandom numbers
  if [[ ${1} = "c" ]]; then
    export PREFIX=${1}${2}
  else
    export PREFIX=${1}
  fi

  if [[ ! -d "${IDIR}/${4}" ]]; then
    mkdir "${IDIR}/${4}"
  fi

  INPUT="${IDIR}/${4}/${PREFIX}_${3}_${4}.input"

  if [[ ${DEBUG} -eq 1 ]]; then
    echo "CREATE_INPUT copying ${TINPUT} to ${INPUT}"
  fi

  cp ${TINPUT} ${INPUT} 
 
  case ${4} in
    *4D_MPI*)
      echo -e "NrXProcs=2\nNrYProcs=2\nNrZProcs=2\n"|cat - ${INPUT} > ${TEMP}
      cp ${TEMP} ${INPUT}
    ;; 
    *mpi*)
      # prepend mpi stuff
      echo -e "NrXProcs=2\nNrYProcs=2\nNrZProcs=1\n"|cat - ${INPUT} > ${TEMP}
      cp ${TEMP} ${INPUT}
    ;;
    *hybrid*)
    # prepend hybrid stuff
      echo -e "ompnumthreads=${6}\n"|cat - ${INPUT} > ${TEMP}
      cp ${TEMP} ${INPUT} 
    ;;
    *openmp*)
      # prepend openmp stuff
      echo -e "ompnumthreads=${6}\n"|cat - ${INPUT} > ${TEMP}
      cp ${TEMP} ${INPUT} 
    ;;
    *serial*)
      # no-op
    ;;
  esac

  if [[ ${1} = "s" ]]; then
    case ${2} in
      *hmc4*)
        sed -i 's/startcondition=S/startcondition=cold/g' ${INPUT}
      ;;
      *)
        sed -i 's/startcondition=S/startcondition=hot/g' ${INPUT}
      ;;
    esac
    sed -i "s/seed=D/seed=${SEED}/g" ${INPUT}
    sed -i "s/initialstorecounter=I/initialstorecounter=0/g" ${INPUT}
  else
    # when we continue we read in InitialStoreCounter
    # and set the seed to the same value it was set for the beginning of the run
    # InitialStoreCounter makes sure that the seed that is actually used will
    # not be the one set here but one modified by nstore
    sed -i "s/seed=D/seed=${SEED}/g" ${INPUT}
    sed -i "s/startcondition=S/startcondition=continue/g" ${INPUT}
    sed -i "s/initialstorecounter=I/initialstorecounter=readin/g" ${INPUT}
  fi

  sed -i "s/measurements=N/measurements=${5}/g" ${INPUT}

  # when doing the correlators measurement we need to add the line to the input file
  if [[ ${CORRELATORS} -eq 1 ]]; then
    echo -e "\nBeginMeasurement CORRELATORS\n  Frequency = 4\nEndMeasurement\n" >> ${INPUT}
  fi
}

# $1 total expected runtime
calc_joblimit ()
{
  # determine correct job length
  export JOBLIMIT=0
  for t in ${JOBLENGTHPARTITIONS}; do
    if [[ $JOBLIMIT -eq 0 ]]; then
      # add a buffer of one hour to make sure that the job runs through
      if [[ `echo "scale=6;a=$1+1;b=$t;r=0;if(a<b)r=1;r"|bc` -eq 1 ]]; then
        export JOBLIMIT=$t
        if [[ ${DEBUG} -eq 1 ]]; then
          echo "CALC_JOBLIMIT joblimit = " $JOBLIMIT
        fi  
      fi
    else
      break
    fi
  done
}

# calculate how many measurements should be done in this run
# $1 total runtime (TOTALTIME)
# $2 calculated JOBLIMIT or remaining time if this is the final part
# $3 total number of measurements to be done (NMEAS)
calc_nmeas_part ()
{
  export NMEAS_PART=`echo "scale=6;a=${1};b=${2};r=(b/a)*${3};r"|bc`
  export NMEAS_PART=`echo "(${NMEAS_PART}+0.5)/1"|bc`

  if [[ ${DEBUG} -eq 1 ]]; then
    echo "NMEAS_PART = ${NMEAS_PART}"
  fi
}

# extract hard and soft realtime limits from an integer maximum
# job time such as "15" (in that case H_RT=14:59:00)
convert_time ()
{
  let T=${1}

  # if the number is a single digit, prepend a zero 
  if [[ ${#T} -eq 1 ]]; then
    T="0"${T}
  fi

  export H_RT=${T}:59:00
  export S_RT=${T}:55:00 
}


##############################
# main part of the generator # 
##############################

for e in ${EXECS}; do

  export AN=${e}
 
  # no parallel environment leads to the deletion of the -pe line in the jobscript template
  export NOPE=0 
  export NCORES=8
  export OMPNUMTHREADS=1
  export QUEUE=""
  export NP=1

  if [[ ${PAX} -eq 1 ]]; then
    export QUEUE="pax"
  fi

  # set some job parameters for which the executable type is important
  case ${e} in
    *hybrid*)
      if [[ ! ${PAX} -eq 1 ]]; then
        export QUEUE="multicore-mpi"
      else
        export QUEUE="pax-2ppn" # use the new pax-2ppn queue for hybrid and openmp
      fi
      export NP=2
      export OMPNUMTHREADS=4
    ;;
    *4D_MPI*)
      export QUEUE="pax"
      export NP=16
      export NCORES=16
    ;;  
    *mpi*)
      export QUEUE="pax"   
      export NP=8
    ;;
    *openmp*)
      if [[ ! ${PAX} -eq 1 ]]; then
        export QUEUE="multicore"
      else
        export QUEUE="pax-2ppn" # use the new pax-2ppn queue for hybrid and openmp
      fi
      export OMPNUMTHREADS=8
    ;;
    *serial*)
      export NOPE=1
      export NCORES=1
    ;;
  esac

  if [[ ! -d ${JDIR}/${e} ]]; then
    mkdir ${JDIR}/${e}
  fi

  for s in ${SAMPLES}; do
    
    export BN=${s}

    case ${s} in
      # no clover term implemented in 5.1.6 so we skip the generation of
      # those jobscripts
      *clover*)
        case ${e} in
          *5.1.6*)
            continue 
          ;;
        esac
      ;;
    esac
    
    echo
    echo "Making a script for" ${e} ${s}
   
    # read table of reference times ${REFTFILE} 
    # SAMPLES will be the names of the indirect variables of the while loop
    # ${!s} is a variable with the variable name set to the sample currently
    # being processed, it thus corresponds to e.g. hmc0 and ${!s} is $hmc0
    # which therefore references the relevant column in the table
    # note that the table colums must be ordered as the SAMPLES variable
    # the rows can be in any order
    headerflag=0
    while read name ${SAMPLES}; do
      # skip the header
      if [[ $headerflag -eq 0 ]]; then
        let headerflag=1
        continue
      fi

      if [[ ${name} = ${e} ]]; then
        TIME=${!s}
        if [[ $DEBUG -eq 1 ]]; then
          echo "For ${s} with ${e} ${REFMEAS} iterations take ${TIME} hours."
        fi
        break
      fi
    done < ${REFTFILE}

    # the time measurements in the table ${REFTFILE} refer to REFMEAS trajectories
    # calculate the total runtime from the ratio NMEAS/REFMEAS
    # when correlators are being measured we need about 10% more time
    NTIMES=`echo "scale=6;${NMEAS}/${REFMEAS}"|bc`
    if [[ ${CORRELATORS} -eq 1 ]]; then 
      TOTALTIME=`echo "scale=6;1.1 * ${NTIMES} * ${TIME}"| bc`
    else
      TOTALTIME=`echo "scale=6;${NTIMES} * ${TIME}"| bc`
    fi

    # determine correct job length
    calc_joblimit ${TOTALTIME}

    # if the job does not fit into any of ${JOBLENGTHPARTITIONS} hours
    # (calc_joblimit will keep JOBLIMIT=0 )
    # set logical variable that continue script is required
    # and set JOBLIMIT to maximum 
    export NEEDCONTINUE=0
    if [[ $JOBLIMIT -eq 0 ]]; then
      export NEEDCONTINUE=1
      export JOBLIMIT=${MAXJOBLENGTH}
      if [[ ${DEBUG} -eq 1 ]]; then
        echo "needcontinue"
      fi
    fi
    
    # generate a sufficient number of jobscripts
    TIME=${TOTALTIME}
    for state in "s" "c"; do
      export ST=${state}
      if [[ $state = "c" ]] && [[ $NEEDCONTINUE -eq 0 ]]; then
        continue
      elif [[ $state = "c" ]] && [[ $NEEDCONTINUE -eq 1 ]]; then
        # compute number of continue scripts and write them
        # the scale variable must be set so that we can properly use
        # floating point numbers in bc
        export NPARTS=`echo "scale=6;a=${TOTALTIME};b=${MAXJOBLENGTH};r=a/b;r"|bc`
        export NPARTS=`echo "(${NPARTS}-0.5)/1"|bc`
        # loop over number of continue scripts and chop off 48 hours
        # from the total time in each iteration
        export i=1
        while [[ `echo "a=${TIME};r=1;if(a<0) r=0;r"|bc` -eq 1 ]]; do
          j="${i}"
          if [[ i -le 9 ]]; then
            j="0${j}"
          fi
          export JFILE="${JDIR}/${e}/${state}${j}_${s}_${e}_${SD}.sh"
          export JOBLIMIT=0
          calc_joblimit ${TIME}
          if [[ ${JOBLIMIT} -eq 0 ]]; then
            export JOBLIMIT=${MAXJOBLENGTH}
          fi 
          if [[ `echo "scale=6;a=${TIME};r=1;if(a<${MAXJOBLENGTH}) r=0;r"|bc` -eq 1 ]];then
            calc_nmeas_part ${TOTALTIME} ${JOBLIMIT} ${NMEAS}
          else
            calc_nmeas_part ${TOTALTIME} ${TIME} ${NMEAS}
          fi
          convert_time ${JOBLIMIT}
          create_input ${ST} ${j} ${s} ${e} ${NMEAS_PART} ${OMPNUMTHREADS} 
          create_script ${TEMPLATE} ${JFILE} ${H_RT} ${S_RT} ${QUEUE} ${NCORES} ${NP} ${BN} ${AN} ${SD} ${ST} ${NOPE} ${i}
          export TIME=`echo "scale=6;a=${TIME};b=${MAXJOBLENGTH};r=a-b;r"|bc`
          if [[ ${DEBUG} -eq 1 ]]; then
            echo "${TIME} remaining out of ${TOTALTIME}"
          fi 
          let i=${i}+1
        done
      elif [[ $state = "s" ]]; then
        export JFILE="${JDIR}/${e}/${state}_${s}_${e}_${SD}.sh"
        if [[ ${NEEDCONTINUE} -eq 1 ]]; then
          export TIME=`echo "scale=6;a=${TOTALTIME};b=${MAXJOBLENGTH};r=a-b;r"|bc`
          calc_nmeas_part ${TOTALTIME} ${JOBLIMIT} ${NMEAS}
        else
          export NMEAS_PART=${NMEAS}
        fi
        
        convert_time ${JOBLIMIT} # writes H_RT and S_RT
        create_input  ${ST} 0 ${s} ${e} ${NMEAS_PART} ${OMPNUMTHREADS}
        create_script ${TEMPLATE} ${JFILE} ${H_RT} ${S_RT} ${QUEUE} ${NCORES} ${NP} ${BN} ${AN} ${SD} ${ST} ${NOPE} 0
      fi
    done
  done
done    
