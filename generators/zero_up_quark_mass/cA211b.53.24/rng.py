#!/usr/bin/python
import argparse
import random

# generate a random time slice
def main():
  parser = argparse.ArgumentParser()
  parser.add_argument('--seed', type=int, help="Seed for rng", required=True)
  parser.add_argument('--Nt', type=int, help="Lattice time extent", required=True)
  parser.add_argument('--cid', type=int, help="Configuration number", required=True)
  
  args = parser.parse_args()
  
  seed = args.seed ^ (116041 * args.cid)
  random.seed(seed)

  print(random.randint(0,args.Nt-1))

if __name__ == "__main__":
  try:
    main()
  except KeyboardInterrupt:
    print("KeyboardInterrupt")

