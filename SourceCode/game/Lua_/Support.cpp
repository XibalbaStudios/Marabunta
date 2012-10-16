#include "stdafx.h"

#include "Lua_/Lua.h"
#include "Lua_/LibEx.h"
#include "Lua_/Helpers.h"
#include "Lua_/Support.h"
#include <vector>

using namespace Lua;

/// Used to read arguments
struct Reader {
	// Members
	va_list & mArgs;///< Variable argument list
	lua_State * mL;	///< Lua state
	const char * mError;///< Error to propagate
	const char * mParams;	///< Parameter list
	int mHeight;///< Table height
	int mTop;	///< Original top of stack used to resolve negative indices
	bool mInKey;///< If @b true, a key is being read
	bool mInValue;	///< If @b true, a value is being read
	bool mShouldSkip;	///< If @b true, do not add an element

	// Lifetime
	Reader (va_list & args, lua_State * L, const char * params, int top) : mArgs(args), mL(L), mError(0), mParams(params), mHeight(0), mTop(top), mInKey(false), mInValue(false), mShouldSkip(false) {}
	~Reader (void) { va_end(mArgs); }

	/// Pass an error down
	bool Error (const char * error)
	{
		if (0 == mError) mError = error;

		return false;
	}

	/// Loads a value from the stack 
	bool _a (void)
	{
		int arg = va_arg(mArgs, int);

		if (!(arg >= lua_upvalueindex(256) && arg <= LUA_REGISTRYINDEX))
		{
			if (arg < 0) arg += 'a' == *mParams ? mTop : lua_gettop(mL) + 1;

			if (arg <= 0 || arg > lua_gettop(mL)) return Error("Bad index");
		}

		if (mInKey && lua_isnil(mL, arg)) return Error("Null key");

		if (!mShouldSkip) lua_pushvalue(mL, arg);	// ...[, arg]

		return true;
	}

	/// Loads a boolean
	void _b (void)
	{
		bool bArg = 'b' == *mParams ? va_arg(mArgs, bool) : 'T' == *mParams;

		if (!mShouldSkip) lua_pushboolean(mL, bArg);// ...[, bArg]
	}

	/// Loads a function
	void _f (void)
	{
		lua_CFunction func = va_arg(mArgs, lua_CFunction);

		if (!mShouldSkip) lua_pushcfunction(mL, func);	// ...[, func]
	}

	/// Loads an integer
	void _i (void)
	{
		int i = va_arg(mArgs, int);

		if (!mShouldSkip) lua_pushinteger(mL, i);	// ...[, i]
	}

	/// Loads a number
	void _n (void)
	{
		double n = va_arg(mArgs, double);

		if (!mShouldSkip) lua_pushnumber(mL, n);// ...[, n]
	}

	/// Loads a string
	void _s (void)
	{
		const char * str = va_arg(mArgs, const char *);

		if (!mShouldSkip) lua_pushstring(mL, str);	// ...[, str]
	}

	/// Loads a userdata
	bool _u (void)
	{
		void * ud = va_arg(mArgs, void *);

		if (!mShouldSkip)
		{
			if (ud == 0)
			{
				if (*mParams == 'U') return Error("Null userdata");

				lua_pushnil(mL);// ...[, nil]
			}

			else lua_pushlightuserdata(mL, ud);	// ...[, ud]
		}

		return true;
	}

	/// Loads a @b nil
	bool _0 (void)
	{
		if (mInKey) return Error("Null key");

		if (!mShouldSkip) lua_pushnil(mL);	// ...[, nil]

		return true;
	}

	/// Loads a global
	void _G (void)
	{
		const char * name = va_arg(mArgs, const char *);

		if (!mShouldSkip) GetGlobal(mL, name);	// ...[, global]
	}

