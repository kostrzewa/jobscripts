#! /bin/sh

# seed the shell RNG from the PID
# the random number generator is required to select the pax nodes
# for small jobs according to the policy established in mid 2014
RANDOM=$$

##############################################################################################
################################ START OF CONFIGURATION ######################################
##############################################################################################

DEBUG=1

# subdirectory in output and jobscript directory
SD="ndcloverrat_211"
TEMPLATE="jobtemplate_ndcloverrat.sh"
EDIR="/afs/ifh.de/user/k/kostrzew/execs/pax/tmLQCD/hmc_tm_icc_openmpi_lemon"
#EDIR="/afs/ifh.de/user/k/kostrzew/execs/pax/tmLQCD/hmc_tm_swallbug"
BASEDIR="/lustre/fs17/group/etmc/${USER}/highstat/${SD}"

# table with reference time measurements for different runs of the various samples
# in columns and the various executables in rows
# note that the table colums must be ordered as the SAMPLES variable
# the rows can be in any order
REFTFILE="runtimes_211_ndcloverrat.csv"
#REFTFILE="runtimes_mpihmc3478.cvs"

# a ratio REFMEAS = 100 means that the times in ${REFTFILE}
# refer to timings of runs with 100 trajectories
NMEAS=10000
REFMEAS=900

# set the random_seed variable in the hmc
SEED=123456
# ranlux luxury level 1 or 2
RLXDLEVEL=2
# reproduce random numbers flag should be "yes" because we want the runs
# to be maximally correlated, even if it is quite a bit slower
REPRO="no"

# whether to compute correlators or not (increases runtime by ~10%)
CORRELATORS=0

# the samples should be named such that if any two samples share a part entirely enclosed in or preceded by
# underscores, such as _tmcloverdet or _ndclover, all further qualifications of this sample
# should be written IN FRONT of this shared part
#   e.g. : hmc_tmcloverdet   and   hmc_nocsw_tmcloverdet
#                             note the   ^  "nocsw" here in FRONT of the common tmcloverdet 

# SAMPLES="hmc0 hmc1 hmc2 hmc3 hmc_ndclover hmc_nosplit_ndclover hmc_nocsw_ndclover \
#          hmc_nosplit_nocsw_ndclover hmc_cloverdet hmc_tmcloverdet hmc_check_ndclover_tmcloverdet\
#          hmc_check_ndclover_nocsw_tmcloverdet hmc_tmcloverdetratio"
#EXECS="serial openmp 1D_hybrid_hs_2 2D_hybrid_hs_4 4D_hybrid_hs_16  2D_MPI_hs_16 3D_MPI_hs_8 3D_MPI_hs_16 3D_MPI_hs_32 3D_MPI_hs_64 4D_MPI_hs_16 4D_MPI_hs_32 4D_MPI_hs_64 4D_MPI_hs_128 4D_MPI_hs_256"

SAMPLES="L16T32_ndcloverrat_211_12"
#SAMPLES="L16T32_ndcloverrat_211_9_tight"
#EXECS="openmp 1D_hybrid_hs_4_2 1D_hybrid_hs_2_4 3D_MPI_hs_32"

#SAMPLES="mpihmc4"
EXECS="4D_MPI_hs_256"

##############################################################################################
################################# END OF CONFIGURATION #######################################
##############################################################################################

ODIR="${BASEDIR}/output"
IDIR="${BASEDIR}/inputfiles"
ITOPDIR="${BASEDIR}/inputfiles"
TIDIR="templates"
JDIR="${BASEDIR}/jobscripts"
JFILE=""

# job lengths are either 1, 2, 5, ... or 47 hours
JOBLENGTHPARTITIONS="1 2 5 8 11 14 17 20 23 26 29 32 35 38 41 44 47"
# the maximum job length that should be aimed for, taking this below 24 hours
# is good for throughput
MAXJOBLENGTH=47

