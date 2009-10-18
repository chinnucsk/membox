-file("/opt/R13B02/lib/erlang/lib/parsetools-2.0/include/leexinc.hrl", 0).
%% The source of this file is part of leex distribution, as such it
%% has the same Copyright as the other files in the leex
%% distribution. The Copyright is defined in the accompanying file
%% COPYRIGHT. However, the resultant scanner generated by leex is the
%% property of the creator of the scanner and is not covered by that
%% Copyright.

-module(membox_lexer).

-export([string/1,string/2,token/2,token/3,tokens/2,tokens/3]).
-export([format_error/1]).

%% User code. This is placed here to allow extra attributes.
-file("./membox_lexer.xrl", 28).
-compile(inline).
is_numeric(N) ->
  try
    begin
      _ = list_to_integer(N),
      true
    end
  catch
    error:badarg ->
      false
  end.
-file("/opt/R13B02/lib/erlang/lib/parsetools-2.0/include/leexinc.hrl", 14).

format_error({illegal,S}) -> ["illegal characters ",io_lib:write_string(S)];
format_error({user,S}) -> S.

string(String) -> string(String, 1).

string(String, Line) -> string(String, Line, String, []).

%% string(InChars, Line, TokenChars, Tokens) ->
%% {ok,Tokens,Line} | {error,ErrorInfo,Line}.
%% Note the line number going into yystate, L0, is line of token
%% start while line number returned is line of token end. We want line
%% of token start.

string([], L, [], Ts) ->                     % No partial tokens!
    {ok,yyrev(Ts),L};
string(Ics0, L0, Tcs, Ts) ->
    case yystate(yystate(), Ics0, L0, 0, reject, 0) of
        {A,Alen,Ics1,L1} ->                  % Accepting end state
            string_cont(Ics1, L1, yyaction(A, Alen, Tcs, L0), Ts);
        {A,Alen,Ics1,L1,_S1} ->              % Accepting transistion state
            string_cont(Ics1, L1, yyaction(A, Alen, Tcs, L0), Ts);
        {reject,_Alen,Tlen,_Ics1,L1,_S1} ->  % After a non-accepting state
            {error,{L0,?MODULE,{illegal,yypre(Tcs, Tlen+1)}},L1};
        {A,Alen,_Tlen,_Ics1,L1,_S1} ->
            string_cont(yysuf(Tcs, Alen), L1, yyaction(A, Alen, Tcs, L0), Ts)
    end.

%% string_cont(RestChars, Line, Token, Tokens)
%% Test for and remove the end token wrapper. Push back characters
%% are prepended to RestChars.

string_cont(Rest, Line, {token,T}, Ts) ->
    string(Rest, Line, Rest, [T|Ts]);
string_cont(Rest, Line, {token,T,Push}, Ts) ->
    NewRest = Push ++ Rest,
    string(NewRest, Line, NewRest, [T|Ts]);
string_cont(Rest, Line, {end_token,T}, Ts) ->
    string(Rest, Line, Rest, [T|Ts]);
string_cont(Rest, Line, {end_token,T,Push}, Ts) ->
    NewRest = Push ++ Rest,
    string(NewRest, Line, NewRest, [T|Ts]);
string_cont(Rest, Line, skip_token, Ts) ->
    string(Rest, Line, Rest, Ts);
string_cont(Rest, Line, {skip_token,Push}, Ts) ->
    NewRest = Push ++ Rest,
    string(NewRest, Line, NewRest, Ts);
string_cont(_Rest, Line, {error,S}, _Ts) ->
    {error,{Line,?MODULE,{user,S}},Line}.

%% token(Continuation, Chars) ->
%% token(Continuation, Chars, Line) ->
%% {more,Continuation} | {done,ReturnVal,RestChars}.
%% Must be careful when re-entering to append the latest characters to the
%% after characters in an accept. The continuation is:
%% {token,State,CurrLine,TokenChars,TokenLen,TokenLine,AccAction,AccLen}

token(Cont, Chars) -> token(Cont, Chars, 1).

token([], Chars, Line) ->
    token(yystate(), Chars, Line, Chars, 0, Line, reject, 0);
token({token,State,Line,Tcs,Tlen,Tline,Action,Alen}, Chars, _) ->
    token(State, Chars, Line, Tcs ++ Chars, Tlen, Tline, Action, Alen).

%% token(State, InChars, Line, TokenChars, TokenLen, TokenLine,
%% AcceptAction, AcceptLen) ->
%% {more,Continuation} | {done,ReturnVal,RestChars}.
%% The argument order is chosen to be more efficient.

