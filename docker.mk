#################################
# Docker targets
#################################

# Default Values, override by setting them on the command line, e.g.
# `make HUB_NAMESPACE=hub.docker.com DOCKERFILE=... build-image`
HUB_NAMESPACE = ghcr.io/meko-tech

BUILD_SUPPORT_DIR := $(shell dirname ./$(lastword $(MAKEFILE_LIST)))
CHECK_VAR = test ! -z "${SKIP_VAR_CHECK}" || $(BUILD_SUPPORT_DIR)/check-var.sh
CHECK_PAT = test ! -z "${SKIP_PAT_CHECK}" || $(BUILD_SUPPORT_DIR)/check-pat.sh

# export all variables so check-vars can check them
export

# build image running the service; tag with long version (includes build info), short version (sem. version + prerelease) and `latest`; use `docker images` to check whether image was successfully built
.PHONY: build-image
build-image:
	@$(CHECK_PAT)
	@$(CHECK_VAR) DOCKERFILE HUB_NAMESPACE TAG_LONG
	DOCKER_BUILDKIT=1 \
	docker build \
		  --secret id=gh_pat,env=PAT \
		  -f ${DOCKERFILE} \
		  $(addprefix --target, $(TARGET)) \
		  -t ${HUB_NAMESPACE}/${IMAGE_NAME}:${TAG_LONG} \
		  .
	@docker images --format '{{.Repository}}:{{.Tag}}\t\t Built: {{.CreatedSince}}\t\tSize: {{.Size}}' |\
		grep ${IMAGE_NAME}:${TAG_LONG}
	docker tag ${HUB_NAMESPACE}/${IMAGE_NAME}:${TAG_LONG} ${HUB_NAMESPACE}/${IMAGE_NAME}:${TAG}
	docker tag ${HUB_NAMESPACE}/${IMAGE_NAME}:${TAG_LONG} ${HUB_NAMESPACE}/${IMAGE_NAME}:latest

# build service image with debugger; tag image with `debug`
.PHONY: build-debug-image
build-debug-image:
	@$(CHECK_PAT)
	@$(CHECK_VAR) DOCKERFILE HUB_NAMESPACE
	DOCKER_BUILDKIT=1 \
	docker build \
		--secret id=gh_pat,env=PAT \
		-f ${DOCKERFILE} \
		--target runner_debug \
		-t ${HUB_NAMESPACE}/${IMAGE_NAME}:debug \
		.
	@docker images --format '{{.Repository}}:{{.Tag}}\t\t Built: {{.CreatedSince}}\t\tSize: {{.Size}}' |\
		grep ${IMAGE_NAME}:debug

# remove local images; continue if docker rmi fails (e.g in case image is not present)
.PHONY: rm-image
rm-image:
	@$(CHECK_VAR) TAG TAG_LONG || true
	@docker rmi ${HUB_NAMESPACE}/${IMAGE_NAME}:${TAG_LONG} || true
	@docker rmi ${HUB_NAMESPACE}/${IMAGE_NAME}:${TAG} || true
	@docker rmi ${HUB_NAMESPACE}/${IMAGE_NAME}:latest || true
	@docker rmi ${HUB_NAMESPACE}/${IMAGE_NAME}:debug || true


# push image with ${TAG} (no build info) and with `latest` tags.
# Fails in case ${TAG} already exists at remote. Overwrites `latest`
.PHONY: push-image
push-image:
	@$(CHECK_PAT)
	@$(CHECK_VAR) HUB_NAMESPACE IMAGE_NAME TAG || true
	@if docker manifest inspect ${HUB_NAMESPACE}/${IMAGE_NAME}:${TAG} > /dev/null; then\
		echo "pushing ${HUB_NAMESPACE}/${IMAGE_NAME}:${TAG} failed; already exists at remote";\
		exit 1;\
	fi
	docker push ${HUB_NAMESPACE}/${IMAGE_NAME}:${TAG}
	docker push ${HUB_NAMESPACE}/${IMAGE_NAME}:latest
