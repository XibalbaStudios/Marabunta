#include "stdafx.h"

#include "Lua_/Lua.h"
#include "Lua_/Arg.h"
#include "Lua_/Helpers.h"
#include "Lua_/Support.h"
#include <cassert>

namespace Lua
{
	static char * s_file;	///< File name registered by SetFuncInfo()
	static char * s_func;	///< Function name registered by SetFuncInfo()
	static int s_line;	///< Line number registered by SetFuncInfo()

	/// Gets the C++ function info registered by SetFuncInfo()
	void GetFuncInfo (char *& file, char *& func, int & line)
	{
		file = s_file;
		func = s_func;
		line = s_line;
	}

	/// Sets the C++ function info
	void SetFuncInfo (char * file, char * func, int line)
	{
		s_file = file;
		s_func = func;
		s_line = line;
	}

	static lua_CFunction s_oldpanic;	///< Previous panic function

	/// Panic function
	static int PanicFunc (lua_State * L)
	{
		lua_pushfstring(L, "%s: file = %s, func = %s, line = %d", S(L, -1), s_file, s_func, s_line);// ..., error, str
		lua_replace(L, -2);	// ..., str

		s_oldpanic(L);

		return 0;
	}

	/// Sets a panic handler with function info
	void AtPanic (lua_State * L)
	{
		s_oldpanic = lua_atpanic(L, PanicFunc);
	}

	/// Runs a boot script
	/// @param path Path to script
	/// @param name Boot script name
	/// @param arg Index of argument on stack (if @b NULL, @b nil)
	/// @param ext Optional extension
	/// @param loader Index of loader on stack (if @b NULL, @b nil)
	/// @return @b lua_pcall result
	int Boot (lua_State * L, const char * path, const char * name, int arg, const char * ext, int loader)
	{
		IndexAbsolute(L, arg);
		IndexAbsolute(L, loader);

		lua_getglobal(L, "Load");	// Load
		lua_createtable(L, 0, 2);	// Load, {}
		lua_pushstring(L, path);	// Load, {}, path
		lua_setfield(L, -2, "name");// Load, { name = path }
		lua_pushstring(L, name);	// Load, { name }, name
		lua_setfield(L, -2, "boot");// Load, { name, boot = name }
		lua_pushliteral(L, "");	// Load, { name, boot }, ""
		lua_pushvalue(L, LUA_GLOBALSINDEX);	// Load, { name, boot }, "", _G

		arg != 0 ? lua_pushvalue(L, arg) : lua_pushnil(L);	// Load, { name, boot }, "", _G, arg_or_nil
		ext != 0 ? lua_pushstring(L, ext) : lua_pushnil(L);	// Load, { name, boot }, "", _G, arg_or_nil, ext_or_nil
		loader != 0 ? lua_pushvalue(L, loader) : lua_pushnil(L);// Load, { name, boot }, "", _G, arg_or_nil, ext_or_nil, loader_or_nil

		return PCall_EF(L, 6, 0);
	}

	/// Calls a Lua routine from C / C++
	/// @param name Routine name
	/// @param retc Result count (q.v. CallCore())
	/// @param params Parameter descriptors (q.v. CallCore())
	/// @param ... Arguments
	/// @return Number of results of call
	int Call (lua_State * L, const char * name, int retc, const char * params, ...)
	{
		GetGlobal(L, name);	// func

		va_list args;

		va_start(args, params);

		return CallCore(L, 0, retc, params, args);
	}

	/// Calls a Lua routine from C / C++ at the top of the stack
	/// @param retc Result count (q.v. CallCore())
	/// @param params Parameter descriptors (q.v. CallCore())
	/// @param ... Arguments
	/// @return Number of results of call
	int Call (lua_State * L, int retc, const char * params, ...)
	{
		va_list args;

		va_start(args, params);

		return CallCore(L, 0, retc, params, args);
	}

	/// Calls a Lua method from C / C++
	/// @param source Source name
	/// @param name Routine name
	/// @param retc Result count (q.v. CallCore())
	/// @param params Parameter descriptors (q.v. CallCore())
	/// @param ... Arguments
	/// @return Number of results of call
	int CallMethod (lua_State * L, const char * source, const char * name, int retc, const char * params, ...)
	{
		GetGlobal(L, source);	// source

		lua_getfield(L, -1, name);	// ..., source, source[name]
		lua_insert(L, -2);	// ..., source[name], source

		va_list args;

		va_start(args, params);

		return CallCore(L, 1, retc, params, args);
	}

