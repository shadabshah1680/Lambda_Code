SHELL := /bin/bash
COMMIT := $(shell git rev-parse --short HEAD)
SHORT_SHA=$(COMMIT)

.PHONY: layer role-policy function
FUNCTION_NAME=dockerized_lambda_check_open_ports
ECR_REPO_NAME=shadab

eks:

	aws eks update-kubeconfig --name ${EKS_CLUSTER_NAME} --region ${AWS_DEFAULT_REGION}

layer:
	mkdir lambda_package
	pip install openpyxl -t lambda_package
	cd lambda_package
	zip -r9 ../openpyxl-layer.zip .
	cd ..
	# zip -g lambda_package.zip ${FUNCTION_NAME}.py
	$(eval LAYER_ARN=$(aws lambda publish-layer-version --layer-name openpyxl --zip-file fileb://openpyxl-layer.zip --output text --query 'LayerArn'))
	echo ${LAYER_ARN} 
role-policy:
	cat role_policy.json | sed "s/BUCKET_NAME/${BUCKET_NAME}/g" > parsed-policy-document.json
	$(eval ROLE_ARN=$(aws iam create-role --role-name lambda-role-for-s3 --assume-role-policy-document file://parsed-policy-document.json --output text --query 'Role.Arn'))
	echo ${ROLE_ARN} 


function:
	zip -r9 lambda_function.zip ${FUNCTION_NAME}.py
	aws lambda create-function \
	--function-name ${FUNCTION_NAME} \
	--runtime python3.8 \
	--role ${ROLE_ARN} \
	--handler ${FUNCTION_NAME}.handler \
	--environment Variables="{BUCKET_NAME=${BUCKET_NAME}, OPEN_PORTS_FILE_NAME=${OPEN_PORTS_FILE_NAME}}" \
	--layers ${LAYER_ARN} \
	--zip-file fileb://lambda_function.zip
	
	

update-function:
	zip lambda_function.zip ${FUNCTION_NAME}.py
	aws lambda update-function-code \
	--function-name ${FUNCTION_NAME} \
	--zip-file fileb://lambda_function.zip
ecr-login:
	aws ecr get-login-password --region ${AWS_DEFAULT_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com
build:	
	docker build -t ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/${ECR_REPO_NAME}:${SHORT_SHA} .
push:
	docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/${ECR_REPO_NAME}:${SHORT_SHA}
update:
	aws lambda update-function-code --region ${AWS_DEFAULT_REGION} --function-name ${FUNCTION_NAME} --image-uri ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_DEFAULT_REGION}.amazonaws.com/${ECR_REPO_NAME}:${SHORT_SHA} --publish

