#!/usr/bin/python

# BSM inversions 
# Generate mappings for a set of scalar fields from some diretory, using npergauge scalar fields
# for each gauge field.
# The set of gauge fields is specified by supplying configuration numbers conf_start and conf_end
# and is stepped through by conf_step

import glob, sys, getopt, random

def main(argv):
  helpstring = 'scalar_combinator.py -d <scalars_dir> -f <conf_end> [-r <reuse_scalars=0>] [-i <conf_start=0>] [-s <conf_step=1>] [-n <npergauge=1>] [-S <rng_seed=123456>]'
  scalars_dir = ''
  conf_start = 0
  conf_end = 0
  conf_step = 1
  npergauge = 1
  rng_seed = 123456
  reuse_scalars = False

  if len(argv) < 1:
    print "You must pass options!"
    print helpstring
    exit(1)
  
  try:
    opts, args = getopt.getopt(argv,"hS:d:i:f:s:n:r:")
  except getopt.GetoptError as err:
    print(err)
    print helpstring
    sys.exit(2)
  
  # this doesn't quite work as it should, but I've spent too much time trying to fix it
  # essentially it fails if any of the options with arguments has been specified without, followed
  # immediately by another option
  # what happens in that case is that this other option becomes the argument of the first... 
  opt, arg = zip(*opts)
  if len(set(opt).intersection(('-d','-f'))) < 2:
    print "scalars_dir and conf_end must be specified!"
    print helpstring
    sys.exit(3)
  
  for opt, arg in opts:
    if opt == '-h':
      print helpstring
      sys.exit()
    elif opt in ("-d"):
      scalars_dir = arg
    elif opt in ("-i"):
      conf_start = int(arg)
    elif opt in ("-f"):
      conf_end =int(arg)
    elif opt in ("-s"):
      conf_step = int(arg)
    elif opt in ("-n"):
      npergauge = int(arg)
    elif opt in ('-S'):
      rng_seed = int(arg)
    elif opt in ('-r'):
      reuse_scalars = bool(arg)
  
  print
  print "### SCALARS_COMBINATOR ###"
  print "scalars_dir="+str(scalars_dir)
  print "conf_start="+str(conf_start)
  print "conf_end="+str(conf_end)
  print "conf_step="+str(conf_step)
  print "npergauge="+str(npergauge)
  print "rng_seed="+str(rng_seed)
  print "reuse_scalars="+str(reuse_scalars)
  print

  random.seed(rng_seed)
  scalars = sorted(glob.glob(scalars_dir+"/*.dat"), key=str.lower)

  
  if reuse_scalars:
    g_scalars = random.sample(scalars,npergauge)

  for g_idx in range(conf_start,conf_end,conf_step):
    cfname = "conf."+str(g_idx).zfill(4)
    ofname = "scalarmap."+str(g_idx).zfill(4)
    
    if not reuse_scalars:
      # sample without replacement 
      g_scalars = random.sample(scalars,npergauge)
      scalars = set(scalars)-set(g_scalars)

    of = open(ofname,'w')
    for item in g_scalars:
      print>>of, item
    of.close()

if __name__ == "__main__":
  main(sys.argv[1:])
