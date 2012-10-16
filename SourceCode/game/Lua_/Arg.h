#ifndef LUA_ARG_H
#define LUA_ARG_H

#include "Lua_/Lua.h"

namespace Lua
{
	/*%%%%%%%%%%%%%%%% ACCESS %%%%%%%%%%%%%%%%*/

	// Signed access
	G2GAME_IMPEXP signed char sC (lua_State * L, int index);
	G2GAME_IMPEXP signed short sS (lua_State * L, int index);
	G2GAME_IMPEXP signed long sL (lua_State * L, int index);
	G2GAME_IMPEXP signed int sI (lua_State * L, int index);

	G2GAME_IMPEXP signed char sC_ (lua_State * L);
	G2GAME_IMPEXP signed short sS_ (lua_State * L);
	G2GAME_IMPEXP signed long sL_ (lua_State * L);
	G2GAME_IMPEXP signed int sI_ (lua_State * L);

	// Unsigned access
	G2GAME_IMPEXP unsigned char uC (lua_State * L, int index);
	G2GAME_IMPEXP unsigned short uS (lua_State * L, int index);
	G2GAME_IMPEXP unsigned long uL (lua_State * L, int index);
	G2GAME_IMPEXP unsigned int uI (lua_State * L, int index);

	G2GAME_IMPEXP unsigned char uC_ (lua_State * L);
	G2GAME_IMPEXP unsigned short uS_ (lua_State * L);
	G2GAME_IMPEXP unsigned long uL_ (lua_State * L);
	G2GAME_IMPEXP unsigned int uI_ (lua_State * L);

	// Floating point access
	G2GAME_IMPEXP float F (lua_State * L, int index);
	G2GAME_IMPEXP double D (lua_State * L, int index);

	G2GAME_IMPEXP float F_ (lua_State * L);
	G2GAME_IMPEXP double D_ (lua_State * L);

	// Boolean access
	G2GAME_IMPEXP bool B (lua_State * L, int index);

	G2GAME_IMPEXP bool B_ (lua_State * L);

	// String access
	G2GAME_IMPEXP const char * S (lua_State * L, int index);

	// Memory access
	G2GAME_IMPEXP void * UD (lua_State * L, int index);
}

#endif // LUA_ARG_H