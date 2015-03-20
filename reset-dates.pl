#!/usr/bin/perl

use strict;
use warnings;

our $VERSION = 0.1;

use Data::Dumper;
use Date::Manip;
use Getopt::Long qw(GetOptions);
use File::Basename;

sub usage
{
	my $self = basename($0);

	printf "\n";
	printf "Usage:\n";
	printf "    $self [OPTIONS] {repos}\n";
	printf "\n";
	printf "    -o,--other [git|now|DATE]\n";
	printf "    Set non-git files to:\n";
	printf "        git  - the date of the last commit\n";
	printf "        now  - the date/time now\n";
	printf "        DATE - this specified date\n";
	printf "\n";
	printf "    -h,--help     show this help\n";
	printf "    -v,--verbose  list actions taken\n";
	printf "\n";
	printf "If --other is not specfied, only git repo files will be touched\n";
	printf "If you don't specify a repo, it will look in the current directory\n";
	printf "\n";
}

sub valid_other
{
	my ($str) = @_;

	if ((${$str} eq '') || (${$str} eq 'git')) {
		return 1;
	}

	my $date = ParseDate (${$str});
	if (!$date) {
		printf "Invalid date: '$str'\n";
		return 0;
	}

	${$str} = $date;
	return 1;
}

sub main
{
	Getopt::Long::Configure qw(gnu_getopt);

	my $other   = '';
	my $verbose = 0;
	my $help    = 0;

	GetOptions(
		'other|o=s'  => \$other,
		'verbose|v!' => \$verbose,
		'help|h!'    => \$help,
	) or die usage();

	if ($help) {
		die usage();
	}

	if (!valid_other (\$other)) {
		die usage();
	}

	print Dumper $other;
	print Dumper $verbose;

	print Dumper \@ARGV;

	foreach my $repo (@ARGV) {
		printf "Repo: $repo\n";
	}
}


main();

