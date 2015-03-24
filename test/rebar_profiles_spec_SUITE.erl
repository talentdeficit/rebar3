-module(rebar_profiles_spec_SUITE).

-export([init_per_suite/1,
         end_per_suite/1,
         init_per_testcase/2,
         end_per_testcase/2,
         all/0]).

-export([no_apply/1,
         apply_selective_true/1,
         apply_selective_false/1,
         apply_idempotent/1]).

-include_lib("common_test/include/ct.hrl").
-include_lib("eunit/include/eunit.hrl").

all() -> [no_apply, apply_selective_true, apply_selective_false, apply_idempotent].

init_per_suite(Config) -> Config.

end_per_suite(_Config) -> ok.

init_per_testcase(_, Config) ->
    rebar_test_utils:init_rebar_state(Config, "core_").

end_per_testcase(_, Config) -> Config.

%% if no profiles are specified (either by a task or by the user via `as`)
%%  they shouldn't be applied
no_apply(Config) ->
    AppDir = ?config(apps, Config),

    Name = rebar_test_utils:create_random_name("no_apply_"),
    Vsn = rebar_test_utils:create_random_vsn(),
    rebar_test_utils:create_app(AppDir, Name, Vsn, [kernel, stdlib]),

    Profiles = {profiles, [{baz, [{baz, true}]},
                           {qux, [{qux, true}]}]},
    RebarConfig = [{foo, true}, {bar, true}, Profiles],

    {ok, State} = rebar_test_utils:run_and_check(Config,
                                                 RebarConfig,
                                                 ["compile"],
                                                 return),

    Opts = rebar_state:opts(State),
    %% `foo` and `bar` should be present in the opts
    lists:map(fun(K) -> {ok, true} = dict:find(K, Opts) end, [foo, bar]),
    %% `baz` and `qux` should not
    lists:map(fun(K) -> error      = dict:find(K, Opts) end, [baz, qux]).

%% if there are multiple available profiles only those specified should
%%  be applied
apply_selective_true(Config) ->
    AppDir = ?config(apps, Config),

    Name = rebar_test_utils:create_random_name("apply_selective_true_"),
    Vsn = rebar_test_utils:create_random_vsn(),
    rebar_test_utils:create_app(AppDir, Name, Vsn, [kernel, stdlib]),

    Profiles = {profiles, [{foo, [{x, true}]},
                           {bar, [{y, true}]},
                           {baz, [{x, false}]},
                           {qux, [{y, false}]}]},
    RebarConfig = [{x, null}, {y, null}, Profiles],

    {ok, State} = rebar_test_utils:run_and_check(Config,
                                                 RebarConfig,
                                                 ["as", "foo,bar", "compile"],
                                                 return),

    Opts = rebar_state:opts(State),
    %% `x` and `y` should both be true
    lists:map(fun(K) -> true = dict:fetch(K, Opts) end, [x, y]).

apply_selective_false(Config) ->
    AppDir = ?config(apps, Config),

    Name = rebar_test_utils:create_random_name("apply_selective_false_"),
    Vsn = rebar_test_utils:create_random_vsn(),
    rebar_test_utils:create_app(AppDir, Name, Vsn, [kernel, stdlib]),

    Profiles = {profiles, [{foo, [{x, true}]},
                           {bar, [{y, true}]},
                           {baz, [{x, false}]},
                           {qux, [{y, false}]}]},
    RebarConfig = [{x, null}, {y, null}, Profiles],

    {ok, State} = rebar_test_utils:run_and_check(Config,
                                                 RebarConfig,
                                                 ["as", "baz,qux", "compile"],
                                                 return),

    Opts = rebar_state:opts(State),
    %% `x` and `y` should both be false
    lists:map(fun(K) -> false = dict:fetch(K, Opts) end, [x, y]).

%% applying profiles should be idempotent and should be repeatable
%%  without issue
apply_idempotent(Config) ->
    AppDir = ?config(apps, Config),

    Name = rebar_test_utils:create_random_name("apply_idempotent_"),
    Vsn = rebar_test_utils:create_random_vsn(),
    rebar_test_utils:create_app(AppDir, Name, Vsn, [kernel, stdlib]),

    Profiles = {profiles, [{foo, [{x, [true, false, null]}]}]},
    RebarConfig = [Profiles],

    {ok, State} = rebar_test_utils:run_and_check(Config,
                                                 RebarConfig,
                                                 ["as", "foo,foo", "compile"],
                                                 return),

    Opts = rebar_state:opts(State),
    [true, false, null] = dict:fetch(x, Opts).