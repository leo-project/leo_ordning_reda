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
-module(leo_ordning_reda_server).

-author('Yosuke Hara').

-behaviour(gen_server).

-include("leo_ordning_reda.hrl").
-include_lib("eunit/include/eunit.hrl").


%% Application callbacks
-export([start_link/3, stop/1]).
-export([stack/4, exec/1]).
-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3]).
-export([loop/2]).

-type(instance_name() :: atom()).
-type(pid_table()     :: ?ETS_TAB_STACK_PID | ?ETS_TAB_DIVIDE_PID).

-define(DEF_TIMEOUT, 30000).

-record(state, {id     :: atom(),
                unit   :: atom(), %% key
                module :: atom(), %% callback-mod
                buf_size = 0     :: integer(), %% size of buffer
                cur_size = 0     :: integer(), %% size of current stacked objects
                stack_obj = <<>> :: binary(),  %% stacked objects
                stack_info = []  :: list(),    %% list of stacked object-info
                timeout = 0      :: integer(), %% stacking timeout
                times   = 0      :: integer()  %% NOT execution times
               }).


%% ===================================================================
%% API
%% ===================================================================
%% Function: start_link() -> {ok,Pid} | ignore | {error,Error}
%% Description: Starts the server
-spec(start_link(atom(), stack, #stack_info{}) ->
             ok | {error, any()}).
start_link(Id, stack, StackInfo) ->
    gen_server:start_link({local, Id}, ?MODULE,
                          [Id, stack, StackInfo], []).

%% @doc Stop this server
%%
-spec(stop(atom()) -> ok).
stop(Id) ->
    gen_server:call(Id, stop, ?DEF_TIMEOUT).


%% @doc Stacking objects
%%
-spec(stack(atom(), integer(), string(), tuple({any(), binary()})) ->
             ok | {error, any()}).
stack(Id, AddrId, Key, Obj) ->
    gen_server:call(Id, {stack, #straw{addr_id = AddrId,
                                       key     = Key,
                                       object  = Obj,
                                       size    = byte_size(Obj)}}, ?DEF_TIMEOUT).


%% @doc Send stacked objects to remote-node(s).
%%
-spec(exec(atom()) ->
             ok | {error, any()}).
exec(Id) ->
    gen_server:call(Id, {exec}, ?DEF_TIMEOUT).


%%====================================================================
%% GEN_SERVER CALLBACKS
%%====================================================================
%% Function: init(Args) -> {ok, State}          |
%%                         {ok, State, Timeout} |
%%                         ignore               |
%%                         {stop, Reason}
%% Description: Initiates the server
init([Id, stack, #stack_info{unit     = Unit,
                             module   = Module,
                             buf_size = BufSize,
                             timeout  = Timeout}]) ->
    _Pid = gen_instance(?ETS_TAB_STACK_PID, Id, Timeout),
    {ok, #state{id       = Id,
                unit     = Unit,
                module   = Module,
                buf_size = BufSize,
                timeout  = Timeout}}.


handle_call(stop, _From, State) ->
    {stop, normal, ok, State};


handle_call({stack, Straw}, From, #state{id       = Id,
                                         unit     = Unit,
                                         module   = Module,
                                         buf_size = BufSize} = State) ->
    case stack_fun0(Id, Straw, State) of
        {ok, #state{cur_size   = CurSize,
                    stack_obj  = StackObj,
                    stack_info = StackInfo} = NewState} when BufSize =< CurSize ->
            timer:sleep(?env_send_after_interval()),
            spawn(fun() ->
                          exec_fun(From, Module, Unit, StackObj, StackInfo)
                  end),
            garbage_collect(self()),
            {noreply, NewState#state{cur_size   = 0,
                                     stack_obj  = <<>>,
                                     stack_info = []}};
        {ok, NewState} ->
            {reply, ok, NewState};
        {error, _} = Error ->
            {reply, Error, State}
    end;