token(S0, Ics0, L0, Tcs, Tlen0, Tline, A0, Alen0) ->
    case yystate(S0, Ics0, L0, Tlen0, A0, Alen0) of
        %% Accepting end state, we have a token.
        {A1,Alen1,Ics1,L1} ->
            token_cont(Ics1, L1, yyaction(A1, Alen1, Tcs, Tline));
        %% Accepting transition state, can take more chars.
        {A1,Alen1,[],L1,S1} ->                  % Need more chars to check
            {more,{token,S1,L1,Tcs,Alen1,Tline,A1,Alen1}};
        {A1,Alen1,Ics1,L1,_S1} ->               % Take what we got
            token_cont(Ics1, L1, yyaction(A1, Alen1, Tcs, Tline));
        %% After a non-accepting state, maybe reach accept state later.
        {A1,Alen1,Tlen1,[],L1,S1} ->            % Need more chars to check
            {more,{token,S1,L1,Tcs,Tlen1,Tline,A1,Alen1}};
        {reject,_Alen1,Tlen1,eof,L1,_S1} ->     % No token match
            %% Check for partial token which is error.
            Ret = if Tlen1 > 0 -> {error,{Tline,?MODULE,
                                          %% Skip eof tail in Tcs.
                                          {illegal,yypre(Tcs, Tlen1)}},L1};
                     true -> {eof,L1}
                  end,
            {done,Ret,eof};
        {reject,_Alen1,Tlen1,Ics1,L1,_S1} ->    % No token match
            Error = {Tline,?MODULE,{illegal,yypre(Tcs, Tlen1+1)}},
            {done,{error,Error,L1},Ics1};
        {A1,Alen1,_Tlen1,_Ics1,L1,_S1} ->       % Use last accept match
            token_cont(yysuf(Tcs, Alen1), L1, yyaction(A1, Alen1, Tcs, Tline))
    end.

%% token_cont(RestChars, Line, Token)
%% If we have a token or error then return done, else if we have a
%% skip_token then continue.

token_cont(Rest, Line, {token,T}) ->
    {done,{ok,T,Line},Rest};
token_cont(Rest, Line, {token,T,Push}) ->
    NewRest = Push ++ Rest,
    {done,{ok,T,Line},NewRest};
token_cont(Rest, Line, {end_token,T}) ->
    {done,{ok,T,Line},Rest};
token_cont(Rest, Line, {end_token,T,Push}) ->
    NewRest = Push ++ Rest,
    {done,{ok,T,Line},NewRest};
token_cont(Rest, Line, skip_token) ->
    token(yystate(), Rest, Line, Rest, 0, Line, reject, 0);
token_cont(Rest, Line, {skip_token,Push}) ->
    NewRest = Push ++ Rest,
    token(yystate(), NewRest, Line, NewRest, 0, Line, reject, 0);
token_cont(Rest, Line, {error,S}) ->
    {done,{error,{Line,?MODULE,{user,S}},Line},Rest}.

%% tokens(Continuation, Chars, Line) ->
%% {more,Continuation} | {done,ReturnVal,RestChars}.
%% Must be careful when re-entering to append the latest characters to the
%% after characters in an accept. The continuation is:
%% {tokens,State,CurrLine,TokenChars,TokenLen,TokenLine,Tokens,AccAction,AccLen}
%% {skip_tokens,State,CurrLine,TokenChars,TokenLen,TokenLine,Error,AccAction,AccLen}

tokens(Cont, Chars) -> tokens(Cont, Chars, 1).

tokens([], Chars, Line) ->
    tokens(yystate(), Chars, Line, Chars, 0, Line, [], reject, 0);
tokens({tokens,State,Line,Tcs,Tlen,Tline,Ts,Action,Alen}, Chars, _) ->
    tokens(State, Chars, Line, Tcs ++ Chars, Tlen, Tline, Ts, Action, Alen);
tokens({skip_tokens,State,Line,Tcs,Tlen,Tline,Error,Action,Alen}, Chars, _) ->
    skip_tokens(State, Chars, Line, Tcs ++ Chars, Tlen, Tline, Error, Action, Alen).

%% tokens(State, InChars, Line, TokenChars, TokenLen, TokenLine, Tokens,
%% AcceptAction, AcceptLen) ->
%% {more,Continuation} | {done,ReturnVal,RestChars}.

tokens(S0, Ics0, L0, Tcs, Tlen0, Tline, Ts, A0, Alen0) ->
    case yystate(S0, Ics0, L0, Tlen0, A0, Alen0) of
        %% Accepting end state, we have a token.
        {A1,Alen1,Ics1,L1} ->
            tokens_cont(Ics1, L1, yyaction(A1, Alen1, Tcs, Tline), Ts);
        %% Accepting transition state, can take more chars.
        {A1,Alen1,[],L1,S1} ->                  % Need more chars to check
            {more,{tokens,S1,L1,Tcs,Alen1,Tline,Ts,A1,Alen1}};
        {A1,Alen1,Ics1,L1,_S1} ->               % Take what we got
            tokens_cont(Ics1, L1, yyaction(A1, Alen1, Tcs, Tline), Ts);
        %% After a non-accepting state, maybe reach accept state later.
        {A1,Alen1,Tlen1,[],L1,S1} ->            % Need more chars to check
            {more,{tokens,S1,L1,Tcs,Tlen1,Tline,Ts,A1,Alen1}};
        {reject,_Alen1,Tlen1,eof,L1,_S1} ->     % No token match
            %% Check for partial token which is error, no need to skip here.
            Ret = if Tlen1 > 0 -> {error,{Tline,?MODULE,
                                          %% Skip eof tail in Tcs.
                                          {illegal,yypre(Tcs, Tlen1)}},L1};
                     Ts == [] -> {eof,L1};
                     true -> {ok,yyrev(Ts),L1}
                  end,
            {done,Ret,eof};
        {reject,_Alen1,Tlen1,_Ics1,L1,_S1} ->
            %% Skip rest of tokens.
            Error = {L1,?MODULE,{illegal,yypre(Tcs, Tlen1+1)}},
            skip_tokens(yysuf(Tcs, Tlen1+1), L1, Error);
        {A1,Alen1,_Tlen1,_Ics1,L1,_S1} ->
            Token = yyaction(A1, Alen1, Tcs, Tline),
            tokens_cont(yysuf(Tcs, Alen1), L1, Token, Ts)
    end.

