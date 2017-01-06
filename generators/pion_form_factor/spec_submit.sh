if [ -z "${1}" ]; then
 echo "usage: ./spec_submit.sh <confs>"
 exit 1
fi

prefix=Z

if [ -z "$( ls ${prefix}* )" ]; then
  touch ${prefix}_xxxx
fi

no_of_chains=8

# array holding the configuration numbers to be processed
configs=()
counter=0
# remove leading zeroes, if present
for i in $@; do
  configs[$counter]="$(echo ${i} | sed 's/^0*//')"
  counter=$(($counter+1))
done

no_per_chain=$(( ${#configs[@]} / $no_of_chains )) # we try to create ${no_of_chains} chains, 
                            # each of which will contain this many jobs
                            # this is due to the way the Jureca QoS system works
                            # remaining configs of the integer division will be packed into a
                            # ${no_of_chains+1}'th overflow chain
remaining=${#configs[@]}
for chain in $( seq 0 $(( $no_of_chains - 1 )) ); do
  jobid=""
  offset=$(( $chain * $no_per_chain ))
  for i in $( seq 0 $(( $no_per_chain - 1 )) ); do
    i4=$(printf %04d ${configs[$(( $offset + $i ))]} )
    echo "chain $chain config $i4"
    if [ -z "${jobid}" ]; then
      jobid=$( sbatch invert.job.${i4}.cmd | awk '{print $NF}' )
    else
      # the next inversion depends on the previous contraction
      jobid=$( sbatch --dependency=afterok:${jobid} invert.job.${i4}.cmd | awk '{print $NF}' )
    fi
    # contraction always depends on inversion
    jobid=$( sbatch --dependency=afterok:${jobid} cntr.job.${i4}.cmd | awk '{printf $NF}' )
    remaining=$(( $remaining - 1 ))
    echo remaining $remaining
    mv ${prefix}_* ${prefix}_${i4}
  done
done
# pop remaining configs into a ($no_of_chains+1)'th job chain
if [ ${remaining} -gt 0 ]; then
  offset=$(( $no_of_chains * $no_per_chain ))
  jobid=""
  for i in $( seq 0 $(( ${remaining} - 1 )) ); do
    i4=$(printf %04d ${configs[$(( $offset + $i ))]} )
    echo "overflow chain config $i4"
    if [ -z "${jobid}" ]; then
      jobid=$( sbatch invert.job.${i4}.cmd | awk '{print $NF}' )
    else
      # the next inversion depends on the previous contraction
      jobid=$( sbatch --dependency=afterok:${jobid} invert.job.${i4}.cmd | awk '{print $NF}' )
    fi
    # contraction always depends on inversion
    jobid=$( sbatch --dependency=afterok:${jobid} cntr.job.${i4}.cmd | awk '{printf $NF}' )
    remaining=$(( $remaining - 1 ))
    echo remaining $remaining
    mv ${prefix}_* ${prefix}_${i4}
  done
fi