handle_call({exec}, From, #state{id       = Id,
                                 unit     = Unit,
                                 module   = Module,
                                 cur_size = CurSize,
                                 timeout  = Timeout,
                                 times    = Times} = State) ->
    case CurSize of
        0 when Times >= (?DEF_REMOVED_TIME + 1) ->
            timer:apply_after(
              0, leo_ordning_reda_api, remove_container, [stack, Unit]),
            {reply, ok, State};
        0 ->
            _ = gen_instance(?ETS_TAB_STACK_PID, Id, Timeout),
            {reply, ok, State#state{times = Times+1}};
        _ ->
            spawn(fun() ->
                          exec_fun(From, Module, Unit, State#state.stack_obj, State#state.stack_info)
                  end),
            garbage_collect(self()),
            _ = gen_instance(?ETS_TAB_STACK_PID, Id, Timeout),
            {noreply, State#state{cur_size   = 0,
                                  stack_obj  = <<>>,
                                  stack_info = []}}
    end.


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
%%
-spec(stack_fun0(instance_name(), #straw{}, #state{}) ->
             {ok, #state{}} | {error, any()}).
stack_fun0(Id, Straw, State) ->
    case catch ets:lookup(?ETS_TAB_STACK_PID, Id) of
        {'EXIT', Cause} ->
            error_logger:error_msg("~p,~p,~p,~p~n",
                                   [{module, ?MODULE_STRING}, {function, "stack_fun0/3"},
                                    {line, ?LINE}, {body, Cause}]),
            {error, Cause};
        [] ->
            #state{id = Id, timeout = Timeout} = State,
            Pid = gen_instance(?ETS_TAB_STACK_PID, Id, Timeout),

            case ets:insert(?ETS_TAB_STACK_PID, {Id, Pid}) of
                true ->
                    stack_fun1(Id, Pid, Straw, State);
                {'EXIT', Cause} ->
                    error_logger:error_msg("~p,~p,~p,~p~n",
                                           [{module, ?MODULE_STRING}, {function, "stack_fun0/3"},
                                            {line, ?LINE}, {body, Cause}]),
                    {error, Cause}
            end;
        [{_, Pid}|_] ->
            stack_fun1(Id, Pid, Straw, State)
    end.

%% @doc Append an object into the process.
%%
-spec(stack_fun1(instance_name(), pid(), #straw{}, #state{}) ->
             {ok, #state{}} | {error, any()}).
stack_fun1(Id, Pid, Straw, #state{cur_size   = CurSize,
                                  stack_obj  = StackObj0,
                                  stack_info = StackInf0} = State) ->
    case erlang:is_process_alive(Pid) of
        false ->
            catch ets:delete(?ETS_TAB_STACK_PID, Id),
            stack_fun0(Id, Straw, State);
        true ->
            Pid ! {self(), request},
            receive
                ok ->
                    List = [Key || {_, Key} <- StackInf0],

                    case lists:member(Straw#straw.key, List) of
                        true ->
                            {ok, State};
                        false ->
                            Bin = Straw#straw.object,
                            StackObj1 = << StackObj0/binary,  Bin/binary>>,
                            StackInf1 = [{Straw#straw.addr_id,
                                          Straw#straw.key}  | StackInf0],
                            Size   = Straw#straw.size + CurSize,
                            {ok, State#state{cur_size   = Size,
                                             stack_obj  = StackObj1,
                                             stack_info = StackInf1}}
                    end
            after
                ?RCV_TIMEOUT ->
                    catch ets:delete(?ETS_TAB_STACK_PID, Id),
                    stack_fun0(Id, Straw, State)
            end
    end.


%% @doc
%%
-spec(loop(atom(), integer()) ->
             ok).
loop(Id, Timeout) ->
    receive
        {From, request} ->
            From ! ok,
            loop(Id, Timeout)
    after
        Timeout ->
            timer:apply_after(0, ?MODULE, exec, [Id]),
            purge_proc(self())
    end.


%% @doc Purge a process
%%
-spec(purge_proc(pid()) ->
             ok).
purge_proc(Pid) ->
    garbage_collect(Pid),
    exit(Pid, purge).


%% @doc Create a process
%%
-spec(gen_instance(pid_table(), atom(), integer()) ->
             pid()).
gen_instance(?ETS_TAB_STACK_PID, Id, Timeout) ->
    spawn(?MODULE, loop, [Id, Timeout]);
gen_instance(?ETS_TAB_DIVIDE_PID,_,_) ->
    ok.


%% @doc Execute a function
%%
-spec(exec_fun(pid(), atom(), atom(), list(), list()) ->
             ok | {error, list()}).
exec_fun(From, Module, Unit, StackObj, StackInf) ->
    %% Compress object-list
    %%
    case catch lz4:pack(StackObj) of
        {ok, CompressedObjs} ->
            %% Send compressed objects
            %%
            case catch erlang:apply(Module, handle_send, [Unit, CompressedObjs]) of
                ok ->
                    gen_server:reply(From, ok);
                {_, Cause} ->
                    error_logger:error_msg("~p,~p,~p,~p~n",
                                           [{module, ?MODULE_STRING}, {function, "exec_fun/3"},
                                            {line, ?LINE}, {body, Cause}]),
                    case catch erlang:apply(Module, handle_fail, [Unit, StackInf]) of
                        ok ->
                            void;
                        {_, Cause0} ->
                            Cause1 = element(1, Cause0),
                            error_logger:error_msg("~p,~p,~p,~p~n",
                                                   [{module, ?MODULE_STRING}, {function, "exec_fun/3"},
                                                    {line, ?LINE}, {body, Cause1}])
                    end,
                    gen_server:reply(From, {error, StackInf})
            end;
        {_, Cause0} ->
            Cause1 = element(1, Cause0),
            gen_server:reply(From, {error, Cause1})
    end.

