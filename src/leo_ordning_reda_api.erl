%%======================================================================
%%
%% Leo Ordning & Reda
%%
%% Copyright (c) 2012-2014 Rakuten, Inc.
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
-export([start/0, stop/0,
         add_container/2, remove_container/1, has_container/1,
         stack/3, stack/4]).

-define(PREFIX, "leo_ord_reda_").

-ifdef(TEST).
-define(out_put_info_log(_Fun, _Unit),
        error_logger:info_msg("~p,~p,~p,~p~n",
                              [{module, ?MODULE_STRING},
                               {function, _Fun},
                               {line, ?LINE}, {body, _Unit}])).
-else.
-define(out_put_info_log(_Fun,_Unit), ok).
-endif.


%%--------------------------------------------------------------------
%% API
%%--------------------------------------------------------------------
%% @doc Launch the application
%%
-spec(start() ->
             ok | {error, any()}).
start() ->
    start_app().


%% @doc Stop the application
%%
-spec(stop() ->
             ok | {error, any()}).
stop() ->
    leo_ordning_reda_sup:stop().


%% @doc Add a container into the App
%%
-spec(add_container(atom(), list()) ->
             ok | {error, any()}).
add_container(Unit, Options) ->
    Id = gen_id(Unit),
    Module  = leo_misc:get_value('module',      Options),
    BufSize = leo_misc:get_value('buffer_size', Options, ?DEF_BUF_SIZE),
    Timeout = leo_misc:get_value('timeout',     Options, ?REQ_TIMEOUT),
    TmpStackedDir = ?env_temp_stacked_dir(),

    Args = [Id, #stack_info{unit     = Unit,
                            module   = Module,
                            buf_size = BufSize,
                            timeout  = Timeout,
                            tmp_stacked_dir = TmpStackedDir
                           }],
    ChildSpec = {Id,
                 {leo_ordning_reda_server, start_link, Args},
                 temporary, 2000, worker, [leo_ordning_reda_server]},

    case supervisor:start_child(leo_ordning_reda_sup, ChildSpec) of
        {ok, _Pid} ->
            ok;
        {error, Cause} ->
            {error, Cause}
    end.


%% @doc Remove a container from the App
%%
-spec(remove_container(atom()) ->
             ok | {error, any()}).
remove_container(Unit) ->
    Id = gen_id(Unit),
    catch supervisor:terminate_child(leo_ordning_reda_sup, Id),
    catch supervisor:delete_child(leo_ordning_reda_sup, Id),
    ?out_put_info_log("remove_container/1", Unit),
    ok.


%% @doc Has a container into the App
%%
-spec(has_container(atom()) ->
             true | false).
has_container(Unit) ->
    whereis(gen_id(Unit)) /= undefined.


%% @doc Stack an object into the proc
%%
-spec(stack(atom(), string(), binary()) ->
             ok | {error, any()}).
stack(Unit, Key, Object) ->
    stack(Unit, -1, Key, Object).

-spec(stack(atom(), integer(), string(), binary()) ->
             ok | {error, any()}).
stack(Unit, AddrId, Key, Object) ->
    case has_container(Unit) of
        true ->
            Id = gen_id(Unit),
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
        {error, Cause} ->
            error_logger:error_msg("~p,~p,~p,~p~n",
                                   [{module, ?MODULE_STRING},
                                    {function, "start_app/0"},
                                    {line, ?LINE}, {body, Cause}]),
            {exit, Cause}
    end.


%% @doc Generate Id
%%
-spec(gen_id(atom()) ->
             string()).
gen_id(Unit) ->
    Unit_1 = case is_atom(Unit) of
                 true  -> atom_to_list(Unit);
                 false -> Unit
             end,
    list_to_atom(lists:append([?PREFIX, Unit_1])).
