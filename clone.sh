#!/bin/bash
sudo su - transport 
cd 
rm -rf ~transport/ansible
git clone -q https://github.com/gatogatogato/ansible ~/ansible
