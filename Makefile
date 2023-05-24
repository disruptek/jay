repository := $(AWS_ACCOUNT_ID).dkr.ecr.$(AWS_REGION).amazonaws.com
tag := pray:jay
opts=--verbose --local --ldflags=-L$(HOME)/lib --cflags=-I$(HOME)/include

install:
	jpm $(opts) install

image:
	docker build --pull --tag $(tag) .

fresh:
	docker build --pull --tag $(tag) --no-cache .

push:
	aws ecr get-login-password --region $(AWS_REGION) | docker login --username AWS --password-stdin $(repository)
	docker tag $(tag) $(repository)/$(tag)
	docker push $(repository)/$(tag)

run:
	docker run --name jay --rm --interactive --tty --entrypoint /bin/sh $(tag)

clean:
	jpm $(opts) clean
	docker system prune --force --volumes

bang:
	make tests
	make image
	make push

tests: Makefile jay/*.janet test/*.janet
	make install
	jpm $(opts) test

repl:
	make install
	jpm $(opts) repl

deps:
	jpm $(opts) deps
