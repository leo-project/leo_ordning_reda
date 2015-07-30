%%======================================================================
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
%% @doc The ordning-reda server
%% @reference https://github.com/leo-project/leo_ordning_reda/blob/master/src/leo_ordning_reda_manager.erl
%% @end
%%======================================================================
-module(leo_ordning_reda_manager).

-author('Yosuke Hara').

-behaviour(gen_server).

-include("leo_ordning_reda.hrl").
-include_lib("eunit/include/eunit.hrl").

%% Application callbacks
-export([start_link/0, stop/0]).
-export([add/2, delete/1,
         restart/1, close/1,
         get/1,
         is_exist/1]).
-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3]).

-define(DEF_TIMEOUT, 30000).

-ifdef(TEST).
-define(out_put_info_log(_Fun, _Unit),
        error_logger:info_msg("~p,~p,~p,~p~n",
                              [{module, ?MODULE_STRING},
                               {function, _Fun},
                               {line, ?LINE}, {body, _Unit}])).
-else.
-define(out_put_info_log(_Fun,_Unit), ok).
-endif.

-record(state, {
          units = [] :: dict()
         }).


%% ===================================================================
%% API
%% ===================================================================
%% @doc Start the server
-spec(start_link() ->
             ok | {error, any()}).
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).


%% @doc Stop this server
-spec(stop() ->
             ok).
stop() ->
    gen_server:call(?MODULE, stop, ?DEF_TIMEOUT).


%% @doc Add a container
-spec(add(Unit, Options) ->
             ok | {error, any()} when Unit::any(),
                                      Options::[{atom(), any()}]).
add(Unit, Options) ->
    gen_server:call(?MODULE, {add, Unit, Options}, ?DEF_TIMEOUT).


%% @doc Remove a container
-spec(delete(Unit) ->
             ok | {error, any()} when Unit::any()).
delete(Unit) ->
    gen_server:call(?MODULE, {delete, Unit}, ?DEF_TIMEOUT).


%% @doc Restart a container
-spec(restart(Unit) ->
             ok | {error, any()} when Unit::any()).
restart(Unit) ->
    gen_server:call(?MODULE, {restart, Unit}, ?DEF_TIMEOUT).


%% @doc Close a container
-spec(close(Unit) ->
             ok | {error, any()} when Unit::any()).
close(Unit) ->
    gen_server:call(?MODULE, {close, Unit}, ?DEF_TIMEOUT).


%% @doc Retrieve a container's pid
-spec(get(Unit) ->
             {ok, pid()} | {error, any()} when Unit::any()).
get(Unit) ->
    gen_server:call(?MODULE, {get, Unit}, ?DEF_TIMEOUT).


-spec(is_exist(Unit) ->
             boolean() when Unit::any()).
is_exist(Unit) ->
    gen_server:call(?MODULE, {is_exist, Unit}, ?DEF_TIMEOUT).


