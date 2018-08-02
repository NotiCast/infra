.PHONY: setup deploy setup-pre deploy-pre

setup:
	terraform plan -out=terraform.apply

setup-pre:
	terraform plan -target aws_route53_zone.primary -out terraform.pre.apply pre/

deploy:
	terraform apply terraform.apply
	terraform output -json > vendor/noticast_web/ansible/vars/terraform.json
	ansible-playbook vendor/noticast_web/ansible/main.yml

deploy-pre:
	terraform apply terraform.pre.apply
