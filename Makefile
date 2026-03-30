.PHONY: generate open clean dmg

generate:
	xcodegen generate

open: generate
	open LocalHostBar.xcodeproj

clean:
	rm -rf LocalHostBar.xcodeproj DerivedData build dist

dmg:
	chmod +x scripts/make-dmg.sh
	./scripts/make-dmg.sh
