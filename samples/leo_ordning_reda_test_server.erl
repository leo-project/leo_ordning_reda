-module(leo_ordning_reda_test_server).

-behaviour(leo_ordning_reda_behaviour).

-include("leo_ordning_reda.hrl").
-include_lib("eunit/include/eunit.hrl"). % for debug

-export([start_link/3, stop/1]).
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


-spec handle_send(atom(), _, binary()) -> ok.
handle_send(Node, StackInfo, CompressedBin) ->
    ?debugVal({Node, length(StackInfo), byte_size(CompressedBin)}),
    Objects = leo_ordning_reda_api:unpack(CompressedBin),
    ?debugVal(Objects),
    ok.

-spec handle_fail(atom(), _) -> ok.
handle_fail(Node, StackInfo) ->
    ?debugVal({Node, length(StackInfo)}),
    ok.
