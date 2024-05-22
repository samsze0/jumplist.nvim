test:
	export $$(cat .env | xargs) && ./scripts/run_tests.sh