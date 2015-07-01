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
    Nodes = ['zraft@10.1.116.52','zraft@10.1.116.53','zraft@10.1.116.54'],
    {Sessions,_}=lists:foldl(fun(I,Acc)->
        {Name,Peers}=create_raft(I,Nodes),
        StartSpec = {zraft_session,start_link,[Name,Peers,60000]},
        [{Name,StartSpec,Restart, Shutdown, Type, [zraft_session]}|Acc]
    end,
        [],
        lists:seq(1,256)),
    Sessions.

create_raft(I,T)->
    NameP = list_to_atom("dlog-1"),
    Name = list_to_atom("sdlog-"++integer_to_list(I)),
    Peers = [{NameP,Node}||Node<-T],
    {Name,Peers}.
