/* FILE dll.h */
#ifdef BUILD_DLL
    #ifdef _WIN32
/* DLL export */
        #define EXPORT __declspec(dllexport)
    #else
        #define EXPORT __attribute__((visibility("default")))
    #endif
#else
    #ifdef _WIN32
    /* EXE import */
        #define EXPORT __declspec(dllimport)
    #else
        #define EXPORT
    #endif
#endif