%% tokens_cont(RestChars, Line, Token, Tokens)
%% If we have an end_token or error then return done, else if we have
%% a token then save it and continue, else if we have a skip_token
%% just continue.

tokens_cont(Rest, Line, {token,T}, Ts) ->
    tokens(yystate(), Rest, Line, Rest, 0, Line, [T|Ts], reject, 0);
tokens_cont(Rest, Line, {token,T,Push}, Ts) ->
    NewRest = Push ++ Rest,
    tokens(yystate(), NewRest, Line, NewRest, 0, Line, [T|Ts], reject, 0);
tokens_cont(Rest, Line, {end_token,T}, Ts) ->
    {done,{ok,yyrev(Ts, [T]),Line},Rest};
tokens_cont(Rest, Line, {end_token,T,Push}, Ts) ->
    NewRest = Push ++ Rest,
    {done,{ok,yyrev(Ts, [T]),Line},NewRest};
tokens_cont(Rest, Line, skip_token, Ts) ->
    tokens(yystate(), Rest, Line, Rest, 0, Line, Ts, reject, 0);
tokens_cont(Rest, Line, {skip_token,Push}, Ts) ->
    NewRest = Push ++ Rest,
    tokens(yystate(), NewRest, Line, NewRest, 0, Line, Ts, reject, 0);
tokens_cont(Rest, Line, {error,S}, _Ts) ->
    skip_tokens(Rest, Line, {Line,?MODULE,{user,S}}).

%%skip_tokens(InChars, Line, Error) -> {done,{error,Error,Line},Ics}.
%% Skip tokens until an end token, junk everything and return the error.

skip_tokens(Ics, Line, Error) ->
    skip_tokens(yystate(), Ics, Line, Ics, 0, Line, Error, reject, 0).

%% skip_tokens(State, InChars, Line, TokenChars, TokenLen, TokenLine, Tokens,
%% AcceptAction, AcceptLen) ->
%% {more,Continuation} | {done,ReturnVal,RestChars}.

skip_tokens(S0, Ics0, L0, Tcs, Tlen0, Tline, Error, A0, Alen0) ->
    case yystate(S0, Ics0, L0, Tlen0, A0, Alen0) of
        {A1,Alen1,Ics1,L1} ->                  % Accepting end state
            skip_cont(Ics1, L1, yyaction(A1, Alen1, Tcs, Tline), Error);
        {A1,Alen1,[],L1,S1} ->                 % After an accepting state
            {more,{skip_tokens,S1,L1,Tcs,Alen1,Tline,Error,A1,Alen1}};
        {A1,Alen1,Ics1,L1,_S1} ->
            skip_cont(Ics1, L1, yyaction(A1, Alen1, Tcs, Tline), Error);
        {A1,Alen1,Tlen1,[],L1,S1} ->           % After a non-accepting state
            {more,{skip_tokens,S1,L1,Tcs,Tlen1,Tline,Error,A1,Alen1}};
        {reject,_Alen1,_Tlen1,eof,L1,_S1} ->
            {done,{error,Error,L1},eof};
        {reject,_Alen1,Tlen1,_Ics1,L1,_S1} ->
            skip_tokens(yysuf(Tcs, Tlen1+1), L1, Error);
        {A1,Alen1,_Tlen1,_Ics1,L1,_S1} ->
            Token = yyaction(A1, Alen1, Tcs, Tline),
            skip_cont(yysuf(Tcs, Alen1), L1, Token, Error)
    end.

%% skip_cont(RestChars, Line, Token, Error)
%% Skip tokens until we have an end_token or error then return done
%% with the original rror.

skip_cont(Rest, Line, {token,_T}, Error) ->
    skip_tokens(yystate(), Rest, Line, Rest, 0, Line, Error, reject, 0);
skip_cont(Rest, Line, {token,_T,Push}, Error) ->
    NewRest = Push ++ Rest,
    skip_tokens(yystate(), NewRest, Line, NewRest, 0, Line, Error, reject, 0);
skip_cont(Rest, Line, {end_token,_T}, Error) ->
    {done,{error,Error,Line},Rest};
skip_cont(Rest, Line, {end_token,_T,Push}, Error) ->
    NewRest = Push ++ Rest,
    {done,{error,Error,Line},NewRest};
skip_cont(Rest, Line, skip_token, Error) ->
    skip_tokens(yystate(), Rest, Line, Rest, 0, Line, Error, reject, 0);
skip_cont(Rest, Line, {skip_token,Push}, Error) ->
    NewRest = Push ++ Rest,
    skip_tokens(yystate(), NewRest, Line, NewRest, 0, Line, Error, reject, 0);
