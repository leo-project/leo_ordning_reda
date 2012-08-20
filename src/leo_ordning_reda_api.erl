%%======================================================================
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
%%======================================================================
-module(leo_ordning_reda_api).

-author('Yosuke Hara').

-include("leo_ordning_reda.hrl").
-include_lib("eunit/include/eunit.hrl").


%% Application callbacks
-export([start/0, add_container/3, remove_container/2, has_container/2,
         stack/3, stack/4]).

-define(PREFIX, "leo_ordning_reda_").

%%--------------------------------------------------------------------
%% API
%%--------------------------------------------------------------------
%% @doc Launch
%%
-spec(start() ->
             ok | {error, any()}).
start() ->
    start_app().


%% @doc Add a container into the App
%%
-spec(add_container(stack, atom(), list()) ->
             ok | {error, any()}).
add_container(stack = Type, Node, Options) ->
    Id = gen_id(Type, Node),
    BufSize  = proplists:get_value('buffer_size', Options, ?DEF_BUF_SIZE),
    Timeout  = proplists:get_value('timeout',     Options, ?REQ_TIMEOUT),
    Fun0     = proplists:get_value('sender',      Options),
    Fun1     = proplists:get_value('recover',     Options),

    Args = [Id, stack, #stack_info{node     = Node,
                                   buf_size = BufSize,
                                   timeout  = Timeout,
                                   sender   = Fun0,
                                   recover  = Fun1}],
    ChildSpec = {Id,
                 {leo_ordning_reda_server, start_link, Args},
                 permanent, 2000, worker, [leo_ordning_reda_server]},

    case supervisor:start_child(leo_ordning_reda_sup, ChildSpec) of
        {ok, _Pid} ->
            ok;
        {error, Cause} ->
            {error, Cause}
    end.


%% @doc Remove a container from the App
%%
-spec(remove_container(stack, atom()) ->
             ok | {error, any()}).
remove_container(stack = Type, Node) ->
    Id = gen_id(Type, Node),
    catch supervisor:terminate_child(leo_ordning_reda_sup, Id),
    catch supervisor:delete_child(leo_ordning_reda_sup, Id),
    ok.


%% @doc Has a container into the App
%%
-spec(has_container(stack, atom()) ->
             true | false).
has_container(stack = Type, Node) ->
    whereis(gen_id(Type, Node)) /= undefined.


%% @doc Stack an object into the proc
%%
-spec(stack(atom(), string(),binary()) ->
             ok | {error, any()}).
stack(Node, Key, Object) ->
    stack(Node, -1, Key, Object).

-spec(stack(atom(), integer(), string(),binary()) ->
             ok | {error, any()}).
stack(Node, AddrId, Key, Object) ->
    Type = stack,
    Id = gen_id(Type, Node),
    case has_container(Type, Node) of
        true ->
            leo_ordning_reda_server:stack(Id, AddrId, Key, Object);
        false ->
            {error, undefined}
    end.


%%--------------------------------------------------------------------
%% INNTERNAL FUNCTIONS
%%--------------------------------------------------------------------
%% @doc Launch the ordning-reda application
%% @private
-spec(start_app() ->
             ok | {error, any()}).
start_app() ->
    Module = leo_ordning_reda,
    case application:start(Module) of
        ok ->
            case ets:info(?ETS_TAB_STACK_PID) of
                undefined ->
                    ?ETS_TAB_STACK_PID =
                        ets:new(?ETS_TAB_STACK_PID,
                                [named_table, set, public, {read_concurrency, true}]),
                    ok;
                _ ->
                    ok
            end;
        {error, {already_started, Module}} ->
            ok;
        Error ->
            Error
    end.


%% @doc Generate Id
%%
-spec(gen_id(stack, atom()) ->
             string()).
gen_id(Type, Node) ->
    list_to_atom(
      lists:append(
        [?PREFIX, atom_to_list(Type), "_", atom_to_list(Node)])).

