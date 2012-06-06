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

for i in ${1}/*/*.sh; do
  BASE=`echo ${i} | awk -F'/' '{print $NF}'`
  echo "Base is ${BASE}"
  DEP=""
  case ${BASE} in
    s_*):
      echo "Submitting start job ${i}"
      #sub ${i}
    ;;
    c*):
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
    ;;
  esac

done
