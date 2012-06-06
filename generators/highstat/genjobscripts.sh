#! /bin/sh

DEBUG=0

# subdirectory in output and jobscript directory
SD="highstat_test"

TEMPLATE="jobtemplate.sh"
SAMPLES="hmc0 hmc1 hmc2 hmc3 hmc4 hmc_cloverdet hmc_tmcloverdet hmc_tmcloverdetratio"
EXECS="5.1.6_mpi 5.1.6_serial serial mpi openmp openmp_noreduct hybrid hybrid_noreduct"
ODIR="/lustre/fs4/group/nic/kostrzew/output/${SD}"
EDIR="${HOME}/tmLQCD/execs/hmc_tm_new"
IDIR="${HOME}/tmLQCD/inputfiles/highstat/${SD}"
TIDIR="${HOME}/tmLQCD/inputfiles/highstat/templates"
JDIR="${HOME}/jobscripts/${SD}"
JFILE=""

if [[ ! -d ${IDIR} ]]; then
  mkdir ${IDIR}
fi

if [[ ! -d ${JDIR} ]]; then
  mkdir ${JDIR}
fi


# a ratio NMEAS/NTIMES = 100 means that the times in runtimes.dat
# refer to timings of runs with 100 trajectories
NMEAS=100000
NTIMES=1000

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

  IN='\/'
  OUT='\\\/'

  TEMP=`echo ${ODIR}|sed "s/${IN}/${OUT}/g"`
  sed -i "s/ODIR=OD/ODIR=${TEMP}/g" ${2}

  TEMP=`echo ${EDIR}|sed "s/${IN}/${OUT}/g"`
  sed -i "s/EFILE=EF/EFILE=${TEMP}\/${8}/g" ${2}

  NCONT=""
  if [[ ${11} = "c" ]]; then
    export NCONT=${13}
    export PREFIX=${11}${13}
  else
    export PREFIX=${11}
  fi
  sed -i "s/NCONT=NC/NCONT=${NCONT}/g" ${2}

  TEMP=`echo ${IDIR}|sed "s/${IN}/${OUT}/g"`
  sed -i "s/IFILE=IF/IFILE=${TEMP}\/${9}\/${PREFIX}_${8}_${9}.input/g" ${2}
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
  RAND=0
  TINPUT="${TIDIR}/sample-${3}.input"
  TEMP="/tmp/Xo321sdTEMP"

  # when we continue we set InitialStoreCounter to a random number
  # to make sure we don't repeat the sequence ofrandom numbers
  if [[ ${1} = "c" ]]; then
    export RAND=${RANDOM}
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
    *mpi*):
      # prepend mpi stuff
      echo -e "NrXProcs=2\nNrYProcs=2\nNrZProcs=2\n"|cat - ${INPUT} > ${TEMP}
      cp ${TEMP} ${INPUT}
    ;;
    *hybrid*):
      # prepend hybrid stuff
      echo -e "ompnumthreads=${6}\n"|cat - ${INPUT} > ${TEMP}
      cp ${TEMP} ${INPUT} 
    ;;
    *openmp*):
      # prepend openmp stuff
      echo -e "ompnumthreads=${6}\n"|cat - ${INPUT} > ${TEMP}
      cp ${TEMP} ${INPUT} 
    ;;
    *serial*):
      # no-op
    ;;
  esac

  if [[ ${1} = "s" ]]; then
    case ${2} in
      *hmc4*):
        sed -i 's/startcondition=S/startcondition=cold/g' ${INPUT}
      ;;
      *):
        sed -i 's/startcondition=S/startcondition=hot/g' ${INPUT}
      ;;
    esac

    sed -i 's/initialstorecounter=I/initialstorecounter=0/g' ${INPUT}
  else
    sed -i "s/initialstorecounter=I/initialstorecounter=${RAND}/g" ${INPUT}
    sed -i "s/startcondition=S/startcondition=continue/g" ${INPUT}
  fi

  sed -i "s/measurements=N/measurements=${5}/g" ${INPUT}
}

