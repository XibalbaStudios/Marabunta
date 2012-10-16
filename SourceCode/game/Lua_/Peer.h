#ifndef LUA_PEER_H
#define LUA_PEER_H

#include "Lua_/Lua.h"
#include "Lua_/Types.h"

namespace Lua
{
	/// Member specification
	struct Member_Reg {
		size_t mOffset;	///< Member offset
		Types::LuaString mName;	///< Member name
		enum Type {
			ePointer,	///< Pointer member
			eSChar, eSShort, eSLong, eSInt,	///< Integer primitives, signed
			eUChar, eUShort, eULong, eUInt,	///< Integer primitives, unsigned
			eString,///< String
			eBoolean,	///< Boolean
			eFloat, eDouble	///< Single- and double-precision floating point
		} mType;///< Member type

		Member_Reg (void)
		{
		}

		void Set (size_t offset, const Types::LuaString & name, Type type)
		{
			mOffset = offset;
			mName = name;
			mType = type;
		}
	};

	void BindPeer (lua_State * L, const luaL_reg * getters, const luaL_reg * setters, const Member_Reg * members, int count, bool bBoxed);

	template<int count> void BindPeer (lua_State * L, const luaL_reg * getters, const luaL_reg * setters, Member_Reg (&members)[count], bool bBoxed)
	{
		BindPeer(L, getters, setters, members, count, bBoxed);
	}
}

#endif // LUA_PEER_H