	/// Loads a table
	bool _table (void)
	{
		++mHeight;

		if (!mShouldSkip) lua_newtable(mL);	// ...[, {}]

		for (++mParams; ; ++mParams)	// skip '{' at start, and skip over last parameter on each pass
		{
			int top = lua_gettop(mL);

			if (!ReadElement()) return Error("Unclosed table");	// ..., { ... }[, element]

			// If the stack has grown, append the element to the table.
			if (lua_gettop(mL) > top) Push(mL, -2);	// ..., { ..., [new top] = element }

			// On a '}' terminate a table (skipped over by caller).
			else if ('}' == *mParams) break;
		}

		--mHeight;

		return true;
	}

	/// Processes a conditional
	bool _C (void)
	{
		if (mInKey) return Error("Conditional key");
		if (mInValue) return Error("Conditional value");

		++mParams;	// Skip 'C' (value skipped by caller)

		bool bSkipSave = mShouldSkip, bDoSkip = !va_arg(mArgs, bool);

		if (!mShouldSkip) mShouldSkip = bDoSkip;
	
		if (!ReadElement()) return Error("Unfinished condition");	// ...[, value]

		mShouldSkip = bSkipSave;

		return true;
	}

	/// Processes a key
	bool _K (void)
	{
		++mParams;	// Skip 'K'

		mInKey = true;

		if (!ReadElement()) return Error("Missing key");	// ..., { ... }[, k]

		++mParams;	// Skip key (value skipped in table logic)

		mInKey = false;
		mInValue = true;

		if (!ReadElement()) return Error("Missing value");// ..., { ... }[, k, v]

		mInValue = false;

		if (!mShouldSkip) lua_settable(mL, -3);	// ..., { ...[, k = v] }

		return true;
	}

	/// Reads an element from the parameter set
	/// @return If true, parameters remain
	bool ReadElement (void)
	{
		// Remove space characters.
		while (isspace(*mParams)) ++mParams;

		// Branch on argument type.
		switch (*mParams)
		{
		case '\0':	// End of list
			return false;
		case 'a':	// Add argument from the stack
		case 'r':
			return _a();
		case 'b':	// Add boolean
		case 'T':
		case 'F':
			_b();
			break;
		case 'f':	// Add function
			_f();
			break;
		case 'i':	// Add integer
			_i();
			break;
		case 'n':	// Add number
			_n();
			break;
		case 's':	// Add string
			_s();
			break;
		case 'u':	// Add userdata
		case 'U':
			return _u();
		case '0':	// Add nil
			return _0();
		case 'g':	// Add global
			_G();
			break;
		case '{':	// Begin table
			return _table();
		case '}':	// End table (error)
			if (0 == mHeight) return Error("Unopened table");
			break;
		case 'C':	// Evaluate condition
			return _C();
		case 'K':	// Key
			if (0 == mHeight) return Error("Key outside table");

			return _K();
		default:
			return Error("Bad type");
		}

		// Keep reading.
		return true;
	}
};

