-module(leo_ordning_reda_test_client).

-include("leo_ordning_reda.hrl").
-include_lib("eunit/include/eunit.hrl"). % for debug

-define(BUFSIZE, 100). %% 100B
-define(TIMEOUT, 100). %% 0.1sec

-export([main/0]).

main() ->
    Node = node(),
    ok = leo_ordning_reda_api:start(),
    ok = leo_ordning_reda_test_server:start_link(Node, ?BUFSIZE, ?TIMEOUT),
    {ok, Bin1} = leo_ordning_reda_api:pack(lists:seq(1,10)),
    {ok, Bin2} = leo_ordning_reda_api:pack(lists:seq(11,20)),
    {ok, Bin3} = leo_ordning_reda_api:pack(lists:seq(21,30)),
    TotalSize = byte_size(Bin1) + byte_size(Bin2) + byte_size(Bin3),
    ?debugVal({"total:", TotalSize}),
    ok = leo_ordning_reda_api:stack(Node, "key1", Bin1),
    ok = leo_ordning_reda_api:stack(Node, "key2", Bin2),
    ok = leo_ordning_reda_api:stack(Node, "key3", Bin3),
    timer:sleep(2000),
    ok = leo_ordning_reda_test_server:stop(Node),
    ok = application:stop(leo_ordning_reda),
    ok.
