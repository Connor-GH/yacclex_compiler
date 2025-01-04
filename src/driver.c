#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include "node.h"
#include "parser.h"

static const char *currently_being_parsed_filename;
extern int yyparse(FILE *);
extern FILE *yyin;
enum {
	oflag = 1,
	wflag = 2,
};

const char *
make_line_string_from_file(size_t lineno)
{
	FILE *fp = fopen(currently_being_parsed_filename, "r");
	if (fp == NULL) {
		perror("fopen");
		exit(EXIT_FAILURE);
	}

	char *line = malloc(4096);
	size_t current_line = 0;

	while (fgets(line, 4096, fp) != NULL) {
		current_line++;
		if (current_line == lineno) {
			fclose(fp);
			return line;
		}
	}
	fclose(fp);
	free(line);
	return NULL;

}

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
	currently_being_parsed_filename = argv[0];
	yyin = fp;
	if (yyparse(fp) == 0) {
	}
	fclose(fp);


	return 0;
}
