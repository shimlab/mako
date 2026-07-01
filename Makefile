.PHONY: serve build clean

serve:
	uv run mkdocs serve

build:
	uv run mkdocs build
	find content -name '*.md' -type f | sort | xargs cat > site/llms.md

clean:
	rm -rf site
