/*
 *  StringUtil.c
 *  quickchm
 *
 *  Created by Qian Qian on 6/29/08.
 *  Copyright 2008 __MyCompanyName__. All rights reserved.
 *
 */

#include "StringUtil.h"


char *concateString(const char *s1, const char *s2) {
	char *s = calloc(strlen(s1) + strlen(s2) + 1, sizeof(char));
	strcpy((char *)s, (char *)s1);
	strcat((char *)s, (char *)s2);
	return s;
}