#!/bin/bash

Ls=(24 32 48 64)
Nnds=(8 16 32 36 64 72)
Ntpn=(1 2 4 8 16 32 64)
Ntpt=(1 2 3 4 6 8 12 16 24 32 64 128 256)

tabfile=performance.dat

echo "# $(date)" > $tabfile
echo L nds tpn tpt mflops nc_mflops >> $tabfile

for L in ${Ls[@]}; do
  for nds in ${Nnds[@]}; do
    for tpn in ${Ntpn[@]}; do
      for tpt in ${Ntpt[@]}; do
        cupn=$(( $tpn * $tpt ))        
        # we want to check up to 256 compute units per node, no more than that
        # we also want to run with no fewer than 32 compute units per node
        if [ $cupn -gt 256 -o $cupn -lt 32 ]; then 
          continue 
        fi

        wdir=$( printf L%02d_nds%03d_tpn%02d_tpt%03d $L $nds $tpn $tpt )
        if [ ! -d $wdir ]; then
          continue
        fi
        
        ofile=$wdir/outputs/out.benchmark_l${L}_nds${nds}_tpn${tpn}_tpt${tpt}.out
        
        mflops=$( grep -h -A2 'switched on' $ofile | grep Mflop | awk '{print $1}' )
        nc_mflops=$( grep -h -A2 'switched off' $ofile | grep Mflop | awk '{print $1}' )

        if [ -z "$mflops" -o -z "$nc_mflops" ]; then
          continue
        else
          echo $L $nds $tpn $tpt $mflops $nc_mflops | tee -a $tabfile 
        fi

      done
    done
  done
done



