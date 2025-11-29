.PHONY: help install test lint clean mock-server dev build-release

help:
	@echo "CommuteTimely - Makefile Commands"
	@echo "=================================="
	@echo "make install      - Install dependencies and resolve SPM packages"
	@echo "make test         - Run unit and UI tests"
	@echo "make lint         - Run SwiftLint"
	@echo "make clean        - Clean build artifacts"
	@echo "make mock-server  - Start Python Flask prediction server"
	@echo "make dev          - Build for development (simulator)"
	@echo "make build-release - Build release configuration"

install:
	@echo "📦 Installing dependencies..."
	@echo "Resolving Swift Package dependencies..."
	xcodebuild -resolvePackageDependencies -project ios/CommuteTimely.xcodeproj
	@echo "✅ Dependencies installed"

test:
	@echo "🧪 Running tests..."
	xcodebuild test \
		-project ios/CommuteTimely.xcodeproj \
		-scheme CommuteTimely \
		-destination 'platform=iOS Simulator,name=iPhone 15' \
		-enableCodeCoverage YES \
		| xcpretty || exit 1
	@echo "✅ Tests passed"

lint:
	@echo "🔍 Running SwiftLint..."
	@if command -v swiftlint >/dev/null 2>&1; then \
		swiftlint --config config/.swiftlint.yml; \
	else \
		echo "⚠️  SwiftLint not installed. Run: brew install swiftlint"; \
		exit 1; \
	fi

clean:
	@echo "🧹 Cleaning build artifacts..."
	xcodebuild clean \
		-project ios/CommuteTimely.xcodeproj \
		-scheme CommuteTimely
	rm -rf DerivedData
	@echo "✅ Clean complete"

mock-server:
	@echo "🚀 Starting mock prediction server..."
	@cd server && \
	if [ ! -d "venv" ]; then \
		echo "Creating virtual environment..."; \
		python3 -m venv venv; \
		. venv/bin/activate && pip install -r requirements.txt; \
	fi && \
	. venv/bin/activate && python app.py

dev:
	@echo "🔨 Building for development..."
	xcodebuild \
		-project ios/CommuteTimely.xcodeproj \
		-scheme CommuteTimely \
		-configuration Debug \
		-destination 'platform=iOS Simulator,name=iPhone 15' \
		build
	@echo "✅ Development build complete"

build-release:
	@echo "🚀 Building release configuration..."
	xcodebuild \
		-project ios/CommuteTimely.xcodeproj \
		-scheme CommuteTimely \
		-configuration Release \
		-destination generic/platform=iOS \
		build
	@echo "✅ Release build complete"

