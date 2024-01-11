BUILD_SUPPORT_DIR := $(shell dirname ./$(lastword $(MAKEFILE_LIST)))
CHECK_VAR = test ! -z "${SKIP_VAR_CHECK}" || $(BUILD_SUPPORT_DIR)/check-var.sh

# export variables for check-var
export

# build test runner image
.PHONY: build-test-runner
build-test-runner:
	@echo "+ $@"
	@$(CHECK_VAR) TEST_RUNNER_DOCKERFILE TEST_RUNNER_IMAGE
	DOCKER_BUILDKIT=1 \
	docker build \
		--secret id=gh_pat,env=PAT \
		-f $(TEST_RUNNER_DOCKERFILE) \
		-t $(TEST_RUNNER_IMAGE) \
		.
	
	@echo "Done."
	@docker images --format '{{.Repository}}:{{.Tag}}\t\t Built: {{.CreatedSince}}\t\tSize: {{.Size}}' |\
    		grep ${TEST_RUNNER_IMAGE}


# remove test runner image
.PHONY: rm-test-runner
rm-test-runner: check-unit-vars
	@echo "+ $@"
	@$(CHECK_VAR) TEST_RUNNER_IMAGE || true
	docker rmi $(TEST_RUNNER_IMAGE) || true

# list of packages to test
# - can be package name, directory/package or full package path
# - go test runs with filter ./.../${packagename} and ./.../${packagename}_test
#	- in case package name is `utils`: finds internal/utils, internal/api/utils or pkg/utils...define
# - add parent directory to package name to avoid conflicts
# metadata_client is skipped for now as we don't join inherited roles atm.
# TEST_TARGETS :=

# targets to run unit tests which print test results to stdout
# corresponds to the respective package names suffixed with ".test-unit"
TARGETS_UNIT = $(TEST_TARGETS:%=%.test-unit)

# targets to run unit tests which print test results to xml files (junit format)
# corresponds to the respective package names suffixed with ".test-unit-xml"
TARGETS_UNIT_XML = $(TEST_TARGETS:%=%.test-unit-xml)

# run unit test targets
# - uses docker container to run `go test`
# - removes container after test

# - `go test` arguments
# 		-count=1 : disables test caching
# 		path = ./.../${test target name (= package name)} (`.test-unit` suffix trimmed)
# - exits with the same error code as `go test`
# - prints test results to stdout
# - make target fails in case `go test` fails

.PHONY: $(TARGETS_UNIT)
$(TARGETS_UNIT):  build-test-runner
	@echo "+ $@"
	@$(CHECK_VAR) TEST_RUNNER_IMAGE
	@docker run --rm=true $(TEST_RUNNER_IMAGE) go test -count=1 ./.../$(@:%.test-unit=%)

# run targets for unit tests with xml output
# - uses docker container to run `go test`
# 	- runs shell script on remote container
# 	- call go test with arguments
#		-v : verbose output (required to store test artefacts)
# 		-count=1 : disable test caching
# 		path = ./.../${test target name (= package name)} (`.test-unit-xml` suffix trimmed)
# 	- pipes test results to `go-junit-report` to generate xml-formatted output. See test-runner Dockerfile for program source
# - writes test results to .xml file
#	- writes `docker run` output to file
# 	- filename: ${timestamp}_${package_name}
# 		- (timestamp required to avoid accidental override of test results in case of equal package names, e.g. internal/utils and pkg/utils)
# - returns `go test`exit code:
# 	- `docker run` returns the exit code of the program which runs at the container (in this case: /bin/sh)
# 	- `set -o pipefail causes shell to exit with last non-zero exit code from pipe
# - make target fails in case go test fails
# - .xml test data is always produced

.PHONY: $(TARGETS_UNIT_XML)
$(TARGETS_UNIT_XML): build-test-runner
	@echo "+ $@"
	@$(CHECK_VAR) TEST_RUNNER_IMAGE TEST_RESULTS_DIR
	@mkdir -p $(TEST_RESULTS_DIR)
	@docker run --rm=true $(TEST_RUNNER_IMAGE) /bin/sh -c \
		"set -o pipefail; \
		go test -v -count=1 ./.../$(@:%.test-unit-xml=%) | go-junit-report" \
		> $(TEST_RESULTS_DIR)/$(shell date +%s)_$(lastword $(subst /, ,$(@:%.test-unit-xml=%))).xml

# remove testresults
.PHONY: clean-testresults
clean-testresults:
	@echo "+ $@"
	@$(CHECK_VAR) TEST_RESULTS_DIR
	@rm $(TEST_RESULTS_DIR)/*.xml || true
	@rmdir $(TEST_RESULTS_DIR)
