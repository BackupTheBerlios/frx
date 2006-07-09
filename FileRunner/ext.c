// $Id: ext.c,v 1.1 2006/07/09 10:10:01 butz Exp $


#include <time.h>
#include <stdlib.h>
#include <stdio.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <errno.h>
#include <fcntl.h>
#include <string.h>
#include <limits.h>

#ifdef WIN32
#include <winsock.h>
#else
#include <unistd.h>
#include <pwd.h>
#include <grp.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#include <sys/utsname.h>
#include <arpa/inet.h>
#include <sys/time.h>
#endif

#ifdef IRIX
#include <bstring.h>
#include <sys/statfs.h>
#endif

#ifdef AIX
#include <sys/select.h>
#include <sys/statfs.h>
#endif

#include "tk.h"

#define HANDLE(exp, blame) if (exp) { \
  sprintf(interp->result, "%s. Error code : %d", blame, errno); \
  return TCL_ERROR; \
}

#define HANDLE2(exp, blame) if (exp) { \
  sprintf(interp->result, "%s.", blame); \
  return TCL_ERROR; \
}

#define BUFFERSIZE (1024*64)
#define min(a,b) ((a) < (b) ? (a) : (b))
#define max(a,b) ((a) > (b) ? (a) : (b))

static int GetTimeFromSecs(ClientData clientData, Tcl_Interp* interp, 
                           int argc, char* argv[]);
static int GetTimeFromSecsSetFormat(ClientData clientData, Tcl_Interp* interp, 
                           int argc, char* argv[]);
static int GetStringFromMode(ClientData clientData, Tcl_Interp* interp, 
                           int argc, char* argv[]);
static int GetUidGidString(ClientData clientData, Tcl_Interp* interp, 
                           int argc, char* argv[]);
static int FTP_CreateServerSocket(ClientData clientData, Tcl_Interp* interp, 
                           int argc, char* argv[]);
static int FTP_AcceptConnect(ClientData clientData, Tcl_Interp* interp, 
                           int argc, char* argv[]);
static int FTP_Socket(ClientData clientData, Tcl_Interp* interp, 
                           int argc, char* argv[]);
static int FTP_Copy(ClientData clientData, Tcl_Interp* interp, 
                           int argc, char* argv[]);
static int FTP_Close(ClientData clientData, Tcl_Interp* interp, 
                           int argc, char* argv[]);
static int FTP_OpenFile(ClientData clientData, Tcl_Interp* interp, 
                           int argc, char* argv[]);
static int FTP_ReadText(ClientData clientData, Tcl_Interp* interp, 
                           int argc, char* argv[]);
static int FTP_WriteText(ClientData clientData, Tcl_Interp* interp, 
                           int argc, char* argv[]);
static int GetDF(ClientData clientData, Tcl_Interp* interp, 
                           int argc, char* argv[]);
static int ClockMilliSeconds(ClientData clientData, Tcl_Interp* interp, 
                           int argc, char* argv[]);
static int GetEuid(ClientData clientData, Tcl_Interp* interp, 
                           int argc, char* argv[]);

static long int  ToNum(char* string);

static int dateformat;

