#ifndef LUA_VARS_H
#define LUA_VARS_H

namespace Lua
{
	/*%%%%%%%%%%%%%%%% TEMPLATED LOADER FUNCTIONS %%%%%%%%%%%%%%%%*/

	/// Support for reading fields from a Lua value and feeding them into C++ variables
	template<typename T> struct Aux_FromFieldsToVars {
		lua_State * mL;	///< Lua state
		T (*mFunc)(lua_State *);///< Function used to grab top value from stack
		T (*mFuncPop)(lua_State *, int);///< Alternative function to grab top value from stack top without popping
		int mIndex;	///< Source index

		Aux_FromFieldsToVars (lua_State * L, T (*func)(lua_State *), int index) : mL(L), mFunc(func), mFuncPop(0), mIndex(index) {}
		Aux_FromFieldsToVars (lua_State * L, T (*func)(lua_State *, int), int index) : mL(L), mFunc(0), mFuncPop(func), mIndex(index) {}

		Aux_FromFieldsToVars & Set (const char * name, T & value)
		{
			lua_getfield(mL, mIndex, name);	// { ... }, ..., field

			if (mFunc != 0) value = mFunc(mL);	// { ... }, ...

			else
			{
				value = mFuncPop(mL, -1);

				lua_pop(mL, 1);	// { ... }, ...
			}

			return *this;
		}
	};

	template<typename T> Aux_FromFieldsToVars<T> FromFieldsToVars (lua_State * L, T (*func)(lua_State * L), int index)
	{
		return Aux_FromFieldsToVars<T>(L, func, index);
	}

	template<typename T> Aux_FromFieldsToVars<T> FromFieldsToVars (lua_State * L, T (*func)(lua_State * L, int), int index)
	{
		return Aux_FromFieldsToVars<T>(L, func, index);
	}

	/// Support for reading fields from a Lua value and feeding them into C++ member variables
	template<typename C, typename T> struct Aux_FromFieldsToMembers {
		C & mObject;///< Object to which members belong
		lua_State * mL;	///< Lua state
		T (*mFunc)(lua_State *);///< Function used to grab top value from stack
		T (*mFuncPop)(lua_State *, int);///< Alternative function to grab top value from stack top without popping
		int mIndex;	///< Source index

		Aux_FromFieldsToMembers (lua_State * L, T (*func)(lua_State *), int index, C & object) : mObject(object), mL(L), mFunc(func), mFuncPop(0), mIndex(index) {}
		Aux_FromFieldsToMembers (lua_State * L, T (*func)(lua_State *, int), int index, C & object) : mObject(object), mL(L), mFunc(0), mFuncPop(func), mIndex(index) {}

		Aux_FromFieldsToMembers & Set (const char * name, T C::*value)
		{
			lua_getfield(mL, mIndex, name);	// { ... }, ..., field

			if (mFunc != 0) mObject.*value = mFunc(mL);	// { ... }, ...

			else
			{
				mObject.*value = mFuncPop(mL, -1);

				lua_pop(mL, 1);	// { ... }, ...
			}

			return *this;
		}
	};

	template<typename C, typename T> Aux_FromFieldsToMembers<C, T> FromFieldsToMembers (lua_State * L, T (*func)(lua_State * L), int index, C & object)
	{
		return Aux_FromFieldsToMembers<C, T>(L, func, index, object);
	}

	template<typename C, typename T> Aux_FromFieldsToMembers<C, T> FromFieldsToMembers (lua_State * L, T (*func)(lua_State * L, int), int index, C & object)
	{
		return Aux_FromFieldsToMembers<C, T>(L, func, index, object);
	}

	template<typename C, typename T> Aux_FromFieldsToMembers<C, T> FromFieldsToMembers (lua_State * L, T (*func)(lua_State * L), int index, C * object)
	{
		return Aux_FromFieldsToMembers<C, T>(L, func, index, *object);
	}

	template<typename C, typename T> Aux_FromFieldsToMembers<C, T> FromFieldsToMembers (lua_State * L, T (*func)(lua_State * L, int), int index, C * object)
	{
		return Aux_FromFieldsToMembers<C, T>(L, func, index, *object);
	}

	/// Support for writing fields of a Lua value from C++ member variables
	template<typename T, typename C, typename F> struct Aux_FromMembersToFields {
		C & mObject;///< Object to which members belong
		lua_State * mL;	///< Lua state
		F mFunc;///< Function used to push member onto stack
		int mIndex;	///< Destination index

		Aux_FromMembersToFields (lua_State * L, F func, int index, C & object) : mObject(object), mL(L), mFunc(func), mIndex(index)
		{
			IndexAbsolute(L, mIndex);
		}

		Aux_FromMembersToFields & Set (const char * name, T C::*value)
		{
			mFunc(mL, mObject.*value);	// { ... }, ..., value
			lua_setfield(mL, mIndex, name);	// { name = value }, ...

			return *this;
		}
	};

	template<typename T, typename C, typename F> Aux_FromMembersToFields<T, C, F> FromMembersToFields (lua_State * L, F func, int index, C & object)
	{
		return Aux_FromMembersToFields<T, C, F>(L, func, index, object);
	}

	template<typename T, typename C, typename F> Aux_FromMembersToFields<T, C, F> FromMembersToFields (lua_State * L, F func, int index, C * object)
	{
		return Aux_FromMembersToFields<T, C, F>(L, func, index, *object);
	}
}

#endif // LUA_VARS_H