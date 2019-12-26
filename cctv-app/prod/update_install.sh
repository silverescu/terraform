#! /usr/bin/bash
yum update -y
amazon-linux-extras install docker -y
service docker start
mkdir s3fs-fuse
cd s3fs-fuse
aws s3 cp s3://drazvt-config-files/env.list .
docker pull drzvt/s3fs-fuse
docker run --restart always -p 21:21 -p 30000-30100:30000-30100 --privileged --env-file env.list drzvt/s3fs-fuse:latest
