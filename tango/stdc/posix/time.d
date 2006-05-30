/*
 * Written by Sean Kelly
 * Placed into Public Domain
 */

module tango.stdc.posix.time;

private import tango.stdc.config;
public import tango.stdc.time;
public import tango.stdc.posix.sys.types;
public import tango.stdc.posix.signal; // for sigevent

extern (C):

//
// Defined in tango.stdc.time
//
/*
char* asctime(tm*);
clock_t clock();
char* ctime(time_t*);
double difftime(time_t, time_t);
tm* gmtime(time_t*);
tm* localtime(time_t*);
time_t mktime(tm*);
size_t strftime(char*, size_t, char*, tm*);
time_t time(time_t*);
*/

//
// C Extension (CX)
// (defined in tango.stdc.time)
//
/*
char* tzname[];
void tzset();
*/

//
// Process CPU-Time Clocks (CPT)
//
/*
int clock_getcpuclockid(pid_t, clockid_t*);
*/

//
// Clock Selection (CS)
//
/*
int clock_nanosleep(clockid_t, int, timespec*, timespec*);
*/

//
// Monotonic Clock (MON)
//
/*
CLOCK_MONOTONIC
*/

//
// Timer (TMR)
//
/*
CLOCK_PROCESS_CPUTIME_ID (TMR|CPT)
CLOCK_THREAD_CPUTIME_ID (TMR|TCT)

struct timespec
{
    time_t  tv_sec;
    int     tv_nsec;
}

struct itimerspec
{
    timespec it_interval;
    timespec it_value;
}

CLOCK_REALTIME
TIMER_ABSTIME

clockid_t
timer_t

int clock_getres(clockid_t, timespec*);
int clock_gettime(clockid_t, timespec*);
int clock_settime(clockid_t, timespec*);
int nanosleep(timespec*, timespec*);
int timer_create(clockid_t, sigevent*, timer_t*);
int timer_delete(timer_t);
int timer_gettime(timer_t, itimerspec*);
int timer_getoverrun(timer_t);
int timer_settime(timer_t, int, itimerspec*, itimerspec*);
*/

version( linux )
{
    const auto CLOCK_PROCESS_CPUTIME_ID = 2; // (TMR|CPT)
    const auto CLOCK_THREAD_CPUTIME_ID  = 3; // (TMR|TCT)

    struct timespec
    {
        time_t  tv_sec;
        c_long  tv_nsec;
    }

    struct itimerspec
    {
        timespec it_interval;
        timespec it_value;
    }

    const auto CLOCK_REALTIME   = 0;
    const auto TIMER_ABSTIME    = 0x01;

    alias int clockid_t;
    alias int timer_t;

    int clock_getres(clockid_t, timespec*);
    int clock_gettime(clockid_t, timespec*);
    int clock_settime(clockid_t, timespec*);
    int nanosleep(timespec*, timespec*);
    int timer_create(clockid_t, sigevent*, timer_t*);
    int timer_delete(timer_t);
    int timer_gettime(timer_t, itimerspec*);
    int timer_getoverrun(timer_t);
    int timer_settime(timer_t, int, itimerspec*, itimerspec*);
}
else version( darwin )
{
    struct timespec
    {
        time_t  tv_sec;
        long    tv_nsec;
    }

    int nanosleep(timespec*, timespec*);
}


//
// Thread-Safe Functions (TSF)
//
/*
char* asctime_r(tm*, char*);
char* ctime_r(time_t*, char*);
tm* gmtime_r(time_t*, tm*);
tm* localtime_r(time_t*, tm*);
*/

//
// XOpen (XSI)
//
/*
getdate_err

int daylight;
int timezone;

tm* getdate(char*);
char* strptime(char*, char*, tm*);
*/

version( darwin )
{
    tm*   getdate(char *);
    char* strptime(char*, char*, tm*);
}