# read names of columns in reference table and prepend a "ref" to each
TREFSAMPLES=`head -n1 ${REFTFILE}`
for i in ${TREFSAMPLES}; do
  REFSAMPLES="${REFSAMPLES} ref${i}"
done

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
# $9 AN (addon, such as "3D_MPI_hs_32")
# $10 SD (subdir in output directory, e.g. highstat3)
# $11 ST (state, "c" or "s" for continue or start)
# $12 NP (no parallel environment, 0 for parallel jobs or 1 for serial jobs)
# $13 NC (number of continue script)
# $14 EX (executable)
# $15 NT (number of threads)
create_script ()
{
  if [ ${DEBUG} -eq 1 ]; then
    echo -e "create_script called with \n template file ${1} \n \
destination ${2} \n H_RT ${3} \n S_RT ${4} \n QUEUE ${5} \n \
NCORES ${6} \n NP ${7} \n BN ${8} \n AN ${9} \n SD ${10} \n \
ST ${11} \n NP ${12} \n NC ${13} \n EX ${14} \n NT ${15}"
  fi

  if [[ ! -d ${JDIR}/${9} ]]; then
    mkdir -p ${JDIR}/${9}
  fi

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
  sed -i "s/OMP_NUM_THREADS=NT/OMP_NUM_THREADS=${15}/g" ${2}

  # need to escape slashes for passing to sed
  IN='\/'
  OUT='\\\/'

  TEMP=`echo ${ODIR}|sed "s/${IN}/${OUT}/g"`
  sed -i "s/ODIR=OD/ODIR=${TEMP}\/${BN}_${AN}/g" ${2}

  TEMP=`echo ${EDIR}|sed "s/${IN}/${OUT}/g"`
  sed -i "s/EFILE=EF/EFILE=${TEMP}\/${14}/g" ${2}

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
# $3 physical situation (sample) name
# $4 executable type (openmp, mpi, hybrid etc..)
# $5 how many measurements to do in this run
# $6 ompnumthreads for openmp
create_input ()
{ 
  if [ ${DEBUG} -eq 1 ]; then
    echo -e "create_input called with \n \
STATE ${1} \n \
NC ${2} \n \
NAME ${3} \n \
EX ${4} \n \
NMEAS ${5} \n \
OMPNUMTHREADS ${6}"
  fi
  TINPUT="${TIDIR}/${3}.input"
  TEMP="/tmp/${USER}Xo321sdTEMP"

  # input files for continuation jobs are prefixed with "cN" where N is the nubmer of the job
  # while for starting jobs the prefix will be s 
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

  # define the various parallelizations in the input file
  case ${4} in
    4D_MPI*_256)
      echo -e "NrXProcs=4\nNrYProcs=4\nNrZProcs=4\n"|cat - ${INPUT} > ${TEMP}
      cp ${TEMP} ${INPUT}
    ;;
    4D_MPI*_128)
      echo -e "NrXProcs=2\nNrYProcs=4\nNrZProcs=4\n"|cat - ${INPUT} > ${TEMP}
      cp ${TEMP} ${INPUT}
    ;;
    4D_MPI*_64)
      echo -e "NrXProcs=4\nNrYProcs=2\nNrZProcs=4\n"|cat - ${INPUT} > ${TEMP}
      cp ${TEMP} ${INPUT}
    ;;
    4D_MPI*_32)
      echo -e "NrXProcs=2\nNrYProcs=4\nNrZProcs=2\n"|cat - ${INPUT} > ${TEMP}
      cp ${TEMP} ${INPUT}
    ;; 
    3D_MPI*_16)
      echo -e "NrXProcs=4\nNrYProcs=2\nNrZProcs=1\n"|cat - ${INPUT} > ${TEMP}
      cp ${TEMP} ${INPUT}
    ;;
    3D_MPI*_32)
      echo -e "NrXProcs=4\nNrYProcs=4\nNrZProcs=1\n"|cat - ${INPUT} > ${TEMP}
      cp ${TEMP} ${INPUT}
    ;;
    3D_MPI*_64)        
      echo -e "NrXProcs=4\nNrYProcs=4\nNrZProcs=1\n"|cat - ${INPUT} > ${TEMP}
      cp ${TEMP} ${INPUT}
    ;;
    2D_MPI*_16)
      echo -e "NrXProcs=4\nNrYProcs=1\nNrZProcs=1\n"|cat - ${INPUT} > ${TEMP}
      cp ${TEMP} ${INPUT}
    ;;
    4D_MPI*_16)
      echo -e "NrXProcs=2\nNrYProcs=2\nNrZProcs=2\n"|cat - ${INPUT} > ${TEMP}
      cp ${TEMP} ${INPUT} 
    ;;
    3D_MPI*_8)
      echo -e "NrXProcs=2\nNrYProcs=2\nNrZProcs=1\n"|cat - ${INPUT} > ${TEMP}
      cp ${TEMP} ${INPUT}
    ;;
    1D_hybrid*)
    # prepend hybrid threads
      echo -e "ompnumthreads=${6}\n"|cat - ${INPUT} > ${TEMP}
      cp ${TEMP} ${INPUT} 
    ;;
    2D_hybrid*_4)
    # prepend hybrid threads and 2D parallelization
      echo -e "NrXProcs=2\nNrYProcs=1\nNrZProcs=1\nompnumthreads=${6}"|cat - ${INPUT} > ${TEMP}
      cp ${TEMP} ${INPUT} 
    ;;
    4D_hybrid*_16)
    # prepend hybrid threads and 4D parallelization
      echo -e "NrXProcs=2\nNrYProcs=2\nNrZProcs=2\nompnumthreads=${6}"|cat - ${INPUT} > ${TEMP}
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

  if [[ "${1}" = "s" ]]; then
    # we currently only support hot starts
    case ${2} in
      *)
        sed -i 's/startcondition=S/startcondition=hot/g' ${INPUT}
      ;;
    esac
    sed -i "s/initialstorecounter=I/initialstorecounter=0/g" ${INPUT}
    sed -i "s/seed=S/seed=${SEED}/g" ${INPUT}
  else
    sed -i "s/startcondition=S/startcondition=continue/g" ${INPUT}
    sed -i "s/initialstorecounter=I/initialstorecounter=readin/g" ${INPUT}
    # these runs are set up such that the state of the RNG of process 0
    # is stored at the end of each trajectory
    # if we are using the reproducible random numbers mode
    # we can initialize the RNG from this state and have reproducibility across
    # multiple executions 
    if [[ "${REPRO}" == "yes" ]]; then
      sed -i "s/seed=S/seed=statefile/g" ${INPUT}
    else 
      sed -i "s/seed=S/seed=${SEED}/g" ${INPUT}
    fi
  fi

  sed -i "s/ranluxdlevel=L/ranluxdlevel=${RLXDLEVEL}/g" ${INPUT}
  sed -i "s/reproducerandomnumbers=R/reproducerandomnumbers=${REPRO}/g" ${INPUT}

  sed -i "s/measurements=N/measurements=${5}/g" ${INPUT}

  # when doing the correlators measurement we need to add the line to the input file
  if [[ ${CORRELATORS} -eq 1 ]]; then
    echo -e "\nBeginMeasurement CORRELATORS\n  Frequency = 10\nEndMeasurement\n" >> ${INPUT}
  fi
}

