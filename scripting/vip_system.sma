#include <amxmodx>
#include <cstrike>
#include <fakemeta_util>
#include <hamsandwich>
#if AMXX_VERSION_NUM < 183
#include <colorchat>
#endif	

// #### Configuration defines ####
#define VIP_ACCESS ADMIN_LEVEL_H			// VIP access flag (default flag is "t" ADMIN_LEVEL_H)
#define CHATTAG "^3[^4VIP INFO^3]^4" 			// Prefix before messages || ^1 - yellow ^3 - team color ^4 - green
#define VIPCONNECTED_SOUND "misc/neugomon/vip.wav"	// Звук при заходе VIP игрока на сервер
#define VIPROUND 2					// C какого раунда можно открыть вип меню
#define AWPM249RND 5					// С какого раунда доступны AWP и пулемет

#define ADDHP_HS 10					// Кол-во HP за убийство в голову
#define ADDHP 10					// Кол-во HP за убийство в тело
#define MAXHP 100					// Максимальное количество HP

#define AUTOVIPMENU					// Автоматически открывать в начале рануда Вип меню (выключено по дефолту)
#define VIPAUTODEAGLE					// В начале каждого раунда давать Дигл
#define VIPAUTOGRENADE					// Давать в начале каждого раунда гранаты
#define VIPTAB						// Показывать статус VIP в таблице на tab
// #### Конфигурационные defines ####

#define is_user_vip(%0) (get_user_flags(%0) & VIP_ACCESS)

new g_roundCount, g_HudSyncMsg;

new bool:isWarmupRound = true, bool:isFirstRound = true, bool:iUseWeapon[33] = false, bool:bDefuse = false;

new const PRIMARY_WEAPONS_BITSUM = (1<<CSW_SCOUT)|(1<<CSW_XM1014)|(1<<CSW_MAC10)|(1<<CSW_AUG)|(1<<CSW_UMP45)|(1<<CSW_SG550)|(1<<CSW_GALIL)|(1<<CSW_FAMAS)|(1<<CSW_AWP)|(1<<CSW_MP5NAVY)|(1<<CSW_M249)|(1<<CSW_M3)|(1<<CSW_M4A1)|(1<<CSW_TMP)|(1<<CSW_G3SG1)|(1<<CSW_SG552)|(1<<CSW_AK47)|(1<<CSW_P90);
new const SECONDARY_WEAPONS_BITSUM = (1<<CSW_P228)|(1<<CSW_ELITE)|(1<<CSW_FIVESEVEN)|(1<<CSW_USP)|(1<<CSW_GLOCK18)|(1<<CSW_DEAGLE);

public plugin_precache() precache_sound(VIPCONNECTED_SOUND);

new iMaxPlayers;
new bool:g_iBlockBonus;

public plugin_init()
{
	register_plugin("VIPka", "1.2", "neygomon");
	
	register_event("TextMsg","eventRoundRestart","a","2&#Game_w");
	register_event("TextMsg","eventCommencingRestart","a","2&#Game_C");
	register_event("Damage","eventDamage","b","2!0","3=0","4!0");
	register_event("DeathMsg","eventDeathMsg","a","1>0");
	register_event("HLTV","eventRoundStartHLTV","a","1=0","2=0");

	#if defined VIPTAB
	if(engfunc(EngFunc_FindEntityByString,FM_NULLENT,"classname","func_vip_safetyzone"))
		register_message(get_user_msgid("ScoreAttrib"),"messageScoreAttrib");
	#endif
	if(engfunc(EngFunc_FindEntityByString,FM_NULLENT,"classname","func_bomb_target")) 
		bDefuse = true;
		
	RegisterHam(Ham_Spawn, "player", "Player_Spawn", 1);
	
	register_clcmd("say /vipmenu", "CmdMenu");
	register_clcmd("vipmenu", "CmdMenu");
	register_clcmd("say", "hook_say");
	register_clcmd("say_team", "hook_say");
	
	register_menucmd(register_menuid("Vip Menu"), MENU_KEY_0|MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4, "handler");
	
	iMaxPlayers = get_maxplayers();
	g_HudSyncMsg = CreateHudSyncObj();
	
	new iMap_Name[32], iMap_Prefix[][] = { "awp_", "aim_" }
	get_mapname(iMap_Name, charsmax(iMap_Name))
	for(new i; i < sizeof(iMap_Prefix); i++)
	{
		if(containi(iMap_Name, iMap_Prefix[i]) != -1)
			g_iBlockBonus = true
	}
}	

