%%%-------------------------------------------------------------------
%%% @author dreyk
%%% @copyright (C) 2015, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 30. Jun 2015 01:32
%%%-------------------------------------------------------------------
-module(log_backend).
-author("dreyk").

-behaviour(zraft_backend).

-export([
    init/1,
    query/2,
    apply_data/2,
    apply_data/3,
    snapshot/1,
    snapshot_done/1,
    snapshot_failed/2,
    install_snapshot/2,
    expire_session/2,fill_async/1,session_write/2]).

-record(state, {tab, next = 1}).


fill_async(N)->
    T = ets:new(stat,[public,ordered_set, {write_concurrency,true}, {read_concurrency, true}]),
    ets:insert(T,{c,0}),
    lists:foldl(fun(I,Acc)->
        spawn_link(fun()->
            fill(T,I,1) end),
        Acc+1 end,0,lists:seq(1,N)),
    stat(T).

stat(T)->
    true  = ets:update_element(T,c,{2,0}),
    Start = os:timestamp(),
    timer:sleep(10000),
    [{_,Count}] = ets:lookup(T,c),
    Delta = timer:now_diff(os:timestamp(),Start),
    lager:info("********* ~p op/s.",[round(Count*1000000/Delta)]),
    stat(T).

fill(T,N,C)->
    session_write(N,C),
    ets:update_counter(T,c,{2,1}),
    fill(T,N,C+1).

session_write(N,C)->
    Idx = N rem 256 +1,
    To = list_to_atom("sdlog-"++integer_to_list(Idx)),
    ok = zraft_session:write(To,{add,{{N,C},[{zraft_util:now_millisec(),[{1,1}]}]}},10000).

%% @doc init backend FSM
init(_) ->
    Tab = ets:new(store, [bag, {write_concurrency, false}, {read_concurrency, false}]),
    {ok, #state{tab = Tab}}.


query(length,#state{tab = Tab})->
    Size = ets:info(Tab,size),
    {ok,Size};
query({read,DevID}, #state{tab = Tab}) ->
    Data = ets:lookup(Tab, DevID),
    {ok,[DevID],Data}.

apply_data({add,{DevID,TimedData}},State = #state{tab = Tab,next = Next}) ->
    ets:insert(Tab,{DevID,Next,TimedData}),
    {ok,[DevID],State#state{next = Next+1}};
apply_data({add,List},State = #state{tab = Tab,next = Next}) when is_list(List)->
    Devices = lists:foldl(fun({DevID,TimedData},Acc)->
        ets:insert(Tab,{DevID,Next,TimedData}),[DevID|Acc] end,[],List),
    {ok,Devices,State#state{next = Next+1}};
apply_data({accept,{DevID,Acc}},State=#state{tab = Tab})->
    Match = [{{DevID, '$1', '_'}, [{'=<', '$1', {const, Acc}}], [true]}],
    ets:select_delete(Tab, Match),
    {ok,[],State};
apply_data(_, State) ->
    {{error, not_supported}, State}.

apply_data(_,_Session, State) ->
    {{error, not_supported}, State}.

expire_session(_Session,State) ->
    {ok,[],State}.

snapshot(State = #state{tab = Tab,next = Next}) ->
    ets:delete(Tab,next),
    ets:insert(Tab,{next,Next}),
    Fun = fun(ToDir) ->
        File = filename:join(ToDir, "state"),
        ets:tab2file(Tab, File, [{extended_info, [md5sum]}]),
        ok
    end,
    {async, Fun, State}.

snapshot_done(Dict) ->
    {ok, Dict}.

snapshot_failed(_Reason, Dict) ->
    {ok, Dict}.

install_snapshot(Dir,OldSate) ->
    File = filename:join(Dir, "state"),
    case ets:file2tab(File, [{verify,true}]) of
        {ok, NewTab} ->
            case OldSate of
                #state{tab = OldTab}->
                    ets:delete(OldTab);
                _->
                    ok
            end,
            [{next,Next}]=ets:lookup(NewTab,next),
            ets:delete(NewTab,next),
            {ok,#state{tab = NewTab,next = Next}};
        Else ->
            Else
    end.
