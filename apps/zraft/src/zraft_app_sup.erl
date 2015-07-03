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
    Count = application:get_env(zraft,scount,1),
    Restart = permanent,
    Shutdown = 2000,
    Type = worker,
    [_|Nodes]= zraft_app:get_nodes(),
    Sessions=lists:foldl(fun(I,Acc)->
        {Name,Peers}=create_raft(I,Nodes),
        StartSpec = {zraft_session,start_link,[Name,Peers,60000]},
        [{Name,StartSpec,Restart, Shutdown, Type, [zraft_session]}|Acc]
    end,
        [],
        lists:seq(1,Count)),
    Sessions.

create_raft(I,T)->
    NameP = "dlog-1-",
    Name = list_to_atom("sdlog-"++integer_to_list(I)),
    {Peers,_}=lists:foldl(fun(Node,{Acc,In})->
        {
            [{list_to_atom(NameP++integer_to_list(In)),Node}|Acc],
            In+1
        } end,{[],1},T),
    {Name,Peers}.