skip_cont(Rest, Line, {error,_S}, Error) ->
    skip_tokens(yystate(), Rest, Line, Rest, 0, Line, Error, reject, 0).

yyrev(List) -> lists:reverse(List).
yyrev(List, Tail) -> lists:reverse(List, Tail).
yypre(List, N) -> lists:sublist(List, 1, N).
yysuf(List, N) -> lists:nthtail(N, List).

%% yystate() -> InitialState.
%% yystate(State, InChars, Line, CurrTokLen, AcceptAction, AcceptLen) ->
%% {Action, AcceptLen, RestChars, Line} |
%% {Action, AcceptLen, RestChars, Line, State} |
%% {reject, AcceptLen, CurrTokLen, RestChars, Line, State} |
%% {Action, AcceptLen, CurrTokLen, RestChars, Line, State}.
%% Generated state transition functions. The non-accepting end state
%% return signal either an unrecognised character or end of current
%% input.

-file("./membox_lexer.erl", 287).
yystate() -> 63.

yystate(66, [80|Ics], Line, Tlen, Action, Alen) ->
    yystate(62, Ics, Line, Tlen+1, Action, Alen);
yystate(66, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,66};
yystate(65, Ics, Line, Tlen, _, _) ->
    {13,Tlen,Ics,Line};
yystate(64, [89|Ics], Line, Tlen, Action, Alen) ->
    yystate(66, Ics, Line, Tlen+1, Action, Alen);
yystate(64, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,64};
yystate(63, [116|Ics], Line, Tlen, Action, Alen) ->
    yystate(59, Ics, Line, Tlen+1, Action, Alen);
yystate(63, [115|Ics], Line, Tlen, Action, Alen) ->
    yystate(43, Ics, Line, Tlen+1, Action, Alen);
yystate(63, [109|Ics], Line, Tlen, Action, Alen) ->
    yystate(23, Ics, Line, Tlen+1, Action, Alen);
yystate(63, [105|Ics], Line, Tlen, Action, Alen) ->
    yystate(7, Ics, Line, Tlen+1, Action, Alen);
yystate(63, [103|Ics], Line, Tlen, Action, Alen) ->
    yystate(16, Ics, Line, Tlen+1, Action, Alen);
yystate(63, [101|Ics], Line, Tlen, Action, Alen) ->
    yystate(24, Ics, Line, Tlen+1, Action, Alen);
yystate(63, [100|Ics], Line, Tlen, Action, Alen) ->
    yystate(44, Ics, Line, Tlen+1, Action, Alen);
yystate(63, [84|Ics], Line, Tlen, Action, Alen) ->
    yystate(64, Ics, Line, Tlen+1, Action, Alen);
yystate(63, [83|Ics], Line, Tlen, Action, Alen) ->
    yystate(58, Ics, Line, Tlen+1, Action, Alen);
yystate(63, [77|Ics], Line, Tlen, Action, Alen) ->
    yystate(42, Ics, Line, Tlen+1, Action, Alen);
yystate(63, [73|Ics], Line, Tlen, Action, Alen) ->
    yystate(30, Ics, Line, Tlen+1, Action, Alen);
yystate(63, [71|Ics], Line, Tlen, Action, Alen) ->
    yystate(10, Ics, Line, Tlen+1, Action, Alen);
yystate(63, [69|Ics], Line, Tlen, Action, Alen) ->
    yystate(1, Ics, Line, Tlen+1, Action, Alen);
yystate(63, [68|Ics], Line, Tlen, Action, Alen) ->
    yystate(25, Ics, Line, Tlen+1, Action, Alen);
yystate(63, [32|Ics], Line, Tlen, Action, Alen) ->
    yystate(61, Ics, Line, Tlen+1, Action, Alen);
yystate(63, [13|Ics], Line, Tlen, Action, Alen) ->
    yystate(65, Ics, Line, Tlen+1, Action, Alen);
yystate(63, [10|Ics], Line, Tlen, Action, Alen) ->
    yystate(65, Ics, Line+1, Tlen+1, Action, Alen);
yystate(63, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,63};
yystate(62, [69|Ics], Line, Tlen, Action, Alen) ->
    yystate(47, Ics, Line, Tlen+1, Action, Alen);
yystate(62, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,62};
yystate(61, [92|Ics], Line, Tlen, _, _) ->
    yystate(57, Ics, Line, Tlen+1, 12, Tlen);
yystate(61, [11|Ics], Line, Tlen, _, _) ->
    yystate(61, Ics, Line, Tlen+1, 12, Tlen);
yystate(61, [12|Ics], Line, Tlen, _, _) ->
    yystate(61, Ics, Line, Tlen+1, 12, Tlen);
yystate(61, [C|Ics], Line, Tlen, _, _) when C >= 0, C =< 9 ->
    yystate(61, Ics, Line, Tlen+1, 12, Tlen);
yystate(61, [C|Ics], Line, Tlen, _, _) when C >= 14, C =< 31 ->
    yystate(61, Ics, Line, Tlen+1, 12, Tlen);
yystate(61, [C|Ics], Line, Tlen, _, _) when C >= 33, C =< 39 ->
    yystate(61, Ics, Line, Tlen+1, 12, Tlen);