# $1 total expected runtime
calc_joblimit ()
{
  if [ ${DEBUG} -eq 1 ]; then 
    echo "calc_joblimit called with JOBLENGTH ${1}"
  fi
  # determine correct job length
  export JOBLIMIT=0
  for t in ${JOBLENGTHPARTITIONS}; do
    # if the current joblength is longer than the maximum specified above, abort
    if [[ $t -gt ${MAXJOBLENGTH} ]]; then
      break
    fi
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
  if [ ${DEBUG} -eq 1 ]; then

    echo -e "calc_nmeas_part called with \n \
TOTALTIME ${1} \n \
JOBLIMIT ${2} \n \
NMEAS ${3}"
  fi
  export NMEAS_PART=`echo "scale=6;a=${1};b=${2};r=(b/a)*${3};r"|bc`
  export NMEAS_PART=`echo "(${NMEAS_PART}+0.5)/1"|bc`
  if [[ ${NMEAS_PART} -eq 0 ]]; then
    export NMEAS_PART=1
  fi

  if [[ ${DEBUG} -eq 1 ]]; then
    echo "NMEAS_PART = ${NMEAS_PART}"
  fi
}

# extract hard and soft realtime limits from an integer maximum
# job time such as "15" (in that case H_RT=14:59:00)
convert_time ()
{
  if [ ${DEBUG} -eq 1 ]; then
    echo "convert_time called with T ${1}"
  fi
  let T=${1}

  # if the number is a single digit, prepend a zero 
  if [[ ${#T} -eq 1 ]]; then
    T="0"${T}
  fi

  export H_RT=${T}:59:00
  export S_RT=${T}:55:00 
}

# we need to abide by the local rules regarding the scheduling of jobs
# on different partitions of the pax cluster
# jobs between 8 and 32 processes go on pax1-4
# jobs with 64 processes go on pax5-7
# jobs with 128 processes go on pax9
# jobs with 256 processes go on pax9 only
# we need to choose randomly between the different possibilities for
# each job script that we create to minimize competition
select_pax_blade()
{
  if [ ${DEBUG} -eq 1 ]; then
    echo "select_pax_blade called with TYPE ${1}"
  fi
  case ${1} in
    *openmp*)
      n=$(( (RANDOM % 4) + 1 ))
      export QUEUE="pax${n}"
    ;;
    *hybrid*_[2,4])
      n=$(( (RANDOM % 4) + 1 ))
      export QUEUE="pax${n}"
    ;;
    *MPI*_8)
      n=$(( (RANDOM % 4) + 1 ))
      export QUEUE="pax${n}"
    ;;
    *MPI*_16)
      n=$(( (RANDOM % 4) + 1 ))
      export QUEUE="pax${n}"
    ;;
    *MPI*_32)
      n=$(( (RANDOM % 4) + 1 ))
      export QUEUE="pax${n}"
    ;;
    *MPI*_64)
      n=$(( (RANDOM % 3) + 5 ))
      export QUEUE="pax${n}"
    ;;
    *hybrid*_16)
      n=$(( (RANDOM % 3) + 5 ))
      export QUEUE="pax${n}"
    ;;
    *MPI*_128)
      #n=$(( RANDOM % 2 )) 
      #if [ ${n} -eq 1 ]; then
      export QUEUE="pax9"
      #else
      #  n=$(( (RANDOM % 3) + 5 ))
      #  export QUEUE="pax${n}"            
      #fi
    ;;
    *MPI*_256)
      export QUEUE="pax9"
    ;;
  esac
}