/// Core operation for various Lua operations called on the C++ end
/// @param count Count of arguments already added to stack
/// @param retc Result count (may be @b MULT_RET)
/// @param params Parameter descriptors
///		   @li @b a Argument (stack index, relative to initial stack top if negative; also accepts pseudo-indices)
///		   @li @b r Relative argument (same as @b a, but relative to current stack top if negative)
///		   @li @b b Boolean
///		   @li @b T true
///		   @li @b F false
///		   @li @b f Function
///		   @li @b i Integer
///		   @li @b n Number
///		   @li @b s String
///		   @li @b u Light userdata (if @b NULL, @b nil is used instead)
///		   @li @b U Light userdata, error on @b NULL
///		   @li <b>0</b> Nil
///		   @li @b g Global (as per Lua::GetGlobal() with no arguments)
///		   @li <b>{</b> Begin table (arguments added up to matching brace added)
///		   @li <b>}</b> End table
///		   @li @b C Condition boolean (if @b false, next parameter is skipped)
///		   @li @b K Next value is table key
/// @param args Variable argument list (cleaned up afterward)
/// @param bProtected If true, call is protected and throws any error
/// @return Number of results of call
int Lua::CallCore (lua_State * L, int count, int retc, const char * params, va_list & args, bool bProtected)
{
	// Parse the arguments.
	int top = lua_gettop(L);

	Reader r(args, L, params, top - count);

	if (*params != '\0')
	{
		while (r.ReadElement()) ++r.mParams;

		count += lua_gettop(L) - top;

		if (!bProtected && r.mError != 0) luaL_error(L, r.mError);
	}

	// Invoke the function.
	int after = lua_gettop(L) - count - 1;

	if (bProtected)
	{
		// If a protected call raises an error, restore the stack to its precall state and
		// throw the error; if the error is not a string, indicate this.
		if (r.mError != 0 || PCall_EF(L, count, retc) != 0)
		{
			Types::LuaString error = r.mError != 0 ? r.mError : luaL_optstring(L, -1, "Caught non-string error");

			lua_settop(L, after);

			throw error;
		}
	}

	else lua_call(L, count, retc);

	return lua_gettop(L) - after;
}

/// Instantiates a class with an overloaded new function
/// @param type Type to instantiate
/// @param argc Minimum argument count
/// @remark New instance left on top of stack
int Lua::OverloadedNew (lua_State * L, const char * type, int argc)
{
	if (lua_gettop(L) < argc) lua_settop(L, argc);

	Lua_Class_New(L, type, lua_gettop(L));

	return 1;
}

static int StringVectorPrintf (lua_State * L)
{
	std::vector<Types::LuaString> * vec = (std::vector<Types::LuaString> *)UD(L, lua_upvalueindex(1));

	GetGlobal(L, "string.format"); // format_str, ..., string.format

	lua_insert(L, 1); // string.format, format_str, ...

	lua_call(L, lua_gettop(L) - 1, 1); // result_str

	vec->push_back(S(L, 1));

	return 0;
}

void Lua::StackView (lua_State * L){

	lua_Debug ar;

	for (int i = 0; lua_getstack(L, i, &ar) != 0; i++) {
		// fill in lua_Debug
		lua_getinfo(L, "Sl", &ar);
		//get locals
		for (int j = 1 ; ; j++, lua_pop(L, 1)){
			const char* name = lua_getlocal(L, &ar, j);
			// break for if no name is returned, meaning no more locals
			if (name == NULL) break;
			// skip internal locals
			if(name[0] == '('){
				continue;
			}
			
			std::vector<Types::LuaString> vec;

			GetGlobal(L, "var_dump.Print"); // local_var, var_dump.Print

			lua_pushvalue(L, -2); // local_var, var_dump.Print, local_var
			lua_pushlightuserdata(L, &vec); // local_var, var_dump.Print, local_var, vec
			lua_pushcclosure(L, StringVectorPrintf, 1); // local_var, var_dump.Print, local_var, StringVectorPrintf
			lua_call(L, 2, 0); // local_var
			// Place breakpoint here!!
		}
	}
}

/// Constructs an Overload
/// @param argc Count of arguments to overloaded function
Overload::Overload (lua_State * L, int argc) : mL(L)
{
	for (int i = 0; i < argc; ++i) mArgs += 's';

	Lua_Class_New(L, "Multimethod", "i", argc);// ..., M
}

/// Adds a function defintion
/// @param func Function to be invoked
/// @note Vararg parameters are the argument types on which to invoke
/// @note Overload must be on the stack top
void Overload::AddDef (lua_CFunction func, ...)
{
	va_list args;

	va_start(args, func);

	lua_getfield(mL, -1, "Define");	// ..., G, G.Define
	lua_pushvalue(mL, -2);	// ..., G, G.Define, G
	lua_pushcfunction(mL, func);// ..., G, G.Define, G, func

	CallCore(mL, 2, 0, Types::AsChar(mArgs), args);
}