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
%%======================================================================
-author('Yosuke Hara').

-define(ETS_TAB_STACK_INFO,  leo_ordning_reda_stack_info).
-define(ETS_TAB_STACK_PID,   leo_ordning_reda_stack_pid).
-define(ETS_TAB_DIVIDE_INFO, leo_ordning_reda_divide_info).
-define(ETS_TAB_DIVIDE_PID,  leo_ordning_reda_divide_pid).

-define(DEF_BUF_SIZE, 1000000). %% about 1MB
-define(REQ_TIMEOUT,    10000). %% 10sec
-define(RCV_TIMEOUT,     1000). %% 1sec


-record(stack_info, {
          node         :: atom(),
          buf_size = 0 :: integer(),
          timeout  = 0 :: integer(),
          function     :: function() }).
