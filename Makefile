.PHONY: setup deploy setup-pre deploy-pre

setup: message_lambda.zip
	terraform plan -out=terraform.apply

clean:
	rm message_lambda.zip terraform.apply vendor/noticast_web/ansible/vars/terraform.json || true

message_lambda.zip:
	cd vendor/message-lambda/libs && \
		zip -r9 ../../../message_lambda.zip *
	cd vendor/message-lambda && \
		zip -g ../../message_lambda.zip lambda_function.py

setup-pre:
	terraform plan -target aws_route53_zone.primary -out terraform.pre.apply pre/

deploy:
	terraform apply terraform.apply
	terraform output -json > vendor/noticast_web/ansible/vars/terraform.json
	ansible-playbook vendor/noticast_web/ansible/main.yml

deploy-pre:
	terraform apply terraform.pre.apply
