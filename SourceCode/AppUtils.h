#ifndef APP_UTILS_H
#define APP_UTILS_H

/// @return The size of the array
template<typename T, int count> int ArrayN (T (&arr)[count])
{
	return count;
}

/// @return The element at the object's offset
template<typename R> R * AtOffset (void * object, int offset)
{
	return (R *)(((char *)object) + offset);
}

/// Helper for binding associated strings
struct AssocPair {
	const char * mK;///< Key part of pair
	const char * mV;///< Value part of pair
};

/// Helper to construct an AssocPair with a value named the same as the key string
#define ASSOC_PAIR(name) { #name, name }

/// Declares and iterates over an array
#define DO_ARRAY(type, name, var, ...)			\
	type name[] = { __VA_ARGS__ };				\
												\
	for (int var = 0; var < ArrayN(name); ++var)

/// Variant of DO_ARRAY that adds a post-condition to each iteration
#define DO_ARRAY_EX(type, name, var, post, ...)			\
	type name[] = { __VA_ARGS__ };						\
														\
	for (int var = 0; var < ArrayN(name); ++var, post)

/// DO_ARRAY with type = const char *
#define DO_STR_ARRAY(name, var, ...) DO_ARRAY(const char *, name, var, __VA_ARGS__)

/// DO_ARRAY_EX with type = const char *
#define DO_STR_ARRAY_EX(name, var, post, ...) DO_ARRAY_EX(const char *, name, var, post, __VA_ARGS__)

/// DO_ARRAY with type = int
#define DO_INT_ARRAY(name, var, ...) DO_ARRAY(int, name, var, __VA_ARGS__)

/// DO_ARRAY_EX with type = int
#define DO_INT_ARRAY_EX(name, var, post, ...) DO_ARRAY_EX(int, name, var, post, __VA_ARGS__)

#endif // APP_UTILS_H