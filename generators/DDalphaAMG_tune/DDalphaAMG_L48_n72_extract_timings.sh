iters=(3 4 5)
blkyz=(3 6)
mucoarse=(2.0 2.5 3.0 3.5 4.0 4.5 5.0 5.5 6.0 6.5 7.0 7.5 8.0 8.5 9.0 9.5 10.0 10.5 11.0 11.5 12.0)
nvecs=(16 18 20 22 24 26 28 30 32 34 36)

test_run=0

nmeas=2

ofile=timings.dat
mfile=missing.dat

dt=$(date)
echo "# $dt" > $ofile
echo "setupiter blkyz nvec mucoarse setuptime setupcgrid solvetime solvecgrid" >> $ofile

echo "# $dt" > $mfile

for iter in ${iters[@]}; do
  for blk in ${blkyz[@]}; do
    for nvec in ${nvecs[@]}; do
      for muc in ${mucoarse[@]}; do
        job=iters${iter}_blkyz${blk}_nvec${nvec}_mucoarse${muc}
        wdir=$(pwd)/iters${iter}_blkyz${blk}_Nvec${nvec}_mucoarse${muc}
        sfile=$wdir/outputs/${job}.72.DDalphaAMG.test.out
        setuptime=$(grep "setup ran" $sfile | awk '{print $5}')
        setupcgrid=$(grep "setup ran" $sfile | awk '{print $7}' | sed 's/(//g')
        if [ -z ${setuptime} ]; then
          if [ $test_run -eq 1 ]; then
            exit 1
          fi
          echo $wdir >> $mfile
          continue
        fi
        
        temp=( $(grep "Solving time" $sfile | awk '{print $3}') )
        solvetime=0
        for num in ${temp[@]}; do
          solvetime=$( echo "scale=2; $solvetime + $num" | bc -l )
        done
        solvetime=$( echo "scale=2; $solvetime / $nmeas" | bc -l )

        temp=( $(grep "Solving time" $sfile | awk '{print $5}' | sed 's/(//g') )
        solvecgrid=0
        for num in ${temp[@]}; do
          solvecgrid=$( echo "scale=2; $solvecgrid + $num" | bc -l )
        done
        solvecgrid=$( echo "scale=2; $solvecgrid / $nmeas" | bc -l )

        echo "$iter $blk $nvec $muc $setuptime $setupcgrid $solvetime $solvecgrid" >> $ofile

        if [ $test_run -eq 1 ]; then
          exit 0
        fi
      done
    done
  done
done
