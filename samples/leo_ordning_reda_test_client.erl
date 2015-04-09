-module(leo_ordning_reda_test_client).

-include("leo_ordning_reda.hrl").
-include_lib("eunit/include/eunit.hrl"). % for debug

-define(BUFSIZE, 100). %% 100B
-define(TIMEOUT, 100). %% 0.1sec

-export([main/0, output/1]).

main() ->
    Node = node(),
    ok = leo_ordning_reda_api:start(),
    ok = leo_ordning_reda_test_server:start_link(Node, ?BUFSIZE, ?TIMEOUT),
    ok = leo_ordning_reda_test_server:stack(Node, "key1", lists:seq(1,10)),
    ok = leo_ordning_reda_test_server:stack(Node, "key2", lists:seq(11,20)),
    ok = leo_ordning_reda_test_server:stack(Node, "key3", lists:seq(21,30)),
    timer:sleep(2000),
    ok = leo_ordning_reda_test_server:stop(Node),
    ok = application:stop(leo_ordning_reda),
    ok.

-spec(output(binary()) ->
             ok).
output(CompressedBin) ->
    Fun = fun(Obj) ->
                  io:format("~p~n",[Obj])
          end,
    ok = leo_ordning_reda_api:unpack(CompressedBin, Fun).