#ifdef WIN32
_declspec(dllexport)
#endif
int
Ext_Init(interp)
    Tcl_Interp *interp;		/* Interpreter for application. */
{
    Tcl_CreateCommand(interp, "GetTimeFromSecs", GetTimeFromSecs, NULL, NULL);
    Tcl_CreateCommand(interp, "GetTimeFromSecsSetFormat", GetTimeFromSecsSetFormat, NULL, NULL);
    Tcl_CreateCommand(interp, "GetStringFromMode", GetStringFromMode, NULL, NULL);
    Tcl_CreateCommand(interp, "GetUidGidString", GetUidGidString, NULL, NULL);
    Tcl_CreateCommand(interp, "FTP_CreateServerSocket", FTP_CreateServerSocket, NULL, NULL);
    Tcl_CreateCommand(interp, "FTP_Socket", FTP_Socket, NULL, NULL);
    Tcl_CreateCommand(interp, "FTP_AcceptConnect", FTP_AcceptConnect, NULL, NULL);
    Tcl_CreateCommand(interp, "FTP_Copy", FTP_Copy, NULL, NULL);
    Tcl_CreateCommand(interp, "FTP_Close", FTP_Close, NULL, NULL);
    Tcl_CreateCommand(interp, "FTP_OpenFile", FTP_OpenFile, NULL, NULL);
    Tcl_CreateCommand(interp, "FTP_ReadText", FTP_ReadText, NULL, NULL);
    Tcl_CreateCommand(interp, "FTP_WriteText", FTP_WriteText, NULL, NULL);
    Tcl_CreateCommand(interp, "GetDF", GetDF, NULL, NULL);
    Tcl_CreateCommand(interp, "ClockMilliSeconds", ClockMilliSeconds, NULL, NULL);
    Tcl_CreateCommand(interp, "GetEuid", GetEuid, NULL, NULL);
    return TCL_OK;
}


static int 
GetTimeFromSecs(ClientData clientData, Tcl_Interp* interp, 
                           int argc, char* argv[])
{
  time_t t;
  char* p;
  struct tm* time_s;

  t = strtol(argv[1], &p, 0);
  HANDLE2(*p != '\0', "Error converting arg to int");

  time_s = localtime(&t);
  if (dateformat)
    sprintf(interp->result, "%02d%02d%02d %02d:%02d:%02d", time_s->tm_mday, time_s->tm_mon+1,
          time_s->tm_year % 100, time_s->tm_hour, time_s->tm_min, time_s->tm_sec);
  else
    sprintf(interp->result, "%02d%02d%02d %02d:%02d:%02d", time_s->tm_year % 100, time_s->tm_mon+1,
          time_s->tm_mday, time_s->tm_hour, time_s->tm_min, time_s->tm_sec);
  return TCL_OK;
}

static int 
GetTimeFromSecsSetFormat(ClientData clientData, Tcl_Interp* interp, 
                           int argc, char* argv[])
{
  HANDLE2(argc != 2, "Wrong # of args");

  dateformat = ToNum(argv[1]);
  return TCL_OK;
}


static int 
GetStringFromMode(ClientData clientData, Tcl_Interp* interp, 
                           int argc, char* argv[])
{
  char* p;
  int mode;

  HANDLE2(argc != 2, "Wrong # of args");

  mode = strtol(argv[1], &p, 0);
  HANDLE2(*p != '\0', "Error converting arg to int");

#ifdef WIN32
  sprintf(interp->result, "0x%x", mode);
#else
  sprintf(interp->result, "%c%c%c%c%c%c%c%c%c", 
    mode & S_IRUSR ? 'r' : '-',
    mode & S_IWUSR ? 'w' : '-',
    mode & S_ISUID ? 'S' : (mode & S_IXUSR ? 'x' : '-'),
    mode & S_IRGRP ? 'r' : '-',
    mode & S_IWGRP ? 'w' : '-',
    mode & S_ISGID ? 'S' : (mode & S_IXGRP ? 'x' : '-'),
    mode & S_IROTH ? 'r' : '-',
    mode & S_IWOTH ? 'w' : '-',
    mode & S_ISVTX ? 'T' : (mode & S_IXOTH ? 'x' : '-'));
#endif
  return TCL_OK;
}


