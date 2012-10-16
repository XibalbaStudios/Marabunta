#ifndef LUA_LIB_EX_H
#define LUA_LIB_EX_H

#include "Lua_/Lua.h"
#include "Lua_/Arg.h"
#include "Lua_/Types.h"

namespace Bindings
{
	G2GAME_IMPEXP int open_std (lua_State * L);
}

namespace Lua
{
	namespace Class
	{
		/// Class definition
		struct Def {
			Types::LuaString mBases;///< Base types
			unsigned int mArr;	///< Environment: Array count
			unsigned int mRec;	///< Environment: Record count
			unsigned int mSize;	///< Class size
			bool mShared;	///< If @b true, use shared environment table

			Def (unsigned int size = 0, const char * bases = 0, bool bShared = false) : mArr(0), mRec(0), mSize(size), mShared(bShared)
			{
				if (bases != 0) mBases = bases;
			}
		};

		G2GAME_IMPEXP void Define (lua_State * L, const char * name, const luaL_reg * methods, const Def & def = Def());
		G2GAME_IMPEXP void Define (lua_State * L, const char * name, const luaL_reg * methods, const char * closures[], const Def & def = Def());
		G2GAME_IMPEXP void New (lua_State * L, const char * name, int count);
		G2GAME_IMPEXP void New (lua_State * L, const char * name, const char * params, ...);

		G2GAME_IMPEXP bool IsInstance (lua_State * L, int index);
		G2GAME_IMPEXP bool IsType (lua_State * L, int index, const char * type);
	}

	G2GAME_IMPEXP int FM_Loader (lua_State * L);

	G2GAME_IMPEXP int LoadDir (lua_State * L, const char * boot);
	G2GAME_IMPEXP int LoadFile (lua_State * L, const char * name);
}

/// Attaches some traceback info to catch Lua::Class::New() constructor errors
#define Lua_Class_New Lua::SetFuncInfo(__FILE__, __FUNCTION__, __LINE__), Lua::Class::New

/// Creates a luaL_Reg table entry 
#define LUAL_REG_ENTRY( _function )\
	{ #_function, _function##B}


#define TABLE_FIELD( _field )\
	lua_getfield( L, -1, _field );\
	VASSERT( lua_istable( L , -1 ));

#define TABLE_NUM_FIELD( _field )\
	lua_pushnumber( L, _field );\
	lua_gettable( L, -2 );\
	VASSERT( lua_istable( L , -1 ));


#define GET_FIELD( _field,  _type , _var )\
	_type _var;	\
	lua_getfield(L, -1, _field);\
	if( !LUA_GetValue( L, -1, _var  ) )\
	{\
		luaL_error( L , "table expected %s field %s", #_type, _field ); \
	}\
	lua_pop( L , 1 );


#define GET_OPT_FIELD( _field, _type, _var, _defvalue ) \
	_type _var = _defvalue;\
	lua_getfield(L, -1, _field);\
	LUA_GetValue( L , -1, _var );\
	lua_pop( L , 1 );


/// Creates a getter
# define BINDINGS_GETTER( _objectType, _VarName, _VarType, _pushAs )\
	static int Get##_VarName##B( lua_State * L ) { \
		DECLARE_ARGS_OK; \
		GET_OBJECT( _objectType *, _obj_ ); \
		if(ARGS_OK) \
		{\
			_VarType _var_ = _obj_->Get##_VarName();\
			lua_push##_pushAs(L, _var_);\
			return 1;\
		}\
		return 0;\
	}

#define BINDINGS_GETTER_ENUM( _objectType, _VarName, _enum_info ) \
	static int Get##_VarName##B( lua_State * L ) { \
		DECLARE_ARGS_OK; \
		GET_OBJECT( _objectType *, _obj_ ); \
		if(ARGS_OK) \
		{\
			LUA_PushEnum( L, &_enum_info , _obj_->Get##_VarName() );\
			return 1;\
		}\
		return 0;\
	}	

/// Creates a setter
#define BINDINGS_SETTER_ENUM(_objectType, _varName, _enum ) \
	static int Set##_varName##B( lua_State *L ) { \
		DECLARE_ARGS_OK; \
		GET_OBJECT( _objectType *, _obj_ ); \
		const int * piValue = LUA_GetEnum( L, 2 );\
		if ( (ARGS_OK) && piValue!=NULL ) \
		{ \
			_obj_->Set##_varName( ( _enum ) *piValue ); \
		} \
		return 0; \
	}

#define BINDINGS_SETTER(_objectType, _varName, _VarType ) \
	static int Set##_varName##B( lua_State *L ) { \
		DECLARE_ARGS_OK; \
		GET_OBJECT( _objectType *, _obj_ ); \
		GET_ARG( 2, _VarType, _var_ ); \
		if ( ARGS_OK ) \
		{ \
			_obj_->Set##_varName( _var_ ); \
		} \
		return 0; \
	}

#define BINDINGS_FUNCCALL( _objectType, _func ) \
	static int _func##B( lua_State * L ) { \
		DECLARE_ARGS_OK;\
		GET_OBJECT( _objectType *, _obj_ );\
		if ( ARGS_OK ) \
		{\
			_obj_->_func();\
		}\
		return 0;\
	}

#define BINDINGS_FUNCCALL_1_RET( _objectType, _func, _retType, _pushAs ) \
	static int _func##B( lua_State * L ) { \
		DECLARE_ARGS_OK;\
		GET_OBJECT( _objectType *, _obj_ );\
		if ( ARGS_OK ) \
		{\
			_retType var = _obj_->_func();\
			lua_push##_pushAs(L, var);\
			return 1;\
		}\
		return 0;\
	}

void CreateVector3 (lua_State * L, const VECTOR & v, int opt = 0);

#endif // LUA_LIB_EX_H