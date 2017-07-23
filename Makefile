TAG = $(shell git describe --tags --always)
PREFIX = $(shell git config --get remote.origin.url | rev | cut -d '/' -f 2 | rev)

all: push

container: image

image:
	docker build -t $(PREFIX)/k8s-wait-for . # Build new image and automatically tag it as latest
	docker tag $(PREFIX)/k8s-wait-for $(PREFIX)/k8s-wait-for:$(TAG)  # Add the version tag to the latest image

push: image
	docker push $(PREFIX)/k8s-wait-for # Push image tagged as latest to repository
	docker push $(PREFIX)/k8s-wait-for:$(TAG) # Push version tagged image to repository (since this image is already pushed it will simply create or update version tag)

clean: