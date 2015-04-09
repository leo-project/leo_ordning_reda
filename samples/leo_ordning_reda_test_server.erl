-module(leo_ordning_reda_test_server).

-behaviour(leo_ordning_reda_behaviour).

-include("leo_ordning_reda.hrl").
-include_lib("eunit/include/eunit.hrl"). % for debug

-export([start_link/3, stop/1, stack/3]).
-export([handle_send/3,
         handle_fail/2]).

-spec start_link(atom(), integer(), integer()) -> ok | {error, _}.
start_link(Node, BufSize, Timeout) ->
    leo_ordning_reda_api:add_container(Node, [{module,      ?MODULE},
                                              {buffer_size, BufSize},
                                              {timeout,     Timeout}]).

-spec stop(atom()) -> ok | {error, _}.
stop(Node) ->
    leo_ordning_reda_api:remove_container(Node).

-spec stack(atom(), _, _) -> ok.
stack(Node, Key, Object) ->
    {ok, Bin} = leo_ordning_reda_api:pack(Object),
    ok = leo_ordning_reda_api:stack(Node, Key, Bin),
    ok.

-spec handle_send(atom(), _, binary()) -> ok.
handle_send(Node, StackInfo, CompressedBin) ->
    Res = rpc:call(Node, leo_ordning_reda_test_client, output, [CompressedBin]),
    ?debugVal({Res, Node, length(StackInfo), byte_size(CompressedBin)}),
    ok.

-spec handle_fail(atom(), _) -> ok.
handle_fail(Node, StackInfo) ->
    ?debugVal({Node, length(StackInfo)}),
    ok.
