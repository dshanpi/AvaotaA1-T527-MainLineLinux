.PHONY: bootstrap check build verify package clean

bootstrap:
	./scripts/bootstrap.sh

check:
	./scripts/check-repository.sh

build:
	./scripts/build.sh

verify:
	./scripts/verify-artifacts.sh

package:
	./scripts/package-release.sh

clean:
	./scripts/clean.sh
