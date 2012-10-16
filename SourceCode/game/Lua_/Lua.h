#ifndef LUA_LUA_H
#define LUA_LUA_H

#ifndef NDEBUG
	#include "Lua/lua.hpp"
#else
	#include "LuaJIT/lua.hpp"
#endif

namespace Lua
{
	G2GAME_IMPEXP void GetFuncInfo (char *& file, char *& func, int & line);
	G2GAME_IMPEXP void SetFuncInfo (char * file, char * func, int line);
}

#endif // LUA_LUA_H