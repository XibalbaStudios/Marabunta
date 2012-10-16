#include "stdafx.h"

#include "Lua_/Lua.h"
#include "Lua_/Arg.h"

// @brief Templated pop-and-return routine
template<typename T> T _popRetT (lua_State * L, T (*func)(lua_State *, int))
{
	T value = func(L, -1);

	lua_pop(L, 1);

	return value;
}

namespace Lua
{
	/// Validates and returns a signed char argument
	/// @param index Argument index
	/// @return signed char value
	signed char sC (lua_State * L, int index)
	{
		return (signed char)luaL_checkint(L, index);
	}

	/// Validates and returns a signed short argument
	/// @param index Argument index
	/// @return signed short value
	signed short sS (lua_State * L, int index)
	{
		return (signed short)luaL_checkint(L, index);
	}

	/// Validates and returns a signed long argument
	/// @param index Argument index
	/// @return signed long value
	signed long sL (lua_State * L, int index)
	{
		return (signed long)luaL_checkint(L, index);
	}

	/// Validates and returns a signed int argument
	/// @param index Argument index
	/// @return signed int value
	signed int sI (lua_State * L, int index)
	{
		return (signed int)luaL_checkint(L, index);
	}

	/// Validates, pops, and returns a signed char argument at the stack top
	/// @return signed char value
	signed char sC_ (lua_State * L)
	{
		return _popRetT(L, sC);
	}

	/// Validates, pops, and returns a signed short argument at the stack top
	/// @return signed short value
	signed short sS_ (lua_State * L)
	{
		return _popRetT(L, sS);
	}

	/// Validates, pops, and returns a signed long argument at the stack top
	/// @return signed long value
	signed long sL_ (lua_State * L)
	{
		return _popRetT(L, sL);
	}

	/// Validates, pops, and returns a signed int argument at the stack top
	/// @return signed int value
	signed int sI_ (lua_State * L)
	{
		return _popRetT(L, sI);
	}

	/// Validates and returns an unsigned char argument
	/// @param index Argument index
	/// @return unsigned char value
	unsigned char uC (lua_State * L, int index)
	{
		return (unsigned char)luaL_checkint(L, index);
	}

	/// Validates and returns an unsigned short argument
	/// @param index Argument index
	/// @return unsigned short value
	unsigned short uS (lua_State * L, int index)
	{
		return (unsigned short)luaL_checkint(L, index);
	}

	/// Validates and returns an unsigned long argument
	/// @param index Argument index
	/// @return unsigned long value
	unsigned long uL (lua_State * L, int index)
	{
		return (unsigned long)luaL_checkint(L, index);
	}

	/// Validates and returns a signed int argument
	/// @param index Argument index
	/// @return unsigned int value
	unsigned int uI (lua_State * L, int index)
	{
		return (unsigned int)luaL_checkint(L, index);
	}

	/// Validates, pops, and returns an unsigned char argument at the stack top
	/// @return unsigned char value
	unsigned char uC_ (lua_State * L)
	{
		return _popRetT(L, uC);
	}

	/// Validates, pops, and returns an unsigned short argument at the stack top
	/// @return unsigned short value
	unsigned short uS_ (lua_State * L)
	{
		return _popRetT(L, uS);
	}

	/// Validates, pops, and returns an unsigned long argument at the stack top
	/// @return unsigned long value
	unsigned long uL_ (lua_State * L)
	{
		return _popRetT(L, uL);
	}

	/// Validates, pops, and returns an unsigned int argument at the stack top
	/// @return unsigned int value
	unsigned int uI_ (lua_State * L)
	{
		return _popRetT(L, uI);
	}

	/// Validates and return a float argument
	/// @param index Argument index
	/// @return float value
	float F (lua_State * L, int index)
	{
		return float(luaL_checknumber(L, index));
	}

	/// Validates and return a double argument
	/// @param index Argument index
	/// @return double value
	double D (lua_State * L, int index)
	{
		return double(luaL_checknumber(L, index));
	}

	/// Validates, pops, and returns a float argument at the stack top
	/// @return float value
	float F_ (lua_State * L)
	{
		return _popRetT(L, F);
	}

	/// Validates, pops, and returns a double argument at the stack top
	/// @return double value
	double D_ (lua_State * L)
	{
		return _popRetT(L, D);
	}

	/// Validates and returns a bool argument
	/// @param index Argument index
	/// @return bool value
	bool B (lua_State * L, int index)
	{
		luaL_checktype(L, index, LUA_TBOOLEAN);

		return lua_toboolean(L, index) != 0;
	}

	/// Validates, pops, and returns a bool argument at the stack top
	/// @return bool value
	bool B_ (lua_State * L)
	{
		return _popRetT(L, B);
	}

	/// Validates and returns a void * argument
	/// @param index Argument index
	/// @return void * value
	void * UD (lua_State * L, int index)
	{
		if (!lua_isuserdata(L, index)) luaL_error(L, "Argument %d is not a userdata", index);

		return lua_touserdata(L, index);
	}

	/// Validates and returns a const char * argument
	/// @param index Argument index
	/// @return const char * value
	const char * S (lua_State * L, int index)
	{
		return luaL_checkstring(L, index);
	}
}