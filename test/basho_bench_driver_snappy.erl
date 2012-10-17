%% -------------------------------------------------------------------
%%
%% basho_bench: Benchmarking Suite
%%
%% Copyright (c) 2009-2010 Basho Techonologies
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
-module(basho_bench_driver_snappy).

-export([new/1,
         run/4]).

-include("basho_bench.hrl").

-record(state, {text = [] :: binary()}).

%% ====================================================================
%% API
%% ====================================================================
new(_Id) ->
    %% Make sure bitcask is available
    case code:which(snappy) of
        non_existing ->
            ?FAIL_MSG("~s requires snappy to be available on code path.\n",
                      [?MODULE]);
        _ ->
            ok
    end,

    File = basho_bench_config:get(sample_file, "sample.txt"),
    {ok, Bin} = file:read_file(File),
    {ok, #state{text = Bin}}.


run(compress, _KeyGen, _ValueGen, #state{text = Text} = State) ->
    case snappy:compress(Text) of
        {ok, _} ->
            {ok, State};
        _ ->
            {error, 'fail'}
    end;
run(suite, _KeyGen, _ValueGen, #state{text = Text} = State) ->
    case snappy:compress(Text) of
        {ok, Compressed} ->
            case snappy:decompress(Compressed) of
                {ok, Original} when Original == Text ->
                    {ok, State};
                _ ->
                    {error, 'fail'}
            end;
        _ ->
            {error, 'fail'}
    end.

