MAINREPO:=robertmueller2/Scratch-Tables
#TARGETS:=$(shell if [ -e Targets ]; then cat Targets; fi)
TARGETS:=$(subst ~,${HOME},$(file < Targets))
HERE:=$(shell /bin/pwd)
DBDIR:=dupes

.PHONY: db-clean clean db file-clean mrproper

db: Targets $(DBDIR) $(foreach t,$(TARGETS),$(subst /,_,$(t)).sql.x)

$(DBDIR):
	dolt clone $(MAINREPO) $(DBDIR)
	cd $(DBDIR) && \
	dolt checkout -b $(DBDIR)

mrproper: clean
	rm -rf $(DBDIR)

clean: file-clean db-clean

file-clean:
	rm -f *.keys.txt *.sql *.sql.x

db-clean:
	cd $(DBDIR) && \
		echo "truncate KeysXFiles" | dolt sql

Targets: | Targets.example
	if [ ! -e "Targets" ]; then cp Targets.example $@ ; fi

define DYNAMICTARGETS

$(1).sql.x: $(1).sql $$(DBDIR)
	cd $$(DBDIR) && dolt sql < ../$(1).sql
	touch $$@

$(1).sql: $(1).keys.txt
	echo -n > $$@
	cat $$< | while IFS='|' read -r f t k ; do \
		echo -n 'INSERT INTO KeysXFiles (`UID_File`, `Ident_Repo`, `Path`, `Type`, `Annex_Key`) ' >> $$@ ; \
		echo "VALUES (UUID(), '$(1)', '$$$$f', '$$$$t', '$$$$k');" >> $$@ ; \
	done

$(1).keys.txt: $(2)
	cd $(2) ;\
	git annex find --include '*' --format='$$$${escaped_file}\000Annex\000$$$${escaped_keyname}\n' \
		| tr -d '|' | tr '\000' '|' | sed -e "s,',\\\',g" -e 's;\..\{1,10\}$$$$;;g' > $$(HERE)/$$@ ; \
	find . -path ./.git -prune -o -type f -print0 | xargs -r -0 sha256sum | awk '{ print $$$$2 "\0regular\0" $$$$1; }' \
		| cut -c 3- \
		| tr -d '|' | tr '\000' '|' | sed -e "s,',\\\',g" >> $$(HERE)/$$@ ;\
	cd - >/dev/null


endef

$(foreach t,$(TARGETS),$(eval $(call DYNAMICTARGETS,$(subst /,_,$(t)),$(t))))

