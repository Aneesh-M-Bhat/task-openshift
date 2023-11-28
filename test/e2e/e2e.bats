#!/usr/bin/env bats

source ./test/helper/helper.sh

# E2E tests parameters for the test pipeline

# Testing the openshift task,
@test "[e2e] openshift task" {
    [ -n "${E2E_OPENSHIFT_PARAMS_SCRIPT}" ]
    
    run kubectl delete taskrun --all
    assert_success

    kubectl delete secret regcred || true
    run kubectl create secret generic regcred \
        --from-file=.dockerconfigjson=$HOME/.docker/config.json \
        --type=kubernetes.io/dockerconfigjson
    assert_success
    run kubectl patch serviceaccount default -p '{"imagePullSecrets": [{"name": "regcred"}]}'
    assert_success

    run tkn task start openshift-client \
        --param="SCRIPT=${E2E_OPENSHIFT_PARAMS_SCRIPT}" \
	    --use-param-defaults \
	    --skip-optional-workspace \
        --showlog >&3
    assert_success

    # waiting a few seconds before asserting results
    sleep 15
    
    # assering the taskrun status, making sure all steps have been successful
    declare tmpl_file="${BASE_DIR}/go-template.tpl"
    # the following template is able to extract information from TaskRun and PipelineRun resources,
    # and as well supports the current Tekton Pipeline version using a different `.task.results`
    # attribute
    cat >${tmpl_file} <<EOS
{{- range .status.conditions }}
    {{- if and (eq .type "Succeeded") (eq .status "True") }}
        {{- printf "%s\n" .message -}}
    {{- end -}}
{{- end }}
{{- range .status.results }}
    {{- printf "%s=%s\n" .name .value -}}
{{- end -}}
EOS

    run tkn taskrun describe --last --output=go-template-file --template=${tmpl_file}
    assert_success
    assert_output "All Steps have completed executing"
}