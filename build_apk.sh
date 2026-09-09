#!/bin/bash

java -jar /usr/local/Cellar/bundletool/1.18.3/libexec/bundletool-all.jar build-apks \
  --bundle=build/app/outputs/bundle/release/app-release.aab \
  --output=~/t4.apks \
  --mode=universal \
  --ks=play/upload-keystore.jks \
  --ks-key-alias=upload \
  --ks-pass=pass:

