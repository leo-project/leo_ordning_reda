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
%%======================================================================
-module(leo_ordning_reda_sup).
-author('Yosuke Hara').

-behaviour(supervisor).

%% API
-export([start_link/0, stop/0]).

%% Supervisor callbacks
-export([init/1]).

-define(SHUTDOWN_WAITING_TIME, 2000).
-define(MAX_RESTART, 5).
-define(MAX_TIME, 60).
-define(RETRY_TIMES, 5).


%% ===================================================================
%% API functions
%% ===================================================================
start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

stop() ->
    case whereis(?MODULE) of
        Pid when is_pid(Pid) == true ->
            List = supervisor:which_children(Pid),
            ok = close(List),
            ok;
        _ -> not_started
    end.


%% ===================================================================
%% Supervisor callbacks
%% ===================================================================
init([]) ->
    ChildProcs = [
                  {leo_ordning_reda_manager,
                   {leo_ordning_reda_manager, start_link, []},
                   permanent,
                   ?SHUTDOWN_WAITING_TIME,
                   worker,
                   [leo_ordning_reda_manager]}],
    {ok, {{one_for_one, ?MAX_RESTART, ?MAX_TIME}, ChildProcs}}.


%% ---------------------------------------------------------------------
%% Inner Function(s)
%% ---------------------------------------------------------------------
%% @doc Close a internal databases
%% @private
close([]) ->
    ok;
close([{Id,_Pid, worker, ['leo_ordning_reda_server' = Mod|_]}|T]) ->
    ok = Mod:close(Id),
    close(T);
close([_|T]) ->
    close(T).
