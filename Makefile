TAG = $(shell git describe --tags --always)
PREFIX = $(shell git config --get remote.origin.url | tr ':.' '/'  | rev | cut -d '/' -f 3 | rev)
REPO_NAME = $(shell git config --get remote.origin.url | tr ':.' '/'  | rev | cut -d '/' -f 2 | rev)
TARGET := $(if $(TARGET),$(TARGET),$(shell ./evaluate_platform.sh))
VCS_REF = $(shell git rev-parse --short HEAD)
BUILD_DATE = $(shell date -u +'%Y-%m-%dT%H:%M:%SZ')
BUILD_FLAGS := $(if $(BUILD_FLAGS),$(BUILD_FLAGS),--load --no-cache)
BUILDER_NAME = k8s-wait-for-builder
DOCKER_IMAGE := $(if $(DOCKER_IMAGE),$(DOCKER_IMAGE),'')
DOCKER_TAGS= $(PREFIX)/$(REPO_NAME):$(DOCKER_IMAGE)latest $(PREFIX)/$(REPO_NAME):$(DOCKER_IMAGE)$(TAG) ghcr.io/$(PREFIX)/$(REPO_NAME):$(DOCKER_IMAGE)latest ghcr.io/$(PREFIX)/$(REPO_NAME):$(DOCKER_IMAGE)$(TAG)
DOCKER_FILE := $(if $(DOCKER_FILE),$(DOCKER_FILE),Dockerfile)

all: push

container: image

image:
	@echo TARGET IS $(TARGET)
	if ! docker buildx inspect $(BUILDER_NAME) 2> /dev/null ; then docker buildx create --name $(BUILDER_NAME) ; fi
	docker buildx build \
		--builder=$(BUILDER_NAME) \
		--platform=$(TARGET) \
		--build-arg VCS_REF=$(VCS_REF) \
		--build-arg BUILD_DATE=$(BUILD_DATE) \
		--file=$(DOCKER_FILE) \
		$(BUILD_FLAGS) \
		$(foreach TAG,$(DOCKER_TAGS),--tag $(TAG)) \
		.

push: BUILD_FLAGS:=$(BUILD_FLAGS:--load=)
push: BUILD_FLAGS+=--push
push: image

clean:
	if docker buildx inspect $(BUILDER_NAME) 2> /dev/null ; then docker buildx rm $(BUILDER_NAME) ; fi
	$(foreach TAG,$(DOCKER_TAGS),docker rmi -f $(TAG); )