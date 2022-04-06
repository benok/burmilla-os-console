#!/bin/bash
set -e

cd $(dirname $0)

rm -rf ./build
mkdir -p ./build
cp ./../02-console/sshd_config.append.tpl ./build/
cp ./../02-console/generate-lsb-release ./build/
cp ./../10-debianconsole/iscsid.conf ./build/
