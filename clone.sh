#!/bin/bash
echo "---------------------------------------"
echo "This   M U S T   run as user transport!"
echo "---------------------------------------"
sleep 3

echo "Continue..."
cd ~transport
rm -rf ~transport/ansible
git clone https://github.com/gatogatogato/ansible ~/ansible
cp ~/ansible/clone.sh ~/clone.sh
echo "End of script."
exit