public client_putinserver(id)
{
	if(is_user_vip(id)) VipConnectNotice(id);
}	
	
public eventCommencingRestart() isFirstRound = isWarmupRound = true;
	
public eventRoundRestart() g_roundCount = 0;

public eventRoundStartHLTV()
{
	if(isFirstRound)
	{
		isFirstRound = false;
		g_roundCount = 0;
	}
	g_roundCount++;
	if(isWarmupRound)
	{
		isWarmupRound = false;
		g_roundCount = 0;
	}
	arrayset(iUseWeapon, false, iMaxPlayers);
}

public eventDamage(id)
{
	static	attID, dmg
	attID = get_user_attacker(id)
	dmg = read_data(2)
	if(is_user_connected(attID) && is_user_vip(attID))
	{
		set_hudmessage(0, 100, 200, -1.0, 0.55, 2, 0.1, 4.0, 0.02, 0.02, -1)
		ShowSyncHudMsg(attID, g_HudSyncMsg, "%i^n", dmg)
	}
}

public eventDeathMsg()
{
	static	killerID
	killerID = read_data(1) 
	if(is_user_vip(killerID))
	{
		static	killer_HP, addHP
		killer_HP = get_user_health(killerID)
		addHP = ((read_data(3) == 1)) ? ADDHP_HS : ADDHP
		fm_set_user_health(killerID,((killer_HP += addHP) > MAXHP)? MAXHP : killer_HP)
		set_hudmessage(0, 255, 0, -1.0, 0.15, 0, 1.0, 1.0, 0.1, 0.1, -1)
		ShowSyncHudMsg(killerID, g_HudSyncMsg, "Добавлено +%d HP", addHP)
	}
}

public Player_Spawn(id)
{
	if(g_iBlockBonus) return;
	
	if(is_user_alive(id) && is_user_vip(id))
	{
		#if defined VIPAUTOGRENADE
		fm_give_item(id, "weapon_hegrenade");
		fm_give_item(id, "weapon_flashbang");
		fm_give_item(id, "weapon_smokegrenade");
		cs_set_user_bpammo(id, CSW_FLASHBANG, 2);
		#endif
		#if defined VIPAUTODEAGLE
		give_item_ex(id,"weapon_deagle",35,1)
		cs_set_user_bpammo(id, CSW_DEAGLE, 35);
		#endif
		cs_set_user_armor(id, 100, CS_ARMOR_VESTHELM);
		if(bDefuse && cs_get_user_team(id) == CS_TEAM_CT) cs_set_user_defuse(id, 1);
		
		#if defined AUTOVIPMENU
			CmdMenu(id);
		#endif	
	}
}

public hook_say(id)
{
	static szMsg[256];
	read_args(szMsg,255);
	remove_quotes(szMsg);

	if(szMsg[0] != '/')
	{
		return 0;
	}
	static a;
	static const szChoosedWP[][] = { "/ak47", "/m4a1", "/awp", "/b51" };
	for(a = 0; a < sizeof szChoosedWP; a++)
	{
		if(equal(szMsg,szChoosedWP[a]))
		{
			if(!is_allow_use(id))
			{
				break;
			}
			if(a > 1 && g_roundCount < AWPM249RND)
			{
				return chat_message(id, 6);
			}
			return handler(id,a);
		}
	}
	return 0;
}	

public CmdMenu(id)
{
	if(is_user_vip(id))
	{
		if(is_user_alive(id))
		{
			if(g_roundCount > 0)
			{
				if(!iUseWeapon[id])
				{
					if(g_roundCount >= VIPROUND)
					{
						static szMenu[512],iLen,iKey;

						iKey = MENU_KEY_0|MENU_KEY_1|MENU_KEY_2;
						iLen = formatex(szMenu,511,"\yVIP \wWeaponMenu^n^n\y1. \wВзять AK47^n\y2. \wВзять M4A1^n");

						if(g_roundCount < AWPM249RND) 
						{
							iLen += formatex(szMenu[iLen],511 - iLen,"\y3. \dВзять AWP \r[c %d раунда]^n\y4. \dВзять Пулемет \r[c %d раунда]^n^n",AWPM249RND,AWPM249RND);
						}
						else
						{
							iKey |= MENU_KEY_3|MENU_KEY_4;
							iLen += formatex(szMenu[iLen],511 - iLen,"\y3. \wВзять AWP^n\y4. \wВзять Пулемет^n^n");
						}
						formatex(szMenu[iLen],511 - iLen,"\y0. \wВыход");
						set_pdata_int(id, 205, 0);
						return show_menu(id,iKey,szMenu,-1,"Vip Menu");
					}
					else chat_message(id, 0);
				}
				else chat_message(id, 1);
			}
			else chat_message(id, 2);
		}
		else chat_message(id, 3);
	}
	else chat_message(id, 4);
	return PLUGIN_HANDLED;
}

