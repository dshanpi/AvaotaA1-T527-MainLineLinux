.PHONY: bootstrap check build loader verify-loader verify package clean

bootstrap:
	./scripts/bootstrap.sh

check:
	./scripts/check-repository.sh

build:
	./scripts/build.sh

loader:
	./scripts/build-loader.sh

verify-loader:
	./scripts/verify-loader.sh

verify:
	./scripts/verify-artifacts.sh

package:
	./scripts/package-release.sh

clean:
	./scripts/clean.sh
