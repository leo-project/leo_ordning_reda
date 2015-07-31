leo_ordning_reda
================

[![Build Status](https://travis-ci.org/leo-project/leo_ordning_reda.svg?branch=develop)](https://travis-ci.org/leo-project/leo_ordning_reda)

**leo_ordning_reda** is a library to handle large objects efficiently.
We can easily write programs that automatically stack and compress large objects to pass them other processes.

## Build Information

* "leo_ordning_reda" uses the [rebar](https://github.com/rebar/rebar) build system. Makefile so that simply running "make" at the top level should work.
* "leo_ordning_reda" requires Erlang R16B03-1 or later.


## Usage in Leo Project

**leo_ordning_reda** is used in [**leo_storage**](https://github.com/leo-project/leo_storage).
It is used to replicate stored objects between remote data centers efficiently.

## Usage

We prepare a server program and a client program to use **leo_ordning_reda**.

First, a client program is as follow.

```erlang
-module(leo_ordning_reda_test_client).

-include("leo_ordning_reda.hrl").
-include_lib("eunit/include/eunit.hrl"). % for debug

-define(BUFSIZE, 100). %% 100B
-define(TIMEOUT, 100). %% 0.1sec

-export([main/0, output/1]).

main() ->
    Node = node(),
    ok = leo_ordning_reda_api:start(),
    ok = leo_ordning_reda_test_server:start_link(Node, ?BUFSIZE, ?TIMEOUT),
    ok = leo_ordning_reda_test_server:stack(Node, "key1", lists:seq(1,10)),
    ok = leo_ordning_reda_test_server:stack(Node, "key2", lists:seq(11,20)),
    ok = leo_ordning_reda_test_server:stack(Node, "key3", lists:seq(21,30)),
    timer:sleep(2000),
    ok = leo_ordning_reda_test_server:stop(Node),
    ok = application:stop(leo_ordning_reda),
    ok.

-spec(output(binary()) ->
    ok).
output(CompressedBin) ->
    Fun = fun(Obj) -> io:format("~p~n",[Obj]) end,
    ok = leo_ordning_reda_api:unpack(CompressedBin, Fun).
```

Second, a server program is as follow.
Note that, `handle_send` is called when objects are stacked more than `BufSize` or more than `Timeout` milliseconds passed.


```erlang
-module(leo_ordning_reda_test_server).

-behaviour(leo_ordning_reda_behaviour).

-include("leo_ordning_reda.hrl").
-include_lib("eunit/include/eunit.hrl"). % for debug

-export([start_link/3, stop/1, stack/3]).
-export([handle_send/3,
         handle_fail/2]).

-spec start_link(atom(), integer(), integer()) -> ok | {error, _}.
start_link(Node, BufSize, Timeout) ->
    leo_ordning_reda_api:add_container(Node, [{module,      ?MODULE},
                                              {buffer_size, BufSize},
                                              {timeout,     Timeout}]).

-spec stop(atom()) -> ok | {error, _}.
stop(Node) ->
    leo_ordning_reda_api:remove_container(Node).

-spec stack(atom(), _, _) -> ok.
stack(Node, Key, Object) ->
    {ok, Bin} = leo_ordning_reda_api:pack(Object),
    ok = leo_ordning_reda_api:stack(Node, Key, Bin),
    ok.

-spec handle_send(atom(), _, binary()) -> ok.
handle_send(Node, StackInfo, CompressedBin) ->
    ?debugVal({Node, length(StackInfo), byte_size(CompressedBin)}),
    rpc:call(Node, leo_ordning_reda_test_client, output, [CompressedBin]).

-spec handle_fail(atom(), _) -> ok.
handle_fail(Node, StackInfo) ->
    ?debugVal({Node, length(StackInfo)}),
    ok.
```

## License

leo_ordning_reda's license is [Apache License Version 2.0](http://www.apache.org/licenses/LICENSE-2.0.html)

## Sponsors

LeoProject/LeoFS is sponsored by [Rakuten, Inc.](http://global.rakuten.com/corp/) and supported by [Rakuten Institute of Technology](http://rit.rakuten.co.jp/).