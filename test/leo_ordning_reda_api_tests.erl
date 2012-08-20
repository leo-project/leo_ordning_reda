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

ordning_reda_test_() ->
    {foreach, fun setup/0, fun teardown/1,
     [{with, [T]} || T <- [fun stack_and_send_0_/1,
                           fun stack_and_send_1_/1,
                           fun proper_/1
                          ]]}.

setup() ->
    %% prepare network
    [] = os:cmd("epmd -daemon"),
    {ok, Hostname} = inet:gethostname(),

    Me = list_to_atom("test_0@" ++ Hostname),
    net_kernel:start([Me, shortnames]),
    {ok, Node} = slave:start_link(list_to_atom(Hostname), 'node_0'),

    %% launch application
    ok = leo_ordning_reda_api:start(),
    Node.

teardown(Node) ->
    %% stop network
    net_kernel:stop(),
    slave:stop(Node),

    %% stop application
    ok = leo_ordning_reda_sup:stop(),
    ok = application:stop(leo_ordning_reda),
    ok.


stack_and_send_0_(Node) ->
    ok = leo_ordning_reda_api:add_container(
           stack, Node,
           [{buffer_size, (1000*10)}, {timeout, 1000}, {function, undefined}]),

    lists:foreach(fun(Obj) ->
                          ok = leo_ordning_reda_api:stack(Node, Obj)
                  end, [term_to_binary({<<"M0">>, crypto:rand_bytes(1024)}),
                        term_to_binary({<<"M1">>, crypto:rand_bytes(1024)}),
                        term_to_binary({<<"M2">>, crypto:rand_bytes(1024)}),
                        term_to_binary({<<"M3">>, crypto:rand_bytes(1024)}),
                        term_to_binary({<<"M4">>, crypto:rand_bytes(1024)}),
                        term_to_binary({<<"M5">>, crypto:rand_bytes(1024)}),
                        term_to_binary({<<"M6">>, crypto:rand_bytes(1024)}),
                        term_to_binary({<<"M7">>, crypto:rand_bytes(1024)}),
                        term_to_binary({<<"M8">>, crypto:rand_bytes(1024)}),
                        term_to_binary({<<"M9">>, crypto:rand_bytes(1024)})]),
    ok.

stack_and_send_1_(Node) ->
    ok = leo_ordning_reda_api:add_container(
           stack, Node,
           [{buffer_size, (1000*10)}, {timeout, 1000}, {function, undefined}]),

    lists:foreach(fun(Obj) ->
                          timer:sleep(1000),
                          ok = leo_ordning_reda_api:stack(Node, Obj)
                  end, [term_to_binary({<<"M10">>, crypto:rand_bytes(1024)}),
                        term_to_binary({<<"M11">>, crypto:rand_bytes(1024)}),
                        term_to_binary({<<"M12">>, crypto:rand_bytes(1024)})]),
    ok.

proper_(_) ->
    ok.

-endif.
