#!/bin/bash

java -jar /usr/local/Cellar/bundletool/1.18.3/libexec/bundletool-all.jar jar build-apks \
  --bundle=build/app/outputs/bundle/release/app-release.aab \
  --output=build/app/outputs/bundle/release/abp-release.apks \
  --mode=universal \
  --ks=play/upload-keystore.jks \
  --ks-key-alias=upload \
  --ks-pass=pass:

