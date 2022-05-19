TAG =  arm64-test-1
PREFIX = $(shell git config --get remote.origin.url | tr ':.' '/'  | rev | cut -d '/' -f 3 | rev)
REPO_NAME = $(shell git config --get remote.origin.url | tr ':.' '/'  | rev | cut -d '/' -f 2 | rev)
TARGET = $(shell ./evaluate_platform.sh)
MANIFEST_ARCHS = amd64 arm64

all: push

container: image push

image-and-push-buildx:
	@echo TARGET IS $(TARGET)
	docker buildx build \
		--no-cache \
		--platform=linux/arm64,linux/amd64 \
		--output type=image \
		--tag $(PREFIX)/$(REPO_NAME):$(TAG) \
		--tag ghcr.io/$(PREFIX)/$(REPO_NAME):$(TAG) \
		--push \
		.	 # Build new image and automatically tag it as latest

image:
	@echo TARGET IS $(TARGET)
	docker build --no-cache -t $(PREFIX)/$(REPO_NAME):latest . --build-arg TARGET_PLATFORM=$(TARGET) # Build new image and automatically tag it as latest
	docker tag $(PREFIX)/$(REPO_NAME) $(PREFIX)/$(REPO_NAME):latest-$(TARGET)  # Add the version tag to the latest image
	docker tag $(PREFIX)/$(REPO_NAME) $(PREFIX)/$(REPO_NAME):$(TAG)  # Add the version tag to the latest image
	docker tag $(PREFIX)/$(REPO_NAME) $(PREFIX)/$(REPO_NAME):$(TAG)-$(TARGET)  # Add the version tag to the latest image
	docker tag $(PREFIX)/$(REPO_NAME) ghcr.io/$(PREFIX)/$(REPO_NAME):latest  # Tag latest for ghcr repository
	docker tag $(PREFIX)/$(REPO_NAME) ghcr.io/$(PREFIX)/$(REPO_NAME):latest-$(TARGET)  # Tag latest for ghcr repository
	docker tag $(PREFIX)/$(REPO_NAME) ghcr.io/$(PREFIX)/$(REPO_NAME):$(TAG)-$(TARGET)  # Tag the version tag for ghcr repository

push: push-docker-hub push-ghcr

push-docker-hub: image
	docker push $(PREFIX)/$(REPO_NAME):latest-$(TARGET) # Push image tagged as latest to docker hub repository
	docker push $(PREFIX)/$(REPO_NAME):$(TAG)-$(TARGET) # Push version tagged image to docker hub repository (since this image is already pushed it will simply create or update version tag)

push-ghcr: image
	docker push ghcr.io/$(PREFIX)/$(REPO_NAME):latest-$(TARGET) # Push image tagged as latest to ghcr repository
	docker push ghcr.io/$(PREFIX)/$(REPO_NAME):$(TAG)-$(TARGET) # Push version tagged image to ghcr repository (since this image is already pushed it will simply create or update version tag)

manifest-docker-hub: ARCHS_LATEST = $(foreach ARCH,$(MANIFEST_ARCHS), $(PREFIX)/$(REPO_NAME):latest-$(ARCH))
manifest-docker-hub: ARCHS_TAGGED = $(foreach ARCH,$(MANIFEST_ARCHS), $(PREFIX)/$(REPO_NAME):$(TAG)-$(ARCH))
manifest-docker-hub:
	docker manifest create \
	$(PREFIX)/$(REPO_NAME):latest \
	$(ARCHS_LATEST)
	docker manifest create \
	$(PREFIX)/$(REPO_NAME):$(TAG) \
	$(ARCHS_TAGGED)

push-multi-arch-docker-hub: manifest-docker-hub
	docker push $(PREFIX)/$(REPO_NAME):latest
	docker push $(PREFIX)/$(REPO_NAME):$(TAG)

clean: