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
-export([
    start/2,
    stop/1,
    start/0,
    get_nodes/0
]).


%%get_nodes()->
 %%   ['zraft@10.1.116.51', 'zraft@10.1.116.52', 'zraft@10.1.116.53', 'zraft@10.1.116.54'].

get_nodes()->
    application:get_env(zraft,test_nodes,['zraft@127.0.0.1','zraft@127.0.0.1','zraft@127.0.0.1','zraft@127.0.0.1']).

start(_StartType, _StartArgs) ->
    First = application:get_env(zraft,master_node,'zraft@127.0.0.1'),
    case file:list_dir("data/raft") of
        {ok, L} when is_list(L) ->
            timer:sleep(1000),
            application:set_env(zraft_lib, election_timeout, 2000),
            zraft_app_sup:start_link();
        _ when node() =:= First ->
            zraft_util:make_dir("data/raft"),
            timer:sleep(1000),
            application:set_env(zraft_lib, election_timeout, 200),
            create_raft(),
            P = spawn_link(fun() -> receive O -> O end end),
            {ok, P};
        _ ->
            timer:sleep(1000),
            application:set_env(zraft_lib, election_timeout, 200),
            P = spawn_link(fun() -> receive O -> O end end),
            {ok, P}
    end.
stop(_State) ->
    ok.


create_raft() ->
    lists:foldl(fun(I, Acc) ->
        create_raft(I, Acc) end, get_nodes(), lists:seq(1, 1)).

create_raft(I, [F | T]) ->
    Name = "dlog-" ++ integer_to_list(I) ++ "-",
    {Peers, _} = lists:foldl(fun(Node, {Acc, In}) ->
        {
            [{list_to_atom(Name ++ integer_to_list(In)), Node} | Acc],
            In + 1
        } end, {[], 1}, T),
    case zraft_client:create(Peers, log_backend) of
        {ok, _} ->
            ok;
        Else ->
            lager:error("Can't crate raft ~p ~p", [I, Else])
    end,
    T ++ [F].


start()->
    spawn(fun()->
        ok = zraft_util:start_app(zraft) end).