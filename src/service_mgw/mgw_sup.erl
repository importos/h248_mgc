%%%-------------------------------------------------------------------
%%% @author rus
%%% @copyright (C) 2017, <COMPANY>
%%% @doc
%%% родитель всех MGW
%%% каждый новый MGW добавляется как gen_server
%%% @end
%%% Created : 12. Май 2017 10:33
%%%-------------------------------------------------------------------
-module(mgw_sup).
-author("rus").

-behaviour(supervisor).

-include_lib("megaco/include/megaco.hrl").
-include_lib("megaco/include/megaco_message_v1.hrl").

%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).

-export([add_mgw/2, add_mgw/3]).

-define(SERVER, ?MODULE).

%%%===================================================================
%%% API functions
%%%===================================================================

%%--------------------------------------------------------------------
%% @doc
%% Starts the supervisor
%%
%% @end
%%--------------------------------------------------------------------
-spec(start_link() ->
    {ok, Pid :: pid()} | ignore | {error, Reason :: term()}).
start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

%%%===================================================================
%%% Supervisor callbacks
%%%===================================================================

%%--------------------------------------------------------------------
%% @private
%% @doc
%% Whenever a supervisor is started using supervisor:start_link/[2,3],
%% this function is called by the new process to find out about
%% restart strategy, maximum restart frequency and child
%% specifications.
%%
%% @end
%%--------------------------------------------------------------------
-spec(init(Args :: term()) ->
    {ok, {SupFlags :: {RestartStrategy :: supervisor:strategy(),
        MaxR :: non_neg_integer(), MaxT :: non_neg_integer()},
        [ChildSpec :: supervisor:child_spec()]
    }} |
    ignore |
    {error, Reason :: term()}).
init([]) ->
    RestartStrategy = one_for_one, % one_for_one | one_for_all | rest_for_one
    Intensity = 10, %% max restarts
    Period = 1000, %% in period of time
    SupervisorSpecification = {RestartStrategy, Intensity, Period},
    log:log(debug, "   Start MGW supervisor with parametrs: ~p~n", [SupervisorSpecification]),
    {ok, {SupervisorSpecification, []}}.

%%%===================================================================
%%% Internal functions
%%%===================================================================

add_mgw(Mid_User, Ip) ->
    add_mgw(Mid_User, Ip, ?megaco_ip_port_text).
add_mgw(Mid_User, Ip, Port) ->
    Addr = case inet:parse_address(Ip) of
               {ok, A} ->
                   tuple_to_list(A);
               {error, einval} ->
                   log:log(warning, "ip not correct, set mid user 127.0.0.1~n"),
                   [127, 0, 0, 1]
           end,
    MidMGW = {ip4Address, #'IP4Address'{address = Addr, portNumber = Port}},
    MgwName = list_to_atom(Ip ++ ":" ++ integer_to_list(Port)),
    Mgw = #{id => MgwName,
        start => {mgw_gen_fsm, start_link, [MidMGW]},
        restart => transient, % рестартовать, если он завершился аварийно
        shutdown => 2000,
        type => worker,
        modules => [mgw_gen_fsm]
    },
    Res = supervisor:start_child(?SERVER, Mgw),
    case Res of
        {ok, _} ->
            base_mgw:add(MgwName, MidMGW, Mid_User, 72),
            log:log(notify, "Add MGW [~p]....ok", [MgwName]),
            ok;
        {error, _} ->
            log:log(notify, "error.~n"),
            error
    end.

