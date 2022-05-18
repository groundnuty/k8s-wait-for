TAG = $(shell git describe --tags --always)
PREFIX = $(shell git config --get remote.origin.url | tr ':.' '/'  | rev | cut -d '/' -f 3 | rev)
REPO_NAME = $(shell git config --get remote.origin.url | tr ':.' '/'  | rev | cut -d '/' -f 2 | rev)
TARGET = $(shell ./evaluate_platform.sh)

all: push

container: image

image:
	@echo TARGET IS $(TARGET)
	docker build --no-cache -t $(PREFIX)/$(REPO_NAME):latest . --build-arg TARGET_PLATFORM=$(TARGET) # Build new image and automatically tag it as latest
	docker tag $(PREFIX)/$(REPO_NAME) $(PREFIX)/$(REPO_NAME):$(TAG)  # Add the version tag to the latest image
	docker tag $(PREFIX)/$(REPO_NAME) ghcr.io/$(PREFIX)/$(REPO_NAME):latest  # Tag latest for ghcr repository
	docker tag $(PREFIX)/$(REPO_NAME) ghcr.io/$(PREFIX)/$(REPO_NAME):$(TAG)  # Tag the version tag for ghcr repository

push: push-docker-hub push-ghcr

push-docker-hub: image
	docker push $(PREFIX)/$(REPO_NAME):latest # Push image tagged as latest to docker hub repository
	docker push $(PREFIX)/$(REPO_NAME):$(TAG) # Push version tagged image to docker hub repository (since this image is already pushed it will simply create or update version tag)

push-ghcr: image
	docker push ghcr.io/$(PREFIX)/$(REPO_NAME):latest # Push image tagged as latest to ghcr repository
	docker push ghcr.io/$(PREFIX)/$(REPO_NAME):$(TAG) # Push version tagged image to ghcr repository (since this image is already pushed it will simply create or update version tag)

clean: