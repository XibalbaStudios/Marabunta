#ifndef LUA_TYPES_H
#define LUA_TYPES_H

#include "Lua_/Lua.h"
#include <ENGINE>
#include <complex>

namespace Lua
{
	namespace Types
	{
/*
		// Object
		OBJECT * Object3D_ (lua_State * L, int index);

		// Entity
		ENTITY * Entity_ (lua_State * L, int index);

		// Physics object
		PHYSICS_OBJECT * PhysicsObject_ (lua_State * L, int index);

		// Math
		typedef std::complex<float> Complex;
		typedef MATRIX3x3 Matrix;
		typedef QUATERNION Quaternion;
		typedef VECTOR Vec3D;

		Complex Complex_ (lua_State * L, int index);
		Matrix Matrix_ (lua_State * L, int index);
		Quaternion Quaternion_ (lua_State * L, int index);
		Vec3D Vec3D_ (lua_State * L, int index);

		Complex & Complex_r (lua_State * L, int index);
		Matrix & Matrix_r (lua_State * L, int index);
		Quaternion & Quaternion_r (lua_State * L, int index);
		Vec3D & Vec3D_r (lua_State * L, int index);
*/
		// Graphics
		COLOR Color_ (lua_State * L, int index);

		typedef STRING LuaString;

		const char * AsChar (const LuaString & lstr);
		bool IsEmpty (const LuaString & lstr);
	}
}

#endif // LUA_TYPES_H