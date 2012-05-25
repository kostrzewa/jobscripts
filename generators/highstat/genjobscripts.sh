#! /bin/sh

TEMPLATE="jobtemplate.sh"
SAMPLES="hmc0 hmc1 hmc2 hmc3 hmc4 hmc_cloverdet hmc_tmcloverdet hmc_tmcloverdetratio"
EXECS="5.1.6_mpi 5.1.6_serial serial mpi openmp openmp_noreduct hybrid hybrid_noreduct"
EDIR="${HOME}/tmLQCD/execs/hmc_tm"
JDIR="${HOME}/jobscripts/highstat_test"
NMEAS=100000
NTIMES=1000

NCORES=8
MPIPROCS=8
HYBRIDPROCS=2

for e in ${EXECS}; do
  if [[ ! -d ${JDIR}/$e ]]; then
    mkdir ${JDIR}/$e
  fi

  for s in ${SAMPLES}; do
    SKIP=0
    case ${s} in
      *clover*):
        case ${e} in
          *5.1.6*) :
            SKIP=1
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
        if [[ $name = $e ]]; then
          TIME=${!s}
        fi
      done < runtimes.csv
      
      TOTALTIME=`echo "${NTIMES} * ${TIME}"| bc`

      echo "Making a script for" ${e} ${s}
      echo $TIME $TOTALTIME

      # determine correct job length
      JOBLIMIT=0
      for t in 6 9 12 15 18 21 24 27 30 33 36 39 42 45 48; do
        if [[ $JOBLIMIT -eq 0 ]]; then
          if [[ `echo "a=$TOTALTIME;b=$t;r=0;if(a<b)r=1;r"|bc` -eq 1 ]]; then
            JOBLIMIT=$t
            echo "joblimit" $JOBLIMIT
          fi
        fi
      done

      # if the job does not fit into any of 12 24 48 hours
      # set logical variable that continue script is required
      # and set JOBLIMIT to maximum 
      NEEDCONTINUE=0
      if [[ $JOBLIMIT -eq 0 ]]; then
        NEEDCONTINUE=1
        JOBLIMIT=48
        echo "needcontinue"
      fi

      for state in "s" "c"; do
        if [[ $state = "c" ]] && [[ $NEEDCONTINUE -eq 0 ]]; then
          continue
        elif [[ $state = "c" ]] && [[ $NEEDCONTINUE -eq 1 ]]; then
          #compute number of partitions and write start and 
          echo "skipping"
        elif [[ $state = 's' ]]; then 
          JFILE="${JDIR}/${e}/${state}_${e}_${s}.sh"
          # cp ${TEMPLATE} 
        fi
      done
        

      #cp ${TEMPLATE} ${JDIR}/${STATE}${BASENAME}${ADDON}.sh
    fi

  done
done    
