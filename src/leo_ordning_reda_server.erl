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
-module(leo_ordning_reda_server).
-author('Yosuke Hara').

-behaviour(gen_server).

-include("leo_ordning_reda.hrl").
-include_lib("eunit/include/eunit.hrl").
-include_lib("kernel/include/file.hrl").

%% Application callbacks
-export([start_link/2, stop/1]).
-export([stack/3, exec/1, close/1]).
-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3]).

-define(DEF_TIMEOUT, 30000).

-record(state, {id     :: atom(), %% container-id
                unit   :: atom(), %% key
                module :: atom(), %% callback-mod
                buf_size = 0         :: non_neg_integer(), %% size of buffer
                cur_size = 0         :: non_neg_integer(), %% size of current stacked objects
                stack_obj = <<>>     :: binary(),          %% stacked objects
                stack_info = []      :: [term()],          %% list of stacked object-info
                timeout = 0          :: non_neg_integer(), %% stacking timeout
                times   = 0          :: integer(),         %% NOT execution times
                tmp_stacked_obj = [] :: string(),          %% Temporary stacked file path - object
                tmp_stacked_inf = [] :: string(),          %% Temporary stacked file path - info
                tmp_file_handler     :: pid(),             %% Temporary file handler
                is_sending = false   :: boolean()          %% is sending a stacked object?
               }).


%% ===================================================================
%% API
%% ===================================================================
%% Function: start_link() -> {ok,Pid} | ignore | {error,Error}
%% Description: Starts the server
-spec(start_link(atom(), #stack_info{}) ->
             ok | {error, any()}).
start_link(Id, StackInfo) ->
    gen_server:start_link({local, Id}, ?MODULE,
                          [Id, StackInfo], []).

%% @doc Stop this server
%%
-spec(stop(atom()) -> ok).
stop(Id) ->
    gen_server:call(Id, stop, ?DEF_TIMEOUT).


%% @doc Stacking objects
%%
-spec(stack(atom(), any(), binary()) ->
             ok | {error, any()}).
stack(Id, StrawId, Obj) ->
    gen_server:call(Id, {stack, #?STRAW{id     = StrawId,
                                        object = Obj,
                                        size   = byte_size(Obj)}}, ?DEF_TIMEOUT).


%% @doc Send stacked objects to remote-node(s).
%%
-spec(exec(atom()) ->
             ok | {error, any()}).
exec(Id) ->
    gen_server:call(Id, exec, ?DEF_TIMEOUT).


%% @doc Close a stacked file
%%
-spec(close(atom()) ->
             ok | {error, any()}).
close(Id) ->
    gen_server:call(Id, close, ?DEF_TIMEOUT).


%%====================================================================
%% GEN_SERVER CALLBACKS
%%====================================================================
%% Function: init(Args) -> {ok, State}          |
%%                         {ok, State, Timeout} |
%%                         ignore               |
%%                         {stop, Reason}
%% Description: Initiates the server
init([Id, #stack_info{unit     = Unit,
                      module   = Module,
                      buf_size = BufSize,
                      timeout  = Timeout,
                      tmp_stacked_dir = TmpStackedDir
                     }]) ->
    _ = filelib:ensure_dir(TmpStackedDir),
    StackedObj = filename:join([TmpStackedDir,
                                lists:append([atom_to_list(Id), ".obj"])]),
    StackedInf = filename:join([TmpStackedDir,
                                lists:append([atom_to_list(Id), ".inf"])]),
    {ok, HandlerObj} = file:open(StackedObj, [read, write, raw]),
    {ok,_HandlerInf} = file:open(StackedInf, [read, write, raw]),

    State = #state{id       = Id,
                   unit     = Unit,
                   module   = Module,
                   buf_size = BufSize,
                   timeout  = Timeout,
                   tmp_stacked_obj = StackedObj,
                   tmp_stacked_inf = StackedInf,
                   tmp_file_handler = HandlerObj,
                   is_sending = false
                  },
    State_1 = case file:read_file_info(StackedObj) of
                  {ok, #file_info{size = Size}} when Size > 0 ->
                      case file:read_file(StackedObj) of
                          {ok, Bin} ->
                              case catch file:consult(StackedInf) of
                                  {ok, Term} ->
                                      State#state{stack_obj  = Bin,
                                                  stack_info = Term};
                                  _ ->
                                      State
                              end;
                          _ ->
                              State
                      end;
                  _ ->
                      State
              end,
    {ok, State_1, Timeout}.


