#!/bin/bash
echo "This must run as user transport!"
echo "Press enter to continue..."
read

cd ~transport
rm -rf ~transport/ansible
git clone -q https://github.com/gatogatogato/ansible ~/ansible
