-module(telcon_humanoid).
-export([observe/2, prompt/1, perform/4, help/0, alias/0]).

%% Semantic event -> text translation
observe(Event, Minion) ->
    case Event of
        {look, self, View} ->
            render_location(View, Minion);
        {{say, Line}, self, success} ->
            "You say,\"" ++ Line ++ "\"";
        {{say, Line}, Speaker, success} ->
            Speaker ++ " says,\"" ++ Line ++ "\"";
        {status, self, MobState} ->
            render_status(MobState);
        {inventory, self, InvList} ->
            render_inventory(InvList);
        {{arrive, Direction}, self, success} ->
            "You arrive from " ++ Direction ++ ".";
        {{arrive, Direction}, Actor, success} ->
            Actor ++ " arrives from " ++ Direction;
        {{depart, _}, self, failure} ->
            "You can't manage to leave!";
        {{depart, Direction}, Actor, failure} ->
            Actor ++ " tried to go " ++ Direction ++ ", and failed.";
        {{depart, Direction}, Actor, success} ->
            Actor ++ " departs " ++ Direction;
        {{take, {nothing, none, none}}, self, failure} ->
            "That isn't here.";
        {{take, _}, self, failure} ->
            "You can't take that.";
        {{take, {ObjName, loc, self}}, self, success} ->
            "You get a " ++ ObjName ++ ".";
        {{take, {ObjName, loc, Actor}}, Actor, success} ->
            Actor ++ " gets a " ++ ObjName ++ ".";
        {{take, {ObjName, Holder, Actor}}, Actor, success} ->
            Actor ++ " gets a " ++ ObjName ++ " from a " ++ Holder ++ ".";
        {{drop, {nothing, none, none}}, self, failure} ->
            "You aren't holding one of those.";
        {{drop, {ObjName, self, loc}}, self, success} ->
            "You drop a " ++ ObjName ++ ".";
        {{drop, {ObjName, Actor, loc}}, Actor, success} ->
            Actor ++ " drops a " ++ ObjName ++ ".";
        {{give, {nothing, none, none}}, self, failure} ->
            "You aren't holding one of those.";
        {{give, {_, self, nobody}}, self, failure} ->
            "Give to who?";
        {{give, {nothing, self, _}}, self, failure} ->
            "Give what?";
        {{give, {ObjName, self, Recipient}}, self, success} ->
            "You give a " ++ ObjName ++ " to " ++ Recipient ++ ".";
        {{give, {ObjName, Actor, self}}, Actor, success} ->
            Actor ++ " gives a " ++ ObjName ++ " to you.";
        {{give, {ObjName, Actor, Recipient}}, Actor, success} ->
            Actor ++ " gives a " ++ ObjName ++ " to " ++ Recipient ++ ".";
        {{look, _}, self, failure} ->
            "That isn't here.";
        {{look, self}, Actor, success} ->
            Actor ++ " looks at you.";
        {{look, _}, self, success} ->
            silent;
        {{look, _}, self, View} ->
            render_look(View);
        {{look, Target}, Actor, success} ->
            Actor ++ " looks at " ++ Target ++ ".";
        {warp, self, _} ->
            "You suddenly find yourself, existing.";
        {warp, Actor, _} ->
            "A quantum fluctuation suddenly manifests " ++ Actor ++ " nearby.";
        {poof, Actor, _} ->
            Actor ++ " disappears in a puff of smoke!";
        {Action, Actor, Outcome} ->
            note("Observed: ~p ~p ~p", [Action, Actor, Outcome]),
            silent
    end.

render_location({Name, Description, Inventory, Exits},
                {_, _, MPid, _, _}) ->
    ExitNames = string:join([N || {N, _, _, _} <- Exits], " "),
    {Mobs, Objs} = render_occupants(MPid, Inventory),
    Stuff = string:join(Mobs ++ Objs, "\r\n"),
    io_lib:format(telcon:cyan("~ts\r\n") ++
                  telcon:gray("~ts\r\n[ obvious exits:") ++
                  telcon:white(" ~ts ") ++
                  telcon:gray("]\r\n") ++
                  telcon:green("~ts"),
                  [Name, Description, ExitNames, Stuff]).

render_occupants(MPid, Inventory) ->
    render_occupants(MPid, Inventory, {[], []}).