handle_call(stop, _From, State) ->
    {stop, normal, ok, State};


handle_call({stack,_Straw},_From, #state{is_sending = true,
                                         timeout  = Timeout} = State) ->
    {reply, {error, sending_data_to_remote}, State#state{times = 0}, Timeout};
handle_call({stack, Straw}, From, #state{unit     = Unit,
                                         module   = Module,
                                         buf_size = BufSize,
                                         timeout  = Timeout} = State) ->
    case stack_fun(Straw, State) of
        {ok, #state{cur_size   = CurSize,
                    stack_obj  = StackObj,
                    stack_info = StackInfo} = NewState} when BufSize =< CurSize ->
            timer:sleep(?env_send_after_interval()),
            Pid = spawn(fun() ->
                                exec_fun(From, Module, Unit, StackObj, StackInfo)
                        end),
            _MonitorRef = erlang:monitor(process, Pid),
            garbage_collect(self()),
            {noreply, NewState#state{cur_size   = 0,
                                     stack_obj  = <<>>,
                                     stack_info = [],
                                     times = 0}, Timeout};
        {ok, NewState} ->
            {reply, ok, NewState#state{times = 0}, Timeout}
    end;

handle_call(exec,_From, #state{cur_size = 0,
                               timeout  = Timeout} = State) ->
    garbage_collect(self()),
    {reply, ok, State#state{cur_size   = 0,
                            stack_obj  = <<>>,
                            stack_info = [],
                            times = 0}, Timeout};

handle_call(exec, From, #state{unit     = Unit,
                               module   = Module,
                               timeout  = Timeout} = State) ->
    spawn(fun() ->
                  exec_fun(From, Module, Unit,
                           State#state.stack_obj, State#state.stack_info)
          end),
    garbage_collect(self()),
    {noreply, State#state{cur_size   = 0,
                          stack_obj  = <<>>,
                          stack_info = [],
                          times = 0}, Timeout};

handle_call(close,_From, #state{stack_info = StackInfo,
                                stack_obj  = StackObj,
                                tmp_stacked_inf  = StackedInf,
                                tmp_file_handler = Handler,
                                timeout = Timeout} = State) ->
    catch leo_file:file_unconsult(StackedInf, StackInfo),
    catch file:write(Handler, StackObj),
    garbage_collect(self()),
    {reply, ok, State, Timeout}.


%% Function: handle_cast(Msg, State) -> {noreply, State}          |
%%                                      {noreply, State, Timeout} |
%%                                      {stop, Reason, State}
%% Description: Handling cast message
handle_cast(_Msg, State) ->
    {noreply, State}.


%% Function: handle_info(Info, State) -> {noreply, State}          |
%%                                       {noreply, State, Timeout} |
%%                                       {stop, Reason, State}
%% Description: Handling all non call/cast messages
handle_info(timeout, #state{times   = ?DEF_REMOVED_TIME,
                            unit    = Unit,
                            timeout = Timeout} = State) ->
    timer:apply_after(100, leo_ordning_reda_api, remove_container, [Unit]),
    {noreply, State, Timeout};
