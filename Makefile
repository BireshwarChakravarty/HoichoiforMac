.PHONY: app run debug icon clean

# Build the universal, ad-hoc signed .app into ./build and a zip into ./dist
app:
	./scripts/build-app.sh

# Build for this Mac's architecture only, then open the app
run:
	ARCHS="$$(uname -m)" ./scripts/build-app.sh
	open "build/Hoichoi for Mac.app"

# Run a debug build straight from SwiftPM (Web Inspector enabled)
debug:
	swift run

# Regenerate Resources/AppIcon.icns (needs Pillow)
icon:
	python3 scripts/make_icon.py

clean:
	rm -rf .build build dist
