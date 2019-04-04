SHELL := /bin/bash

STACKNAME = EnergicosTest
STACKBUCKET = energicostestbucket

checkgit:
	@if ! [ -x "$$(command -v git)" ]; then \
          echo 'Error: git is not installed.' >&2;\
          exit 1;\
     fi;

checknode:
	@if ! [ -x "$$(command -v npm)" ]; then \
          echo 'Error: nodejs is not installed.' >&2;\
          exit 1;\
     fi;
checkpython:
	@if ! [[ -x "$$(command -v python)" ]]; then \
       echo 'Error: python is not installed.' >&2; \
       exit 1; \
     fi

checkpip:
	@if ! [[ -x "$$(command -v pip)" ]]; then \
       echo 'Error: pip is not installed.' >&2; \
       exit 1; \
     fi

checkaws:
	@if ! [[ -x "$$(command -v aws)" ]]; then \
       pip install awscli; \
       echo "You need to Configure the AWS CLI."; \
       echo "Opening browser..."; \
       open https://docs.aws.amazon.com/rekognition/latest/dg/setting-up.html; \
       aws configure; \
       echo "Thank you!"; \
     fi

checkbucket:
	@if aws s3 ls s3://$(STACKBUCKET) 2>&1 | grep -q 'NoSuchBucket'; then \
		aws s3 mb s3://$(STACKBUCKET); \
    fi

updatebucket: checkbucket
	aws s3 sync cloudformation s3://$(STACKBUCKET);

toolcheck: checkgit checkpython checkpip checkaws checknode
	@echo 'Available tool checking successful'

validatetemplate:
	@for filename in cloudformation/*.yaml; do \
		echo $$filename; \
		aws cloudformation validate-template --template-body  file://$$filename; \
	done;

stackexists:
	@if aws cloudformation describe-stacks --stack-name $(STACKNAME) &>/dev/null; then \
        echo "Stack Exists"; \
    else \
		echo "Stack doesn't exist"; \
		exit 1; \
	 fi

stackdoesntexist:
	@if !aws cloudformation describe-stacks --stack-name $(STACKNAME) &>/dev/null; then \
            echo "Stack Doesn't Exist" \
    else \
    	echo "Stack exists"; \
    	exit 1; \
    fi

deploy: toolcheck stackdoesntexist validatetemplate updatebucket
	@echo 'Setting up Master Stack'
	@aws cloudformation create-stack  --stack-name $(STACKNAME)  --parameters ParameterKey=BucketName,ParameterValue=$(STACKBUCKET),UsePreviousValue=true --capabilities CAPABILITY_AUTO_EXPAND CAPABILITY_NAMED_IAM CAPABILITY_IAM   --template-body file://cloudformation/Master.yaml
	@echo "Waiting for Completetion..."
	@aws cloudformation wait stack-create-complete --stack-name $(STACKNAME)
	@echo "Stack Deploy Complete!"

teardown: toolcheck stackexists
	@echo "Tearing down Stack"
	@aws cloudformation delete-stack --stack-name $(STACKNAME)
	@echo "Waiting for Stack Deletion to complete..."
	@aws cloudformation wait stack-delete-complete --stack-name $(STACKNAME)
	@-aws s3 rb s3://$(STACKBUCKET) --force
	@echo "Stack Delete Complete"