handle_info({'DOWN', MonitorRef,_Type,_Pid,_Info}, State) ->
    erlang:demonitor(MonitorRef),
    {noreply, State#state{is_sending = false}};
handle_info(timeout, #state{cur_size = CurSize,
                            times    = Times,
                            timeout  = Timeout} = State) when CurSize == 0 ->
    {noreply, State#state{times = Times + 1}, Timeout};
handle_info(timeout, #state{id = Id,
                            cur_size = CurSize,
                            timeout  = Timeout} = State) when CurSize > 0 ->
    timer:apply_after(100, ?MODULE, exec, [Id]),
    {noreply, State#state{times = 0}, Timeout};
handle_info(_Info, State) ->
    {noreply, State}.

%% Function: terminate(Reason, State) -> void()
%% Description: This function is called by a gen_server when it is about to
%% terminate. It should be the opposite of Module:init/1 and do any necessary
%% cleaning up. When it returns, the gen_server terminates with Reason.
%% The return value is ignored.
terminate(_Reason, _State) ->
    ok.

%% Func: code_change(OldVsn, State, Extra) -> {ok, NewState}
%% Description: Convert process state when code is changed
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.


%%====================================================================
%% INNTERNAL FUNCTION
%%====================================================================
%% @doc Stack an object
%% @private
-spec stack_fun(#?STRAW{}, #state{}) -> {ok, #state{}}.
stack_fun(Straw, #state{cur_size   = CurSize,
                        stack_obj  = StackObj_1,
                        stack_info = StackInfo_1} = State) ->
    List = [Key || {_, Key} <- StackInfo_1],

    case exists_straw_id(Straw, List) of
        true ->
            {ok, State};
        false ->
            Bin = Straw#?STRAW.object,
            StackObj_2  = << StackObj_1/binary, Bin/binary>>,
            StackInfo_2 = [ Straw#?STRAW.id | StackInfo_1],
            Size = Straw#?STRAW.size + CurSize,
            {ok, State#state{cur_size   = Size,
                             stack_obj  = StackObj_2,
                             stack_info = StackInfo_2}}
    end.

%% @private
exists_straw_id(#?STRAW{id = StrawId} = Straw, List) when is_tuple(StrawId) ->
    ElSize = erlang:size(Straw#?STRAW.id),
    exists_straw_id_1(ElSize, Straw, List);
exists_straw_id(Straw, List) ->
    lists:member(Straw#?STRAW.id, List).

%% @private
exists_straw_id_1(0,_,_) ->
    false;
exists_straw_id_1(Index, Straw, List) ->
    case lists:member(erlang:element(Index, Straw#?STRAW.id), List) of
        true ->
            true;
        false ->
            exists_straw_id_1(Index - 1, Straw, List)
    end.


%% @doc Execute a function
%% @private
-spec(exec_fun({_, pid()}, atom(), atom(), binary(), list()) ->
             ok | {error, list()}).
exec_fun(From, Module, Unit, StackObj, StackInf) ->
    %% Compress object-list
    Reply = case catch lz4:pack(StackObj) of
                {ok, CompressedObjs} ->
                    %% Send compressed objects
                    case catch erlang:apply(
                                 Module, handle_send,
                                 [Unit, StackInf, CompressedObjs]) of
                        ok ->
                            ok;
                        {_, Cause} ->
                            error_logger:error_msg("~p,~p,~p,~p~n",
                                                   [{module, ?MODULE_STRING},
                                                    {function, "exec_fun/5"},
                                                    {line, ?LINE}, {body, Cause}]),
                            case catch erlang:apply(
                                         Module, handle_fail, [Unit, StackInf]) of
                                ok ->
                                    void;
                                {_, Cause0} ->
                                    Cause1 = element(1, Cause0),
                                    error_logger:error_msg("~p,~p,~p,~p~n",
                                                           [{module, ?MODULE_STRING},
                                                            {function, "exec_fun/5"},
                                                            {line, ?LINE}, {body, Cause1}])
                            end,
                            {error, StackInf}
                    end;
                {_, Cause0} ->
                    Cause1 = element(1, Cause0),
                    {error, Cause1}
            end,
    garbage_collect(self()),
    gen_server:reply(From, Reply).
