%%%-------------------------------------------------------------------
%%% @author dreyk
%%% @copyright (C) 2015, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 30. Jun 2015 01:21
%%%-------------------------------------------------------------------
-module(zraft_app).
-author("dreyk").

-behaviour(application).

%% Application callbacks
-export([start/2,
    stop/1]).

start(_StartType, _StartArgs) ->
    case file:list_dir("data/raft") of
        {ok,L} when length(L)>0->
            timer:sleep(1000),
            application:set_env(zraft_lib,election_timeout,2000),
            zraft_app_sup:start_link();
        _ when node()=:='zraft@10.1.116.51'->
            zraft_util:make_dir("data/raft"),
            timer:sleep(1000),
            application:set_env(zraft_lib,election_timeout,200),
            create_raft(),
            P = spawn_link(fun()->receive O->O end end),
            {ok,P};
        _->
            timer:sleep(1000),
            application:set_env(zraft_lib,election_timeout,200),
            P = spawn_link(fun()->receive O->O end end),
            {ok,P}
    end.
stop(_State) ->
    ok.


create_raft()->
    lists:foldl(fun(I,Acc)->
        create_raft(I,Acc) end,['zraft@10.1.116.51','zraft@10.1.116.52','zraft@10.1.116.53','zraft@10.1.116.54'],
    lists:seq(1,1)).

create_raft(I,[F|T])->
    Name = list_to_atom("dlog-"++integer_to_list(I)),
    Peers = [{Name,Node}||Node<-T],
    case zraft_client:create(Peers,log_backend) of
        {ok,_}->
            ok;
        Else->
            lager:error("Can't crate raft ~p ~p",[I,Else])
    end,
    T++[F].