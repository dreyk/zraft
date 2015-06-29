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
    expire_session/2,fill_aync/3]).

-record(state, {tab, next = 1}).


fill_aync(Form,To,N)->
    Step = round((To-Form+1)/N),
    Ref = make_ref(),
    Me = self(),
    lists:foldl(fun(I,Acc)->
        Form1 = Form+(I-1)*Step,
        To1 = Form+I*Step,
        spawn_link(fun()->
            fill(Me,Ref,Form1,To1) end),
        Acc+1 end,0,lists:seq(1,N)),
    clr(Ref,N,0).
clr(_Ref,0,Acc)->
    Acc;
clr(Ref,N,Acc)->
    receive
        {Ref,Count}->
            clr(Ref,N-1,Acc+Count)
    end.
fill(Me,Ref,Form1,To1)->
    Count = To1-Form1+1,
    [session_write(I)||I<-lists:seq(Form1,To1)],
    Me ! {Ref,Count}.

session_write(I)->
    Idx = I rem 256 + 1,
    To = list_to_atom("dlog-"++integer_to_list(Idx)),
    ok = zraft_session:write(To,{add,{I,[{zont_time_util:system_time(millisec),[{1,1}]}]}},10000).

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