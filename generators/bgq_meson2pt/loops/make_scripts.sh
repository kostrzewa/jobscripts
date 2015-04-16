START=0
END=5368
STEP=8

JDIR=/work/hch02/hch028/meson_2pt/nf2/iwa_b2.1-L32T64-csw1.57551-k0.1373-mul0.006_combined/loops/jobscripts

for i in `seq ${START} ${STEP} ${END}`; do
  c4num=`printf "%04d" ${i}`
  cp job_disc_serial.job.template ${JDIR}/job_disc_serial.${c4num}.job
  sed -i "s/NC/${c4num}/g" ${JDIR}/job_disc_serial.${c4num}.job
done

