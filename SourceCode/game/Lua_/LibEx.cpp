#include "stdafx.h"

#include "Lua_/Lua.h"
#include "Lua_/LibEx.h"
#include "Lua_/Helpers.h"
#include "Lua_/Support.h"
#include "Lua_/Types.h"
#include <SCRIPT_MANAGER>
#include <cassert>

namespace Lua
{
	/// Configures a new Lua state
	/// @param libs Libraries to load
	void LoadLibs (lua_State * L, lua_CFunction libs[])
	{
		for (int i = 0; libs[i] != 0; ++i)
		{
			lua_pushcfunction(L, libs[i]);	// ..., lib

			if (PCall_EF(L, 0, 0) != 0) throw Types::LuaString(S(L, -1));
		}
	}

	/// Defines a class without closures
	/// @param name Type name
	/// @param methods Methods to associate with class
	/// @param def Class definition
	void Class::Define (lua_State * L, const char * name, const luaL_reg * methods, const Def & def)
	{
		const char * dummy[] = { 0 };

		Class::Define(L, name, methods, dummy, def);
	}

	/// Shared environment instance allocator
	/// @remark Stack top: Metatable
	/// @remark Upvalue #1: Instance size
	/// @remark Upvalue #2: Environment
	static int SharedAlloc (lua_State * L)
	{
		lua_newuserdata(L, uI(L, lua_upvalueindex(1)));	// meta, ud
		lua_insert(L, 1);	// ud, meta
		lua_setmetatable(L, 1);	// ud
		lua_pushvalue(L, lua_upvalueindex(2));	// ud, env
		lua_setfenv(L, 1);	// ud

		return 1;
	}

	/// Unique environment instance allocator
	/// @remark Stack top: Metatable
	/// @remark Upvalue #1: Instance size
	/// @remark Upvalue #2: Array size
	/// @remark Upvalue #3: Hash size
	static int UniqueAlloc (lua_State * L)
	{
		lua_newuserdata(L, uI(L, lua_upvalueindex(1)));	// meta, ud
		lua_insert(L, 1);	// ud, meta
		lua_setmetatable(L, 1);	// ud
		lua_createtable(L, sI(L, lua_upvalueindex(2)), sI(L, lua_upvalueindex(3)));	// ud, env
		lua_setfenv(L, 1);	// ud

		return 1;
	}

	/// Default @b __index metamethod
	/// @remark Environment: Object environment
	static int Index (lua_State * L)
	{
		lua_getfenv(L, 1);	// object, key, env
		lua_replace(L, 1);	// env, key
		lua_rawget(L, 1);	// env, value

		return 1;
	}

	/// Default @b __newindex metamethod
	/// @remark Environment: Object environment
	static int NewIndex (lua_State * L)
	{
		lua_getfenv(L, 1);	// object, key, value, env
		lua_replace(L, 1);	// env, key, value
		lua_rawset(L, 1);	// env

		return 0;
	}

	/// Defines a class, with closures on the stack
	/// @param name Type name
	/// @param methods Methods to associate with class
	/// @param closures Closure names
	/// @param def Class definition
	void Class::Define (lua_State * L, const char * name, const luaL_reg * methods, const char * closures[], const Def & def)
	{
		assert(name != 0);
		assert(methods != 0 || closures != 0);

		// Count the closures.
		int count = 0;

		while (closures != 0 && closures[count] != 0) ++count;

		// Load methods, starting with default __index / __newindex metamethods.
		lua_newtable(L);// ..., M
		lua_pushcfunction(L, Index);// ..., M, Index
		lua_setfield(L, -2, "__index");	// ..., M = { __index = Index }
		lua_pushcfunction(L, NewIndex);	// ..., M, NewIndex
		lua_setfield(L, -2, "__newindex");	// ..., M = { __index, __newindex = NewIndex }

		if (methods != 0) luaL_register(L, 0, methods);

		// Load closures.
		for (int i = 0; i < count; ++i)
		{
			lua_pushstring(L, closures[i]);	// ..., M, name
			lua_pushvalue(L, -count - 2 + i);	// ..., M, name, closure
			lua_settable(L, -3);// ..., M = { ..., name = closure }
		}

		lua_insert(L, -count - 1);	// M, ...
		lua_pop(L, count);	// M

		// Build an allocator.
		lua_pushinteger(L, def.mSize);	// M, size

		if (def.mShared)
		{
			lua_createtable(L, def.mArr, def.mRec);	// M, size, shared
			lua_pushcclosure(L, SharedAlloc, 2);// M, SharedAlloc
		}

		else
		{
			lua_pushinteger(L, def.mArr);	// M, size, narr
			lua_pushinteger(L, def.mRec);	// M, size, narr, nrec
			lua_pushcclosure(L, UniqueAlloc, 3);// M, UniqueAlloc
		}

		// Assign any parameters.
		if (!Types::IsEmpty(def.mBases)) Lua_Call(L, "class.Define", 0, "sa{ Kss Ksa }", name, -2, "base", Types::AsChar(def.mBases), "alloc", -1);

		else Lua_Call(L, "class.Define", 0, "sa{ Ksa }", name, -2, "alloc", -1);

		lua_pop(L, 2);
	}

	/// Dummy variable; @b class.New is cached under its address
	static int _New;

