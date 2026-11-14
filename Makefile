TF_DIRS := terraform/environments/dev terraform/environments/staging terraform/environments/prod
CHART := helm/charts/trakr
HELM_VALUES := $(CHART)/values-dev.yaml $(CHART)/values-staging.yaml $(CHART)/values-prod.yaml

.PHONY: fmt fmt-check terraform-validate helm-lint helm-template

fmt:
	terraform fmt -recursive terraform

fmt-check:
	terraform fmt -check -recursive terraform

terraform-validate:
	@for dir in $(TF_DIRS); do \
		echo "==> $$dir"; \
		terraform -chdir=$$dir init -backend=false -input=false >/dev/null; \
		terraform -chdir=$$dir validate; \
	done

helm-lint:
	helm dependency build $(CHART)
	@for values in $(HELM_VALUES); do \
		echo "==> $$values"; \
		helm lint $(CHART) --values $(CHART)/values.yaml --values $$values; \
	done

helm-template:
	helm dependency build $(CHART)
	@for values in $(HELM_VALUES); do \
		echo "==> $$values"; \
		helm template trakr $(CHART) --values $(CHART)/values.yaml --values $$values >/dev/null; \
	done
