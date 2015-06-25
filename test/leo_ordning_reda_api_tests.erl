%%====================================================================
%%
%% Leo Ordning & Reda
%%
%% Copyright (c) 2012-2015 Rakuten, Inc.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%% -------------------------------------------------------------------
%% Leo Ordning & Reda - TEST
%% @doc
%% @end
%%====================================================================
-module(leo_ordning_reda_api_tests).
-author('Yosuke Hara').

-include_lib("eunit/include/eunit.hrl").

%%--------------------------------------------------------------------
%% TEST FUNCTIONS
%%--------------------------------------------------------------------
-ifdef(EUNIT).

-define(BUF_SIZE, 5000).
-define(TIMEOUT,   500).

ordning_reda_test_() ->
    {foreach, fun setup/0, fun teardown/1,
     [{with, [T]} || T <- [fun stack_and_send_0_/1,
                           fun stack_and_send_1_/1,
                           fun stack_and_send_2_/1,
                           fun stack_and_send_3_/1,
                           fun stack_and_send_4_/1
                          ]]}.

setup() ->
    %% prepare
    os:cmd("rm work/ord_reda/*"),
    os:cmd("epmd -daemon"),
    {ok, Hostname} = inet:gethostname(),

    Me = list_to_atom("me@" ++ Hostname),
    net_kernel:start([Me, shortnames]),
    {ok, Node0} = slave:start_link(list_to_atom(Hostname), 'node_0'),
    {ok, Node1} = slave:start_link(list_to_atom(Hostname), 'node_1'),

    %% launch application
    ok = leo_ordning_reda_api:start(),
    {Node0, Node1}.

teardown({Node0, Node1}) ->
    %% stop network
    net_kernel:stop(),
    slave:stop(Node0),
    slave:stop(Node1),

    %% stop application
    catch leo_ordning_reda_sup:stop(),
    catch application:stop(leo_ordning_reda),
    ok.


stack_and_send_0_({Node0, Node1}) ->
    ok = leo_ordning_reda_stack:start_link(Node0, ?BUF_SIZE, ?TIMEOUT),
    ok = leo_ordning_reda_stack:start_link(Node1, ?BUF_SIZE, ?TIMEOUT),

    lists:foreach(fun({N, Key, Obj}) ->
                          ok  = leo_ordning_reda_api:stack(N, {-1, Key}, Obj)
                  end, [{Node0, "K0", crypto:rand_bytes(1024)},
                        {Node1, "K1", crypto:rand_bytes(1024)},
                        {Node0, "K0", crypto:rand_bytes(1024)}, %% duplicate-data
                        {Node0, "K2", crypto:rand_bytes(1024)},
                        {Node1, "K3", crypto:rand_bytes(1024)},
                        {Node0, "K4", crypto:rand_bytes(1024)},
                        {Node1, "K5", crypto:rand_bytes(1024)},
                        {Node0, "K6", crypto:rand_bytes(1024)},
                        {Node1, "K7", crypto:rand_bytes(1024)},
                        {Node0, "K8", crypto:rand_bytes(1024)},
                        {Node1, "K9", crypto:rand_bytes(1024)}
                       ]),
    timer:sleep(4000),
    ok.

stack_and_send_1_({Node0, Node1}) ->
    ok = leo_ordning_reda_stack:start_link(Node0, ?BUF_SIZE, ?TIMEOUT),
    ok = leo_ordning_reda_stack:start_link(Node1, ?BUF_SIZE, ?TIMEOUT),

    lists:foreach(fun({N, Key, Obj}) ->
                          ok = leo_ordning_reda_api:stack(N, {-1, Key}, Obj),
                          timer:sleep(1000)
                  end, [{Node0, "K10", crypto:rand_bytes(1024)},
                        {Node1, "K11", crypto:rand_bytes(1024)}
                       ]),
    ok = leo_ordning_reda_stack:stop(Node0),
    ok = leo_ordning_reda_stack:stop(Node1),
    ok.

