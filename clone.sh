#!/bin/bash
echo "--------------------------------"
echo "This must run as user transport!"
echo "--------------------------------"
cd ~transport
rm -rf ~transport/ansible
git clone https://github.com/gatogatogato/ansible ~/ansible
