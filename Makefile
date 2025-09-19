.PHONY: render test clean

render:
	python3 render.py --output goose_egg.sh

# Ensure rendered script matches legacy reference
test: render
	./tests/test_render_matches_final.sh

clean:
	rm -f goose_egg.sh