static int 
GetUidGidString(ClientData clientData, Tcl_Interp* interp, 
                           int argc, char* argv[])
{
  char *p;
  struct passwd* pass;
  struct group* gidname;
  static char gidstring[100];
  static char uidstring[100];
  static int old_uid = -1, old_gid = -1;
  int uid, gid;

  HANDLE2(argc != 3, "Wrong # of args");

#ifdef WIN32
  sprintf(interp->result, "");
#else
  uid = strtol(argv[1], &p, 0);
  HANDLE2(*p != '\0', "Error converting arg to int");

  gid = strtol(argv[2], &p, 0);
  HANDLE2(*p != '\0', "Error converting arg to int");

  if (old_uid != uid) {
    old_uid = uid;
    pass = getpwuid(uid);
    if (pass) 
      sprintf(uidstring, "%s", pass->pw_name);
    else
      strcpy(uidstring, argv[1]);
  }
  if (old_gid != gid) {
    old_gid = gid;
    gidname = getgrgid(gid);
    if (gidname) 
      sprintf(gidstring, "%s", gidname->gr_name);
    else
      strcpy(gidstring, argv[2]);
  }

  sprintf(interp->result, "%s/%s",uidstring,gidstring);
#endif
  return TCL_OK;
}


/* FTP_CreateServerSocket localhost-IP -> returns ipnum,port sockfd ex: 127.0.0.1,1022 4 */
static int 
FTP_CreateServerSocket(ClientData clientData, Tcl_Interp* interp, 
                           int argc, char* argv[])
{
  int status, sock, length;
  struct sockaddr_in sockaddr;        /* Socket address */
  struct hostent *hostent;            /* Host database entry */
  struct in_addr addr;                /* For 64/32 bit madness */
  char* host;

  HANDLE2(argc != 2, "Wrong # of args");

  host = argv[1];

  memset((char *) &sockaddr, '\0', sizeof(struct sockaddr_in));
  sockaddr.sin_family = AF_INET;
  sockaddr.sin_port = htons(0);
  hostent = gethostbyname(host);
  if (hostent != NULL) {
    memcpy((char *) &addr,
      (char *) hostent->h_addr_list[0], (size_t) hostent->h_length);
  } else {
    addr.s_addr = inet_addr(host);
    HANDLE2(addr.s_addr == (unsigned long)-1, "Error in inet_addr()");
  }

  sockaddr.sin_addr.s_addr = addr.s_addr;

  sock = socket(AF_INET, SOCK_STREAM, 0);
  HANDLE(sock < 0, "Error in socket()");

  status = 1;
  setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, (char *) &status, sizeof(status));
  /* status ignored */

  status = bind(sock, (struct sockaddr *) &sockaddr, sizeof(struct sockaddr));
  HANDLE(status == -1, "Error in bind()");

  status = listen(sock, 5);
  HANDLE(status == -1, "Error in listen()");

  length = sizeof(sockaddr);
  status = getsockname(sock, (struct sockaddr *) &sockaddr, &length);
  HANDLE(status == -1, "Error in getsockname()");

  sprintf(interp->result, "%s,%u %u", inet_ntoa(addr), ntohs(sockaddr.sin_port), sock);

  return TCL_OK;
}

/* FTP_Socket host port -> return {socket-fd local-host}*/
static int 
FTP_Socket(ClientData clientData, Tcl_Interp* interp, 
                           int argc, char* argv[])
{
  struct sockaddr_in sockaddr;	/* Socket address */
  struct hostent *hostent;	/* Host database entry */
  struct in_addr addr;		/* For 64/32 bit madness */
  int sock;
  int port;
  char* host;
  int length;
  int status;

  HANDLE2(argc != 3, "Wrong # of args");

  port = ToNum(argv[2]);
  HANDLE2(port <= 0, "Error conv to number");

  host = argv[1];

  memset(&sockaddr, '\0', sizeof(struct sockaddr_in));
  sockaddr.sin_family = AF_INET;
  sockaddr.sin_port = htons((unsigned short) (port & 0xFFFF));
  hostent = gethostbyname(host);
  if (hostent != NULL) {
    memcpy((char *) &addr, (char *) hostent->h_addr_list[0], (size_t) hostent->h_length);
  } else {
    addr.s_addr = inet_addr(host);
    HANDLE2(addr.s_addr == (unsigned long)-1, "Error in inet_addr()");
  }

  sockaddr.sin_addr.s_addr = addr.s_addr;

  sock = socket(AF_INET, SOCK_STREAM, 0);
  HANDLE(sock < 0, "Error in socket()");

  status = connect(sock, (struct sockaddr *) &sockaddr, sizeof(sockaddr));
  HANDLE(status == -1, "Error in connect()");

  length = sizeof(sockaddr);
  status = getsockname(sock, (struct sockaddr *) &sockaddr, &length);
  HANDLE(status == -1, "Error in getsockname()");

  sprintf(interp->result, "%d %s", sock, inet_ntoa(sockaddr.sin_addr));

  return TCL_OK;
}

