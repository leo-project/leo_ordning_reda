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
-export([stack/4, send/1]).
-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3]).
-export([loop/2]).

-type(instance_name() :: atom()).
-type(pid_table()     :: ?ETS_TAB_STACK_PID | ?ETS_TAB_DIVIDE_PID).

-record(state, {id   :: atom(),
                node :: atom(),
                buf_size = 0  :: integer(),
                cur_size = 0  :: integer(),
                stack    = [] :: list(#straw{}),
                timeout  = 0  :: integer(),
                sender        :: function(),
                recover       :: function()
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
    gen_server:call(Id, stop).


%% @doc Stacking objects
%%
-spec(stack(atom(), integer(), string(), any()) ->
             ok | {error, any()}).
stack(Id, AddrId, Key, Obj) ->
    gen_server:call(Id, {stack, #straw{addr_id = AddrId,
                                       key     = Key,
                                       object  = Obj}}).


%% @doc Send stacked objects to remote-node(s).
%%
-spec(send(atom()) ->
             ok | {error, any()}).
send(Id) ->
    gen_server:call(Id, {send}).


%%====================================================================
%% GEN_SERVER CALLBACKS
%%====================================================================
%% Function: init(Args) -> {ok, State}          |
%%                         {ok, State, Timeout} |
%%                         ignore               |
%%                         {stop, Reason}
%% Description: Initiates the server
init([Id, stack, #stack_info{node     = Node,
                             buf_size = BufSize,
                             timeout  = Timeout,
                             sender   = Fun0,
                             recover  = Fun1}]) ->
    {ok, #state{id       = Id,
                node     = Node,
                buf_size = BufSize,
                stack    = [],
                timeout  = Timeout,
                sender   = Fun0,
                recover  = Fun1}}.


handle_call(stop, _From, State) ->
    {stop, normal, ok, State};


handle_call({stack, Straw}, _From, #state{id       = Id,
                                          node     = Node,
                                          buf_size = BufSize,
                                          sender   = Fun0,
                                          recover  = Fun1} = State) ->
    case stack_fun0(Id, Straw, State) of
        {ok, #state{cur_size = CurSize,
                    stack    = Stack} = NewState} when BufSize =< CurSize ->
            Reply = exec_fun(Fun0, Fun1, Node, Stack),
            %% ?debugVal({Id, BufSize, CurSize, length(Stack), Reply}),

            garbage_collect(self()),
            {reply, Reply, NewState#state{cur_size = 0,
                                          stack    = []}};
        {ok, NewState} ->
            {reply, ok, NewState};
        {error, _} = Error ->
            {reply, Error, State}
    end;


handle_call({send}, _From, #state{node     = Node,
                                  sender   = Fun0,
                                  recover  = Fun1,
                                  cur_size = CurSize} = State) ->
    case CurSize of
        0 ->
            {reply, ok, State};
        _ ->
            Reply = exec_fun(Fun0, Fun1, Node, State#state.stack),
            %% ?debugVal({Node, Reply}),

            garbage_collect(self()),
            {reply, Reply, State#state{cur_size = 0,
                                       stack    = []}}
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
            {error, Cause};
        [] ->
            #state{id = Id, timeout = Timeout} = State,
            Pid = gen_instance(?ETS_TAB_STACK_PID, Id, Timeout),

            case ets:insert(?ETS_TAB_STACK_PID, {Id, Pid}) of
                true ->
                    stack_fun1(Id, Pid, Straw, State);
                {'EXIT', Cause} ->
                    {error, Cause}
            end;
        [{_, Pid}|_] ->
            stack_fun1(Id, Pid, Straw, State)
    end.

%% @doc Append an object into the process.
%%
-spec(stack_fun1(instance_name(), pid(), #straw{}, #state{}) ->
             {ok, #state{}} | {error, any()}).
stack_fun1(Id, Pid, Straw, #state{cur_size = CurSize,
                                  stack    = Stack0} = State) ->
    case erlang:is_process_alive(Pid) of
        false ->
            catch ets:delete(?ETS_TAB_STACK_PID, Id),
            stack_fun0(Id, Straw, State);

        true ->
            Pid ! {self(), request},
            receive
                ok ->
                    Stack1 = [Straw|Stack0],
                    Size   = byte_size(Straw#straw.object) + CurSize,
                    %% ?debugVal({Id, Size}),

                    {ok, State#state{cur_size = Size,
                                     stack    = Stack1}}
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
            timer:apply_after(0, ?MODULE, send, [Id]),
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
-spec(exec_fun(function(), function(), atom(), list()) ->
             ok | {error, list()}).
exec_fun(Fun0, Fun1, Node, Stack) ->
    case Fun0(Node, Stack) of
        ok ->
            ok;
        {error, _Cause} ->
            Errors = lists:map(fun(#straw{addr_id = AddrId,
                                          key     = Key}) ->
                                       {AddrId, Key}
                               end, Stack),
            _ = Fun1(Errors),
            {error, Errors}
    end.
