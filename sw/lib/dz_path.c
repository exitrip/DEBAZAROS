/* dz_path.c - program and web folder lookup (see dz_path.h) */
#include "dz_path.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#define N_PROGS	16

static struct { char name[32], path[160]; } progs[N_PROGS];

static int found(char *out, size_t cap, const char *dir, const char *name)
{
	if (!dir || !*dir)
		return 0;
	snprintf(out, cap, "%s/%s", dir, name);
	return access(out, X_OK) == 0;
}

const char *dz_prog(const char *name)
{
	int i;

	for (i = 0; i < N_PROGS && progs[i].name[0]; i++)
		if (!strcmp(progs[i].name, name))
			return progs[i].path;
	if (i == N_PROGS)
		i = N_PROGS - 1;		/* full: reuse the last entry */
	snprintf(progs[i].name, sizeof(progs[i].name), "%s", name);
	if (!found(progs[i].path, sizeof(progs[i].path), getenv("DZ_BIN"), name) &&
	    !found(progs[i].path, sizeof(progs[i].path), DZ_DEV_BIN, name) &&
	    !found(progs[i].path, sizeof(progs[i].path), DZ_IMG_BIN, name))
		snprintf(progs[i].path, sizeof(progs[i].path), "%s", name);
	return progs[i].path;
}

const char *dz_www_dir(void)
{
	return access(DZ_DEV_WWW "/index.html", R_OK) == 0 ? DZ_DEV_WWW : DZ_IMG_WWW;
}
