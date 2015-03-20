#!/usr/bin/perl

use strict;
use warnings;

our $VERSION = 0.1;

use Data::Dumper;

use Getopt::Long qw(GetOptions);
use File::Basename;

sub usage
{
	my $self = basename($0);

	printf "\n";
	printf "Usage:\n";
	printf "    $self [OPTIONS] {repos}\n";
	printf "\n";
	printf "    -v,--verbose           list actions taken\n";
	printf "\n";
	printf "    -g,--other-git-latest  set non-git files to latest git commit date\n";
	printf "    -n,--other-now         set non-git files to the time now\n";
	printf "    -d,--other-date DATE   set non-git files to this date\n";
	printf "\n";
	printf "With no options, only git repo files will be touched\n";
	printf "If you don't specify a repo, it will look in the current directory\n";
	printf "It only makes sense to use one of the 'other' options at one time\n";
	printf "\n";
}

sub main
{
	Getopt::Long::Configure qw(gnu_getopt);

	my $opt_other;
	my $opt_verbose = 0;
	# my $repos = ();

	GetOptions(
		'other|o=s'  => $opt_other,
		'verbose|v!' => $opt_verbose,
	) or die usage();

	print Dumper ($opt_other);
	print Dumper ($opt_verbose);
}


main();