stack_and_send_2_({Node0, Node1}) ->
    ok = leo_ordning_reda_stack_error:start_link(Node0, ?BUF_SIZE, ?TIMEOUT),
    ok = leo_ordning_reda_stack_error:start_link(Node1, ?BUF_SIZE, ?TIMEOUT),

    lists:foreach(fun({N, Key, Obj}) ->
                          ok = leo_ordning_reda_api:stack(N, {-1, Key}, Obj),
                          timer:sleep(1000)
                  end, [{Node0, "K12", crypto:rand_bytes(1024)},
                        {Node1, "K13", crypto:rand_bytes(1024)}
                       ]),
    ok = leo_ordning_reda_stack_error:stop(Node0),
    ok = leo_ordning_reda_stack_error:stop(Node1),
    ok.

stack_and_send_3_({Node0, Node1}) ->
    BufSize = 4096 * 8,
    ok = leo_ordning_reda_stack:start_link(Node0, BufSize, ?TIMEOUT),
    ok = leo_ordning_reda_stack:start_link(Node1, BufSize, ?TIMEOUT),

    lists:foreach(fun({N, Key, Obj}) ->
                          ok = leo_ordning_reda_api:stack(N, {-1, Key}, Obj)
                  end, [{Node0, "K10", crypto:rand_bytes(4096)},
                        {Node0, "K11", crypto:rand_bytes(4096)},
                        {Node0, "K12", crypto:rand_bytes(4096)},
                        {Node0, "K13", crypto:rand_bytes(4096)},
                        {Node0, "K14", crypto:rand_bytes(4096)},
                        {Node1, "K20", crypto:rand_bytes(4096)},
                        {Node1, "K21", crypto:rand_bytes(4096)},
                        {Node1, "K22", crypto:rand_bytes(4096)},
                        {Node1, "K23", crypto:rand_bytes(4096)},
                        {Node1, "K24", crypto:rand_bytes(4096)}
                       ]),
    ok = leo_ordning_reda_api:force_sending_obj(Node0),
    ok = leo_ordning_reda_api:force_sending_obj(Node1),
    ok = leo_ordning_reda_stack_error:stop(Node0),
    ok = leo_ordning_reda_stack_error:stop(Node1),
    ok.

stack_and_send_4_({Node0, Node1}) ->
    BufSize = 4096 * 8,
    ok = leo_ordning_reda_stack:start_link(Node0, BufSize, ?TIMEOUT),
    ok = leo_ordning_reda_stack:start_link(Node1, BufSize, ?TIMEOUT),

    lists:foreach(fun({N, Key, Obj}) ->
                          ok = leo_ordning_reda_api:stack(N, {-1, Key}, Obj)
                  end, [{Node0, "K10", crypto:rand_bytes(4096)},
                        {Node0, "K11", crypto:rand_bytes(4096)},
                        {Node0, "K12", crypto:rand_bytes(4096)},
                        {Node0, "K13", crypto:rand_bytes(4096)},
                        {Node0, "K14", crypto:rand_bytes(4096)},
                        {Node1, "K20", crypto:rand_bytes(4096)},
                        {Node1, "K21", crypto:rand_bytes(4096)},
                        {Node1, "K22", crypto:rand_bytes(4096)},
                        {Node1, "K23", crypto:rand_bytes(4096)},
                        {Node1, "K24", crypto:rand_bytes(4096)}
                       ]),
    ok = leo_ordning_reda_api:close_container(Node0),
    ok = leo_ordning_reda_api:close_container(Node1),

    lists:foreach(fun({N, Key, Obj}) ->
                          {error, not_available} = leo_ordning_reda_api:stack(N, {-1, Key}, Obj)
                  end, [{Node0, "K30", crypto:rand_bytes(4096)},
                        {Node0, "K31", crypto:rand_bytes(4096)},
                        {Node0, "K32", crypto:rand_bytes(4096)},
                        {Node0, "K33", crypto:rand_bytes(4096)},
                        {Node0, "K34", crypto:rand_bytes(4096)},
                        {Node1, "K40", crypto:rand_bytes(4096)},
                        {Node1, "K41", crypto:rand_bytes(4096)},
                        {Node1, "K42", crypto:rand_bytes(4096)},
                        {Node1, "K43", crypto:rand_bytes(4096)},
                        {Node1, "K44", crypto:rand_bytes(4096)}
                       ]),

    {ok, StateL_1} = leo_ordning_reda_api:restart_container(Node0),
    {ok, StateL_2} = leo_ordning_reda_api:restart_container(Node1),
    ?debugVal(StateL_1),
    ?debugVal(StateL_2),
    ?assertEqual(Node0, leo_misc:get_value('unit', StateL_1)),
    ?assertEqual(Node1, leo_misc:get_value('unit', StateL_2)),
    ?assertEqual(true, byte_size(leo_misc:get_value('stacked_obj', StateL_1, <<>>)) > 0),
    ?assertEqual(true, byte_size(leo_misc:get_value('stacked_obj', StateL_2, <<>>)) > 0),
    ?assertEqual(true, length(leo_misc:get_value('stacked_info', StateL_1, <<>>)) > 0),
    ?assertEqual(true, length(leo_misc:get_value('stacked_info', StateL_2, <<>>)) > 0),

    ok = leo_ordning_reda_api:force_sending_obj(Node0),
    ok = leo_ordning_reda_api:force_sending_obj(Node1),

    {ok, StateL_1_1} = leo_ordning_reda_api:state(Node0),
    {ok, StateL_2_1} = leo_ordning_reda_api:state(Node1),
    ?debugVal(StateL_1_1),
    ?debugVal(StateL_2_1),
    ?assertEqual(true, byte_size(leo_misc:get_value('stacked_obj', StateL_1_1, <<>>)) == 0),
    ?assertEqual(true, byte_size(leo_misc:get_value('stacked_obj', StateL_2_1, <<>>)) == 0),
    ?assertEqual(true, length(leo_misc:get_value('stacked_info', StateL_1_1, <<>>)) == 0),
    ?assertEqual(true, length(leo_misc:get_value('stacked_info', StateL_2_1, <<>>)) == 0),

    ok = leo_ordning_reda_stack_error:stop(Node0),
    ok = leo_ordning_reda_stack_error:stop(Node1),
    ok.


