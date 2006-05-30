/*
 * Written by Sean Kelly
 * Placed into Public Domain
 */

module tango.stdc.fenv;

extern (C):

version( Win32 )
{
    struct fenv_t
    {
        ushort status;
        ushort control;
        ushort round;
        ushort reserved[2];
    }
}
else version( linux )
{
    struct fenv_t
    {
    	ushort __control_word;
    	ushort __unused1;
    	ushort __status_word;
    	ushort __unused2;
    	ushort __tags;
    	ushort __unused3;
    	uint   __eip;
    	ushort __cs_selector;
    	ushort __opcode;
    	uint   __data_offset;
    	ushort __data_selector;
    	ushort __unused5;
    }
}
else
{
    static assert( false );
}

alias int fexcept_t;

enum
{
    FE_INVALID      = 1,
    FE_DENORMAL     = 2, // non-standard
    FE_DIVBYZERO    = 4,
    FE_OVERFLOW     = 8,
    FE_UNDERFLOW    = 0x10,
    FE_INEXACT      = 0x20,
    FE_ALL_EXCEPT   = 0x3F,
    FE_TONEAREST    = 0,
    FE_UPWARD       = 0x800,
    FE_DOWNWARD     = 0x400,
    FE_TOWARDZERO   = 0xC00,
}

version( Win32 )
{
    private extern fenv_t _FE_DFL_ENV;
    fenv_t* FE_DFL_ENV = &_FE_DFL_ENV;
}
else version( linux )
{
    fenv_t* FE_DFL_ENV = cast(fenv_t*)(-1);
}
else
{
    static assert( false );
}

void feraiseexcept(int excepts);
void feclearexcept(int excepts);

int fetestexcept(int excepts);
int feholdexcept(fenv_t* envp);

void fegetexceptflag(fexcept_t* flagp, int excepts);
void fesetexceptflag(fexcept_t* flagp, int excepts);

int fegetround();
int fesetround(int round);

void fegetenv(fenv_t* envp);
void fesetenv(fenv_t* envp);
void feupdateenv(fenv_t* envp);