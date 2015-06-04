# zraft

It's standalone RAFT server used for testing [zraft_lib](https://github.com/dreyk/zraft_lib).

## Usage

Compile.

```
./rebar get-deps
./rebar compile

```

Start in console.

```
cd test
./test_linux

Erlang/OTP 17 [erts-6.4.1] [source-381fb6c] [64-bit] [smp:8:8] [async-threads:10] [hipe] [kernel-poll:true]

Eshell V6.4.1  (abort with ^G)

(zraft@127.0.0.1)1> zraft_lib_app:start().
(zraft@127.0.0.1)1> zraft_client:create([{test1,node()},{test2,node()},{test3,node()}],zraft_dict_backend).
{ok,[{test1,'zraft@127.0.0.1'},
     {test2,'zraft@127.0.0.1'},
     {test3,'zraft@127.0.0.1'}]}

(zraft@127.0.0.1)4> zraft_client:write({test2,'zraft@127.0.0.1'},{1,1},1000).
{ok,{test1,'zraft@127.0.0.1'}},%%test1 is leader,send next request to it.

(zraft@127.0.0.1)8> zraft_client:query({test1,'zraft@127.0.0.1'},1,1000).
{ok,1,{test1,'zraft@127.0.0.1'}}

```

OR

```
./rebar generate

cd rel/zraft

bin/zraft console

````