	/// Calls a Lua method from C / C++
	/// @param source Source argument stack index
	/// @param name Routine name
	/// @param retc Result count (q.v. CallCore())
	/// @param params Parameter descriptors (q.v. CallCore())
	/// @param ... Arguments
	/// @return Number of results of call
	int CallMethod (lua_State * L, int source, const char * name, int retc, const char * params, ...)
	{
		IndexAbsolute(L, source);

		lua_getfield(L, source, name);	// ..., source[name]
		lua_pushvalue(L, source);	// ..., source[name], source

		va_list args;

		va_start(args, params);

		return CallCore(L, 1, retc, params, args);
	}

	/// Calls a Lua routine from C / C++; throws an exception on errors
	/// @param name Routine name
	/// @param retc Result count (q.v. CallCore)
	/// @param params Parameter descriptors (q.v. CallCore)
	/// @param ... Arguments
	/// @return Number of results of call
	int PCall (lua_State * L, const char * name, int retc, const char * params, ...)
	{
		GetGlobal(L, name);	// func

		va_list args;

		va_start(args, params);

		return CallCore(L, 0, retc, params, args, true);
	}

	/// Calls a Lua routine from C / C++ at the top of the stack; throws an exception on errors
	/// @param retc Result count (q.v. CallCore)
	/// @param params Parameter descriptors (q.v. CallCore)
	/// @param ... Arguments
	/// @return Number of results of call
	int PCall (lua_State * L, int retc, const char * params, ...)
	{
		va_list args;

		va_start(args, params);

		return CallCore(L, 0, retc, params, args, true);
	}

	/// Calls a Lua method from C / C++; throws an exception on errors
	/// @param source Source name
	/// @param name Routine name
	/// @param retc Result count (q.v. CallCore())
	/// @param params Parameter descriptors (q.v. CallCore())
	/// @param ... Arguments
	/// @return Number of results of call
	int PCallMethod (lua_State * L, const char * source, const char * name, int retc, const char * params, ...)
	{
		GetGlobal(L, source);	// source

		lua_getfield(L, -1, name);	// ..., source, source[name]
		lua_insert(L, -2);	// ..., source[name], source

		va_list args;

		va_start(args, params);

		return CallCore(L, 1, retc, params, args, true);
	}

	/// Calls a Lua method from C / C++; throws an exception on errors
	/// @param source Source argument stack index
	/// @param name Routine name
	/// @param retc Result count (q.v. CallCore())
	/// @param params Parameter descriptors (q.v. CallCore())
	/// @param ... Arguments
	/// @return Number of results of call
	int PCallMethod (lua_State * L, int source, const char * name, int retc, const char * params, ...)
	{
		IndexAbsolute(L, source);

		lua_getfield(L, source, name);	// ..., source[name]
		lua_pushvalue(L, source);	// ..., source[name], source

		va_list args;

		va_start(args, params);

		return CallCore(L, 1, retc, params, args, true);
	}

	/// Gets a value, cached after the first use
	/// @param name Global function name
	/// @param key Address used for lookup
	/// @remark Value left on stack
	void CacheAndGet (lua_State * L, const char * name, void * key)
	{
		lua_pushlightuserdata(L, key);	// ..., key
		lua_rawget(L, LUA_REGISTRYINDEX);	// ..., value_or_nil

		if (lua_isnil(L, -1))
		{
			lua_pop(L, 1);	// ...
			lua_pushlightuserdata(L, key);	// ..., key

			GetGlobal(L, name);	// ..., key, value

			lua_pushvalue(L, -1);	// ..., key, value, value
			lua_insert(L, -3);	// ..., value, key, value
			lua_rawset(L, LUA_REGISTRYINDEX);	// ..., value
		}
	}

	/// Gets a function, cached after the first use
	/// @param func Key / value of function
	/// @remark Function left on stack
	void CacheAndGet (lua_State * L, lua_CFunction func)
	{
		lua_pushlightuserdata(L, func);// ..., key
		lua_rawget(L, LUA_REGISTRYINDEX);	// ..., func_or_nil

		if (lua_isnil(L, -1))
		{
			lua_pop(L, 1);	// ...
			lua_pushlightuserdata(L, func);	// ..., key
			lua_pushcfunction(L, func);	// ..., key, func
			lua_pushvalue(L, -1);	// ..., key, func, func
			lua_insert(L, -3);	// ..., func, key, func
			lua_rawset(L, LUA_REGISTRYINDEX);	// ..., func
		}									
	}

	/// Gets a global variable, allowing nested paths
	/// @param name Routine name (allows for nesting)
	void GetGlobal (lua_State * L, const char * name)
	{
		lua_pushvalue(L, LUA_GLOBALSINDEX);	// _G

		for (const char * pDot; (pDot = strchr(name, '.')) != 0; name = pDot + 1)
		{
			lua_pushlstring(L, name, pDot - name);	// table, name
			lua_gettable(L, -2);// table, level
			lua_replace(L, -2);	// level
		}

		lua_getfield(L, -1, name);	// table, value
		lua_replace(L, -2);	// value
	}

