\m5_TLV_version 1d: tl-x.org
\m5
   / A template for players/teams to compete in:
   /
   / /------------------------------------------------------------------------------\
   / | The Second Annual Makerchip ASIC Design Showdown, Summer 2026, Eleven Towers |
   / \------------------------------------------------------------------------------/
   /
   / Showdown details: https://www.redwoodeda.com/showdown-info and in the repository README.
   /
   / Each team provides their control logic in a file on GitHub based on:
   / https://github.com/rweda/showdown-2026-eleven-towers/blob/main/eleven_towers_template.tlv
   / (or eleven_towers_verilog_template.tlv for Verilog-based entries).
   /
   / This template supports 2, 3, or 4 teams competing. To run fewer than four teams,
   / comment out the unwanted team(s) in STEP 2 with "///" (not "//") to prevent M5
   / macro evaluation. Each active team must have its matching library included in STEP 1.
   /
   / Instructions for configuring the battle: Follow STEP 1 and STEP 2 below.

   use(m5-1.0)
\SV
   // STEP 1: Include URLs for the player circuits (raw files from GitHub).
   m4_include_lib(https://raw.githubusercontent.com/m-fajris/redwood-showdown-2026/refs/heads/main/sparks_team.tlv)
   m4_include_lib(https://raw.githubusercontent.com/Chronos-TL/Chronos_TL-VERILOG_Showdown/refs/heads/main/Final_version_Chronos_TL.tlv)
   m4_include_lib(https://raw.githubusercontent.com/JustNothingJay/JustNothing-eleven-towers/refs/heads/main/SECS_bot.tlv)
   m4_include_lib(https://raw.githubusercontent.com/Weiyet/showdown-2026-eleven-towers/refs/heads/main/eleven_towers_Weiyet.tlv)

   // Include the Eleven Towers framework.
   m4_include_lib(https://raw.githubusercontent.com/rweda/showdown-2026-eleven-towers/a7a75ffde289282804aae012bd1dcbef179adb78/eleven_towers_lib.tlv)

   m5_makerchip_module
\TLV

   // STEP 2: Enlist teams for battle (2, 3, or 4 teams).
   // Provide each team's GitHub ID (matching its \TLV team_* macro) and player name.
   // Comment out inactive teams with "///" (not "//").
   m5_define_player(mfajris,        Sparks)       /// m-fajris
   m5_define_player(Chronos_TL,     Chronos TL)   /// Chronos-TL
   m5_define_player(JustNothingJay, JustNothing)  /// JustNothingJay
   m5_define_player(Weiyet,         Wei Yet Ng)   /// Weiyet

   // Instantiate the Eleven Towers game.
   m5+eleven_towers_game(/top)
\SV
   endmodule
   // Declare Verilog modules for any enlisted teams that provide them (Verilog-based entries).
   m4_ifdef(['m5']_team_\m5_get_ago(github_id, 0)_module, ['m5_call(team_\m5_get_ago(github_id, 0)_module)'])
   m4_ifdef(['m5']_team_\m5_get_ago(github_id, 1)_module, ['m5_call(team_\m5_get_ago(github_id, 1)_module)'])
   m4_ifdef(['m5']_team_\m5_get_ago(github_id, 2)_module, ['m5_call(team_\m5_get_ago(github_id, 2)_module)'])
   m4_ifdef(['m5']_team_\m5_get_ago(github_id, 3)_module, ['m5_call(team_\m5_get_ago(github_id, 3)_module)'])
