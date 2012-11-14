#!/bin/bash
# qsubmit_zeuthen is a batch submitter for the zeuthen batch system
# provided with a directory which contains one level of 
# subdirectories with jobscripts, it will
# descend into the subdirectories and submit jobscripts
# according to the pattern:

# there are two types of scripts
# the ones beginning with s_ are "start" scripts, the first script to be
# submitted in a chain of scripts or simply the only script in a chain
# the ones beginning with c#_, where # is a number, are continuation scripts
# they depend on the successful execution of the preceding s_ script
# or, when # > 1, the preceding continue script

# NOTE: this is currently broken for # > 99



export PAX=1
eval `/etc/site/ini.pl -b pax`

for i in ${1}/*/s_*.sh; do
  case ${i} in
    *serial*):
      if [[ $PAX -ne 0 ]]; then
        eval `/etc/site/ini.pl -b -d pax`
        export PAX=0
      fi
    ;;
    *):
      if [[ $PAX -ne 1 ]]; then
        eval `/etc/site/ini.pl -b pax`
        export PAX=1
      fi
    ;;
  esac
  echo "Submitting start job ${i}"
  qsub ${i}
done

# array only supported with bash!
cfiles=(${1}/*/c*_*.sh)

if [[ ! -e ${cfiles[1]} ]]; then
  exit
fi

for i in ${1}/*/c*_*.sh; do  
  case ${i} in
    *serial*)
      if [[ $PAX -ne 0 ]]; then
        eval `/etc/site/ini.pl -b -d pax`
        export PAX=0
      fi
    ;;
    *)
      if [[ $PAX -ne 1 ]]; then
        eval `/etc/site/ini.pl -b pax`
        export PAX=1
      fi
    ;;
  esac
  BASE=`echo ${i} | awk -F'/' '{print $NF}'`
  DEP=""
  case ${BASE} in
    c01*)
      export DEP=`echo ${BASE} | sed 's/c01/s/g'`
    ;;
    *)
      # remove the c and 0 in case it's less than 10 (0 only at start ^)
      NUM=`echo ${BASE} | awk -F'_' '{print $1}' | sed 's/c//g' | sed 's/^0//g'`
      # calculate the dependency
      let NUM=${NUM}-1
      
      # prepend a zero if the dependency is less than 10
      if [[ ${NUM} -le 9 ]]; then
        TEXTNUM="0${NUM}"
      else
        TEXTNUM="${NUM}"
      fi
      
      # print all fields starting from field 2 to the end
      export DEP="c${TEXTNUM}_`echo ${BASE} | cut -f2- -d '_'`"
    ;;
  esac
    echo -e "Submitting continue job ${i}\n   depending on ${DEP}\n"
    qsub -hold_jid ${DEP} ${i}
done
