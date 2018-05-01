#!/usr/bin/env make

.PHONY: artefacts apk docker_image

artifacts:
	docker run --rm -it \
	  -v $(shell pwd)/artifacts:/var/src/artifacts \
	  -v $(shell pwd)/distfiles:/var/src/distfiles \
	  -v $(shell pwd)/build-artifacts.sh:/usr/local/bin/build-artifacts.sh \
	  xmrwallet_build bash /usr/local/bin/build-artifacts.sh

artifactsd:
	docker run --rm -it \
	  -v $(shell pwd)/artifacts:/var/src/artifacts \
	  -v $(shell pwd)/distfiles:/var/src/distfiles \
	  -v $(shell pwd)/build-artifacts.sh:/usr/local/bin/build-artifacts.sh \
	  xmrwallet_build /bin/bash

docker_image:
	docker build . -t xmrwallet_build