/* FTP_AcceptConnect server-fd -> return client fd */
static int 
FTP_AcceptConnect(ClientData clientData, Tcl_Interp* interp, 
                           int argc, char* argv[])
{
  int newsock, serversock;
  HANDLE2(argc != 2, "Wrong # of args");

  serversock = ToNum(argv[1]);
  HANDLE2(serversock <= 0, "Error conv to number");

  newsock = accept(serversock, NULL, NULL);
  HANDLE(newsock < 0, "Error in accept()");

#if 0
  low_watermark = BUFFERSIZE;
  status = setsockopt(newsock, SOL_SOCKET, SO_RCVLOWAT, (char *) &low_watermark, sizeof(int));
  HANDLE(status != 0, "Error in setsockopt");
#endif

  sprintf(interp->result, "%d", newsock);
  return TCL_OK;
}



/* FTP_ReadText fd timeout(sec) -> returns text */
static int 
FTP_ReadText(ClientData clientData, Tcl_Interp* interp, 
                           int argc, char* argv[])
{
  int fd;
  char c;
  int r, to, nb;
  struct timeval tv;
  int count = 0;
  fd_set read_template;

  HANDLE2(argc != 3, "Wrong # of args");

  fd = ToNum(argv[1]);
  HANDLE2(fd <= 0, "Error conv to number");

  to = ToNum(argv[2]);
  HANDLE2(to <= 0, "Error conv to number");

  while(1) {
    FD_ZERO(&read_template);
    FD_SET(fd, &read_template);
    tv.tv_sec = to;
    tv.tv_usec = 0;
    nb = select(FD_SETSIZE, &read_template, NULL, NULL, &tv);
    HANDLE(nb < 0, "Select error (reading)");
    HANDLE2(nb == 0, "Timeout when communicating with FTP server.");
    HANDLE2(!FD_ISSET(fd, &read_template), "Select returned wrong descriptor (reading)");
    r = read(fd, &c, 1); /* Ugly, I know, but I don't care ;-) */
    HANDLE(r == -1, "Error reading");
    if (r == 0) break;
    if (c != '\r')
      interp->result[count++] = c;
    if (c == '\n' || count >= (TCL_RESULT_SIZE-1)) break;
  }
  interp->result[count++] = '\0';

  return TCL_OK;
}

/* FTP_WriteText fd text */
static int 
FTP_WriteText(ClientData clientData, Tcl_Interp* interp, 
                           int argc, char* argv[])
{
  int fd;
  int r;
  int count = 0;

  HANDLE2(argc != 3, "Wrong # of args");
  fd = ToNum(argv[1]);
  HANDLE2(fd <= 0, "Error conv to number");

  count = strlen(argv[2]);
  r = write(fd, argv[2], count);
  HANDLE(r != count, "Write error");

  return TCL_OK;
}


/* FTP_OpenFile file mode(r or w) */
static int 
FTP_OpenFile(ClientData clientData, Tcl_Interp* interp, 
                           int argc, char* argv[])
{
  int fd;

  HANDLE2(argc != 3, "Wrong # of args");

  if (argv[2][0] == 'w') {
    if (argv[2][1] == '+') {
      fd = open(argv[1], O_CREAT|O_WRONLY|O_APPEND, 0666);
    } else {
      fd = open(argv[1], O_CREAT|O_WRONLY|O_TRUNC, 0666);
    }
  } else {
    fd = open(argv[1], O_RDONLY);
  }
  HANDLE(fd < 0, "Can't open file");

  sprintf(interp->result, "%d", fd);
  return TCL_OK;
}