%%====================================================================
%% GEN_SERVER CALLBACKS
%%====================================================================
%% @doc Initiates the server
init([]) ->
    {ok, #state{units = dict:new()}}.


%% @doc gen_server callback - Module:handle_call(Request, From, State) -> Result
handle_call(stop, _From, State) ->
    {stop, normal, ok, State};

handle_call({add, Unit, Options},_From, #state{units = Units} = State) ->
    case dict:find(Unit, Units) of
        {ok,_} ->
            {reply, ok, State};
        _ ->
            ChildId = {leo_ord_reda, Unit},
            Module  = leo_misc:get_value(?PROP_ORDRED_MOD,      Options),
            BufSize = leo_misc:get_value(?PROP_ORDRED_BUF_SIZE, Options, ?DEF_BUF_SIZE),
            Timeout = leo_misc:get_value(?PROP_ORDRED_TIMEOUT,  Options, ?REQ_TIMEOUT),
            IsComp  = leo_misc:get_value(?PROP_ORDRED_IS_COMP,  Options, true),
            RemovedCount = leo_misc:get_value(?PROP_REMOVED_COUNT, Options, ?DEF_REMOVED_COUNT),
            TmpStackedDir = ?env_temp_stacked_dir(),

            Args = [#stack_info{unit     = Unit,
                                module   = Module,
                                buf_size = BufSize,
                                timeout  = Timeout,
                                removed_count = RemovedCount,
                                is_compression_obj = IsComp,
                                tmp_stacked_dir = TmpStackedDir}],
            ChildSpec = {ChildId,
                         {leo_ordning_reda_server, start_link, Args},
                         temporary, 2000, worker, [leo_ordning_reda_server]},
            {Reply, NewUnits} =
                case supervisor:start_child(leo_ordning_reda_sup, ChildSpec) of
                    {ok, Pid} ->
                        Units_1 = dict:store(Unit, Pid, Units),
                        {ok, Units_1};
                    {error,{already_started,_Pid}} ->
                        {ok, Units};
                    {error, Cause} ->
                        {{error, Cause}, Units}
                end,
            {reply, Reply, State#state{units = NewUnits}}
    end;

handle_call({delete, Unit},_From, #state{units = Units} = State) ->
    {Reply, NewUnits} =
        case dict:find(Unit, Units) of
            {ok, Pid} ->
                case is_process_alive(Pid) of
                    true ->
                        case supervisor:which_children('leo_ordning_reda_sup') of
                            [] ->
                                ok;
                            Children ->
                                ok = remove_container_1(Children, Pid),
                                ?out_put_info_log("remove_container/1", Unit),
                                ok
                        end;
                    false ->
                        ok
                end,
                Units_1 = dict:erase(Unit, Units),
                {ok, Units_1};
            _ ->
                {ok, Units}
        end,
    {reply, Reply, State#state{units = NewUnits}};

handle_call({restart, Unit},_From, #state{units = Units} = State) ->
    Reply = case dict:find(Unit, Units) of
                {ok, Pid} ->
                    leo_ordning_reda_server:restart(Pid);
                _ ->
                    ok
            end,
    {reply, Reply, State};

handle_call({close, Unit},_From, #state{units = Units} = State) ->
    Reply = case dict:find(Unit, Units) of
                {ok, Pid} ->
                    leo_ordning_reda_server:close(Pid);
                _ ->
                    ok
            end,
    {reply, Reply, State};

handle_call({get, Unit},_From, #state{units = Units} = State) ->
    Reply = case dict:find(Unit, Units) of
                {ok, Pid} ->
                    {ok, Pid};
                _ ->
                    {error, not_found}
            end,
    {reply, Reply, State};

handle_call({is_exist, Unit},_From, #state{units = Units} = State) ->
    Reply = case dict:find(Unit, Units) of
                {ok,_} ->
                    true;
                _ ->
                    false
            end,
    {reply, Reply, State}.


%% @doc Handling cast message
%% <p>
%% gen_server callback - Module:handle_cast(Request, State) -> Result.
%% </p>
handle_cast(_Msg, State) ->
    {noreply, State}.


%% @doc Handling all non call/cast messages
%% <p>
%% gen_server callback - Module:handle_info(Info, State) -> Result.
%% </p>
handle_info(_Info, State) ->
    {noreply, State}.

%% @doc This function is called by a gen_server when it is about to
%%      terminate. It should be the opposite of Module:init/1 and do any necessary
%%      cleaning up. When it returns, the gen_server terminates with Reason.
terminate(_Reason,_State) ->
    ok.

%% @doc Convert process state when code is changed
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.


%%====================================================================
%% INNTERNAL FUNCTION
%%====================================================================
%% @doc Remove the process from sup
%% @private
remove_container_1([],_) ->
    ok;
remove_container_1([{_Id, Pid, worker, ['leo_ordning_reda_server'|_]}|_], Pid) ->
    _ = supervisor:terminate_child(leo_ordning_reda_sup, _Id),
    _ = supervisor:delete_child(leo_ordning_reda_sup, _Id),
    ok;
remove_container_1([_|T],Pid) ->
    remove_container_1(T, Pid).