yystate(61, [C|Ics], Line, Tlen, _, _) when C >= 42, C =< 91 ->
    yystate(61, Ics, Line, Tlen+1, 12, Tlen);
yystate(61, [C|Ics], Line, Tlen, _, _) when C >= 93, C =< 123 ->
    yystate(61, Ics, Line, Tlen+1, 12, Tlen);
yystate(61, [C|Ics], Line, Tlen, _, _) when C >= 125 ->
    yystate(61, Ics, Line, Tlen+1, 12, Tlen);
yystate(61, Ics, Line, Tlen, _, _) ->
    {12,Tlen,Ics,Line,61};
yystate(60, [121|Ics], Line, Tlen, Action, Alen) ->
    yystate(49, Ics, Line, Tlen+1, Action, Alen);
yystate(60, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,60};
yystate(59, [121|Ics], Line, Tlen, Action, Alen) ->
    yystate(55, Ics, Line, Tlen+1, Action, Alen);
yystate(59, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,59};
yystate(58, [69|Ics], Line, Tlen, Action, Alen) ->
    yystate(54, Ics, Line, Tlen+1, Action, Alen);
yystate(58, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,58};
yystate(57, [124|Ics], Line, Tlen, _, _) ->
    yystate(61, Ics, Line, Tlen+1, 12, Tlen);
yystate(57, [94|Ics], Line, Tlen, _, _) ->
    yystate(53, Ics, Line, Tlen+1, 12, Tlen);
yystate(57, [93|Ics], Line, Tlen, _, _) ->
    yystate(61, Ics, Line, Tlen+1, 12, Tlen);
yystate(57, [92|Ics], Line, Tlen, _, _) ->
    yystate(57, Ics, Line, Tlen+1, 12, Tlen);
yystate(57, [40|Ics], Line, Tlen, _, _) ->
    yystate(61, Ics, Line, Tlen+1, 12, Tlen);
yystate(57, [41|Ics], Line, Tlen, _, _) ->
    yystate(61, Ics, Line, Tlen+1, 12, Tlen);
yystate(57, [32|Ics], Line, Tlen, _, _) ->
    yystate(61, Ics, Line, Tlen+1, 12, Tlen);
yystate(57, [13|Ics], Line, Tlen, _, _) ->
    yystate(61, Ics, Line, Tlen+1, 12, Tlen);
yystate(57, [11|Ics], Line, Tlen, _, _) ->
    yystate(61, Ics, Line, Tlen+1, 12, Tlen);
yystate(57, [12|Ics], Line, Tlen, _, _) ->
    yystate(61, Ics, Line, Tlen+1, 12, Tlen);
yystate(57, [C|Ics], Line, Tlen, _, _) when C >= 0, C =< 9 ->
    yystate(61, Ics, Line, Tlen+1, 12, Tlen);
yystate(57, [C|Ics], Line, Tlen, _, _) when C >= 14, C =< 31 ->
    yystate(61, Ics, Line, Tlen+1, 12, Tlen);
yystate(57, [C|Ics], Line, Tlen, _, _) when C >= 33, C =< 39 ->
    yystate(61, Ics, Line, Tlen+1, 12, Tlen);
yystate(57, [C|Ics], Line, Tlen, _, _) when C >= 42, C =< 91 ->
    yystate(61, Ics, Line, Tlen+1, 12, Tlen);
yystate(57, [C|Ics], Line, Tlen, _, _) when C >= 95, C =< 123 ->
    yystate(61, Ics, Line, Tlen+1, 12, Tlen);
yystate(57, [C|Ics], Line, Tlen, _, _) when C >= 125 ->
    yystate(61, Ics, Line, Tlen+1, 12, Tlen);
yystate(57, Ics, Line, Tlen, _, _) ->
    {12,Tlen,Ics,Line,57};
yystate(56, [98|Ics], Line, Tlen, _, _) ->
    yystate(60, Ics, Line, Tlen+1, 6, Tlen);
yystate(56, Ics, Line, Tlen, _, _) ->
    {6,Tlen,Ics,Line,56};
yystate(55, [112|Ics], Line, Tlen, Action, Alen) ->
    yystate(51, Ics, Line, Tlen+1, Action, Alen);
yystate(55, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,55};
yystate(54, [84|Ics], Line, Tlen, Action, Alen) ->
    yystate(50, Ics, Line, Tlen+1, Action, Alen);
yystate(54, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,54};
yystate(53, [124|Ics], Line, Tlen, _, _) ->
    yystate(61, Ics, Line, Tlen+1, 12, Tlen);
yystate(53, [92|Ics], Line, Tlen, _, _) ->
    yystate(57, Ics, Line, Tlen+1, 12, Tlen);
yystate(53, [40|Ics], Line, Tlen, _, _) ->
    yystate(61, Ics, Line, Tlen+1, 12, Tlen);
yystate(53, [41|Ics], Line, Tlen, _, _) ->
    yystate(61, Ics, Line, Tlen+1, 12, Tlen);
yystate(53, [32|Ics], Line, Tlen, _, _) ->
    yystate(61, Ics, Line, Tlen+1, 12, Tlen);
