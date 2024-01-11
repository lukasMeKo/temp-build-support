BUILD_SUPPORT_DIR := $(shell dirname ./$(lastword $(MAKEFILE_LIST)))

#################################
# Helm targets
#################################

# Default Values, override by setting them on the command line, e.g.
# `make CHARTS_NAMESPACE=hub.docker.com DOCKERFILE=... build-image`
CHARTS_NAMESPACE = ghcr.io/meko-tech/helm-charts

# export all variables so check-vars can check them
export

.PHONY: publish-chart
publish-chart: update-chart-deps
	@$(CHECK_VAR) CHARTS_DIR CHART_NAME CHARTS_NAMESPACE
	@$(eval CUR_CHART_VERSION=`helm show chart ${CHARTS_DIR}/${CHART_NAME} | sed -n -E -e "s/(^version:[[:blank:]]*)([[:graph:]]+)([[:blank:]]*\r?)/\2/p"`)
	@if [ -z "${CUR_CHART_VERSION}" ]; then\
		echo "unable to extract chart version from \"${CHARTS_DIR}/${CHART_NAME}\"";\
		exit 1;\
	fi;
	@echo "current version of chart \"${CHARTS_DIR}/${CHART_NAME}\" is \"${CUR_CHART_VERSION}\""
	@if helm show chart --version "${CUR_CHART_VERSION}" oci://${CHARTS_NAMESPACE}/${CHART_NAME} > /dev/null; then\
  		echo "oci://${CHARTS_NAMESPACE}/${CHART_NAME}:${CUR_CHART_VERSION} already exists at remote. Skipping";\
	else\
		helm package ${CHARTS_DIR}/${CHART_NAME} --dependency-update --destination ./tmp;\
		helm push "./tmp/${CHART_NAME}-${CUR_CHART_VERSION}.tgz" oci://${CHARTS_NAMESPACE};\
	fi

.PHONY: update-chart-deps
update-chart-deps:
	@$(CHECK_VAR) CHARTS_DIR CHART_NAME
	@helm dependency update ${CHARTS_DIR}/${CHART_NAME}

.PHONY: test-chart
test-chart: update-chart-deps
	@$(CHECK_VAR) CHARTS_DIR CHART_NAME
	@helm lint --with-subcharts ${CHARTS_DIR}/${CHART_NAME}

# set Chart.yaml(appVersion) = API_TAG, increment Chart.yaml(version) if API_TAG changed
.PHONY: update-chart-version
update-chart-version:
	@$(CHECK_VAR) CHARTS_DIR CHART_NAME
	$(BUILD_SUPPORT_DIR)/update_chart_version.sh ${TAG} ${CHARTS_DIR}/${CHART_NAME}/Chart.yaml
