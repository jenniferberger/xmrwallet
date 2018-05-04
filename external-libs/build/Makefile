#!/usr/bin/env make

.PHONY: artifacts artifactsd artifacts-verification docker_image

artifacts:
	@echo "running the artifacts build"
	mkdir -p artifacts
	mkdir -p distfiles
	docker run --rm -it \
	  -v $(shell pwd)/artifacts:/var/src/artifacts \
	  -v $(shell pwd)/distfiles:/var/src/distfiles \
	  -v $(shell pwd)/build-artifacts.sh:/usr/local/bin/build-artifacts.sh \
	  xmrwallet_build /bin/bash /usr/local/bin/build-artifacts.sh

artifactsd:
	@echo "debugable build - enters the container and requires you to execute the commands"
	mkdir -p artifacts
	mkdir -p distfiles
	docker run --rm -it \
	  -v $(shell pwd)/artifacts:/var/src/artifacts \
	  -v $(shell pwd)/distfiles:/var/src/distfiles \
	  -v $(shell pwd)/build-artifacts.sh:/usr/local/bin/build-artifacts.sh \
	  xmrwallet_build /bin/bash

artifacts-verification:
	@echo "running a verification build that compares with a previous artifacts build"
	mkdir -p artifacts-verification
	mkdir -p distfiles
	docker run --rm -it \
	  -v $(shell pwd)/artifacts-verification:/var/src/artifacts \
	  -v $(shell pwd)/distfiles:/var/src/distfiles \
	  -v $(shell pwd)/build-artifacts.sh:/usr/local/bin/build-artifacts.sh \
	  xmrwallet_build /bin/bash /usr/local/bin/build-artifacts.sh
	diff -r artifacts artifacts-verification && echo "verify ok"

docker_image:
	docker build . -t xmrwallet_build
