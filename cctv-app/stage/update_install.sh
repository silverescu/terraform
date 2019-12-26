#! /usr/bin/bash
yum update -y
yum install git -y
amazon-linux-extras install docker
service docker start
git clone https://github.com/silverescu/open-docker.git s3fs-fuse
cd s3fs-fuse
aws s3 cp s3://drazvt-config-files/env.list .
docker build --rm -t drzvt/s3fs-fuse-cctv:1.0 .
docker run --restart always -p 21:21 -p 30000-30100:30000-30100 --privileged --env-file env.list drzvt/s3fs-fuse-cctv:1.0