/* FTP_Close fd */
static int 
FTP_Close(ClientData clientData, Tcl_Interp* interp, 
                           int argc, char* argv[])
{
  int fd;
  int r;

  HANDLE2(argc != 2, "Wrong # of args");

  fd = ToNum(argv[1]);
  HANDLE2(fd <= 0, "Error conv to number");

  shutdown(fd, 2); /* I don't care if this is a file... */
  r = close(fd);
  HANDLE(r != 0, "Error closing file");

  return TCL_OK;
}

/* FTP_Copy fdfrom fdto maxsize timeout (secs)-> returns actualsize */
static int 
FTP_Copy(ClientData clientData, Tcl_Interp* interp, 
                           int argc, char* argv[])
{
  static char buffer[BUFFERSIZE];
  int fdfrom, fdto, maxsize;
  int count = 0;
  int r, w, s;
  int size;
  struct timeval tv;
  int to, nb;
  fd_set read_template;

  HANDLE2(argc != 5, "Wrong # of args");

  fdfrom = ToNum(argv[1]);
  HANDLE2(fdfrom <= 0, "Error conv to number");

  fdto = ToNum(argv[2]);
  HANDLE2(fdto <= 0, "Error conv to number");

  if (!strcmp(argv[3],"-1")) {
    maxsize = -1;
  } else {  
    maxsize = ToNum(argv[3]);
    HANDLE2(maxsize <= 0, "Error conv to number");
  }

  to = ToNum(argv[4]);
  HANDLE2(to <= 0, "Error conv to number");

  /*printf("maxsize %d\n", maxsize);*/

  while (1) {
    if (maxsize == -1)
      size = BUFFERSIZE;
    else
      size = min(BUFFERSIZE, maxsize-count);
    /*printf("size %d\n", size);*/
    r = 0;
    while (1) {

      FD_ZERO(&read_template);
      FD_SET(fdfrom, &read_template);
      tv.tv_sec = to;
      tv.tv_usec = 0;
      nb = select(FD_SETSIZE, &read_template, NULL, NULL, &tv);
      HANDLE(nb < 0, "Select error (reading)");
      HANDLE2(nb == 0, "Timeout when communicating with FTP server.");
      HANDLE2(!FD_ISSET(fdfrom, &read_template), "Select returned wrong descriptor (reading)");
      s = read(fdfrom, buffer+r, size-r);
      /*printf("r %d s %d\n", r, s);*/
      HANDLE(s == -1, "Error reading");
      r += s;
      if ((s == 0) || (r == size)) break;
    }
    /*printf("r %d s %d\n", r, s);*/
    if (r == 0) break;
    w = write(fdto, buffer, r);
    HANDLE(w != r, "Error writing");
    count += r;
    if (s == 0) break;
    if (count == maxsize) break;    
  }
  sprintf(interp->result, "%d", count);
  return TCL_OK;
}


static long int 
ToNum(char* string) {
  char *p;
  long int i;
  i = strtol(string, &p, 0);
  if (p == string) i = -1;
  return i;
}

/* ClockMilliSeconds -> return milliseconds since startup */
static int 
ClockMilliSeconds(ClientData clientData, Tcl_Interp* interp, 
                           int argc, char* argv[])
{
#ifdef WIN32
  sprintf(interp->result, "%f", 0.0);
  return TCL_OK;
#else
  struct timeval date;
  struct timezone tz;
  double t;
  
  HANDLE2(argc != 1, "Wrong # of args");

  gettimeofday(&date,&tz);

  t = (double)date.tv_sec * 1000.0 + (double)date.tv_usec / 1000.0;

  sprintf(interp->result, "%f", t);
  return TCL_OK;
#endif
}