	/// Instantiates a class
	/// @param name Type name
	/// @param count Count of parameters on stack
	void Class::New (lua_State * L, const char * name, int count)
	{
		CacheAndGet(L, "class.New", &_New);	// class.New

		lua_pushstring(L, name);// ..., class.New, name
		lua_insert(L, -2 - count);	// name, ..., class.New 
		lua_insert(L, -2 - count);	// class.New, name, ...
		lua_call(L, count + 1, 1);	// I

		SetFuncInfo(0, 0, 0);
	}

	/// Instantiates a class
	/// @param name Type name
	/// @param params Parameter descriptors (q.v. CallCore())
	/// @param ... Arguments
	void Class::New (lua_State * L, const char * name, const char * params, ...)
	{
		CacheAndGet(L, "class.New", &_New);	// class.New

		lua_pushstring(L, name);// class.New, name

		va_list args;

		va_start(args, params);

		CallCore(L, 1, 1, params, args);

		SetFuncInfo(0, 0, 0);
	}

	/// Dummy variable; @b class.IsInstance is cached under its address
	static int _IsInstance;

	/// Indicates whether an item is an instance
	/// @param index Index of argument
	/// @return If @b true, item is an instance
	bool Class::IsInstance (lua_State * L, int index)
	{
		IndexAbsolute(L, index);

		CacheAndGet(L, "class.IsInstance", &_IsInstance);// class.IsInstance

		lua_pushvalue(L, index);// class.IsInstance, arg
		lua_call(L, 1, 1);	// bIsInstance

		bool bIsInstance = lua_toboolean(L, -1) != 0;

		lua_pop(L, 1);

		return bIsInstance;
	}

	/// Dummy variable; @b class.IsType is cached under its address
	static int _IsType;

	/// Indicates whether an item is of the given type
	/// @param index Index of item
	/// @param type Type name
	/// @param return If @b true, item is of the type
	bool Class::IsType (lua_State * L, int index, const char * type)
	{
		IndexAbsolute(L, index);

		CacheAndGet(L, "class.IsType", &_IsType);// class.IsType

		lua_pushvalue(L, index);// class.IsType, arg
		lua_pushstring(L, type);// class.IsType, arg, type
		lua_call(L, 2, 1);	// bIsType

		bool bIsType = lua_toboolean(L, -1) != 0;

		lua_pop(L, 1);

		return bIsType;
	}

	/// Loads a Lua file through the file manager
	/// @param name File name
	/// @remark On success, puts the chunk on the stack (returns it, called from Lua)
	/// @remark On failure, puts @b nil and the error message on the stack (returns them, called from Lua)
	int Lua::FM_Loader (lua_State * L)
	{
		const char * pszFilename = S(L, 1);

		IN_STREAM * pIn = CREATE_FILESTREAM(pszFilename, 0);

		if (0 == pIn)
		{
			lua_pushnil(L);	// file, nil
			lua_pushfstring(L, "Could not open file: %s", pszFilename);	// file, nil, error

			WARNING("Could not open file: %s", pszFilename);

			return 2;
		}

		int iScriptLen = pIn->GetSize();

		TEMP_BUFFER<16 * 1024> buffer(iScriptLen + 1);

		char *szBuffer = (char *)buffer.GetBuffer();

		pIn->Read(szBuffer, iScriptLen);

		szBuffer[iScriptLen] = 0;

		pIn->Close();

		// Load the string as a chunk.
		if (luaL_loadbuffer(L, szBuffer, iScriptLen, pszFilename) != 0)	// file[, chunk]
		{
			lua_pushnil(L);	// file, nil
			lua_insert(L, -2);	// file, nil, error

			return 2;
		}

		return 1;
	}

	/// Helper to load a Lua directory through the file manager
	/// @param boot Directory to boot, using Boot()
	/// @return @b lua_pcall result
	int Lua::LoadDir (lua_State * L, const char * boot)
	{
		CacheAndGet(L, Lua::FM_Loader);	// ..., loader

		int loader = lua_gettop(L);

		int result = Lua::Boot(L, "", boot, 0, 0, loader);

		lua_remove(L, loader);	// ...

		return result;
	}

	/// Helper to load a Lua file through the file manager
	/// @param name File name
	/// @return Result of @b lua_pcall(L, argc, retc, ERROR)
	int Lua::LoadFile (lua_State * L, const char * name)
	{
		CacheAndGet(L, Lua::FM_Loader);	// ..., loader

		lua_pushstring(L, name);// ..., loader, name

		return PCall_EF(L, 1, 1);	// file
	}

	namespace Types
	{
		/// @param lstr Lua-type string
		/// @return Pointer to const char * version of string
		const char * AsChar (const LuaString & lstr)
		{
			return lstr;
		}

		/// @param lstr Lua-type string
		/// @return If @b true, the string is empty
		bool IsEmpty (const LuaString & lstr)
		{
			return lstr.IsEmpty();
		}
	}
}

///
void CreateVector3 (lua_State * L, const VECTOR & v, int opt)
{
	if (!opt || lua_isnoneornil(L, opt)) LUA_CreateVector3(L, v);	// ..., v

	else
	{
		ASSERT_MSG(LUA_TestUserData(L, opt, LUA_TYPE_VECTOR3), "Expected vector");

		lua_Number * pVector = GET_VECTOR3(L, opt);

		pVector[0] = v.x;
		pVector[1] = v.y;
		pVector[2] = v.z;

		if (opt != -1 && opt != lua_gettop(L)) lua_pushvalue(L, opt);// ..., v
	}
}