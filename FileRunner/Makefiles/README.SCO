
How to build on SCO OpenServer 5.0
----------------------------------

For SCO OpenServer I have not fixed specific changes in the ext.c file
since it was getting too complicated already with the zillion
implementations of the statfs() call. Anyway, here is a description
for changes you need for this platform (thanks to Daniel Cox):

1. Start with Makefile.solaris2_cc
2. Add -lc to the Makefile
3. Change include <sys/statvfs.h> to <sys/statfs.h>
4. change all calls statvfs to statfs
5. change all f_bavail to f_bfree