render_occupants(_, [], {Mobs, Objs}) ->
    {lists:reverse(Mobs), lists:reverse(Objs)};
render_occupants(MPid, [{MPid, _, _} | Inv], Stuff) ->
    render_occupants(MPid, Inv, Stuff);
render_occupants(MPid, [{_, _, {Name, mob, _, _}} | Inv], {Mobs, Objs}) ->
    render_occupants(MPid, Inv, {[io_lib:format("~ts is standing here.", [Name]) | Mobs], Objs});
render_occupants(MPid, [{_, _, {Name, obj, _, _}} | Inv], {Mobs, Objs}) ->
    render_occupants(MPid, Inv, {Mobs, [io_lib:format("~ts is here.", [Name]) | Objs]}).

render_status(Mob) ->
    {Str, Int, Wil, Dex, Con, Speed} = mob:read(stats, Mob),
    {Moral, Chaos, Law} = mob:read(alignment, Mob),
    {Level, Exp} = mob:read(score, Mob),
    {{{CurHP, MaxHP}, {CurSP, MaxSP}, {CurMP, MaxMP}},
     Vis, OB, PB, DB, Abs} = mob:read(condition, Mob),
    io_lib:format("You are ~s, a ~s ~s ~s from ~s.\r\n"
                  "You are wearing ~p and carrying ~p.\r\n"
                  "STR: ~p INT: ~p WIL: ~p DEX: ~p CON: ~p SPD: ~p\r\n"
                  "Morality: ~p  Chaos: ~p Lawfulness: ~p\r\n"
                  "Level:  ~p Experience: ~p\r\n"
                  "Health: (~p/~p) Stamina: (~p/~p) Magika (~p/~p)\r\n"
                  "Vis: ~w OB: ~w PB: ~w DB: ~w Abs: ~w%",
                  [mob:read(name, Mob), mob:read(sex, Mob),
                   mob:read(species, Mob), mob:read(class, Mob), mob:read(homeland, Mob),
                   mob:read(worn_weight, Mob), mob:read(held_weight, Mob),
                   Str, Int, Wil, Dex, Con, Speed,
                   Moral, Chaos, Law,
                   Level, Exp,
                   CurHP, MaxHP, CurSP, MaxSP, CurMP, MaxMP,
                   Vis, OB, PB, DB, Abs]).

render_inventory([]) ->
    "You aren't holding anything.";
render_inventory(InvList) ->
    "You are carrying:\r\n  " ++
    string:join(lists:reverse(lists:foldl(fun render_entity/2, [], InvList)), "\r\n  ").

render_look({Species, Class, Homeland, Desc, HP, Equip, Inv}) ->
    io_lib:format("You see a ~ts ~ts from ~ts.\r\n"
                  "~ts\r\n"
                  "Wearing: ~tp\r\n"
                  "Carrying: ~tp\r\n"
                  "Appears to be ~ts",
                  [Species, Class, Homeland, Desc, Equip, Inv, health(HP)]);
render_look({obj, Name, Description}) ->
    io_lib:format("You look at the ~ts and see: ~ts", [Name, Description]).

render_entity({_, _, {Name, _, _, _}}) ->
    io_lib:format("~ts", [Name]).

render_entity(Entity, Acc) ->
    [render_entity(Entity) | Acc].

prompt(Pid) ->
    {HP, SP, MP} = mob:check(health, Pid),
    io_lib:format("(~ts, ~ts, ~ts) $ ", [health(HP), stamina(SP), magika(MP)]).

health({Current, Max}) ->
    Ratings = ["critical", "beaten", "wounded", "hurt", "scratched", "healthy"],
    rate(Current, Max, Ratings).

stamina({Current, Max}) ->
    Ratings = ["bonked", "haggard", "winded", "tired", "strong", "fresh"],
    rate(Current, Max, Ratings).

magika({Current, Max}) ->
    Ratings = ["zonked", "migrane", "headachy", "distracted", "focused", "enflow"],
    rate(Current, Max, Ratings).

rate(Index, Range, Ratings) ->
    lists:nth(em_lib:bracket(Index, Range, length(Ratings)), Ratings).

perform(Keyword, Data, Name, MPid) ->
    case do(Keyword, Data, Name) of
        {none, Message} ->
            {ok, Message};
        {ToDo, Message} ->
            MPid ! {action, ToDo},
            {ok, Message};
        bargle ->
            bargle
    end.

