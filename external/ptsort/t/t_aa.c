/*-
 * Copyright (c) 2016-2024 Dag-Erling Smørgrav
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. The name of the author may not be used to endorse or promote
 *    products derived from this software without specific prior written
 *    permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#if HAVE_CONFIG_H
#include "config.h"
#endif

#include <stdint.h>
#include <string.h>

#include <cryb/test.h>

#include "aa_tree.h"

static struct t_aa_case {
	const char	*desc;
	int		 n;
	int		 i[16];
	int		 o[16];
} t_aa_cases[] = {
	/* trivial cases */
	{
		.desc	 = "empty",
		.n	 = 0,
		.i	 = { },
		.o	 = { },
	},
	{
		.desc	 = "single",
		.n	 = 1,
		.i	 = { 1 },
		.o	 = { 1 },
	},
	/* seven basic shapes */
	{
		.desc	 = "right",
		.n	 = 2,
		.i	 = { 1, 2 },
		.o	 = { 1, 2 },
	},
	{
		.desc	 = "left",
		.n	 = 2,
		.i	 = { 2, 1 },
		.o	 = { 1, 2 },
	},
	{
		.desc	 = "both",
		.n	 = 3,
		.i	 = { 2, 1, 3 },
		.o	 = { 1, 2, 3 },
	},
	{
		.desc	 = "right dogleg",
		.n	 = 3,
		.i	 = { 1, 3, 2 },
		.o	 = { 1, 2, 3 },
	},
	{
		.desc	 = "left dogleg",
		.n	 = 3,
		.i	 = { 3, 1, 2 },
		.o	 = { 1, 2, 3 },
	},
	{
		.desc	 = "left-left",
		.n	 = 3,
		.i	 = { 3, 2, 1 },
		.o	 = { 1, 2, 3 },
	},
	{
		.desc	 = "right-right",
		.n	 = 3,
		.i	 = { 1, 2, 3 },
		.o	 = { 1, 2, 3 },
	},
};

static int num_s[] = {
	 1,  2,  3,  4,
	 5,  6,  7,  8,
	 9, 10, 11, 12,
	13, 14, 15, 16,
};

static int num_u[] = {
	 1, 16,  6,  5,
	 2, 15,  8,  7,
	 3, 14, 10,  9,
	 4, 13, 12, 11,
};

static int t_aa_comparisons;

static int
t_aa_compare_i(const void *a, const void *b)
{

	t_aa_comparisons++;
	return (*(const int *)a - *(const int *)b);
}

static int
t_aa_test(char **desc CRYB_UNUSED, void *arg)
{
	struct t_aa_case *tc = arg;
	aa_tree t;
	aa_iterator *it;
	int *e;
	int i, ret;

	aa_init(&t, t_aa_compare_i);
	ret = t_compare_u(0, t.size);
	for (i = 0; i < tc->n; ++i)
		ret &= t_compare_ptr(&tc->i[i], aa_insert(&t, &tc->i[i]));
	ret &= t_compare_u(tc->n, t.size);
	e = aa_first(&t, &it);
	if (tc->n == 0)
		ret &= t_is_null(e);
	else
		ret &= t_compare_i(tc->o[0], *(int *)e);
	for (i = 1; i < tc->n; ++i)
		ret &= t_compare_i(tc->o[i], *(int *)aa_next(&it));
	ret &= t_is_null(aa_next(&it));
	aa_finish(&it);
	aa_destroy(&t);
	return (ret);
}

static int
t_aa_find(char **desc CRYB_UNUSED, void *arg CRYB_UNUSED)
{
	aa_tree t;
	unsigned int i;
	int ret;

	ret = 1;
	aa_init(&t, t_aa_compare_i);
	for (i = 0; i < sizeof num_u / sizeof num_u[0]; ++i)
		ret &= t_compare_ptr(&num_u[i], aa_insert(&t, &num_u[i]));
	for (i = 0; i < sizeof num_u / sizeof num_u[0]; ++i)
		ret &= t_compare_ptr(&num_u[i], aa_find(&t, &num_u[i]));
	for (i = 0; i < sizeof num_s / sizeof num_s[0]; ++i)
		ret &= t_compare_mem(&num_s[i], aa_find(&t, &num_s[i]), sizeof(int));
	aa_destroy(&t);
	return (ret);
}

static int
t_aa_next(char **desc CRYB_UNUSED, void *arg CRYB_UNUSED)
{
	aa_tree t;
	aa_iterator *iter;
	unsigned int i, n;
	int ret;

	ret = 1;
	n = sizeof num_u / sizeof num_u[0];
	aa_init(&t, t_aa_compare_i);
	for (i = 0; i < n; ++i)
		ret &= t_compare_ptr(&num_u[i], aa_insert(&t, &num_u[i]));
	ret &= t_compare_u(n, t.size);
	ret &= t_compare_mem(&num_s[0], aa_first(&t, &iter), sizeof(int));
	for (i = 1; i < n; ++i)
		ret &= t_compare_mem(&num_s[i], aa_next(&iter), sizeof(int));
	ret &= t_is_null(aa_next(&iter));
	aa_finish(&iter);
	aa_destroy(&t);
	ret &= t_compare_u(0, t.size);
	return (ret);
}

static int
t_aa_destroy(char **desc CRYB_UNUSED, void *arg CRYB_UNUSED)
{
	aa_tree t;
	unsigned int i, n;
	int ret;

	ret = 1;
	n = sizeof num_u / sizeof num_u[0];
	aa_init(&t, t_aa_compare_i);
	for (i = 0; i < n; ++i)
		ret &= t_compare_ptr(&num_u[i], aa_insert(&t, &num_u[i]));
	ret &= t_compare_u(n, t.size);
	t_aa_comparisons = 0;
	aa_destroy(&t);
	ret &= t_compare_u(0, t_aa_comparisons);
	return (ret);
}

static int
t_prepare(int argc CRYB_UNUSED, char *argv[] CRYB_UNUSED)
{
	unsigned int i;

	for (i = 0; i < sizeof t_aa_cases / sizeof t_aa_cases[0]; ++i)
		t_add_test(t_aa_test, &t_aa_cases[i], "%s", t_aa_cases[i].desc);
	t_add_test(t_aa_find, NULL, "aa_find()");
	t_add_test(t_aa_next, NULL, "aa_next()");
	t_add_test(t_aa_destroy, NULL, "aa_destroy()");
	return (0);
}

int
main(int argc, char *argv[])
{

	t_main(t_prepare, NULL, argc, argv);
}
