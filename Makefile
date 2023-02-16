SHELL := /bin/bash

.PHONY: layer role-policy function

layer:
	mkdir lambda_package
	pip install openpyxl -t lambda_package
	cd lambda_package
	zip -r9 ../openpyxl-layer.zip .
	cd ..
	# zip -g lambda_package.zip ${FUNCTION_NAME}.py
	$(eval LAYER_ARN=$(aws lambda publish-layer-version --layer-name openpyxl --zip-file fileb://openpyxl-layer.zip --output text --query 'LayerArn'))
role-policy:
	cat role_policy.json | sed "s/BUCKET_NAME/${BUCKET_NAME}/g" > parsed-policy-document.json
	$(eval ROLE_ARN=$(aws iam create-role --role-name lambda-role-for-s3 --assume-role-policy-document file://parsed-policy-document.json --output text --query 'Role.Arn'))

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
	zip -r9 lambda_function.zip ${FUNCTION_NAME}.py
	aws lambda update-function-code \
	--function-name ${FUNCTION_NAME} \
	--zip-file fileb://lambda_function.zip