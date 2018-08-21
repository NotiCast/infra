.PHONY: setup deploy setup-pre deploy-pre deploy-terraform deploy-ansible \
	fullclean clean

PYTHON_VERSION ?= python3.6
LAMBDA_FILES = lambda_function.py rds_models/*
ANSIBLE_JSON_FILE = vendor/noticast_web/ansible/vars/terraform.json
# Change to release *versions*
NOTICAST_WEB_VERSION = master
NOTICAST_WEB_REPO = git+https://github.com/NotiCast/web@$(NOTICAST_WEB_VERSION)

setup: message_lambda.zip
	terraform plan -out=terraform.apply

fullclean: clean
	rm message_lambda.zip

clean:
	rm terraform.apply hosts $(ANSIBLE_JSON_FILE) || true

message_lambda.zip:
	cd vendor/message-lambda/libs/lib/$(PYTHON_VERSION)/site-packages && \
		zip -r9 ../../../../../../message_lambda.zip *
	cd vendor/message-lambda && \
		zip -g ../../message_lambda.zip $(LAMBDA_FILES)

setup-pre:
	terraform plan -target aws_route53_zone.primary -out \
		terraform.pre.apply pre/

deploy: deploy-terraform deploy-ansible

deploy-terraform:
	terraform apply terraform.apply

$(ANSIBLE_JSON_FILE):
	terraform output -json > $(ANSIBLE_JSON_FILE)

hosts: $(ANSIBLE_JSON_FILE)
	echo '[noticast_web]' > hosts
	jq -r '.noticast_ips.value[]' < $(ANSIBLE_JSON_FILE) >> hosts
	echo >> hosts
	echo '[noticast_web:vars]' >> hosts
	echo noticast_package=$(NOTICAST_WEB_REPO) >> hosts

deploy-ansible: $(ANSIBLE_JSON_FILE) hosts
	ansible-playbook vendor/noticast_web/ansible/main.yml

deploy-pre:
	terraform apply terraform.pre.apply
