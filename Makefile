.PHONY: doc
doc:
	a2x -f xhtml README.asciidoc

.PHONY: man
man:
	a2x -f manpage README.asciidoc -D man/
	gzip -f man/*.1

.PHONY: clean
clean:
	rm *.1
