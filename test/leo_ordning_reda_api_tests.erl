%%====================================================================
%%
%% Leo Ordning & Reda
%%
%% Copyright (c) 2012 Rakuten, Inc.
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
-define(TIMEOUT,  1000).

ordning_reda_test_() ->
    {foreach, fun setup/0, fun teardown/1,
     [{with, [T]} || T <- [fun stack_and_send_0_/1,
                           fun stack_and_send_1_/1,
                           fun stack_and_send_2_/1,
                           fun proper_/1
                          ]]}.

setup() ->
    %% prepare network
    [] = os:cmd("epmd -daemon"),
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
    ok = leo_ordning_reda_sup:stop(),
    ok = application:stop(leo_ordning_reda),
    ok.


stack_and_send_0_({Node0, Node1}) ->
    ok = leo_ordning_reda_stack:start_link(Node0, ?BUF_SIZE, ?TIMEOUT),
    ok = leo_ordning_reda_stack:start_link(Node1, ?BUF_SIZE, ?TIMEOUT),

    lists:foreach(fun({N, Key, Obj}) ->
                          ok = leo_ordning_reda_api:stack(N, Key, Obj)
                  end, [{Node0, "K0", term_to_binary({<<"M0">>, crypto:rand_bytes(1024)})},
                        {Node1, "K1", term_to_binary({<<"M1">>, crypto:rand_bytes(1024)})},
                        {Node0, "K2", term_to_binary({<<"M2">>, crypto:rand_bytes(1024)})},
                        {Node1, "K3", term_to_binary({<<"M3">>, crypto:rand_bytes(1024)})},
                        {Node0, "K4", term_to_binary({<<"M4">>, crypto:rand_bytes(1024)})},
                        {Node1, "K5", term_to_binary({<<"M5">>, crypto:rand_bytes(1024)})},
                        {Node0, "K6", term_to_binary({<<"M6">>, crypto:rand_bytes(1024)})},
                        {Node1, "K7", term_to_binary({<<"M7">>, crypto:rand_bytes(1024)})},
                        {Node0, "K8", term_to_binary({<<"M8">>, crypto:rand_bytes(1024)})},
                        {Node1, "K9", term_to_binary({<<"M9">>, crypto:rand_bytes(1024)})}
                       ]),
    ok = leo_ordning_reda_stack:stop(Node0),
    ok = leo_ordning_reda_stack:stop(Node1),
    ok.

stack_and_send_1_({Node0, Node1}) ->
    ok = leo_ordning_reda_stack:start_link(Node0, ?BUF_SIZE, ?TIMEOUT),
    ok = leo_ordning_reda_stack:start_link(Node1, ?BUF_SIZE, ?TIMEOUT),

    lists:foreach(fun({N, Key, Obj}) ->
                          ok = leo_ordning_reda_api:stack(N, Key, Obj),
                          timer:sleep(1000)
                  end, [{Node0, "K10", term_to_binary({<<"M10">>, crypto:rand_bytes(1024)})},
                        {Node1, "K11", term_to_binary({<<"M11">>, crypto:rand_bytes(1024)})}
                       ]),
    ok = leo_ordning_reda_stack:stop(Node0),
    ok = leo_ordning_reda_stack:stop(Node1),
    ok.

stack_and_send_2_({Node0, Node1}) ->
    ok = leo_ordning_reda_stack_error:start_link(Node0, ?BUF_SIZE, ?TIMEOUT),
    ok = leo_ordning_reda_stack_error:start_link(Node1, ?BUF_SIZE, ?TIMEOUT),

    lists:foreach(fun({N, Key, Obj}) ->
                          ok = leo_ordning_reda_api:stack(N, Key, Obj),
                          timer:sleep(1000)
                  end, [{Node0, "K12", term_to_binary({<<"M12">>, crypto:rand_bytes(1024)})},
                        {Node1, "K13", term_to_binary({<<"M13">>, crypto:rand_bytes(1024)})}
                       ]),
    ok = leo_ordning_reda_stack_error:stop(Node0),
    ok = leo_ordning_reda_stack_error:stop(Node1),
    ok.

proper_(_) ->
    ok.

-endif.