# $1 total expected runtime
calc_joblimit ()
{
  # determine correct job length
  export JOBLIMIT=0
  for t in 6 9 12 15 18 21 24 27 30 33 36 39 42 45 48; do
    if [[ $JOBLIMIT -eq 0 ]]; then
      if [[ `echo "scale=6;a=$1;b=$t;r=0;if(a<b)r=1;r"|bc` -eq 1 ]]; then
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
# $2 calculated JOBLIMIT
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
  let T=${1}-1

  # if the number is a single digit, prepend a zero 
  if [[ ${#T} -eq 1 ]]; then
    T="0"${T}
  fi

  export H_RT=${T}:59:00
  export S_RT=${T}:45:00 
}

for e in ${EXECS}; do

  export AN=${e}
 
  export NOPE=0 
  export NCORES=8
  export OMPNUMTHREADS=1
  export QUEUE="none"
  export NP=1
  # set some job parameters for which the executable type is important
  case ${e} in
    *hybrid*):
      export QUEUE="multicore-mpi"
      export NP=2
      export OMPNUMTHREADS=4
    ;;
    *mpi*):
      export QUEUE="mpi"
      export NP=8
    ;;
    *openmp*):
      export QUEUE="multicore"
      export OMPNUMTHREADS=8
    ;;
    *serial*):
      export NOPE=1
      export NCORES=1
    ;;
  esac

  if [[ ! -d ${JDIR}/${e} ]]; then
    mkdir ${JDIR}/${e}
  fi

  for s in ${SAMPLES}; do
    
    export BN=${s}

    SKIP=0
    case ${s} in
      # no clover term implemented in 5.1.6 so we skip the generation of
      # those jobscripts
      *clover*):
        case ${e} in
          *5.1.6*) :
            export SKIP=1
          ;;
        esac
      ;;
    esac
    
    if [[ ${SKIP} -ne 1 ]]; then
      # SAMPLES will be the names of the indirect variables of the while loop
      # ${!s} is a variable with the variable name set to the sample currently
      # being processed, it thus corresponds to e.g. hmc0 and ${!s} is $hmc0
      # which therefore references the relevant column in the table
      # runtimes.dat
      while read name ${SAMPLES}; do
        if [[ ${name} = ${e} ]]; then
          TIME=${!s}
        fi
      done < runtimes.dat
      
      TOTALTIME=`echo "scale=3;${NTIMES} * ${TIME}"| bc`

      echo "Making a script for" ${e} ${s}

      # determine correct job length
      calc_joblimit ${TOTALTIME}

      # if the job does not fit into any of 12 24 48 hours
      # set logical variable that continue script is required
      # and set JOBLIMIT to maximum 
      export NEEDCONTINUE=0
      if [[ $JOBLIMIT -eq 0 ]]; then
        export NEEDCONTINUE=1
        export JOBLIMIT=48
        if [[ ${DEBUG} -eq 1 ]]; then
          echo "needcontinue"
        fi
      fi

      TIME=${TOTALTIME}
      for state in "s" "c"; do
        export ST=${state}
        if [[ $state = "c" ]] && [[ $NEEDCONTINUE -eq 0 ]]; then
          continue
        elif [[ $state = "c" ]] && [[ $NEEDCONTINUE -eq 1 ]]; then
          # compute number of continue scripts and write them
          # the scale variable must be set so that we can properly use
          # floating point numbers in bc
          export NPARTS=`echo "scale=6;a=${TOTALTIME};b=48.0;r=a/b;r"|bc`
          export NPARTS=`echo "(${NPARTS}-0.5)/1"|bc`
          # loop over number of continue scripts and chop off 48 hours
          # from the total time in each iteration
          export i=1
          while [[ `echo "a=${TIME};r=1;if(a<0) r=0;r"|bc` -eq 1 ]]; do
             export JFILE="${JDIR}/${e}/${state}${i}_${e}_${s}.sh"
             export JOBLIMIT=0
             calc_joblimit ${TIME}
             if [[ ${JOBLIMIT} -eq 0 ]]; then
               export JOBLIMIT=48
             fi 
             if [[ `echo "scale=6;a=${TIME};r=1;if(a<48.0) r=0;r"|bc` -eq 1 ]];then
               calc_nmeas_part ${TOTALTIME} ${JOBLIMIT} ${NMEAS}
             else
               calc_nmeas_part ${TOTALTIME} ${TIME} ${NMEAS}
             fi
             convert_time ${JOBLIMIT}
             create_input ${ST} ${i} ${s} ${e} ${NMEAS_PART} ${OMPNUMTHREADS} 
             create_script ${TEMPLATE} ${JFILE} ${H_RT} ${S_RT} ${QUEUE} ${NCORES} ${NP} ${BN} ${AN} ${SD} ${ST} ${NOPE} ${i}
             export TIME=`echo "scale=6;a=${TIME};b=48.0;r=a-b;r"|bc`
             if [[ ${DEBUG} -eq 1 ]]; then
               echo "${TIME} remaining out of ${TOTALTIME}"
             fi 
             let i=${i}+1
          done
        elif [[ $state = "s" ]]; then
          export JFILE="${JDIR}/${e}/${state}_${e}_${s}.sh"
          if [[ ${NEEDCONTINUE} -eq 1 ]]; then
            export TIME=`echo "scale=6;a=${TOTALTIME};b=48.0;r=a-b;r"|bc`
            calc_nmeas_part ${TOTALTIME} ${JOBLIMIT} ${NMEAS}
          else
            export NMEAS_PART=${NMEAS}
          fi
          
          convert_time ${JOBLIMIT} # writes H_RT and S_RT
          create_input  ${ST} 0 ${s} ${e} ${NMEAS_PART} ${OMPNUMTHREADS}
          create_script ${TEMPLATE} ${JFILE} ${H_RT} ${S_RT} ${QUEUE} ${NCORES} ${NP} ${BN} ${AN} ${SD} ${ST} ${NOPE} 0
        fi
      done
    fi
  done
done    