do("go", "", _) ->
    {none, "Go which way?"};
do("go", String, _) ->
    {{go, parse(single, String)}, none};
do("say", "", _) ->
    {{say, "..."}, none};
do("say", String, _) ->
    {{say, String}, none};
do("status", _, _) ->
    {{status, self}, none};
do("look", "", _) ->
    {{look, loc}, none};
do("look", Name, Name) ->
    {none, "Am I beautiful? Yes. Yes, I am beautiful."};
do("look", String, _) ->
    {{look, parse(single, String)}, none};
do("take", "", _) ->
    {none, "Take what?"};
do("take", Name, Name) ->
    {none, "Not in public! What's wrong with you..."};
do("take", String, _) ->
    case parse(multiple, String) of
        [Target, Holder] -> {{take, {Target, Holder}}, none};
        [Target]         -> {{take, {Target, loc}}, none};
        _                -> {none, "Wut?"}
    end;
do("give", "", _) ->
    {none, "Give what? Hopes and dreams?"};
do("give", Name, Name) ->
    {none, "That's... awkward..."};
do("give", String, Name) ->
    case parse(multiple, String) of
        [Name, _]           -> {none, "That's... awkward..."};
        [_, Name]           -> {none, "You're already holding it!"};
        [Target, Recipient] -> {{give, {Target, Recipient}}, none};
        _                   -> {none, "Wut?"}
    end;
do("drop", "", _) ->
    {none, "Drop what?"};
do("drop", Name, Name) ->
    {none, "Don't be so down on yourself."};
do("drop", String, _) ->
    {{drop, parse(single, String)}, none};
do("inventory", _, _) ->
    {{inventory, self}, none};
do("equipment", _, _) ->
    {{equipment, self}, none};
do(_, _, _) ->
    bargle.

help() ->
    telcon:white("  Mob commands:\r\n") ++
    telcon:gray( "    go Exit                - Move to a new location through Exit\r\n"
                 "    say Text               - Say something out loud\r\n"
                 "    status                 - Check your character's current status\r\n"
                 "    look                   - View your surroundings\r\n"
                 "    look Target            - Look at a target\r\n"
                 "    take Target            - Get something from the ground\r\n"
                 "    drop Item              - Drop Item from your carried inventory\r\n"
                 "    give Item Someone      - Give the Item to the mob you name\r\n"
                 "    inventory              - Check your carried inventory\r\n"
                 "    equipment              - Check your equipped items\r\n").

alias() ->
    [{"n", "go north"},
     {"s", "go south"},
     {"e", "go east"},
     {"w", "go west"},
     {"d", "go down"},
     {"u", "go up"},
     {"l", "look"},
     {"k", "kill"},
     {"inv", "inventory"},
     {"eq", "equipment"},
     {"equip", "equipment"},
     {"8", "go north"},
     {"2", "go south"},
     {"6", "go east"},
     {"4", "go west"},
     {"3", "go down"},
     {"9", "go up"},
     {"5", "look"},
     {"7", "status"},
     {"55", "kill"},
     {"st", "status"},
     {"stat", "status"},
     {"north", "go north"},
     {"south", "go south"},
     {"east", "go east"},
     {"west", "go west"},
     {"down", "go down"},
     {"up", "go up"}].

%% Binary & String handling
parse(single, String) ->
    split(hd(string:tokens(String, [$\s])));
parse(double, String) ->
    {Head, Tail} = head(String),
    {split(Head), Tail};
parse(multiple, String) ->
    lists:map(fun split/1, string:tokens(String, [$\s])).

split(Token) ->
    case string:tokens(Token, [$.]) of
        ["all", Name]  -> {Name, all};
        [Prefix, Name] -> index(Prefix, Name);
        [Name]         -> Name;
        _              -> Token
    end.

index(Prefix, Name) ->
    case string:to_integer(Prefix) of
        {error, no_integer} -> Name;
        {Index, _}          -> {Name, Index}
    end.

head(Line) ->
    {Head, Tail} = head([], string:strip(Line)),
    {lists:reverse(Head), Tail}.

head(Word, []) ->
    {Word, []};
head(Word, [H|T]) ->
    case H of
        $\s -> {Word, T};
        Z   -> head([Z|Word], T)
    end.

%% System
note(String, Args) ->
    em_lib:note(?MODULE, String, Args).
