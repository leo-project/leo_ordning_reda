%%====================================================================
%%
%% Leo Ordning Reda
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
%% Leo Ordning Reda - Property TEST
%% @doc
%% @end
%%====================================================================
-module(leo_ordning_reda_api_prop).

-author('Yosuke Hara').

-include_lib("proper/include/proper.hrl").
-include_lib("eunit/include/eunit.hrl").

-behaviour('proper_statem').

-export([initial_state/0,
         command/1,
         precondition/2,
         next_state/3,
         postcondition/3]).


-type ordning_reda_type() :: 'stack'.

-record(state, {stored = []  :: [string()],  %% list of object in an inner proces
                type         :: ordning_reda_type()
               }).
-define(UNIT, "ordning-reda").
-define(KEYS, lists:map(fun(N) ->
                                list_to_binary(
                                  integer_to_list(N))
                        end, lists:seq(0, 100))).
-define(BUF_SIZE, 10000).
-define(TIMEOUT,   1000).


%% @doc Utils
%%
key() ->
    frequency([{1, elements(?KEYS)}]).

value() ->
    crypto:rand_bytes(1024).


%% @doc Property TEST
%%
prop_stack() ->
    ?FORALL(Type, noshrink(ordning_reda_type()),
            ?FORALL(Cmds, commands(?MODULE, initial_state(Type)),
                    begin
                        leo_ordning_reda_api:start(),
                        ok = leo_ordning_reda_stack:start_link(?UNIT, ?BUF_SIZE, ?TIMEOUT),

                        {H,S,Res} = run_commands(?MODULE, Cmds),

                        application:stop(leo_ordning_reda),
                        ?WHENFAIL(
                           io:format("History: ~p\nState: ~p\nRes: ~p\n", [H,S,Res]),
                           collect(Type, Res =:= ok))
                    end)).


%% @doc Initialize state
%%
initial_state() ->
    #state{}.
initial_state(Type) ->
    #state{type = Type}.


%% @doc Command
%%
command(_S) ->
    Cmd0 = [{call, leo_ordning_reda_api, stack, [?UNIT, key(), value()]}],
    oneof(Cmd0).


%% @doc Pre-Condition
%%
precondition(_S, {call,_,_,_}) ->
    true.


%% @doc Next-State
%%
next_state(S, _V, {call,_,stack,[_Unit, Key, _Object]}) ->
    case proplists:is_defined(Key, S#state.stored) of
        false ->
            S#state{stored = S#state.stored ++ [Key]};
        true ->
            S
    end;

next_state(S, _V, {call,_,_,_}) ->
    S.


%% @doc Post-Condition
%%
postcondition(_S,_V,_) ->
    true.
