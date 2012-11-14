#!/bin/bash

# this utility reads the "runtimes.csv" output ${1} of the highstat R routine
# and compares the runtimes to the reference specified in REFTFILE

# the REFSAMPLES and SAMPLES variables hold a list of reference samples
# and samples in the two runtimes files

# the names in these two variables are immaterial, they only serve to label to columns
# in the files. They must have the same number and they must be in the same order
# for the tool to work correctly. The order must also match the column order in the two
# tables that are read. The row order in the tables is of no consequence.

# currently the comparison of partial runtime output is not supported because 
# of the aforementioned importance of ordering

REFTFILE="${HOME}/jobscripts/generators/highstat/runtimes_hmc56.csv"
TFILE="/lustre/fs4/group/etmc/kostrzew/plots/${1}/runtimes.csv"

#REFTFILE="../runtimes.csv"

# read the column names (sample names) and their order from the runtimes file
TREFSAMPLES=`head -n1 ${REFTFILE}`

# prepend "ref" to each name in TREFSAMPLES
for i in $TREFSAMPLES; do
  REFSAMPLES="${REFSAMPLES} ref${i}"
done

# read the columne names and their order from the file to be analyzed

SAMPLES=`head -n1 ${TFILE}`
IDIR="${HOME}/tmLQCD/inputfiles/highstat/${1}"

# skip the headers in the files
readrefheaderflag=0
readheaderflag=0

missingvalues="\n"

symbols[1]=">"
symbols[2]="<"

while read name ${SAMPLES}; do
  # skip the first line
  if [[ readrefheaderflag -eq 0 ]]; then
    let readrefheaderflag=1
    continue
  fi

  let readheaderflag=0
  foundref=0
  while read refname ${REFSAMPLES}; do
    # skip the first line
    if [[ readheaderflag -eq 0 ]]; then
      let readheaderflag=1
      continue
    fi

    # if a given run exists in both files, do a comparison
    if [[ $refname = $name ]]; then
      foundref=1
      for i in ${SAMPLES}; do
        if [[ -z ${!i} || ${!i} = "NA" ]]; then
          missingvalues="${missingvalues}`echo "The $name run of $i has an empty time measurement (${!i}).\n"`"
          continue
        fi
        for j in ${REFSAMPLES}; do
          
          # if in a given run
          if [[ ${j} = "ref"${i} ]]; then
            if [[ -z ${!j} || ${!j} = "NA" ]]; then
              missingvalues="${missingvalues}`echo "The $refname REFERENCE run of $j has an empty time measurement (${!j}).\n"`"
              continue
            fi

            IFILE="${IDIR}/${name}/s_${i}_${name}.input"
            ratio=`echo "scale=3;${!i}/${!j}"|bc`
            ratioflag=`echo "scale=4;out=0;if(${ratio}>1.05) out=1;if(${ratio}<0.95) out=2;out" | bc`
            if [[ ${ratioflag} -eq 1 || ${ratioflag} -eq 2 ]]; then
              NMEAS=`grep "measurements" ${IFILE} | awk -F'=' '{print $2}'`
              TIME=`echo "scale=4; ${NMEAS}*${!i}/1000" | bc`
              printf "%20s %45s   ratio %-4.5s    runtime %-4.5s hours    %-4.6s %c %-4.6s\n" $name $i $ratio $TIME ${!i} ${symbols[$ratioflag]} ${!j}
            fi
          fi
        done
      done
    fi
  done < ${REFTFILE}
  if [[ $foundref -eq 0 ]]; then
    echo "No reference found for $name!"
  fi 
done < ${TFILE}

# print error messages for empty measurements at the end
if [[ ${2} -eq 1 ]]; then
  echo -n -e $missingvalues
else
  echo "Not printing missing values. To enable, pass '1' as second argument."
fi
