VERSION ?= v0.0.1

REGISTRY ?= docker.io/lmctague


docker: docker-build docker-push

docker-build:
	docker build . --target cli -t ${REGISTRY}/cli:${VERSION}
	docker build . --target cron -t ${REGISTRY}/cron:${VERSION}
	docker build . --target fpm_server -t ${REGISTRY}/fpm_server:${VERSION}
	docker build . --target web_server -t ${REGISTRY}/web_server:${VERSION}

docker-push:
	docker push ${REGISTRY}/cli:${VERSION}
	docker push ${REGISTRY}/cron:${VERSION}
	docker push ${REGISTRY}/fpm_server:${VERSION}
	docker push ${REGISTRY}/web_server:${VERSION}