#ifndef LUA_HELPERS_H
#define LUA_HELPERS_H

#include "Lua_/Lua.h"

namespace Lua
{
	/*%%%%%%%%%%%%%%%% INITIALIZATION %%%%%%%%%%%%%%%%*/

	G2GAME_IMPEXP void LoadLibs (lua_State * L, lua_CFunction libs[]);

	/*%%%%%%%%%%%%%%%% HELPERS %%%%%%%%%%%%%%%%*/

	G2GAME_IMPEXP int Boot (lua_State * L, const char * path, const char * name, int arg = 0, const char * ext = 0, int loader = 0);
	G2GAME_IMPEXP int Call (lua_State * L, const char * name, int retc, const char * params, ...);
	G2GAME_IMPEXP int Call (lua_State * L, int retc, const char * params, ...);
	G2GAME_IMPEXP int CallMethod (lua_State * L, const char * source, const char * name, int retc, const char * params, ...);
	G2GAME_IMPEXP int CallMethod (lua_State * L, int source, const char * name, int retc, const char * params, ...);
	G2GAME_IMPEXP int PCall (lua_State * L, const char * name, int retc, const char * params, ...);
	G2GAME_IMPEXP int PCall (lua_State * L, int retc, const char * params, ...);
	G2GAME_IMPEXP int PCallMethod (lua_State * L, const char * source, const char * name, int retc, const char * params, ...);
	G2GAME_IMPEXP int PCallMethod (lua_State * L, int source, const char * name, int retc, const char * params, ...);

	/// Attaches some traceback info to catch Lua::Call() errors
	#define Lua_Call Lua::SetFuncInfo(__FILE__, __FUNCTION__, __LINE__), Lua::Call

	/// Attaches some traceback info to catch Lua::CallMethod() errors
	#define Lua_CallMethod Lua::SetFuncInfo(__FILE__, __FUNCTION__, __LINE__), Lua::CallMethod

	/// Attaches some traceback info to catch Lua::PCall() errors
	#define Lua_PCall Lua::SetFuncInfo(__FILE__, __FUNCTION__, __LINE__), Lua::PCall

	/// Attaches some traceback info to catch Lua::Call() errors
	#define Lua_PCallMethod Lua::SetFuncInfo(__FILE__, __FUNCTION__, __LINE__), Lua::PCallMethod

	/// Attaches some traceback info to catch lua_call() errors
	#define lua_CALL Lua::SetFuncInfo(__FILE__, __FUNCTION__, __LINE__), lua_call

	/// Attaches some traceback info to catch lua_pall() errors
	#define lua_PCALL Lua::SetFuncInfo(__FILE__, __FUNCTION__, __LINE__), lua_pcall

	G2GAME_IMPEXP void AtPanic (lua_State * L);
	G2GAME_IMPEXP void CacheAndGet (lua_State * L, const char * name, void * key);
	G2GAME_IMPEXP void CacheAndGet (lua_State * L, lua_CFunction func);
	G2GAME_IMPEXP void GetGlobal (lua_State * L, const char * name);
	G2GAME_IMPEXP void Pop (lua_State * L, int index, bool bPutOnStack = false);
	G2GAME_IMPEXP void Push (lua_State * L, int index);
	G2GAME_IMPEXP void Register (lua_State * L, const char * name, const luaL_reg * funcs, int env = 0);
	G2GAME_IMPEXP void SetGlobal (lua_State * L, const char * name);
	G2GAME_IMPEXP void Top (lua_State * L, int index);
	G2GAME_IMPEXP void Unpack (lua_State * L, int source, int start = 1, int end = -1);

	G2GAME_IMPEXP int GetN (lua_State * L, int index);
	G2GAME_IMPEXP int PCall_EF (lua_State * L, int argc, int retc);

	G2GAME_IMPEXP bool IsCallable (lua_State * L, int index);

	/*%%%%%%%%%%%%%%%% INLINE HELPER FUNCTIONS %%%%%%%%%%%%%%%%*/

	/// Absolutizes acceptable indices
	G2GAME_IMPEXP inline void IndexAbsolute (lua_State * L, int & index)
	{
		int top = lua_gettop(L);

		if (index < 0 && index >= -top) index += top + 1;
	}
}

#endif // LUA_HELPERS_H