build:
	mkdir -p build bin && gnatmake -gnat2012 -gnata -O2 -Wall -D build -o bin/card-scan src/card_scan_cli.adb

test: build
	mkdir -p build && gnatmake -gnat2012 -gnata -O2 -Wall -D build -o build/test tests/test_card_scan.adb -Isrc && ./build/test

sample: build
	mkdir -p docs site
	./bin/card-scan examples/data > docs/sample-output.txt; true
	./bin/card-scan examples/data --tsv > docs/sample-output.tsv; true
	python3 scripts/site.py docs/sample-output.tsv site/index.html "card-scan" "Finds payment card numbers (PANs) in files for PCI DSS scoping. Never prints a full number. Ada." "Synthetic files with public test card numbers and invented numbers."
