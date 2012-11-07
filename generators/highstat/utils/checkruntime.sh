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

REFTFILE="../runtimes_csw.csv"

# read the column names (sample names) and their order from the runtimes file
TREFSAMPLES=`head -n1 ${REFTFILE}`

# prepend "ref" to each name in TREFSAMPLES
for i in $TREFSAMPLES; do
  REFSAMPLES="${REFSAMPLES} ref${i}"
done

# read the columne names and their order from the file to be analyzed
SAMPLES=`head -n1 ${1}`

# skip the headers in the files
readrefheaderflag=0
readheaderflag=0

while read refname ${REFSAMPLES}; do
  if [[ readrefheaderflag -eq 0 ]]; then
    let readrefheaderflag=1
    continue
  fi

  let readheaderflag=0
  while read name ${SAMPLES}; do
    if [[ readheaderflag -eq 0 ]]; then
      let readheaderflag=1
      continue
    fi

    # if a given run exists in both files, do a comparison
    if [[ $refname = $name ]]; then
      for i in ${SAMPLES}; do
        if [[ -z ${!i} || ${!i} = "NA" ]]; then
          echo "The $name run of sample $i has an empty time measurement. The set is probably not complete!"
          continue
        fi
        for j in ${REFSAMPLES}; do
          # if in a given run
          if [[ ${j} = "ref"${i} ]]; then
            if [[ `echo "scale=6;out=0;r=${!i}/${!j};if(r>1.05) out=1;out" | bc` -eq 1 ]]; then
              echo "The $name run of sample $i took longer than the reference time: ${!i} > ${!j} !"
            fi
          fi
        done
      done
    fi
  done < ${1}
done < ${REFTFILE}