##############################
# main part of the generator # 
##############################

for e in ${EXECS}; do

  export AN=${e}
  # remove the numers at the end of the executable name 
  export EF=`echo ${e} | sed 's/[_[0-9]*]*$//g'` 
 
  # no parallel environment leads to the deletion of the -pe line in the jobscript template
  export NOPE=0 
  export NCORES=8
  export OMPNUMTHREADS=1
  export QUEUE="NONE"
  export NP=1

  # set some job parameters for which the executable type is important

  case ${e} in
    *MPI*_8)
      export NP=8
      export NCORES=8
    ;;
    *MPI*_16)
      export NP=16
      export NCORES=16
    ;;
    *MPI*_32)
      export NP=32
      export NCORES=32
    ;;
    *MPI*_64)
      export NP=64
      export NCORES=64
    ;;
    *MPI*_128)
      export NP=128
      export NCORES=128
    ;;
    *MPI*_256)
      export NP=256
      export NCORES=256
    ;;
    *hybrid*_2_4)
      export NP=4
      export OMPNUMTHREADS=2
      export NCORES=8
    ;;
    *hybrid*_4_2)
      export NP=2
      export OMPNUMTHREADS=4
      export NCORES=8
    ;;
    *hybrid*_16)
      export NP=16
      export OMPNUMTHREADS=4
      export NCORES=64
    ;;
    *openmp*)
      export OMPNUMTHREADS=8
    ;;
    *serial*)
      export NOPE=1
      export NCORES=1
    ;;
  esac

  for s in ${SAMPLES}; do

    export BN=${s}

    echo
    echo "Making a script for" ${e} ${s}
   
    # read table of reference times ${REFTFILE} 
    # SAMPLES will be the names of the indirect variables of the while loop
    # ${!s} is a variable with the variable name set to the sample currently
    # being processed, it thus corresponds to e.g. hmc0 and ${!s} is $hmc0
    # which therefore references the relevant column in the table
    headerflag=0
    foundreftime=0
    while read name ${REFSAMPLES}; do
      # skip the header
      if [[ $headerflag -eq 0 ]]; then
        let headerflag=1
        continue
      fi

      if [[ ${name} = ${e} ]]; then
        for i in ${REFSAMPLES}; do
          if [[ ${i} = "ref"${s} ]]; then
            foundreftime=1
            TIME=${!i}
            if [[ $DEBUG -eq 1 ]]; then
              echo "For ${s} with ${e} ${REFMEAS} iterations take ${TIME} hours."
            fi
            # break out of for loop as we've matched the reference measurement to the current sample
            break
          fi
        done
      fi
      # when the correct reference time has been found, break out of the while loop 
      if [[ $foundreftime -eq 1 ]]; then
        break
      fi
    done < ${REFTFILE}

    if [[ $foundreftime -eq 0 ]]; then
      echo "##### No reference time found for ${e} run of ${s}! Assuming default of 2 hours!"
      TIME=2
    fi

    # the time measurements in the table ${REFTFILE} refer to REFMEAS trajectories
    # calculate the total runtime from the ratio NMEAS/REFMEAS
    # when correlators are being measured we need about 10% more time
    # the factor of 1.5 (or 1.5+0.1=1.6) is to account for performance flucutations
    NTIMES=`echo "scale=6;${NMEAS}/${REFMEAS}"|bc`
    if [[ ${CORRELATORS} -eq 1 ]]; then 
      TOTALTIME=`echo "scale=6;1.1*${NTIMES}*${TIME}"| bc`
    else
      TOTALTIME=`echo "scale=6;1.05*${NTIMES}*${TIME}"| bc`
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
          # choose the correct queue with random distribution across equivalent queues
          select_pax_blade ${e}
          convert_time ${JOBLIMIT}
          create_input ${ST} ${j} ${s} ${e} ${NMEAS_PART} ${OMPNUMTHREADS} 
          create_script ${TEMPLATE} ${JFILE} ${H_RT} ${S_RT} ${QUEUE} ${NCORES} ${NP} ${BN} ${AN} ${SD} ${ST} ${NOPE} ${i} ${EF} ${OMPNUMTHREADS}
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
        # choose the correct queue with random distribution across equivalent queues   
        select_pax_blade ${e}
        convert_time ${JOBLIMIT} # writes H_RT and S_RT
        create_input  ${ST} 0 ${s} ${e} ${NMEAS_PART} ${OMPNUMTHREADS}
        create_script ${TEMPLATE} ${JFILE} ${H_RT} ${S_RT} ${QUEUE} ${NCORES} ${NP} ${BN} ${AN} ${SD} ${ST} ${NOPE} 0 ${EF} ${OMPNUMTHREADS}
      fi
    done
  done
done    
