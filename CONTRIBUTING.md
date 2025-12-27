# Contributing to CommuteTimely

Thank you for your interest in contributing to CommuteTimely! This document provides guidelines and instructions for contributing.

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/callmeumair/CommuteTimely-ios.git
   cd CommuteTimely
   ```
3. **Create a branch** for your changes:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## Development Setup

### Prerequisites

- Xcode 15.0+ (iOS 16.0+ target)
- macOS 13.0+ (Ventura)
- Swift 5.9+
- Python 3.8+ (for mock server)

### Initial Setup

1. **Configure API Keys:**
   ```bash
   cp ios/Resources/Secrets.template.xcconfig ios/Resources/Secrets.xcconfig
   # Edit ios/Resources/Secrets.xcconfig with your API keys
   ```

2. **Install Dependencies:**
   ```bash
   make install
   ```

3. **Start the Mock Server:**
   ```bash
   make mock-server
   ```

4. **Build the Project:**
   ```bash
   make dev
   ```

## Code Style

### Swift

- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use SwiftLint for consistency (run `make lint`)
- Prefer `let` over `var`
- Use meaningful variable names
- Comment complex logic, not obvious code
- Maximum line length: 120 characters

### Formatting

Run the formatter before committing:
```bash
./scripts/format.sh
```

## Testing

### Running Tests

```bash
# Run all tests
make test

# Run specific test suite
xcodebuild test \
  -project ios/CommuteTimely.xcodeproj \
  -scheme CommuteTimely \
  -destination 'platform=iOS Simulator,name=iPhone 15' \
  -only-testing:CommuteTimelyTests/YourTestClass
```

### Writing Tests

- Write unit tests for all new features
- Aim for >80% code coverage
- Use descriptive test names: `testFunctionName_WhenCondition_ShouldReturnExpectedResult`
- Follow AAA pattern: Arrange, Act, Assert

## Pull Request Process

1. **Update Documentation:**
   - Update README.md if needed
   - Add/update relevant documentation in `Documentation/`
   - Update CHANGELOG.md with your changes

2. **Ensure Tests Pass:**
   ```bash
   make test
   make lint
   ```

3. **Create Pull Request:**
   - Use a clear, descriptive title
   - Provide a detailed description of changes
   - Reference any related issues
   - Include screenshots for UI changes

4. **Code Review:**
   - Address review comments promptly
   - Keep commits focused and atomic
   - Squash commits if requested

## Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(<scope>): <subject>

<body>

<footer>
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

Example:
```
feat(trip-planner): Add support for recurring trips

Users can now set trips to repeat daily, weekly, or on specific days.
Includes UI updates and persistence layer changes.

Closes #123
```

## Project Structure

```
ios/
├── CommuteTimely/          # Main iOS app
│   ├── App/                # App entry, coordinators, DI
│   ├── Features/           # Feature modules (MVVM)
│   ├── Services/           # Business logic
│   ├── Models/             # Data models
│   └── DesignSystem/       # UI components
├── CommuteTimelyTests/     # Unit tests
└── CommuteTimelyUITests/   # UI tests

server/                     # Python Flask backend
ml/                         # ML training and models
Documentation/              # Project documentation
```

## Areas for Contribution

- **Bug Fixes**: Check open issues labeled "bug"
- **Features**: Check open issues labeled "enhancement"
- **Documentation**: Improve docs, add examples
- **Tests**: Increase test coverage
- **Performance**: Optimize slow code paths
- **UI/UX**: Improve user experience

## Questions?

- Open an issue for bug reports or feature requests
- Email: support@commutetimely.app
- Check `Documentation/` for detailed guides

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

