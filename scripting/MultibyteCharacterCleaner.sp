#pragma newdecls required

#include <sdktools_functions>

public Plugin myinfo = 
{
    name        = "Multibyte Character Cleaner",
    author      = "nyood? (ReWork by PSIH :{)",
    description = "Очищает ник игрока от мультибайтовых символов",
    version     = "1.0.0",
    url         = "https://github.com/0RaKlE19/Multibyte-Character-Cleaner"
};

char g_szEmptyValue[MAX_NAME_LENGTH];
bool g_bRemoveFlood, skipThis[MAXPLAYERS+1];
int g_iFlagImmunite;

public void OnPluginStart()
{  
    HookEvent("player_changename", OnNameChanged);
    HookUserMessage(GetUserMessageId("SayText2"), UserMessage_SayText2, true);
}

public void OnMapStart()
{
    static char szConfig[PLATFORM_MAX_PATH] = "configs/MultibyteCharacterCleaner.ini";

    if(szConfig[0] == 'c')
        BuildPath(Path_SM, szConfig, sizeof(szConfig), szConfig);
    
    KeyValues kv = new KeyValues("settings");
    if(kv.ImportFromFile(szConfig))
    {
        kv.Rewind();
        kv.GetString("empty_name", g_szEmptyValue, sizeof(g_szEmptyValue), "unnamed");
        g_bRemoveFlood = view_as<bool>(kv.GetNum("remove_flood", 1));

        char szSMB[4];
        kv.GetString("immunity_level", szSMB, sizeof(szSMB), NULL_STRING);
        g_iFlagImmunite = (szSMB[0]) ? ReadFlagString(szSMB) : 0;
    }
    else
        LogError("Невозможно найти cfg или ключевое слово -settings- в cfg.");

    delete kv;
}

public void OnClientPutInServer(int iClient)
{
    if(!IsFakeClient(iClient))
    {
        skipThis[iClient] = false;

        char szName[MAX_NAME_LENGTH];
        GetClientInfo(iClient, "name", szName, sizeof(szName));
        FilterUsername(iClient, szName, sizeof(szName));
    }
}

public void OnNameChanged(Event ev, const char[] name, bool bdcst)
{
    int iClient = GetClientOfUserId(ev.GetInt("userid"));
    if(!iClient || !IsClientInGame(iClient) || IsFakeClient(iClient) || IsImmunity(iClient))
        return;
    
    if(skipThis[iClient])
    {
        skipThis[iClient] = false;
        return;
    }

    char szName[MAX_NAME_LENGTH];
    ev.GetString("newname", szName, sizeof(szName));
    FilterUsername(iClient, szName, sizeof(szName));
}

void FilterUsername(int iClient, char[] szName, int size)
{
    FilterThisInfo(szName);

    TrimString(szName);

    if(!strlen(szName))
        strcopy(szName, size, g_szEmptyValue);
    
    skipThis[iClient] = true;
    SetClientInfo(iClient, "name", szName);
    SetClientName(iClient, szName);
    /* This crutch is for instant updating of the NET variable, since GetClientName() works with it */
    //SetEntPropString(iClient, Prop_Data, "m_szNetname", szName);
}

void FilterThisInfo(char[] szInfo)
{
    if(!szInfo[0])
        return;
    
    int len = strlen(szInfo);

    for(int i, b; i < len; i++)
    {
        if(szInfo[i] == '\0' || i >= len)
            break;

        if((b = IsCharMB(szInfo[i])) <= 2)
        {
            if(b)
                i += b-1;

            continue;
        }
    
        for(int j = b+i; j <= len; j++) {
            szInfo[j-b] = szInfo[j];
        }
        
        len = strlen(szInfo);
        i--;
    }
}

bool IsImmunity(int iClient)
{
    if(!g_iFlagImmunite)
        return false;
    
    int ClientFl = GetUserFlagBits(iClient);    
    return ClientFl && ((ClientFl & g_iFlagImmunite) || (ClientFl & ReadFlagString("z")));
}

public Action UserMessage_SayText2(UserMsg msg_id, Handle msg, const int[] players, int playersNum, bool reliable, bool init)
{
    if(!msg || !playersNum || !g_bRemoveFlood)
        return Plugin_Continue

    int sender = getParamsFromMsg(msg);
    if(sender != -1 && skipThis[sender] && g_bRemoveFlood)
        return Plugin_Handled;
        
    return Plugin_Continue;
}

int getParamsFromMsg(Handle msg) {
    Protobuf message = view_as<Protobuf>(msg);

    char szMessage[MAX_NAME_LENGTH];
    message.ReadString("msg_name", szMessage, sizeof(szMessage));

    if(StrContains(szMessage, "Cstrike_Name_Change") == -1)
        return -1;
    
    return message.ReadInt("ent_idx");
}