public handler(id, key)
{
	switch(key)
	{
		case 0: 
		{
			give_item_ex(id,"weapon_ak47",90,1);
			iUseWeapon[id] = true;
		}
		case 1:
		{
			give_item_ex(id,"weapon_m4a1",90,1);
			iUseWeapon[id] = true;
		}		
		case 2: 
		{
			if(g_roundCount < AWPM249RND)
				chat_message(id, 6);
			else
			{
				give_item_ex(id,"weapon_awp",30,1);
				iUseWeapon[id] = true;
			}
		}
		case 3: 
		{
			if(g_roundCount < AWPM249RND)
				chat_message(id, 6);
			else
			{
				give_item_ex(id,"weapon_m249",250,1);
				iUseWeapon[id] = true;
			}
		}
	}
	return 1
}

stock give_item_ex(id,currWeaponName[],ammoAmount,dropFlag=0)
{
	static	weaponsList[32], weaponName[32], weaponsNum, currWeaponID;		
	currWeaponID = get_weaponid(currWeaponName);
	if(dropFlag)
	{	
		weaponsNum = 0;
		get_user_weapons(id,weaponsList,weaponsNum);
		for (new i;i < weaponsNum;i++)
		{
			if(((1 << currWeaponID) & PRIMARY_WEAPONS_BITSUM && (1 << weaponsList[i]) & PRIMARY_WEAPONS_BITSUM) | ((1 << currWeaponID) & SECONDARY_WEAPONS_BITSUM && (1 << weaponsList[i]) & SECONDARY_WEAPONS_BITSUM))
			{
				get_weaponname(weaponsList[i],weaponName,charsmax(weaponName));
				engclient_cmd(id,"drop",weaponName);
			}
		}
	}
	fm_give_item(id,currWeaponName);
	cs_set_user_bpammo(id,currWeaponID,ammoAmount);
}

public VipConnectNotice(id)
{
	chat_message(0, 5);
	client_cmd(0,"spk ^"%s^"", VIPCONNECTED_SOUND);
}

stock chat_message(id, message=0)
{
	switch(message)
	{
		case 0: client_print_color(id, 0, "%s Оружия доступны только с^3 %d ^4раунда!", CHATTAG, VIPROUND);
		case 1: client_print_color(id, 0, "%s Вы ^3уже брали ^4оружие в этом раунде!", CHATTAG);
		case 2: client_print_color(id, 0, "%s Разминочный раунд. ^3Запрещено ^4пользоваться командой!", CHATTAG);
		case 3: client_print_color(id, 0, "%s Для использования данной команды вы должны быть ^3живы^4!", CHATTAG);
		case 4: client_print_color(id, 0, "%s ^3Только VIP-игрок ^4может пользоваться этой командой!", CHATTAG);
		case 5: 
		{
			new name[32];
			get_user_name(id, name, charsmax(name));
			client_print_color(id, 0, "%s На сервер зашёл ^3VIP клиент ^1%s", CHATTAG, name);
		}
		case 6: client_print_color(id, 0, "%s Данное оружие доступно только с^3 %d ^4раунда!", CHATTAG, AWPM249RND);
	}
	return 1
}

bool:is_allow_use(id)
{
	if(!is_user_vip(id))
	{
		chat_message(id, 4);
		return false;
	}
	if(!is_user_alive(id))
	{
		chat_message(id, 3);
		return false;
	}
	if(!g_roundCount)
	{
		chat_message(id, 2);
		return false;
	}
	if(iUseWeapon[id])
	{
		chat_message(id, 1);
		return false;
	}
	if(g_roundCount < VIPROUND)
	{
		chat_message(id, 0);
		return false;
	}
	return true;
}

#if defined VIPTAB
public MessageScoreAttrib(iMsgId, iDest, iReceiver)
{	
	static id; id = get_msg_arg_int(1);
	if(is_user_vip(id) && !get_msg_arg_int(2))
	{
		set_msg_arg_int(2, ARG_BYTE, 4);
	}
}
#endif
