leo_ordning_reda
================

[![Build Status](https://secure.travis-ci.org/leo-project/leo_ordning_reda.png?branch=master)](http://travis-ci.org/leo-project/leo_ordning_reda)

**leo_ordning_reda** is a library to handle large objects efficiently.
We can easily write programs that automatically stack and compress large objects to pass them other processes.

## Build Information

* "leo_ordning_reda" uses the [rebar](https://github.com/rebar/rebar) build system. Makefile so that simply running "make" at the top level should work.
* "leo_ordning_reda" requires Erlang R15B03-1 or later.


## Usage in Leo Project

**leo_ordning_reda** is used in [**leo_storage**](https://github.com/leo-project/leo_storage).
It is used to replicate stored objects between remote data centers efficiently.

## Usage

We prepare a server program and a cliente program to use **leo_ordning_reda**.

First, a server program is as follow.
Note that, `handle_send` is called when objects are stacked more than `BufSize` or more than `Timeout` miliseconds imepassed.

```erlang
-module(leo_ordning_reda_test_server).

-behaviour(leo_ordning_reda_behaviour).

-include("leo_ordning_reda.hrl").
-include_lib("eunit/include/eunit.hrl"). % for debug

-export([start_link/3, stop/1]).
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


-spec handle_send(atom(), _, binary()) -> ok.
handle_send(Node, StackInfo, CompressedBin) ->
    ?debugVal({Node, length(StackInfo), byte_size(CompressedBin)}),
    Objects = leo_ordning_reda_api:unpack(CompressedBin),
    ?debugVal(Objects),
    ok.

-spec handle_fail(atom(), _) -> ok.
handle_fail(Node, StackInfo) ->
    ?debugVal({Node, length(StackInfo)}),
    ok.
```

Second, a client program is as follow.

```erlang
-module(leo_ordning_reda_test_client).

-include("leo_ordning_reda.hrl").
-include_lib("eunit/include/eunit.hrl"). % for debug

-define(BUFSIZE, 100). %% 100B
-define(TIMEOUT, 100). %% 0.1sec

-export([main/0]).

main() ->
    Node = node(),
    ok = leo_ordning_reda_api:start(),
    ok = leo_ordning_reda_test_server:start_link(Node, ?BUFSIZE, ?TIMEOUT),
    {ok, Bin1} = leo_ordning_reda_api:pack(lists:seq(1,10)),
    {ok, Bin2} = leo_ordning_reda_api:pack(lists:seq(11,20)),
    {ok, Bin3} = leo_ordning_reda_api:pack(lists:seq(21,30)),
    TotalSize = byte_size(Bin1) + byte_size(Bin2) + byte_size(Bin3),
    ?debugVal({"total:", TotalSize}),
    ok = leo_ordning_reda_api:stack(Node, "key1", Bin1),
    ok = leo_ordning_reda_api:stack(Node, "key2", Bin2),
    ok = leo_ordning_reda_api:stack(Node, "key3", Bin3),
    timer:sleep(2000),
    ok = leo_ordning_reda_test_server:stop(Node),
    ok = application:stop(leo_ordning_reda),
    ok.
```

## License

leo_ordning_reda's license is [Apache License Version 2.0](http://www.apache.org/licenses/LICENSE-2.0.html)