yystate(53, [13|Ics], Line, Tlen, _, _) ->
    yystate(61, Ics, Line, Tlen+1, 12, Tlen);
yystate(53, [11|Ics], Line, Tlen, _, _) ->
    yystate(61, Ics, Line, Tlen+1, 12, Tlen);
yystate(53, [12|Ics], Line, Tlen, _, _) ->
    yystate(61, Ics, Line, Tlen+1, 12, Tlen);
yystate(53, [C|Ics], Line, Tlen, _, _) when C >= 0, C =< 9 ->
    yystate(61, Ics, Line, Tlen+1, 12, Tlen);
yystate(53, [C|Ics], Line, Tlen, _, _) when C >= 14, C =< 31 ->
    yystate(61, Ics, Line, Tlen+1, 12, Tlen);
yystate(53, [C|Ics], Line, Tlen, _, _) when C >= 33, C =< 39 ->
    yystate(61, Ics, Line, Tlen+1, 12, Tlen);
yystate(53, [C|Ics], Line, Tlen, _, _) when C >= 42, C =< 91 ->
    yystate(61, Ics, Line, Tlen+1, 12, Tlen);
yystate(53, [C|Ics], Line, Tlen, _, _) when C >= 93, C =< 123 ->
    yystate(61, Ics, Line, Tlen+1, 12, Tlen);
yystate(53, [C|Ics], Line, Tlen, _, _) when C >= 125 ->
    yystate(61, Ics, Line, Tlen+1, 12, Tlen);
yystate(53, Ics, Line, Tlen, _, _) ->
    {12,Tlen,Ics,Line,53};
yystate(52, [114|Ics], Line, Tlen, Action, Alen) ->
    yystate(56, Ics, Line, Tlen+1, Action, Alen);
yystate(52, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,52};
yystate(51, [101|Ics], Line, Tlen, Action, Alen) ->
    yystate(47, Ics, Line, Tlen+1, Action, Alen);
yystate(51, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,51};
yystate(50, [78|Ics], Line, Tlen, _, _) ->
    yystate(46, Ics, Line, Tlen+1, 0, Tlen);
yystate(50, Ics, Line, Tlen, _, _) ->
    {0,Tlen,Ics,Line,50};
yystate(49, Ics, Line, Tlen, _, _) ->
    {8,Tlen,Ics,Line};
yystate(48, [108|Ics], Line, Tlen, Action, Alen) ->
    yystate(33, Ics, Line, Tlen+1, Action, Alen);
yystate(48, [99|Ics], Line, Tlen, Action, Alen) ->
    yystate(52, Ics, Line, Tlen+1, Action, Alen);
yystate(48, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,48};
yystate(47, Ics, Line, Tlen, _, _) ->
    {11,Tlen,Ics,Line};
yystate(46, [88|Ics], Line, Tlen, Action, Alen) ->
    yystate(27, Ics, Line, Tlen+1, Action, Alen);
yystate(46, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,46};
yystate(45, [89|Ics], Line, Tlen, Action, Alen) ->
    yystate(49, Ics, Line, Tlen+1, Action, Alen);
yystate(45, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,45};
yystate(44, [101|Ics], Line, Tlen, Action, Alen) ->
    yystate(48, Ics, Line, Tlen+1, Action, Alen);
yystate(44, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,44};
yystate(43, [101|Ics], Line, Tlen, Action, Alen) ->
    yystate(39, Ics, Line, Tlen+1, Action, Alen);
yystate(43, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,43};
yystate(42, [71|Ics], Line, Tlen, Action, Alen) ->
    yystate(38, Ics, Line, Tlen+1, Action, Alen);
yystate(42, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,42};
yystate(41, [66|Ics], Line, Tlen, _, _) ->
    yystate(45, Ics, Line, Tlen+1, 6, Tlen);
yystate(41, Ics, Line, Tlen, _, _) ->
    {6,Tlen,Ics,Line,41};
yystate(40, [115|Ics], Line, Tlen, Action, Alen) ->
    yystate(21, Ics, Line, Tlen+1, Action, Alen);
yystate(40, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,40};
yystate(39, [116|Ics], Line, Tlen, Action, Alen) ->
    yystate(35, Ics, Line, Tlen+1, Action, Alen);
yystate(39, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,39};
yystate(38, [69|Ics], Line, Tlen, Action, Alen) ->
    yystate(34, Ics, Line, Tlen+1, Action, Alen);
yystate(38, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,38};
yystate(37, [82|Ics], Line, Tlen, Action, Alen) ->
    yystate(41, Ics, Line, Tlen+1, Action, Alen);
yystate(37, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,37};
yystate(36, [116|Ics], Line, Tlen, Action, Alen) ->
    yystate(40, Ics, Line, Tlen+1, Action, Alen);
yystate(36, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,36};
yystate(35, [110|Ics], Line, Tlen, _, _) ->
    yystate(31, Ics, Line, Tlen+1, 0, Tlen);
yystate(35, Ics, Line, Tlen, _, _) ->
    {0,Tlen,Ics,Line,35};
yystate(34, [84|Ics], Line, Tlen, Action, Alen) ->
    yystate(11, Ics, Line, Tlen+1, Action, Alen);
