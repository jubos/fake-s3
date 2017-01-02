.PHONY: test

build-test-container:
	docker build -t fake-s3 .

test: build-test-container
	docker run --rm --add-host="posttest.localhost:127.0.0.1" -e "RUBYOPT=-W0" fake-s3 sh -c "rake test_server & rake test"
