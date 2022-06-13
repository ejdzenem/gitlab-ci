#!/usr/bin/env bats

[ -n "$TRACE" ] && set -x

function test_jaeger_inject_sidecar {
    env=$1
    target=$2

    test_dir="${PWD}/kubernetes/${env}"
    mkdir -p "${test_dir}"
    cp "${PWD}/test/test_files/${target}" "${test_dir}"
    cp "${PWD}/test/test_files/kustomization.yaml" "${test_dir}"
    run ./lib/jaeger-inject-sidecar.sh --env "${env}" --manifest-file "${target}" 2>/dev/null

    if [ "$status" -ne 0 ]; then
        echo "status_code: $status"
        echo "output: $output"
    fi

    run diff -u "${PWD}/test/test_files/kubernetes_deployment-jaeger-sidecar.yaml" \
        "${test_dir}/kubernetes_deployment-jaeger-sidecar.yaml"

    if [ "$status" -eq 0 ]; then
        rm -rf "${PWD}/kubernetes"
    else
        printf "unexpected diff:\n%s" "$output"
        false
    fi
}

@test "inject jaeger sidecar basic test" {
    test_jaeger_inject_sidecar "production" "kubernetes_deployment.yaml"
}
