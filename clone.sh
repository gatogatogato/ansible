#!/bin/bash
echo "---------------------------------------"
echo "This   M U S T   run as user transport!"
echo "---------------------------------------"
echo "Waiting 5 seconds..."
sleep 5

echo "Continue..."
cd ~transport
rm -rf ~transport/ansible
git clone https://github.com/gatogatogato/ansible ~/ansible
cp ~/ansible/clone.sh ~/clone.sh
echo "End of script."
exit