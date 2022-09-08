ifndef VERBOSE
.SILENT:
endif

.PHONY: docs
docs:
	dart doc --validate-links

.PHONY: coverage
coverage:
	# Reference: https://pub.dev/packages/coverage
	dart pub global run coverage:test_with_coverage \
	  --function-coverage --branch-coverage
	genhtml coverage/lcov.info -o coverage/html

.PHONY: test
test:
	dart test/generate_sample_output.dart
	dart test
