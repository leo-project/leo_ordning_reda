-module(leo_ordning_reda_test_client_test).

-include("leo_ordning_reda.hrl").
-include_lib("eunit/include/eunit.hrl"). % for debug

-define(BUFSIZE, 1000). %% 1KB
-define(TIMEOUT, 1000). %% 1sec

-export([test_/0]).

test_() ->
    Node = node(),
    ok = leo_ordning_reda_api:start(),
    ok = leo_ordning_reda_test_server:start_link(Node, ?BUFSIZE, ?TIMEOUT),
    ok = leo_ordning_reda_api:stack(Node, "key1", term_to_binary(lists:seq(1,300))),
    ?debugVal({Node, "hey"}),
    ok = leo_ordning_reda_api:stack(Node, "key2", term_to_binary(lists:seq(301,600))),
    ?debugVal({Node, "hey2"}),
    ok = leo_ordning_reda_api:stack(Node, "key3", term_to_binary(lists:seq(601,900))),
    ?debugVal({Node, "hey3"}),
    ok = leo_ordning_reda_api:stop(Node),
    ok = application:stop(leo_ordning_reda),
    ok.
