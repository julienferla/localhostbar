.PHONY: generate open clean

generate:
	xcodegen generate

open: generate
	open LocalHostBar.xcodeproj

clean:
	rm -rf LocalHostBar.xcodeproj DerivedData build
