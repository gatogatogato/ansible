#!/bin/bash
echo "---------------------------------------"
echo "This   M U S T   run as user transport!"
echo "---------------------------------------"

cd ~transport
rm -rf ~transport/ansible
git clone https://github.com/gatogatogato/ansible ~/ansible
cp ~/ansible/clone.sh ~/clone.sh