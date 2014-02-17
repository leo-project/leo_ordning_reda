leo_ordning_reda
================

[![Build Status](https://secure.travis-ci.org/leo-project/leo_ordning_reda.png?branch=master)](http://travis-ci.org/leo-project/leo_ordning_reda)


Overview
--------
* "leo_ordning_reda" is bulked files and compression/decompression library for [LeoFS](http://leo-project.net/leofs) and other Erlang applications.
* "leo_ordning_reda" uses the [rebar](https://github.com/rebar/rebar) build system. Makefile so that simply running "make" at the top level should work.
* "leo_ordning_reda" requires Erlang R15B03-1 or later.


## Usage

```erlang

-module(leo_ordning_reda_stack).
-behaviour(leo_ordning_reda_behaviour).

-include("leo_ordning_reda.hrl").
-include_lib("eunit/include/eunit.hrl").

-export([start_link/3, stop/1]).
-export([sample/0]).
-export([handle_send/2,
         handle_fail/2]).

%%--------------------------------------------------------------------
%% API
%%--------------------------------------------------------------------
start_link(Node, BufSize, Timeout) ->
    leo_ordning_reda_api:add_container(stack, Node, [{module,      ?MODULE},
                                                     {buffer_size, BufSize},
                                                     {timeout,     Timeout}]).
stop(Node) ->
    leo_ordning_reda_api:remove_container(stack, Node).

sample() ->
    Buffer = 64*1024*1024,
    Expire = timer:seconds(30),

    ok = leo_ordning_reda_api:start(),
    ok = leo_ordning_reda_stack:start_link(Node0, Buffer, Expire),

    DestNode = 'node_0@127.0.0.1',
    Key = "test_key_1",
    Obj = crypto:rand_bytes(erlang:phash2(Index, 1024)),
    ok  = leo_ordning_reda_api:stack(Node, Key, Obj),

    ok = application:stop(leo_ordning_reda),
    ok.

%%--------------------------------------------------------------------
%% Callback
%%--------------------------------------------------------------------
handle_send(_Node, _StackedObjects) ->
    %% Able to implement a sending stacked objects to a destination node
    ?debugVal({_Node, byte_size(_StackedObjects)}),
    ok.

handle_fail(_Node, _Errors) ->
    %% Able to implement a fail processing
    ?debugVal({_Node, length(_Errors)}),
    ok.

```

## License

leo_ordning_reda's license is [Apache License Version 2.0](http://www.apache.org/licenses/LICENSE-2.0.html)