#!/usr/bin/perl
#
# File: build_full_match_network.pl
# Purpose: Takes as input a file of comma separated records indicating
#          year observed and pairwise distances between treated and 
#          control subjects.
#
#          treated year, treated id, control year, control id
#       ie: 71,1995002,90,2292005,23.385852
#
#          The year observed was split out because of the original format 
#          of the data this script was working with.
#
# Author: Eric Harley (harley@ams.jhu.edu)
# Date: 2005

$| = 1;

use strict;

# comma separated data file
my $distance_file;

# ids sent to the network flow solver must be integers in the range 0...N-1.
# the map file preserves the map between the data and the network flow program
my $map_file;

# file to pass to the network flow solver. Output is in DMX format (a standard interchange format)
my $network_file;
my $temp_network_file;

if ($#ARGV < 2) {
	print "Usage: build_full_match_network.pl <distance file> <mapping file> <network file>\n";
	exit(0);

} else {

	$distance_file = $ARGV[0];
	$map_file = $ARGV[1];
	$network_file = $ARGV[2];

	die "Cannot open distance file ($distance_file) for reading\n" unless -r $distance_file;

	die "Cannot create new mapping file ($map_file) for writing. File already exists.\n" if -e $map_file;
	open MAP,">$map_file" || die "Cannot create mapping file ($map_file) for writing.\n";

	die "Cannot create new network file ($network_file) for writing. File already exists.\n" if -e $network_file;
	open NET,">$network_file" || die "Cannot create network file ($network_file) for writing.\n";
	close NET;
	unlink("$network_file");

	$temp_network_file = int(rand()*10000)."_$network_file";
	open NET,">$temp_network_file" || die "Cannot create temporary file ($temp_network_file)\n";
}



###
###
my %n;
my %t;
my %c;
my %d;

my $arc_count = 0;
my $node_count = 0;

my $num_controls = 0;
my $num_treated = 0;

print STDERR "Reading distance file...\n";
open FILE, "<$distance_file";
my $i = 0;

###
# read in the records
###
while(<FILE>) {
	chomp;
	my ($year_t,$id_t, $year_c, $id_c, $dist) = split /,/;
	die "Data format error. Not enough fields near line $node_count" unless /.*,.*,.*,.*/;
	unless (defined $t{"$year_t:$id_t"}) {
		$num_treated++;
		$node_count++;
		$t{"$year_t:$id_t"} = 1;
		$n{"$year_t:$id_t"} = $node_count;
	}
	unless (defined $c{"$year_c:$id_c"}) {
		$num_controls++;
		$node_count++;
		$c{"$year_c:$id_c"} = 1;
		$n{"$year_c:$id_c"} = $node_count;
	}
	$d{"$year_t:$id_t:$year_c:$id_c"} = $dist;
	last;
}
close FILE;
foreach my $key (sort {$n{$a} <=> $n{$b}} keys %n) {
	print MAP "$key,$n{$key}\n";
}
close MAP;
$node_count++;
$n{"sink"} = $node_count;

$node_count++;
$n{"overflow"} = $node_count;

my $min_controls = 1.0/(1.0*$num_treated);
my $max_controls = $num_controls;

print STDERR "Building network...\n";
print STDERR "Initializing nodes...\n";
foreach my $key_t (sort keys %t) {
	print NET "n $n{$key_t} $max_controls\n";
}
print NET "\n\n";

# these node definitions are implicit
#foreach my $key_c (sort keys %c) {
#	print NET "n $n{$key_c} 0\n";
#}
#print NET "\n\n";

print NET "n ".$n{"overflow"}." ".($num_controls - $num_treated*$max_controls)."\n";
print NET "n ".$n{"sink"}." ".(-$num_controls)."\n";
print NET "\n\n";


print STDERR "Defining arcs...\n";
foreach my $key_t (sort keys %t) {
	foreach my $key_c (sort keys %c) {
		my $d = $d{"$key_t:$key_c"};
		if (abs($d) < 0.001) {
			$d += 0.001;
		}
		$d = int($d * 1000);
		print NET "a $n{$key_t} $n{$key_c} 0 1 $d\n";
		$arc_count++;
	}
	print NET "\n";
}

print NET "\n";

print STDERR "Finishing up...\n";
my $control_gap = 0;
foreach my $key_t (sort keys %t) {
	$control_gap = $max_controls - 1;
	next if $control_gap == 0;
	$arc_count++;
	print NET <<_END_
a $n{$key_t} $n{"overflow"} 0 $control_gap 0
_END_
}
print NET "\n";
foreach my $key_c (sort keys %c) {
	$control_gap = 1.0/$min_controls - 1;
	next if $control_gap == 0;
	$arc_count++;
	print <<_END_
a $n{$key_c} $n{"overflow"} 0 $control_gap 0
_END_
}
print NET "\n\n";
foreach my $key_c (sort keys %c) {
	print NET "a $n{$key_c} ".$n{"sink"}." 0 1 0\n";
	$arc_count++;
}
print NET "\n\n";

close NET;

# we need to put the line: "p min $node_count $arc_count" at the start of 
# the file
# but we only know those after we've generated the program
# so we need to copy the temp network file into the network file

open NET, ">>$network_file";
open NET2, "<$temp_network_file";
print NET "p min $node_count $arc_count\n";
while(<NET2>) {
	print NET $_;
}
close NET;
close NET2;
unlink("$temp_network_file");

print STDERR "Done.\n";

sub max {
	my ($a,$b) = @_;
	return $a if $a >= $b;
	return $b;
}
sub min {
	my ($a,$b) = @_;
	return $a if $a <= $b;
	return $b;
}

