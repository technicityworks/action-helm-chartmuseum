#!/bin/bash -l
set -eo pipefail

export HELM_VERSION=${HELM_VERSION:="3.9.1"}
export HELM_PUSH_PLUGIN_VERSION=${HELM_PUSH_PLUGIN_VERSION:="v0.10.3"}
export CHART_VERSION=${CHART_VERSION:-}

print_title() {
    echo "#####################################################"
    echo "$1"
    echo "#####################################################"
}

fix_chart_version() {
    if [[ -z "$CHART_VERSION" ]]; then
        print_title "Calculating chart version"
        echo "Installing prerequisites"
        pip3 install PyYAML
        pushd "$CHART_DIR"
        CANDIDATE_VERSION=$(python3 -c "import yaml; f=open('Chart.yaml','r');  p=yaml.safe_load(f.read()); print(p['version']); f.close()")
        popd
        echo "${GITHUB_EVENT_NAME}"
        if [ "${GITHUB_EVENT_NAME}" == "pull_request" ]; then
            CHART_VERSION="${CANDIDATE_VERSION}-$(git rev-parse --short "$GITHUB_SHA")"
        else
            CHART_VERSION="${CANDIDATE_VERSION}"
        fi
        export CHART_VERSION
    fi
}

get_helm() {
    print_title "Get helm:${HELM_VERSION}"
    curl -L "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" | tar xvz
    chmod +x linux-amd64/helm
    sudo mv linux-amd64/helm /usr/local/bin/helm
}

install_helm() {
    if ! command -v helm; then
        echo "Helm is missing"
        get_helm
    elif ! [[ $(helm version --short -c) == *${HELM_VERSION}* ]]; then
        echo "Helm $(helm version --short -c) is not desired version"
        get_helm
    fi
}

install_helm_push_plugin() {
    print_title "Install Chartmuseum helm push plugin"
    if ! (helm plugin list | grep -q cm-push); then
        helm plugin install https://github.com/chartmuseum/helm-push --version ${HELM_PUSH_PLUGIN_VERSION}
    fi
}

install_versio_plugin() {
    print_title "Install helm versio plugin"
    if ! (helm plugin list | grep -q versio); then
        PLUGIN_DIR=$(dirname -- "$(readlink -f "${BASH_SOURCE[0]}" || realpath "${BASH_SOURCE[0]}")")
        helm plugin install "$PLUGIN_DIR/versio-helm-plugin"
    fi
}

remove_helm() {
    helm plugin uninstall cm-push
    sudo rm -rf /usr/local/bin/helm
}

helm_dependency() {
    print_title "Helm dependency build"
    helm dependency build "${CHART_DIR}"
}

helm_lint() {
    print_title "Linting"
    helm lint "${CHART_DIR}"
    helm repo add target "${REGISTRY_URL}" --username "${REGISTRY_USERNAME}" --password "${REGISTRY_PASSWORD}"
    helm versio validate "${CHART_DIR}" target
}

helm_package() {
    print_title "Packaging"
    helm package "${CHART_DIR}" --version v"${CHART_VERSION}" --app-version "${CHART_VERSION}" --destination "${RUNNER_WORKSPACE}"
}

helm_push() {
    print_title "Push chart"
    helm cm-push "${CHART_DIR}" "${REGISTRY_URL}" --username "${REGISTRY_USERNAME}" --password "${REGISTRY_PASSWORD}" --version "${CHART_VERSION}"
}
