if [ -z "${1}" -o -z "${2}" -o -z "${3}" ]; then
 echo "usage: ./submit.sh <start> <step> <no> [-co]"
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

for i in $( seq ${start} ${step} $(( ${start} + (${no}-1)*${step} )) ); do 
  i4=$( printf %04d $i )
  jobid=""
  if [ -z "${4}" ]; then
    jobid=$( sbatch invert.job.${i4}.cmd | awk '{print $NF}' )
    sbatch --dependency=afterok:${jobid} cntr.job.${i4}.cmd
  else
    sbatch cntr.job.${i4}.cmd
  fi
  mv ${prefix}_* ${prefix}_${i4}
done
