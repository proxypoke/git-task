.PHONY: doc
doc:
	a2x -f manpage README.asciidoc

.PHONY: clean
clean:
	rm *.1
