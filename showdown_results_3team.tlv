\m5_TLV_version 1d: tl-x.org
\m5
   / The Second Annual Makerchip ASIC Design Showdown, Summer 2026: Eleven Towers
   /
   / 3-TEAM TOURNAMENT RUN  (batch grid + subset seating + points scoring)
   /
   / All four enlisted teams are instantiated ONCE (the roster). Every game seats 3 of
   / them (a "3-team game"). We play every ordered seating (all 24 permutations of 3 teams
   / drawn from the 4), each replayed with several dice seeds, for a total of 48 games.
   /
   / The 48 games run on a reused 12-board grid over 4 rounds (batch mode): a "round" is one
   / game per board; when every board's game is done the controller resets all boards together
   / and loads the next round. Game index g = round*12 + board (0..47) maps to a seating
   / (g % 24, looked up in *seat_map) and a dice seed (g), so every (seating, seed) pair plays
   / once. Which 3 of the 4 teams are seated -- and in what turn order -- is chosen per game by
   // *seat_map (a runtime lookup via the per-board $lineup index), so all 4 team circuits are
   / built once yet only 3 play any given game (num_seats=3 decouples seats from the roster).
   /
   / Scoring: only the SOLE winner of a game scores, 5 point(s) each (a 3-team game is worth
   / 5). Draws (timed out) score nothing. The scoreboard under the grid shows each team's
   / cumulative points, growing live as rounds complete.

   use(m5-1.0)
