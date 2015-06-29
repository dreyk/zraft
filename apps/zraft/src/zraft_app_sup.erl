%%%-------------------------------------------------------------------
%%% @author dreyk
%%% @copyright (C) 2015, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 30. Jun 2015 01:22
%%%-------------------------------------------------------------------
-module(zraft_app_sup).
-author("dreyk").

-behaviour(supervisor).

%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).


init([]) ->
    RestartStrategy = one_for_one,
    MaxRestarts = 1000,
    MaxSecondsBetweenRestarts = 3600,

    SupFlags = {RestartStrategy, MaxRestarts, MaxSecondsBetweenRestarts},

    {ok, {SupFlags, create_raft()}}.


create_raft()->
    Restart = permanent,
    Shutdown = 2000,
    Type = worker,
    {Sessions,_}=lists:foldl(fun(I,{SupAcc,Acc})->
        {Name,Peers,Acc1}=create_raft(I,Acc),
        StartSpec = {zraft_session,start_link,[Name,Peers,60000]},
        SupAcc1 = [{Name,StartSpec,Restart, Shutdown, Type, [zraft_session]}|SupAcc],
        {SupAcc1,Acc1}
    end,
        {[],['zraft@10.1.116.51','zraft@10.1.116.52','zraft@10.1.116.53','zraft@10.1.116.54']},
        lists:seq(1,256)),
    Sessions.

create_raft(I,[F|T])->
    NameP = list_to_atom("dlog-"++integer_to_list(I)),
    Name = list_to_atom("sdlog-"++integer_to_list(I)),
    Peers = [{NameP,Node}||Node<-T],
    {Name,Peers,T++[F]}.
