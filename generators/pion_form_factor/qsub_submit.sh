if [ -z "${1}" -o -z "${2}" -o -z "${3}" ]; then
 echo "usage: ./submit.sh <start> <step> <no> [co] [<initial jobid dependence>]"
 echo "[-co] contraction only"
 exit 1
fi

start=${1}
step=${2}
no=${3}

prefix=Z

if [ -z "$( ls ${prefix}* )" ]; then
  touch ${prefix}_xxxx
fi

no_of_chains=1

jobid=""
# if we submit 1 job, or we are doing contractions only,
# we submit with normal dependency rules
if [ $no -eq 1 -o "${4}" = "co" ]; then
  for i in $( seq ${start} ${step} $(( ${start} + (${no}-1)*${step} )) ); do 
    i4=$( printf %04d $i )
    if [ "${4}" != "co" ]; then
      if [ ! -z ${4} ]; then
        # if an initial dependency has been specified on the command line, job has to wait for this
        jobid=$( qsub -W depend=afterok:${4} invert.job.${i4}.cmd )
      else
        jobid=$( qsub invert.job.${i4}.cmd )
      fi
      # contraction always depends on inversion
      qsub -W depend=afterok:${jobid} cntr.job.${i4}.cmd
    else
      # only contraction jobs have been requested, no job dependencies
      qsub cntr.job.${i4}.cmd
    fi
    counter=$(( $counter + 1 ))
    mv ${prefix}_* ${prefix}_${i4}
  done
# if we have more jobs, we would like to generate several job chains to ensure that
# inversions only run after contractions have successfully deleted propagators, to
# make sure that we don't overflow the file-system
else
  # array holding the configuration numbers to be processed
  configs=( $( seq ${start} ${step} $(( ${start} + (${no}-1)*${step} )) ) )
  no_per_chain=$(( $no / $no_of_chains )) # we try to create ${no_of_chains} chains, 
                              # each of which will contain this many jobs
                              # this is due to the way the Jureca QoS system works
                              # remaining configs of the integer division will be packed into a
                              # ${no_of_chains+1}'th overflow chain
  remaining=${no}
  for chain in $( seq 0 $(( $no_of_chains - 1 )) ); do
    # initial dependency specified via command line, all job chains should wait for this job
    jobid="${4}"
    offset=$(( $chain * $no_per_chain ))
    for i in $( seq 0 $(( $no_per_chain - 1 )) ); do
      i4=$(printf %04d ${configs[$(( $offset + $i ))]} )
      echo "chain $chain config $i4"
      # the first inversion in the job chain does not depend on any job, unless
      # a dependency has been specified on the command line
      if [ -z "${jobid}" ]; then
        jobid=$( qsub invert.job.${i4}.cmd )
      else
        # the next inversion depends on the previous contraction
        jobid=$( qsub -W depend=afterok:${jobid} invert.job.${i4}.cmd )
      fi
      # contraction always depends on inversion
      jobid=$( qsub -W depend=afterok:${jobid} cntr.job.${i4}.cmd )
      remaining=$(( $remaining - 1 ))
      echo remaining $remaining
      mv ${prefix}_* ${prefix}_${i4}
    done
  done
  # pop remaining configs into a ($no_of_chains+1)'th job chain
  if [ ${remaining} -gt 0 ]; then
    # initial dependency specified via command line, all job chains should wait for this job
    jobid="${4}"
    offset=$(( $no_of_chains * $no_per_chain ))
    for i in $( seq 0 $(( ${remaining} - 1 )) ); do
      i4=$(printf %04d ${configs[$(( $offset + $i ))]} )
      echo "overflow chain config $i4"
      # the first inversion in the job chain does not depend on any job, unless
      # a dependency has been specified on the command line
      if [ -z "${jobid}" ]; then
        jobid=$( qsub invert.job.${i4}.cmd )
      else
        # the next inversion depends on the previous contraction
        jobid=$( qsub -W depend=afterok:${jobid} invert.job.${i4}.cmd )
      fi
      # contraction always depends on inversion
      jobid=$( qsub -W depend=afterok:${jobid} cntr.job.${i4}.cmd )
      remaining=$(( $remaining - 1 ))
      echo remaining $remaining
      mv ${prefix}_* ${prefix}_${i4}
    done
  fi
fi

