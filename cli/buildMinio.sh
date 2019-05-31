#!/bin/bash

echo "Build Minio"
_start=`date +%s`
./cluster --cluster=cluster.cfg destroy-node --node-prefix=minio --force
./cluster --cluster=cluster.cfg create-node --type=service --nrof-nodes=4 --machine-type=cx11 --node-prefix=minio --force
./app --cluster=cluster.cfg deploy-app --app=app_config/minio.cfg --target="minio056,minio057,minio058,minio059"
_end=`date +%s`
echo "Build of Minio completed"
echo "Duration: $((_end-_start))"