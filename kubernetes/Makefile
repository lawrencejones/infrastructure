.PHONY: deploy set-context

# validate=false is required due to cert-manager issues
deploy: set-context
	kustomize build . | kubectl apply --validate=false -f -

set-context:
	kubectl config use-context lawrjone
