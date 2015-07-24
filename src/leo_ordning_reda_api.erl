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
%% @doc The ordning-reda's API
%% @reference https://github.com/leo-project/leo_ordning_reda/blob/master/src/leo_ordning_reda_api.erl
%% @end
%%======================================================================
-module(leo_ordning_reda_api).
-author('Yosuke Hara').

-include("leo_ordning_reda.hrl").
-include_lib("eunit/include/eunit.hrl").


%% Application callbacks
-export([start/0, stop/0,
         add_container/2, remove_container/1,
         has_container/1,
         restart_container/1, close_container/1,
         stack/3, pack/1, unpack/2, force_sending_obj/1,
         state/1
        ]).

%% -define(PREFIX, "leo_ord_reda_").

-ifdef(TEST).
-define(out_put_info_log(_Fun, _Unit),
        error_logger:info_msg("~p,~p,~p,~p~n",
                              [{module, ?MODULE_STRING},
                               {function, _Fun},
                               {line, ?LINE}, {body, _Unit}])).
-else.
-define(out_put_info_log(_Fun,_Unit), ok).
-endif.


%%--------------------------------------------------------------------
%% API
%%--------------------------------------------------------------------
%% @doc Launch the application
%%
-spec(start() ->
             ok | {error, any()}).
start() ->
    start_app().


%% @doc Stop the application
%%
-spec(stop() ->
             ok | {error, any()}).
stop() ->
    leo_ordning_reda_sup:stop().


%% @doc Add the container into the App
%%
-spec(add_container(Unit, Options) ->
             ok | {error, any()} when Unit::atom(),
                                      Options::[any()]).
add_container(Unit, Options) ->
    leo_ordning_reda_manager:add(Unit, Options).


%% @doc Remove the container from the App
%%
-spec(remove_container(Unit) ->
             ok | {error, any()} when Unit::atom()).
remove_container(Unit) ->
    leo_ordning_reda_manager:delete(Unit).


%% @doc Check whether the container exists
%%
-spec(has_container(Unit) ->
             true | false when Unit::atom()).
has_container(Unit) ->
    leo_ordning_reda_manager:is_exist(Unit).


%% @doc Restart the container
-spec(restart_container(Unit) ->
             ok | {error, any()} when Unit::atom()).
restart_container(Unit) ->
    leo_ordning_reda_manager:restart(Unit).


%% @doc Close the container
-spec(close_container(Unit) ->
             ok | {error, any()} when Unit::atom()).
close_container(Unit) ->
    leo_ordning_reda_manager:close(Unit).


%% @doc Stack the object into the container
%%
-spec(stack(Unit, StrawId, Object) ->
             ok | {error, any()} when Unit::atom(),
                                      StrawId::any(),
                                      Object::binary()).
stack(Unit, StrawId, Object) ->
    case leo_ordning_reda_manager:get(Unit) of
        {ok, PId} ->
            leo_ordning_reda_server:stack(PId, StrawId, Object);
        _ ->
            {error, undefined}
    end.


%% @doc Pack the object
%%
-spec(pack(Object) ->
             {ok, Bin} | {error, _} when Object::any(),
                                         Bin::binary()).
pack(Object) ->
    ObjBin = term_to_binary(Object),
    SizeBin = binary:encode_unsigned(byte_size(ObjBin)),
    SizeBinSize = binary:encode_unsigned(byte_size(SizeBin)),
    {ok, << SizeBinSize/binary, SizeBin/binary, ObjBin/binary >>}.


%% @doc Unpack the object
%%
-spec(unpack(CompressedBin, Fun) ->
             ok when CompressedBin::binary(),
                     Fun::function()).
unpack(CompressedBin, Fun) ->
    {ok, Bin} = lz4:unpack(CompressedBin),
    unpack_1(Bin, Fun).

-spec(unpack_1(Bin, Fun) ->
             ok when Bin :: binary(),
                     Fun :: function()).
unpack_1(<<>>,_Fun) ->
    ok;
unpack_1(Bin, Fun) ->
    %% Retrieve an object
    HSizeH = binary:part(Bin, {0, 1}),
    HSize = binary:decode_unsigned(HSizeH),
    H = binary:part(Bin, {1, HSize}),
    Size = binary:decode_unsigned(H),
    Obj = binary_to_term(binary:part(Bin, {1 + HSize, Size})),
    %% Execute fun
    Fun(Obj),

    %% Retrieve rest objects
    Rest = binary:part(Bin, {1 + HSize + Size, byte_size(Bin) - 1 - HSize - Size}),
    unpack_1(Rest, Fun).


%% @doc Force executing object transfer
%%
-spec(force_sending_obj(Unit) ->
             ok | {error, undefined} when Unit::atom()).
force_sending_obj(Unit) ->
    case leo_ordning_reda_manager:get(Unit) of
        {ok, PId} ->
            leo_ordning_reda_server:exec(PId);
        _ ->
            {error, undefined}
    end.


%% @doc Retrieve a current state of the unit
%%
-spec(state(Unit) ->
             ok | {error, undefined} when Unit::atom()).
state(Unit) ->
    case leo_ordning_reda_manager:get(Unit) of
        {ok, PId} ->
            leo_ordning_reda_server:state(PId);
        _ ->
            {error, undefined}
    end.


%%--------------------------------------------------------------------
%% INNTERNAL FUNCTIONS
%%--------------------------------------------------------------------
%% @doc Launch the ordning-reda application
%% @private
-spec(start_app() ->
             ok | {error, any()}).
start_app() ->
    Module = leo_ordning_reda,
    case application:start(Module) of
        ok ->
            ok;
        {error, {already_started, Module}} ->
            ok;
        {error, Cause} ->
            error_logger:error_msg("~p,~p,~p,~p~n",
                                   [{module, ?MODULE_STRING},
                                    {function, "start_app/0"},
                                    {line, ?LINE}, {body, Cause}]),
            {exit, Cause}
    end.
