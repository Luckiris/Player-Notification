[ANY] Dream - Player view and notification [V 1.3]
===================

Description
-------------
Sourcemod plugin which control what the player can see in-game (messages, players in scoreboard, ...)

Cvars
-------------
> - sm_dnotification_admin_see_message "1" (Default: "1" - Admins can see other admins connecting)
> - sm_dnotification_hide_admin_connect "1" (Default: "1" - Hide the admin connecting)
> - sm_dnotification_hide_admin_disconnect "1" (Default: "1" - Hide the admin disconnecting)
> - sm_dnotification_hide_admin_spectator "1" (Default: "1" - Hide the admins in spectator)
> - sm_dnotification_hide_admin_team "1" (Default: "1" - Hide the admin joining a team)
> - sm_dnotification_hide_normal_connect "1" (Default: "1" - Hide the normal connet message)
> - sm_dnotification_hide_normal_disconnect "1" (Default: "1" - Hide the normal disconnect message)
> - sm_dnotification_supporter_see_message "1" (Default: "1" - Supporters can see admins connecting/disconnecting)

Changelog
-------------
> - V 1.0 (18 august 2017): Release of the plugin.
> - V 1.1 (21 december 2017): Added new functionalities like !adminspec, !info, !stealth + new messages for connect/disconnect messages (in translations file now) + added multi colors + optimize a bit the code
> - V 1.2 (30 december 2017): Fixed the function IsClientAdmin in my include and change the command !adminspec to !admins which prints every admins connected to the server
> - V 1.3 (02 january 2017): Removed the filter for the commands in console (weird bug filtering random words in chat)

Credits
-------------
> - Sky : German translation
> - AlliedModders : Code for invisibility in spectators
> - Luckiris : Coding the plugin
