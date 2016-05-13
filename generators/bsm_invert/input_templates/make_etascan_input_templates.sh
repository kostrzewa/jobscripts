#!/bin/sh

if [ -z "${1}" -o -z "${2}" -o -z "${3}" ]; then
  echo "one of the specified parameters was an empty string"
  echo "usage: ./make_etascan_input_templates.sh <target basename> <template_template.input> '<eta values as space separated string enclosed in single quotes>'"
  echo "pay special attention to the single quotes around the list of eta values!"
  exit 1
fi

for eta in ${3}; do
  # replace minus signs in the eta value with an "m"
  texteta=$( echo $eta | sed "s/-/m/g" )
  targetfile=${1}.${texteta}.input
  cp ${2} ${targetfile}
  sed -i "s/ETA/${eta}/g" ${targetfile}
done
