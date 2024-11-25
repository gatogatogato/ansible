# ansible
Just my ansible stuff to set up new LXCs and VMs in a structured manner.

# Setup
As user transport on ansible server run 
cd ~transport && rm -rf ansible ; git clone -q https://github.com/gatogatogato/ansible ~/ansible

# Similar
export ANS_PATH=/home/transport/ansible/
export INVNTRY=${ANS_PATH}/inventory.yaml
/home/transport/clone.sh
cp ${ANS_PATH}/clone.sh /home/transport/clone.sh
