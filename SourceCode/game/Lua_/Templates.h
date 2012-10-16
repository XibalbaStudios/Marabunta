#ifndef LUA_TEMPLATES_H
#define LUA_TEMPLATES_H

namespace Lua
{
	/*%%%%%%%%%%%%%%%% TEMPLATED HELPER FUNCTIONS %%%%%%%%%%%%%%%%*/

	/// Templated type stub
	/// @return Empty string
	template<typename T> const char * luaT_type (void) { return ""; }

	/// Templated boxed type stub
	/// @return Empty string
	template<typename T> const char * luaT_boxed_type (void) { return ""; }

	/// Templated type accessor
	/// @param index Stack index
	/// @return Pointer to type
	template<typename T> T * luaT_ptr (lua_State * L, int index)
	{
		// Given an instance, supply its memory; if it is a non-T type, report an error.
		// Otherwise, simply return the non-instance's memory.
		if (Class::IsInstance(L, index))
		{
			// If the instance is a boxed T, look up its memory.
			if (Class::IsType(L, index, luaT_boxed_type<T>())) return luaT_boxed_get<T>(L, index);

			// Otherwise, point to its memory.
			if (!Class::IsType(L, index, luaT_type<T>())) luaL_error(L, "Arg #%d: non-%s / %s", index, luaT_type<T>(), luaT_boxed_type<T>());
		}

		return (T *)UD(L, index);
	}

	/// Templated type accessor
	/// @param index Stack index
	/// @return Reference to type
	template<typename T> T & luaT_ref (lua_State * L, int index)
	{
		return *luaT_ptr<T>(L, index);
	}

	/// Templated type accessor
	/// @param index Stack index
	/// @return Pointer to type, or @b NULL if absent
	template<typename T> T * luaT_ptr_or_null (lua_State * L, int index)
	{
		if (!lua_isnoneornil(L, index)) return luaT_ptr<T>(L, index);

		return 0;
	}

	/// Templated member getter; builds a new object or fills in a passed one if available (passed-in object version)
	/// @param index Stack index
	/// @param ref
	/// @param type
	/// @param d
	/// @param bTop
	/// @remark
	template<typename D> int luaT_get_member_arg (lua_State * L, int index, D & (*ref)(lua_State *, int), const char * type, const D & d, bool bTop = true)
	{
		if (!lua_isnoneornil(L, index))
		{
			ref(L, index) = d;

			if (bTop) lua_settop(L, index);
		}

		else Lua_Class_New(L, type, "u", &d);

		return 1;
	}

	/// Templated member getter; builds a new object or fills in a passed one if available (reference version)
	/// @param pObject
	/// @param index Stack index
	/// @param ref
	/// @param type
	/// @param func
	/// @param bTop
	/// @remark
	template<typename O, typename D> int luaT_get_member_ref (lua_State * L, O * pObject, int index, D & (*ref)(lua_State *, int), const char * type, void (O::*func)(D &) const, bool bTop = true)
	{
		D d;

		(pObject->*func)(d);

		return luaT_get_member_arg(L, index, ref, type, d, bTop);
	}

	/// Templated member getter; builds a new object or fills in a passed one if available (returned object version)
	/// @param pObject
	/// @param index Stack index
	/// @param ref
	/// @param type
	/// @param func
	/// @param bTop
	/// @remark
	template<typename O, typename D> int luaT_get_member_retv (lua_State * L, O * pObject, int index, D & (*ref)(lua_State *, int), const char * type, D (O::*func)(void) const, bool bTop = true)
	{
		return luaT_get_member_arg(L, index, ref, type, (pObject->*func)(), bTop);
	}

	/// Templated boxed member get
	/// @param source
	/// @return
	template<typename T> T * luaT_boxed_get (lua_State * L, int source)
	{
		return *(T **)UD(L, source);
	}

	/// Templated boxed member direct set
	/// @param dest
	/// @param value
	/// @remark
	template<typename T> int luaT_boxed_set (lua_State * L, int dest, T * value)
	{
		*(T **)UD(L, dest) = value;

		return 0;
	}

	/// Templated boxed member set
	/// @param dest
	/// @param source
	/// @remark
	template<typename T> int luaT_boxed_set (lua_State * L, int dest, int source)
	{
		return luaT_boxed_set(L, dest, luaT_ptr<T>(L, source));
	}

