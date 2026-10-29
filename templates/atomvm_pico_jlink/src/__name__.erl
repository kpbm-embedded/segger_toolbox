%% @NAME@: AtomVM application (Erlang). Same .avm on the host AtomVM and on the Pico.
%% (atomvmlib 0.6.6 has no lists:sum/1, hence the foldl.)
-module(@NAME@).
-export([start/0]).

start() ->
    io:format("@NAME@ on ~p~n", [atomvm:platform()]),
    Squares = [X * X || X <- lists:seq(1, 5)],
    io:format("@NAME@ squares ~p sum ~p~n", [Squares, lists:foldl(fun(X, Acc) -> X + Acc end, 0, Squares)]),
    ok.