	/// Pops the last element from a table
	/// @param index Table stack index
	/// @param bPutOnStack If true, leave value on stack
	void Pop (lua_State * L, int index, bool bPutOnStack)
	{
		IndexAbsolute(L, index);

		int top = GetN(L, index);

		if (bPutOnStack) lua_rawgeti(L, index, top);// [top]

		lua_pushnil(L);	// [top, ]nil
		lua_rawseti(L, index, top);	// [top]
	}

	/// Pushes the top stack element onto the end of a table
	/// @param index Table stack index
	void Push (lua_State * L, int index)
	{
		lua_rawseti(L, index, GetN(L, index) + 1);
	}

	/// Registers a set of functions with a common environment; pops the table
	/// @param name [optional] Library name to register
	/// @param funcs Functions to register
	/// @param env Stack index of environment (0 for default)
	void Register (lua_State * L, const char * name, const luaL_reg * funcs, int env)
	{
		if (env != 0)
		{
			lua_pushvalue(L, LUA_ENVIRONINDEX);	// ..., curenv
			lua_pushvalue(L, env < 0 ? env - 1 : env);	// ..., curenv, env
			lua_replace(L, LUA_ENVIRONINDEX);	// ..., curenv
		}

		luaL_register(L, name, funcs);	// ...[, curenv, set]

		if (name != 0) lua_pop(L, 1);	// ...[, curenv]
		if (env != 0) lua_replace(L, LUA_ENVIRONINDEX); // ...
	}

	/// Sets a global variable, allowing nested paths
	/// @param name Global name (allows for nesting)
	/// @remark Stack top: Value to assign
	void SetGlobal (lua_State * L, const char * name)
	{
		lua_pushvalue(L, LUA_GLOBALSINDEX);	// value, _G

		for (const char * pDot; (pDot = strchr(name, '.')) != 0; name = pDot + 1)
		{
			lua_pushlstring(L, name, pDot - name);	// value, table, name
			lua_gettable(L, -2);// value, table, level
			lua_replace(L, -2);	// value, level
		}

		lua_insert(L, -2);	// table, value
		lua_setfield(L, -2, name);	// table[name] = value
		lua_pop(L, 1);	// stack clear
	}

	/// Pushes the top table element onto the stack
	/// @param index Table stack index
	void Top (lua_State * L, int index)
	{
		lua_rawgeti(L, index, GetN(L, index));	// top
	}

	/// Gets a series of indexed elements from a source
	/// @param source Source argument stack index
	/// @param start Index of first element in source
	/// @param end Index of final element in source
	void Unpack (lua_State * L, int source, int start, int end)
	{
		IndexAbsolute(L, source);

		if (start < 0 || end < 0)
		{
			int count = GetN(L, source);

			if (start < 0) start = count + start + 1;
			if (end < 0) end = count + end + 1;

			assert(start <= end);
		}

		for (int i = start; i <= end; ++i) lua_rawgeti(L, source, i);	// ...[, elem1, ...]
	}

	/// Gets an object size
	/// @param index Stack index
	/// @return Size of object
	int GetN (lua_State * L, int index)
	{
		return int(lua_objlen(L, index));
	}

	/// Error function
	/// @remark Stack top: Error message
	/// @return Message augmented with traceback
	static int ErrorFunc (lua_State * L)
	{
		lua_Debug ar; 
 
		for (int i = 1; lua_getstack(L, i, &ar) != 0; ++i)
		{
			lua_getinfo(L, "Sl", &ar);
			lua_pushfstring(L, ar.currentline != -1 ? "\n%s:%d" : "\n%s", ar.source, ar.currentline);	// message, about
			lua_concat(L, 2);	// message
		}

		return 1;
	}

	/// Performs a protected call with an error function installed
	/// @param argc Argument count
	/// @param retc Return count
	/// @return Result of @b lua_pcall(L, argc, retc, ERROR)
	int PCall_EF (lua_State * L, int argc, int retc)
	{
		CacheAndGet(L, ErrorFunc);	// ..., func, ..., errfunc

		int err = -(argc + 2);

		IndexAbsolute(L, err);

		lua_insert(L, err);	// ..., errfunc, func, ...

		// If a protected call raises an error, restore the stack to its precall state and
		// throw the error; if the error is not a string, indicate this.
		int result = lua_pcall(L, argc, retc, err);

		lua_remove(L, err);	// ..., results

		return result;
	}

	/// Indicates whether the argument can be called
	/// @param index Stack index
	/// @return If true, argument can be called
	bool IsCallable (lua_State * L, int index)
	{
		if (lua_isfunction(L, index)) return true;
		if (luaL_getmetafield(L, index, "__call") == 0) return false;	// __call

		lua_pop(L, 1);

		return true;
	}
}