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

# NOTE: this is currently broken for # > 9

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

for i in ${1}/*/c*_*.sh; do  
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
  BASE=`echo ${i} | awk -F'/' '{print $NF}'`
  echo "Base is ${BASE}"
  DEP=""
  case ${BASE} in
    c1*):
      export DEP=`echo ${BASE} | sed 's/c1/s/g'`
    ;;
    *):
      NUM=`echo ${BASE} | awk -F'_' '{print $1}'`
      NUM=`echo ${NUM} | sed 's/c//g'`
      let NUM=${NUM}-1
      # print all fields starting from field 2 to the end
      export DEP="c${NUM}_`echo ${BASE} | cut -f2- -d '_'`"
    ;;
  esac
    echo -e "Submitting continue job ${i}\n   depending on ${DEP}"
    qsub -hold_jid ${DEP} ${i}
done