yystate(34, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,34};
yystate(33, Ics, Line, Tlen, _, _) ->
    {10,Tlen,Ics,Line};
yystate(32, [115|Ics], Line, Tlen, Action, Alen) ->
    yystate(36, Ics, Line, Tlen+1, Action, Alen);
yystate(32, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,32};
yystate(31, [120|Ics], Line, Tlen, Action, Alen) ->
    yystate(27, Ics, Line, Tlen+1, Action, Alen);
yystate(31, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,31};
yystate(30, [78|Ics], Line, Tlen, Action, Alen) ->
    yystate(26, Ics, Line, Tlen+1, Action, Alen);
yystate(30, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,30};
yystate(29, [76|Ics], Line, Tlen, Action, Alen) ->
    yystate(33, Ics, Line, Tlen+1, Action, Alen);
yystate(29, [67|Ics], Line, Tlen, Action, Alen) ->
    yystate(37, Ics, Line, Tlen+1, Action, Alen);
yystate(29, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,29};
yystate(28, [105|Ics], Line, Tlen, Action, Alen) ->
    yystate(32, Ics, Line, Tlen+1, Action, Alen);
yystate(28, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,28};
yystate(27, Ics, Line, Tlen, _, _) ->
    {2,Tlen,Ics,Line};
yystate(26, [67|Ics], Line, Tlen, Action, Alen) ->
    yystate(22, Ics, Line, Tlen+1, Action, Alen);
yystate(26, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,26};
yystate(25, [69|Ics], Line, Tlen, Action, Alen) ->
    yystate(29, Ics, Line, Tlen+1, Action, Alen);
yystate(25, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,25};
yystate(24, [120|Ics], Line, Tlen, Action, Alen) ->
    yystate(28, Ics, Line, Tlen+1, Action, Alen);
yystate(24, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,24};
yystate(23, [103|Ics], Line, Tlen, Action, Alen) ->
    yystate(19, Ics, Line, Tlen+1, Action, Alen);
yystate(23, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,23};
yystate(22, [82|Ics], Line, Tlen, Action, Alen) ->
    yystate(18, Ics, Line, Tlen+1, Action, Alen);
yystate(22, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,22};
yystate(21, Ics, Line, Tlen, _, _) ->
    {9,Tlen,Ics,Line};
yystate(20, [116|Ics], Line, Tlen, Action, Alen) ->
    yystate(2, Ics, Line, Tlen+1, Action, Alen);
yystate(20, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,20};
yystate(19, [101|Ics], Line, Tlen, Action, Alen) ->
    yystate(15, Ics, Line, Tlen+1, Action, Alen);
yystate(19, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,19};
yystate(18, [66|Ics], Line, Tlen, _, _) ->
    yystate(14, Ics, Line, Tlen+1, 5, Tlen);
yystate(18, Ics, Line, Tlen, _, _) ->
    {5,Tlen,Ics,Line,18};
yystate(17, [83|Ics], Line, Tlen, Action, Alen) ->
    yystate(21, Ics, Line, Tlen+1, Action, Alen);
yystate(17, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,17};
yystate(16, [101|Ics], Line, Tlen, Action, Alen) ->
    yystate(20, Ics, Line, Tlen+1, Action, Alen);
yystate(16, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,16};
yystate(15, [116|Ics], Line, Tlen, Action, Alen) ->
    yystate(11, Ics, Line, Tlen+1, Action, Alen);
yystate(15, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,15};
yystate(14, [89|Ics], Line, Tlen, Action, Alen) ->
    yystate(12, Ics, Line, Tlen+1, Action, Alen);
yystate(14, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,14};
yystate(13, [84|Ics], Line, Tlen, Action, Alen) ->
    yystate(17, Ics, Line, Tlen+1, Action, Alen);
yystate(13, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,13};
yystate(12, Ics, Line, Tlen, _, _) ->
    {7,Tlen,Ics,Line};
yystate(11, Ics, Line, Tlen, _, _) ->
    {3,Tlen,Ics,Line};
yystate(10, [69|Ics], Line, Tlen, Action, Alen) ->
    yystate(6, Ics, Line, Tlen+1, Action, Alen);
yystate(10, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,10};
yystate(9, [83|Ics], Line, Tlen, Action, Alen) ->
    yystate(13, Ics, Line, Tlen+1, Action, Alen);
yystate(9, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,9};
yystate(8, [121|Ics], Line, Tlen, Action, Alen) ->
    yystate(12, Ics, Line, Tlen+1, Action, Alen);
yystate(8, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,8};
yystate(7, [110|Ics], Line, Tlen, Action, Alen) ->
    yystate(3, Ics, Line, Tlen+1, Action, Alen);
yystate(7, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,7};
yystate(6, [84|Ics], Line, Tlen, Action, Alen) ->
    yystate(2, Ics, Line, Tlen+1, Action, Alen);
yystate(6, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,6};
yystate(5, [73|Ics], Line, Tlen, Action, Alen) ->
    yystate(9, Ics, Line, Tlen+1, Action, Alen);
yystate(5, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,5};
yystate(4, [98|Ics], Line, Tlen, _, _) ->
    yystate(8, Ics, Line, Tlen+1, 5, Tlen);
