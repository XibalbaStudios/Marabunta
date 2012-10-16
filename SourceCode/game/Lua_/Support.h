#ifndef LUA_SUPPORT_H
#define LUA_SUPPORT_H

#include <cstdarg>
#include "Lua_/Lua.h"
#include "Lua_/Types.h"

namespace Lua
{
	G2GAME_IMPEXP int CallCore (lua_State * L, int count, int retc, const char * params, va_list & args, bool bProtected = false);
	G2GAME_IMPEXP int OverloadedNew (lua_State * L, const char * type, int argc);

	G2GAME_IMPEXP void StackView (lua_State * L);

	/// Overloaded function builder
	struct Overload {
		Types::LuaString mArgs;	///< String used to fetch arguments
		lua_State * mL;	///< Lua state

		Overload (lua_State * L, int argc);

		void AddDef (lua_CFunction func, ...);
	};
}

#endif // LUA_SUPPORT_H