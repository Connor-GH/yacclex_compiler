#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include "node.h"
#include "parser.h"

extern int yyparse(FILE *);
extern FILE *yyin;
enum {
	oflag = 1,
	wflag = 2,
};

static void usage(const char *progname) {
	fprintf(stderr, "usage: %s -o [output] [FILE]\n", progname);
	exit(1);
}
int main(int argc, char **argv) {
	char c;
	char *output_filename = NULL;
	while ((c = getopt(argc, argv, "o:w")) != -1) {
		switch (c) {
		case 'o':
			output_filename = optarg;
			break;
		case 'w':
			break;
		default:
			break;
		}
	}
	argc -= optind;
	argv += optind;
	if (output_filename == NULL) {
		argc -= optind;
		argv -= optind;
		usage(argv[0]);
	}
	FILE *fp = fopen(argv[0], "r");
	if (fp == NULL) {
		perror("fopen");
		exit(EXIT_FAILURE);
	}
	yyin = fp;
	if (yyparse(fp) == 0) {
	}
	fclose(fp);


	return 0;
}