yystate(4, Ics, Line, Tlen, _, _) ->
    {5,Tlen,Ics,Line,4};
yystate(3, [99|Ics], Line, Tlen, Action, Alen) ->
    yystate(0, Ics, Line, Tlen+1, Action, Alen);
yystate(3, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,3};
yystate(2, Ics, Line, Tlen, _, _) ->
    {1,Tlen,Ics,Line};
yystate(1, [88|Ics], Line, Tlen, Action, Alen) ->
    yystate(5, Ics, Line, Tlen+1, Action, Alen);
yystate(1, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,1};
yystate(0, [114|Ics], Line, Tlen, Action, Alen) ->
    yystate(4, Ics, Line, Tlen+1, Action, Alen);
yystate(0, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,0};
yystate(S, Ics, Line, Tlen, Action, Alen) ->
    {Action,Alen,Tlen,Ics,Line,S}.

%% yyaction(Action, TokenLength, TokenChars, TokenLine) ->
%% {token,Token} | {end_token, Token} | skip_token | {error,String}.
%% Generated action function.

yyaction(0, _, _, TokenLine) ->
    yy_0_(TokenLine);
yyaction(1, _, _, TokenLine) ->
    yy_1_(TokenLine);
yyaction(2, _, _, TokenLine) ->
    yy_2_(TokenLine);
yyaction(3, _, _, TokenLine) ->
    yy_3_(TokenLine);
yyaction(4, _, _, TokenLine) ->
    yy_4_(TokenLine);
yyaction(5, _, _, TokenLine) ->
    yy_5_(TokenLine);
yyaction(6, _, _, TokenLine) ->
    yy_6_(TokenLine);
yyaction(7, _, _, TokenLine) ->
    yy_7_(TokenLine);
yyaction(8, _, _, TokenLine) ->
    yy_8_(TokenLine);
yyaction(9, _, _, TokenLine) ->
    yy_9_(TokenLine);
yyaction(10, _, _, TokenLine) ->
    yy_10_(TokenLine);
yyaction(11, _, _, TokenLine) ->
    yy_11_(TokenLine);
yyaction(12, TokenLen, YYtcs, TokenLine) ->
    TokenChars = yypre(YYtcs, TokenLen),
    yy_12_(TokenChars, TokenLine);
yyaction(13, _, _, _) ->
    yy_13_();
yyaction(_, _, _, _) -> error.

-compile({inline,yy_0_/1}).
-file("./membox_lexer.xrl", 4).
yy_0_(TokenLine) ->
     { token , { set , TokenLine , "set" } } .

-compile({inline,yy_1_/1}).
-file("./membox_lexer.xrl", 5).
yy_1_(TokenLine) ->
     { token , { get , TokenLine , "get" } } .

-compile({inline,yy_2_/1}).
-file("./membox_lexer.xrl", 6).
yy_2_(TokenLine) ->
     { token , { setnx , TokenLine , "setnx" } } .

-compile({inline,yy_3_/1}).
-file("./membox_lexer.xrl", 7).
yy_3_(TokenLine) ->
     { token , { mget , TokenLine , "mget" } } .

-compile({inline,yy_4_/1}).
-file("./membox_lexer.xrl", 8).
yy_4_(TokenLine) ->
     { token , { setnx , TokenLine , "setnx" } } .

-compile({inline,yy_5_/1}).
-file("./membox_lexer.xrl", 9).
yy_5_(TokenLine) ->
     { token , { incr , TokenLine , "incr" } } .

-compile({inline,yy_6_/1}).
-file("./membox_lexer.xrl", 10).
yy_6_(TokenLine) ->
     { token , { decr , TokenLine , "decr" } } .

-compile({inline,yy_7_/1}).
-file("./membox_lexer.xrl", 11).
yy_7_(TokenLine) ->
     { token , { incrby , TokenLine , "incrby" } } .

-compile({inline,yy_8_/1}).
-file("./membox_lexer.xrl", 12).
yy_8_(TokenLine) ->
     { token , { decrby , TokenLine , "decrby" } } .

-compile({inline,yy_9_/1}).
-file("./membox_lexer.xrl", 13).
yy_9_(TokenLine) ->
     { token , { exists , TokenLine , "exists" } } .

-compile({inline,yy_10_/1}).
-file("./membox_lexer.xrl", 14).
yy_10_(TokenLine) ->
     { token , { del , TokenLine , "del" } } .

-compile({inline,yy_11_/1}).
-file("./membox_lexer.xrl", 15).
yy_11_(TokenLine) ->
     { token , { type , TokenLine , "type" } } .

-compile({inline,yy_12_/2}).
-file("./membox_lexer.xrl", 17).
yy_12_(TokenChars, TokenLine) ->
     T = lists : sublist ( TokenChars , 2 , length ( TokenChars ) ) ,
     case is_numeric ( T ) of
     true ->
     { token , { number , TokenLine , T } } ;
     false ->
     { token , { datum , TokenLine , T } }
     end .

-compile({inline,yy_13_/0}).
-file("./membox_lexer.xrl", 24).
yy_13_() ->
     skip_token .

-file("/opt/R13B02/lib/erlang/lib/parsetools-2.0/include/leexinc.hrl", 282).
