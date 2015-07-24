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
-compile(nowarn_deprecated_type).

-define(ETS_TAB_STACK_INFO,  leo_ordning_reda_stack_info).
-define(ETS_TAB_STACK_PID,   leo_ordning_reda_stack_pid).
-define(ETS_TAB_DIVIDE_INFO, leo_ordning_reda_divide_info).
-define(ETS_TAB_DIVIDE_PID,  leo_ordning_reda_divide_pid).

-define(PROP_ORDRED_MOD,      'module').
-define(PROP_ORDRED_BUF_SIZE, 'buffer_size').
-define(PROP_ORDRED_TIMEOUT,  'timeout').
-define(PROP_ORDRED_IS_COMP,  'is_compress_obj').
-define(PROP_REMOVED_COUNT,   'removed_count').


-ifdef(TEST).
-define(DEF_REMOVED_COUNT, 5).
-else.
-define(DEF_REMOVED_COUNT, 10).
-endif.

-define(DEF_BUF_SIZE, 1000000). %% about 1MB
-define(REQ_TIMEOUT,    10000). %% 10sec
-define(RCV_TIMEOUT,     1000). %% 1sec
-define(DEF_TMP_STACKED_DIR, "work/ord_reda/").

-record(stack_info, {
          unit         :: term(),     %% id of unit of stack
          module       :: atom(),     %% callback module
          buf_size = 0 :: integer(),  %% buffer size
          is_compression_obj = true :: boolean(),  %% is compression stacked objects
          timeout  = 0 :: non_neg_integer(),  %% buffering timeout
          removed_count = ?DEF_REMOVED_COUNT :: non_neg_integer(),  %% removed container count (Timeout = ${timeout} x ${removed_count})
          tmp_stacked_dir = [] :: string()    %% temporary stacked dir
         }).

-record(straw, {addr_id :: integer(), %% ring address id
                key     :: string(),  %% key (filename)
                object  :: binary(),  %% unstructured-data
                size    :: integer()  %% object-size
               }).
-record(straw_1, {id      :: any(),     %% straw-id
                  object  :: binary(),  %% unstructured-data
                  size    :: integer()  %% object-size
                 }).
-define(STRAW, 'straw_1').


-define(env_send_after_interval(),
        case application:get_env(leo_ordning_reda, send_after_interval) of
            {ok, _SendAfterInterval} -> _SendAfterInterval;
            _ -> 100 %% 100msec
        end).

-define(env_temp_stacked_dir(),
        case application:get_env(leo_ordning_reda, temp_stacked_dir) of
            {ok, _TmpStackedDir} -> _TmpStackedDir;
            _ -> ?DEF_TMP_STACKED_DIR
        end).
