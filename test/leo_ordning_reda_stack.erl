%%====================================================================
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
%% -------------------------------------------------------------------
%% Leo Ordning & Reda - TEST
%% @doc
%% @end
%%====================================================================
-module(leo_ordning_reda_stack).
-author('Yosuke Hara').

-behaviour(leo_ordning_reda_behaviour).

-include("leo_ordning_reda.hrl").
-include_lib("eunit/include/eunit.hrl").

-export([start_link/3, stop/1]).
-export([handle_send/3,
         handle_fail/2]).

%%--------------------------------------------------------------------
%% API
%%--------------------------------------------------------------------
%% @doc Add a container into the supervisor
%%
-spec(start_link(atom(), integer(), integer()) ->
             ok | {error, any()}).
start_link(Node, BufSize, Timeout) ->
    leo_ordning_reda_api:add_container(Node, [{module,      ?MODULE},
                                              {buffer_size, BufSize},
                                              {timeout,     Timeout}]).

%% @doc Remove a container from the supervisor
%%
-spec(stop(atom()) ->
             ok | {error, any()}).
stop(Node) ->
    leo_ordning_reda_api:remove_container(Node).


%%--------------------------------------------------------------------
%% Callback
%%--------------------------------------------------------------------
%% @doc
%%
handle_send(_Node, _StackedInfo, _StackedObjects) ->
    ?debugVal({_Node, length(_StackedInfo), byte_size(_StackedObjects)}),
    ok.


%% @doc
%%
handle_fail(_Node, _StackedInfo) ->
    ?debugVal({_Node, length(_StackedInfo)}),
    ok.

