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
-module(leo_ordning_reda_app).
-author('Yosuke Hara').

-behaviour(application).

%% Application callbacks
-export([start/2, prep_stop/1, stop/1]).

%% ===================================================================
%% Application callbacks
%% ===================================================================

-spec start(_,_) -> {'ok',pid()} | {'error',_}.
start(_StartType, _StartArgs) ->
    leo_ordning_reda_sup:start_link().

-spec prep_stop(_) -> 'ok'.
prep_stop(_State) ->
    ok = leo_ordning_reda_sup:stop(),
    ok.

-spec stop(_) -> 'ok'.
stop(_State) ->
    ok.