/* GetEuid -> return effective user ID */
static int 
GetEuid(ClientData clientData, Tcl_Interp* interp, 
                           int argc, char* argv[])
{
  HANDLE2(argc != 1, "Wrong # of args");

#ifdef WIN32
  sprintf(interp->result, "%d", 1); /* Anything not zero... */
#else
  sprintf(interp->result, "%d", geteuid());
#endif
  return TCL_OK;
}


#ifdef SVR4

#include <sys/statvfs.h>

/* GetDF path -> returns free bytes in MB in path */
static int 
GetDF(ClientData clientData, Tcl_Interp* interp, 
                           int argc, char* argv[])
{
  int i;
  struct statvfs stat;
  double b, x;
  char tmp[5];
  HANDLE2(argc != 2, "Wrong # of args");

  i = statvfs(argv[1], &stat);
  if (i) 
  {
    strcpy(interp->result, "?");
    return TCL_OK;
  }
  
  /*printf("dir %s avail %d bsize %d\n", argv[1], stat.f_bavail, stat.f_frsize);*/
  b = (double)stat.f_bavail * (double)stat.f_frsize;
  if (b < 1024) {
    x = b;
    strcpy(tmp, "");
  } else if (b >= 1024*1024*1024) {
    x = b / (1024*1024*1024.0);
    strcpy(tmp, "G");
  } else if (b >= 1024*1024) {
    x = b / (1024*1024.0);
    strcpy(tmp, "M");
  } else {
    x = b / (1024.0);
    strcpy(tmp, "k");
  }
  
  if (x < 10 && (tmp[0]))
    sprintf(interp->result, "%.1f%s", x, tmp);
  else
    sprintf(interp->result, "%d%s", (int)x, tmp);

  return TCL_OK;
}

#else

#ifdef WIN32

/* GetDF path -> returns free bytes in MB in path */
static int 
GetDF(ClientData clientData, Tcl_Interp* interp, 
                           int argc, char* argv[])
{
  int i;
  double b, x;
  char tmp[5];
  HANDLE2(argc != 2, "Wrong # of args");

  sprintf(interp->result, "?MB");

  return TCL_OK;
}

#else

#ifdef OSF
#  include <sys/mount.h>
#else
#  ifdef __FreeBSD__
#    include <sys/param.h>
#    include <sys/mount.h>
#  else
#    include <sys/param.h>
#    include <sys/mount.h>
//#    include <sys/vfs.h>
#  endif
#endif

/* GetDF path -> returns free bytes in MB in path */
static int 
GetDF(ClientData clientData, Tcl_Interp* interp, 
                           int argc, char* argv[])
{
  int i;
  struct statfs stat;
  double b, x;
  char tmp[5];
  HANDLE2(argc != 2, "Wrong # of args");

#ifdef IRIX
  i = statfs(argv[1], &stat, sizeof(stat), 0);
#else
  i = statfs(argv[1], &stat);
#endif
  if (i) 
  {
    strcpy(interp->result, "?");
    return TCL_OK;
  }

#ifdef IRIX
  b = (double)stat.f_bfree * (double)stat.f_bsize;
#else
  b = (double)stat.f_bavail * (double)stat.f_bsize;
#endif
  if (b < 1024) {
    x = b;
    strcpy(tmp, "");
  } else if (b >= 1024*1024*1024) {
    x = b / (1024*1024*1024.0);
    strcpy(tmp, "G");
  } else if (b >= 1024*1024) {
    x = b / (1024*1024.0);
    strcpy(tmp, "M");
  } else {
    x = b / (1024.0);
    strcpy(tmp, "k");
  }
  
  if (x < 10 && (tmp[0]))
    sprintf(interp->result, "%.1f%s", x, tmp);
  else
    sprintf(interp->result, "%d%s", (int)x, tmp);

  return TCL_OK;
}

#endif

#endif