suite_test_() ->
    {setup,
     fun () ->
             ok
     end,
     fun (_) ->
             ok
     end,
     [
      {"check deletion of containers",
       {timeout, 180, fun remove_procs/0}}
     ]}.

remove_procs() ->
    %% === Launch procs ===
    %% prepare network
    [] = os:cmd("epmd -daemon"),
    {ok, Hostname} = inet:gethostname(),

    Me = list_to_atom("me@" ++ Hostname),
    net_kernel:start([Me, shortnames]),
    {ok, Node0} = slave:start_link(list_to_atom(Hostname), 'node_0'),
    {ok, Node1} = slave:start_link(list_to_atom(Hostname), 'node_1'),

    %% launch application
    ok = leo_ordning_reda_api:start(),

    %% === Check ===
    ok = leo_ordning_reda_stack:start_link(Node0, ?BUF_SIZE, ?TIMEOUT),
    {ok, _Size_1} = loop(1000, Node0, 0),
    timer:sleep(5000),

    _ = leo_ordning_reda_stack:start_link(Node0, ?BUF_SIZE, ?TIMEOUT),
    {ok, _Size_2} = loop(3, Node0, 0),
    timer:sleep(5000),

    ok = leo_ordning_reda_stack:start_link(Node1, ?BUF_SIZE, ?TIMEOUT),
    {ok, _Size_3} = loop(1000, Node1, 0),
    timer:sleep(5000),

    %% === Terminate procs ===
    %% stop network
    net_kernel:stop(),
    slave:stop(Node0),
    slave:stop(Node1),

    %% stop application
    ok = leo_ordning_reda_sup:stop(),
    ok = application:stop(leo_ordning_reda),
    ok.

loop(0, _, Sum) ->
    {ok, Sum};
loop(Index, Node, Sum) ->
    Key = lists:append(["key_", integer_to_list(Index)]),
    Obj = crypto:rand_bytes(erlang:phash2(Index, 1024)),
    Size = erlang:byte_size(Obj),
    _ = leo_ordning_reda_api:stack(Node, {-1, Key}, Obj),
    loop(Index - 1, Node, Sum + Size).

-endif.