\SV
   // Player circuits (raw files from GitHub) -- the same four teams as the event.
   m4_include_lib(https://raw.githubusercontent.com/m-fajris/redwood-showdown-2026/refs/heads/main/sparks_team.tlv)
   m4_include_lib(https://raw.githubusercontent.com/Chronos-TL/Chronos_TL-VERILOG_Showdown/refs/heads/main/Final_version_Chronos_TL.tlv)
   m4_include_lib(https://raw.githubusercontent.com/JustNothingJay/JustNothing-eleven-towers/refs/heads/main/SECS_bot.tlv)
   m4_include_lib(https://raw.githubusercontent.com/Weiyet/showdown-2026-eleven-towers/refs/heads/main/eleven_towers_Weiyet.tlv)

   // The Eleven Towers framework -- pinned published copy (batch mode, seat/roster decoupling,
   // team-consistent colors). Included LAST so its \TLV macros win the (non-fatal) last-definition
   // redefinition over the teams' own pinned framework copies.
   m4_include_lib(['https://raw.githubusercontent.com/rweda/showdown-2026-eleven-towers/9c23c2081649f4b2f1b479f61a624a05bbb850d8/eleven_towers_lib.tlv'])

\SV
   m5_makerchip_module
\TLV
   // --- Tournament configuration ---
   m5_var(max_game_cycles, 400)  // per-game cycle cap (from each game's own reset; no winner by
                                 // this many cycles is a draw for that board)
   m5_var(num_boards, 12)        // boards (games running simultaneously per round); laid out 4x3
   m5_var(num_games, 48)         // total games across all rounds (48 / 12 = 4 rounds)
   m5_var(num_batches, m5_calc((m5_num_games + m5_num_boards - 1) / m5_num_boards))
   m5_var(num_lineups, 24)        // distinct ordered seatings (permutations of 3 of the 4 teams)
   m5_var(num_seats, 3)          // players seated per game (K); < roster => subset seating

   // The four teams, defined ONCE in fixed order: team index k -> player[k]. define_player assigns
   // no color_id, so each team's color id defaults to its define order (0..3 = its palette slot),
   // giving team-consistent colors across all games.
   m5_define_player(mfajris, Sparks)
   m5_define_player(Chronos_TL, Chronos TL)
   m5_define_player(JustNothingJay, JustNothing)
   m5_define_player(Weiyet, Wei Yet Ng)

   // Module-global game constants: declare once for all boards.
   m5+eleven_towers_globals(/top)

   // Module-global batch signals + per-board status vectors. Boards WRITE their status into these
   // SV-global vectors (indexed by board); the controller READS them (avoids cross-pipe refs).
   \SV_plus
      logic[7:0] *BatchNum;
      logic *batch_reset;
      logic[m5_calc(m5_num_boards - 1):0] *BoardDone;    // each board's game finished?
      logic[m5_calc(m5_num_boards - 1):0] *BoardWon;     // finished with a real winner (not a draw)?
      logic[7:0] *BoardWinner[0:m5_calc(m5_num_boards - 1)];   // winning TEAM index (0..3)

   // Seat->team map: for each of the 24 ordered seatings, the team index (0..3) seated at seats
   // 0..2, flattened as [lineup * 3 + seat]. A per-board $Lineup selects the seating at runtime.
   \SV_plus
      logic[1:0] *seat_map[0:71] = {
         2'd0, 2'd1, 2'd2,  // lineup  0: [0, 1, 2]
         2'd0, 2'd1, 2'd3,  // lineup  1: [0, 1, 3]
         2'd0, 2'd2, 2'd1,  // lineup  2: [0, 2, 1]
         2'd0, 2'd2, 2'd3,  // lineup  3: [0, 2, 3]
         2'd0, 2'd3, 2'd1,  // lineup  4: [0, 3, 1]
         2'd0, 2'd3, 2'd2,  // lineup  5: [0, 3, 2]
         2'd1, 2'd0, 2'd2,  // lineup  6: [1, 0, 2]
         2'd1, 2'd0, 2'd3,  // lineup  7: [1, 0, 3]
         2'd1, 2'd2, 2'd0,  // lineup  8: [1, 2, 0]
         2'd1, 2'd2, 2'd3,  // lineup  9: [1, 2, 3]
         2'd1, 2'd3, 2'd0,  // lineup 10: [1, 3, 0]
         2'd1, 2'd3, 2'd2,  // lineup 11: [1, 3, 2]
         2'd2, 2'd0, 2'd1,  // lineup 12: [2, 0, 1]
         2'd2, 2'd0, 2'd3,  // lineup 13: [2, 0, 3]
         2'd2, 2'd1, 2'd0,  // lineup 14: [2, 1, 0]
         2'd2, 2'd1, 2'd3,  // lineup 15: [2, 1, 3]
         2'd2, 2'd3, 2'd0,  // lineup 16: [2, 3, 0]
         2'd2, 2'd3, 2'd1,  // lineup 17: [2, 3, 1]
         2'd3, 2'd0, 2'd1,  // lineup 18: [3, 0, 1]
         2'd3, 2'd0, 2'd2,  // lineup 19: [3, 0, 2]
         2'd3, 2'd1, 2'd0,  // lineup 20: [3, 1, 0]
         2'd3, 2'd1, 2'd2,  // lineup 21: [3, 1, 2]
         2'd3, 2'd2, 2'd0,  // lineup 22: [3, 2, 0]
         2'd3, 2'd2, 2'd1  // lineup 23: [3, 2, 1]
      };

   // The boards, laid out 4 wide x 3 high. Each board runs a SEQUENCE of games (one per round) on
   // reused hardware. Game index = round*boards + board; its seating = index % num_lineups and its
   // dice seed = index (distinct, reproducible dice per game). $lineup is passed as the framework's
   // seating-permutation index (_perm), so *seat_map picks which K teams sit where this game.
   /board[m5_calc(m5_num_boards - 1):0]
      \viz_js
         box: {left: -42.5, top: 0, width: 85, height: 100, strokeWidth: 0},
         layout: {
            left(i) { return (i % 4) * 85 },
            top(i) { return Math.floor(i / 4) * 100 }
         },
      |game
         @1
            $game_index[15:0] = *BatchNum * m5_num_boards + #board;
            $game_seed[31:0] = $game_index;
            $lineup[7:0] = $game_index % m5_num_lineups;
            m5+eleven_towers_logic(|game, , $lineup, batch)
            // Export this board's status to the module-global vectors for the round controller.
            *BoardDone\[#board\] = $Done;
            *BoardWon\[#board\] = $Won;
            *BoardWinner\[#board\] = $WinnerPlayer;
            `BOGUS_USE($passed $failed)

   // ---- Round controller ----
   // A "round" is one game per board, all running simultaneously. The round ENDS as soon as EVERY
   // board's game is complete (won or timed out); then all boards reset together and load the next
   // round's games. Every game finishes within m5_max_game_cycles, so a round always completes.
   |batch
      @1
         $reset = *reset;
         $all_done = & *BoardDone;
         // One-shot rising edge (init prev high so cycle 0 out of reset isn't mistaken for an edge).
         $AllDonePrev <= $reset ? 1'b1 : $all_done;
         $round_done = $all_done && ! $AllDonePrev;
         $last_round = $BatchNum >= m5_calc(m5_num_batches - 1);
         $advance = $round_done && ! $last_round;
         $BatchNum[7:0] <= $reset ? 8'd0 : ($advance ? $BatchNum + 8'd1 : $BatchNum);
         // Pulse batch_reset the cycle AFTER advancing so BatchNum has updated (boards reseed/reseat).
         $AdvancePrev <= $reset ? 1'b0 : $advance;
         *batch_reset = $reset || $AdvancePrev;
         *BatchNum[7:0] = $BatchNum;
         // Latch "tournament finished" on the final round's genuine completion EDGE.
         $Finished <= $reset ? 1'b0 : ($Finished || ($round_done && $last_round));

         // ---- Per-team total score: cumulative TOURNAMENT POINTS won by each team across rounds. ----
         // $WinnerPlayer (hence *BoardWinner) is already the TEAM index (0..3), so we tally by team.
         // On each round's completion edge, add 5 point(s) for every board this team won.
         // The inner (board) m5_repeat clobbers m5_LoopCnt, so we save the outer (team) index in
         // m5_CurTeam and restore m5_LoopCnt before the outer body ends.
         m5_var(CurTeam, 0)
         m5_repeat(m5_num_players, ['m5_set(CurTeam, m5_LoopCnt)
         $win_inc['']m5_CurTeam[7:0] = m5_repeat(m5_num_boards, ['(*BoardWon\[m5_LoopCnt\] && *BoardWinner\[m5_LoopCnt\] == m5_CurTeam ? 8'd5 : 8'd0) + ']) 8'd0;
         $Score['']m5_CurTeam[15:0] <= $reset ? 16'd0 : ($round_done ? $Score['']m5_CurTeam + $win_inc['']m5_CurTeam : $Score['']m5_CurTeam);
         m5_set(LoopCnt, m5_CurTeam)'])

         // Simulation control with the event "backdoor" (! clk) to run past Makerchip's default
         // 600-cycle sim end. Both *passed and *failed carry the ! clk term for the backdoor.
         *passed = ! clk || $Finished;
         *failed = ! clk || 1'b0;

         // ---- Scoreboard VIZ ----
         // A bar chart under the 4x3 grid: one bar per team, height proportional to cumulative
         // tournament points ($Score0..3). Colors/names are baked at M5 time from the roster.
         \viz_js
            box: {left: -42.5, top: 305, width: 340, height: 160, strokeWidth: 1, stroke: "#c0c0c0", fill: "#fafafa"},
            init() {
               let colors = ["#m5_base_player_color(0)", "#m5_base_player_color(1)", "#m5_base_player_color(2)", "#m5_base_player_color(3)"]
               let names = ["m5_index_by_player(player_name, 0)", "m5_index_by_player(player_name, 1)", "m5_index_by_player(player_name, 2)", "m5_index_by_player(player_name, 3)"]
               let objs = {}
               objs.title = new fabric.Text("Tournament Points (5 per 3-team win)", {
                  left: -38, top: 310, fontSize: 11, fontFamily: "Roboto", fontWeight: "bold", fill: "black"})
               for (let i = 0; i < 4; i++) {
                  objs["bar" + i] = new fabric.Rect({
                     left: i * 85 - 30, top: 445, width: 60, height: 0, fill: colors[i], strokeWidth: 0})
                  objs["val" + i] = new fabric.Text("0", {
                     left: i * 85, top: 430, fontSize: 13, fontFamily: "Roboto", fontWeight: "bold",
                     fill: "black", originX: "center"})
                  objs["name" + i] = new fabric.Text(names[i], {
                     left: i * 85, top: 448, fontSize: 9, fontFamily: "Roboto", fill: "black", originX: "center"})
               }
               return objs
            },
            render() {
               let o = this.getObjects()
               // Spaces inside the brackets are required: a bare [ directly against a '$...' signal
               // read forms M5's quote-open delimiter and swallows the rest of the block.
               let scores = [ '$Score0'.asInt(), '$Score1'.asInt(), '$Score2'.asInt(), '$Score3'.asInt() ]
               let maxScore = Math.max(1, scores[0], scores[1], scores[2], scores[3])
               let baseline = 445
               let maxBarH = 95
               for (let i = 0; i < 4; i++) {
                  let h = scores[i] / maxScore * maxBarH
                  o["bar" + i].set({top: baseline - h, height: h})
                  o["val" + i].set({text: "" + scores[i], top: baseline - h - 16})
               }
            },
            where: {}
\SV
   endmodule
   // Declare the Verilog module for each Verilog-based team (once each; harmless if absent).
   m4_ifdef(['m5']_team_mfajris_module, ['m5_call(team_mfajris_module)'])
   m4_ifdef(['m5']_team_Chronos_TL_module, ['m5_call(team_Chronos_TL_module)'])
   m4_ifdef(['m5']_team_JustNothingJay_module, ['m5_call(team_JustNothingJay_module)'])
   m4_ifdef(['m5']_team_Weiyet_module, ['m5_call(team_Weiyet_module)'])
