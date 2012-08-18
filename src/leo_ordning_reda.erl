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
-module(leo_ordning_reda).

-author('Yosuke Hara').

-behaviour(gen_server).

-include("leo_ordning_reda.hrl").
-include_lib("eunit/include/eunit.hrl").


%% Application callbacks
-export([start_link/3, stop/1]).
-export([stack/2]).
-export([init/1,
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3]).
-export([loop/3]).

-type(instance_name() :: atom()).
-type(metadata()      :: binary()).
-type(object()        :: binary()).
-type(pid_table()     :: ?ETS_TAB_STACK_PID | ?ETS_TAB_DIVIDE_PID).


-record(state, {id   :: atom(),
                node :: atom(),
                buf_size = 0 :: integer(),
                timeout  = 0 :: integer(),
                function     :: function()
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


%% @doc
%%
-spec(stack(atom(), binary()) ->
             ok | {error, any()}).
stack(Id, Object) ->
    gen_server:call(Id, {stack, Object}).


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
                             function = Function}]) ->
    ?debugVal({Id, Node, BufSize, Timeout}),
    {ok, #state{id       = Id,
                node     = Node,
                buf_size = BufSize,
                timeout  = Timeout,
                function = Function}}.

handle_call(stop, _From, State) ->
    {stop, normal, ok, State};


handle_call({stack, Object}, _From, #state{id = Id} = State) ->
    Reply = stack_fun0(Id, Object, State),
    {reply, Reply, State}.


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
-spec(stack_fun0(instance_name(), {metadata(), object()}, #state{}) ->
             ok | {error, any()}).
stack_fun0(Id, Object, StackInfo) ->
    case catch ets:lookup(?ETS_TAB_STACK_PID, Id) of
        {'EXIT', Cause} ->
            {error, Cause};
        [] ->
            Pid = gen_instance(?ETS_TAB_STACK_PID, StackInfo),

            case ets:insert(?ETS_TAB_STACK_PID, {Id, Pid}) of
                true ->
                    stack_fun1(Id, Pid, Object);
                {'EXIT', Cause} ->
                    {error, Cause}
            end;
        [{_, Pid}|_] ->
            stack_fun1(Id, Pid, Object)
    end.

%% @doc Append an object into the process.
%%
-spec(stack_fun1(instance_name(), pid(), {metadata(), object()}) ->
             ok | {error, any()}).
stack_fun1(Id, Pid, Object) ->
    case erlang:is_process_alive(Pid) of
        false ->
            catch ets:delete(?ETS_TAB_STACK_PID, Id),
            stack(Id, Object);
        true ->
            Pid ! {self(), append, Object},
            receive
                Res ->
                    Res
            after
                ?RCV_TIMEOUT ->
                    catch ets:delete(?ETS_TAB_STACK_PID, Id),
                    stack(Id, Object)
            end
    end.


%% @doc
%%
-spec(loop(#state{}, list(), integer()) ->
             ok).
loop(#state{node     = _Node,
            buf_size = BufSize,
            timeout  = Timeout,
            function = _Function} = StackInfo, Acc0, Size0) ->
    receive
        {From, append, Object} ->
            Acc1  = [Object|Acc0],
            Size1 = byte_size(element(2, Object)) + Size0,

            case (Size1 >= BufSize) of
                true ->
                    %% @TODO Execute a fun
                    ?debugVal(Size1),
                    From ! ok,

                    purge_proc(self()),
                    ok;
                _ ->
                    From ! ok,
                    ?debugVal(length(Acc1)),
                    loop(StackInfo, Acc1, Size1)
            end
    after
        Timeout ->
            %% @TODO Execute a fun
            ?debugVal(Timeout),
            purge_proc(self()),
            ok
    end.


%% @doc Purge a process
%%
-spec(purge_proc(pid()) ->
             ok).
purge_proc(Pid) ->
    exit(Pid, purge),
    garbage_collect(),
    ok.


%% @doc Create a process
%%
-spec(gen_instance(pid_table(), #state{}) ->
             pid()).
gen_instance(?ETS_TAB_STACK_PID, State) ->
    spawn(?MODULE, loop, [State, [], 0]);
gen_instance(?ETS_TAB_DIVIDE_PID,_) ->
    ok.

