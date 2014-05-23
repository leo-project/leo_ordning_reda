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


```

Second, a client program is as follow.

```erlang


```

## License

leo_ordning_reda's license is [Apache License Version 2.0](http://www.apache.org/licenses/LICENSE-2.0.html)