	/// Templated boxed member direct set (reference count version)
	/// @param dest
	/// @param value
	/// @param bCheckTarget
	/// @remark
	template<typename T> int luaT_boxed_set_ref (lua_State * L, int dest, T * value, bool bCheckTarget = true)
	{
		T ** target = (T **)UD(L, dest);

		if (value != 0) value->AddRef();
		if (bCheckTarget && *target != 0) (*target)->Release();

		*target = value;

		return 0;
	}

	/// Templated boxed member set (reference count version)
	/// @param dest
	/// @param source
	/// @param bCheckTarget
	/// @remark
	template<typename T> int luaT_boxed_set_ref (lua_State * L, int dest, int source, bool bCheckTarget = true)
	{
		return luaT_boxed_set_ref<T>(L, dest, luaT_ptr_or_null<T>(L, source), bCheckTarget);
	}

	/// Templated copy
	/// @param t
	/// @remark
	template<typename T> int luaT_copy (lua_State * L, T & t)
	{
		Lua_Class_New(L, luaT_type<T>(), "u", &t);	// t

		return 1;
	}

	/// Templated constructor set helper (reference count version)
	/// @param source
	/// @remark
	template<typename T> int luaT_cons_set_ref (lua_State * L, int source)
	{
		return luaT_boxed_set_ref<T>(L, 1, source, false);
	}

	/// Templated constructor set helper (reference count version)
	/// @param value
	/// @remark
	template<typename T> int luaT_cons_set_ref (lua_State * L, T * value)
	{
		return luaT_boxed_set_ref(L, 1, value, false);
	}

	/// Templated copy @b __cons metamethod
	/// @remark Note that this adheres to the @b lua_CFunction signature
	template<typename T> int luaT_cons_copy (lua_State * L)
	{
		return luaT_boxed_set<T>(L, 1, 2);
	}

	/// Templated @b __cons metamethod (reference count version)
	/// @remark Note that this adheres to the @b lua_CFunction signature
	template<typename T> int luaT_cons_ref (lua_State * L)
	{
		return luaT_cons_set_ref(L, new T);
	}

	/// Templated copy @b __cons metamethod (reference count version)
	/// @remark Note that this adheres to the @b lua_CFunction signature
	template<typename T> int luaT_cons_ref_copy (lua_State * L)
	{
		return luaT_cons_set_ref<T>(L, 2);
	}

	/// Templated @b __cons metamethod (reference / pointer version)
	/// @remark Note that this adheres to the @b lua_CFunction signature
	template<typename T> int luaT_cons_refp (lua_State * L)
	{
		return luaT_cons_set_ref(L, luaT_ptr<T>(L, 2));
	}

	/// Templated @b __cons metamethod (reference / pointer or @b NULL version)
	/// @remark Note that this adheres to the @b lua_CFunction signature
	template<typename T> int luaT_cons_refp_or_null (lua_State * L)
	{
		return luaT_cons_set_ref(L, luaT_ptr_or_null<T>(L, 2));
	}

	/// Templated @b __gc metamethod (reference count version)
	/// @remark Note that this adheres to the @b lua_CFunction signature
	template<typename T> int luaT_gc_ref (lua_State * L)
	{
		return luaT_boxed_set_ref(L, 1, (T *)0);
	}

	/// Templated @b __gc metamethod (explicit destructor version)
	/// @remark Note that this adheres to the @b lua_CFunction signature
	template<typename T> int luaT_gc_dtor (lua_State * L)
	{
		((T *)UD(L, 1))->~T();

		return 0;
	}

	/// Installs a typed object to be garbage-collected, without construction
	/// @return Pointer to new object memory (not yet constructed)
	/// @remark The object is stored in the registry with pointer as key
	template<typename T> T * luaT_install_raw_gc_object (lua_State * L)
	{
		T * gc_object = (T *)lua_newuserdata(L, sizeof(T));	// ..., gc_object

		lua_newtable(L);// ..., gc_object, {}
		lua_pushcfunction(L, luaT_gc_dtor<T>);	// ..., gc_object, {}, GC
		lua_setfield(L, -2, "__gc");// ..., gc_object, { __gc = GC }
		lua_setmetatable(L, -2);// ..., gc_object
		lua_pushboolean(L, true);	// ..., gc_object, true
		lua_rawset(L, LUA_REGISTRYINDEX);	// ...

		return gc_object;
	}

	/// Installs a typed objected to be garbage-collected
	/// @return Pointer to new object
	/// @remark The object is stored in the registry with pointer as key
	template<typename T> T * luaT_install_gc_object (lua_State * L)
	{
		T * gc_object = luaT_install_raw_gc_object<T>(L);

		new (gc_object) T;

		return gc_object;
	}
}

#endif // LUA_TEMPLATES_H