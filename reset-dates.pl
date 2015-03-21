#!/usr/bin/perl

use strict;
use warnings;

our $VERSION = 0.1;

use Data::Dumper;
use Date::Manip::Date; #XXX
use DateTime::Format::ISO8601;
use Getopt::Long qw(GetOptions);
use File::Basename;
use Cwd;
use English qw(-no_match_vars);
use IPC::Open3;
use Carp;
use File::Touch;

sub usage
{
	my $self = basename ($PROGRAM_NAME);

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
	return;
}

sub valid_other
{
	my ($str) = @_;

	if ((${$str} eq q{}) || (${$str} eq 'git')) {
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

sub parse_options
{
	Getopt::Long::Configure qw(gnu_getopt);

	my $other   = q{};
	my $verbose = 0;
	my $help    = 0;

	my %opts = (
		error => 1,
	);

	GetOptions (
		'other|o=s'  => \$other,
		'verbose|v!' => \$verbose,
		'help|h!'    => \$help,
	) or return \%opts;

	if ($help) {
		return \%opts;
	}

	if (!valid_other (\$other)) {
		$opts{'other'} = $other;
		return \%opts;
	}

	my @repos = @ARGV;
	if (scalar @repos == 0) {    # Add a default repo
		push @repos, q{.};
	}

	%opts = (
		repos   => \@repos,
		verbose => $verbose,
		other   => $other,
		error   => 0,
	);

	return \%opts;
}

sub run_command
{
	my ($cmd) = @_;

	printf "%s\n", $cmd;

	my $in;
	my $out;
	my $err;

	my $pid = open3 $in, $out, $err, $cmd;
	if (!defined $pid) {
		croak "Could not run command: $cmd";
	}

	my $answer_out;
	my $answer_err;

	if (defined $out) {
		while (my $line = <$out>) {
			$answer_out .= $line;
		}
	}

	if (defined $err) {
		while (my $line = <$err>) {
			$answer_err .= $line;
		}
	}

	if (!close $in) {
		printf "close failed\n";
	}
	waitpid $pid, 0;

	# my $child_exit_status = $? >> 8;
	# printf "retval = $child_exit_status\n";

	return $answer_out || $answer_err;
}

sub get_git_date
{
	my ($obj) = @_;

	my $cmd = 'git log --format="%ct" -n1';
	if (defined $obj) {
		$cmd .= " '$obj'";
	}

	my $date = run_command ($cmd);
	chomp $date;
	return $date;
}

sub touch_file
{
	my ($file, $unix) = @_;

	if (!defined $unix) {
		$unix = time();
		printf "$unix\n";
	}

	my $t = File::Touch->new (
		no_create => 1,
		atime => $unix,
		mtime => $unix,
	);

	return ($t->touch ($file) == 1);
}

sub git_dir
{
	return (-d '.git');
}

sub add_dir_component
{
	my ($list, $dir, $date) = @_;

	if (exists $list->{$dir}) {
		if ($date > $list->{$dir}) {
			$list->{$dir} = $date;
		}
	} else {
		$list->{$dir} = $date;
	}
}

sub add_git_dir
{
	my ($list, $dir, $date) = @_;

	until ($dir eq q{.}) {
		add_dir_component ($list, $dir, $date);
		$dir = dirname $dir;
	}

	add_dir_component ($list, q{.}, $date);
}

sub get_git_files
{
	my $data = run_command ("git ls-files -z | xargs -I{} -0 -n1 git log -n1 --format=\"%ct\t{}\" {}");
	if (!$data) {
		return;
	}

	my @lines = split /\n/msx, $data;

	my %git_files = ();

	foreach (@lines) {
		my ($date, $dir_file) = split /\t/msx, $_, 2;

		my ($file, $dir) = fileparse ($dir_file);
		chop $dir;

		add_git_dir (\%git_files, $dir, $date);

		$git_files{$dir_file} = $date;
	}

	return %git_files;
}

sub main
{
	my $opts = parse_options ();
	if ($opts->{'error'}) {
		usage ();
		return 1;
	}

	# print Dumper ($opts);

	my $homedir = getcwd ();

	my @repos = @{$opts->{'repos'}};
	foreach (keys @repos) {
		chdir $homedir;
		my $dir = $repos[$_];
		if (!-d $dir) {
			printf "Directory doesn't exist: '$dir'\n";
			next;
		}

		chdir $repos[$_];
		if (!git_dir ()) {
			printf "Not a git repo: '$dir'\n";
			next;
		}

		printf "Repo: %s\n", $repos[$_];

		my $other = $opts->{'other'};
		if ($other eq 'git') {
			$other = get_git_date ();
		}

		if ($other ne q{}) {
			printf "reset dates to '$other'\n";
			run_command ("find . -name .git -prune -o -print0 | xargs --no-run-if-empty --null touch -d '$other'");
		}

		my $files = run_command ("git ls-files -z | xargs -I{} -0 -n1 git log -n1 --format=\"%ct\t{}\" {}");
		my @file_list = split /\n/msx, $files;

		my %dirs = ();
		foreach my $line (@file_list) {
			my ($date, $file) = split /\t/msx, $line, 2;
			# printf "'$date' '$file'\n"
			# print Dumper (fileparse ($file));
			touch_file ($file, $date);
			my ($f, $d) = fileparse ($file);
			$dirs{$d} = ();
		}

		# print Dumper (\%dirs);
		# printf "%d\n", exists $dirs{'e2/'};
		foreach (sort keys %dirs) {
			my $d = $_;
			my $date = get_git_date ($d);
			touch_file ($d, $date);
		}

		$dir = q{.};
		my $date = get_git_date ($dir);
		touch_file ($dir, $date);
	}

	return 0;
}


exit main ();

