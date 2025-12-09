.PHONY: all compile deps test eunit xref dialyzer check_plt build_plt typer doc clean distclean

REBAR := rebar3
APPS = erts kernel stdlib sasl crypto compiler inets mnesia public_key runtime_tools snmp syntax_tools tools xmerl ssl
LIBS = _build/default/lib/leo_commons/ebin
PLT_FILE = .leo_ordning_reda_dialyzer_plt
DOT_FILE = leo_ordning_reda.dot
CALL_GRAPH_FILE = leo_ordning_reda.png

all: compile xref eunit

compile:
	@$(REBAR) compile

deps:
	@$(REBAR) get-deps

xref:
	@$(REBAR) xref

eunit:
	@$(REBAR) eunit

test: eunit

check_plt:
	@$(REBAR) compile
	dialyzer --check_plt --plt $(PLT_FILE) --apps $(APPS)

build_plt:
	@$(REBAR) compile
	dialyzer --build_plt --output_plt $(PLT_FILE) --apps $(APPS) $(LIBS)

dialyzer:
	@$(REBAR) compile
	dialyzer --plt $(PLT_FILE) -r _build/default/lib/leo_ordning_reda/ebin/ --dump_callgraph $(DOT_FILE)

typer:
	typer --plt $(PLT_FILE) -I include/ -r src/

doc:
	@$(REBAR) edoc

callgraph: graphviz
	dot -Tpng -o$(CALL_GRAPH_FILE) $(DOT_FILE)

graphviz:
	$(if $(shell which dot),,$(error "To make the depgraph, you need graphviz installed"))

clean:
	@$(REBAR) clean

distclean:
	@rm -rf _build
	@$(REBAR) clean
