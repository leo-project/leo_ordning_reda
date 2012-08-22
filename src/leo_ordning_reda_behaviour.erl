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
%% ---------------------------------------------------------------------
%% Leo Ordning & Reda  - Behaviour.
%% @doc
%% @end
%%======================================================================
-module(leo_ordning_reda_behaviour).

-author('Yosuke Hara').

-export([behaviour_info/1]).

behaviour_info(callbacks) ->
    [
     %% handle_send(Node::atom(), Stack::list(#straw{})) ->
     %%     ok | {error, list()}
     {handle_send, 2},

     %% handle_fail(Node::atom(), Errors::list(#straw{})) ->
     %%     ok | {error, any()}
     {handle_fail, 2}
    ];
behaviour_info(_Other) ->
    undefined.

