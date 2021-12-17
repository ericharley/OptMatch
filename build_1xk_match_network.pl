#!/usr/bin/perl
#          
# File: build_1xk_match_network.pl
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

$minMatch = 1;
$maxMatch = 1;

$numNodes = 0;
$numEdges = 0;

$numTreated = 0;

$curID = 1;

if ($#ARGV < 3) {
        print "Usage: build_1xk_match_network.pl <k> <distance file> <mapping file> <network file>\n";
        exit(0);
} else {
	die "k ($ARGV[0]) not valid.\n" unless ($ARGV[0] =~ /^[0-9]+$/);
	$minMatch = $ARGV[0];
	$maxMatch = $ARGV[0];
	$matchGap = $maxMatch - $minMatch;
	die "minimum number of matchings cannot exceed maximum number of matchings" if $matchGap < 0;

        $distance_file = $ARGV[1];
        $map_file = $ARGV[2];
        $network_file = $ARGV[3];

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


print STDERR "Reading distance file...\n";
open FILE,"<$distance_file";

while(<FILE>) {

	chomp;

	($treatedYear, $treatedID, $controlYear, $controlID, $distance) = split /,/;
	die "Data format error. Not enough fields near line $node_count" unless /.*,.*,.*,.*/;
	$treatedID = "$treatedYear:"."$treatedID";
	unless (defined $ids{$treatedID}) {
		$ids{$treatedID} = $curID++;
		$numNodes++;
		$numTreated++;
	}
	$controlID = "$controlYear:"."$controlID";
	unless (defined $ids{$controlID}) {
		$ids{$controlID} = $curID++;
		$numNodes++;
	}


	$distance{$treatedID}{$controlID} = $distance;
}
close FILE;

print STDERR "Building network...\n";

$lowerCapacity = 0;
$upperCapacity = 1;

$maxWeight = 0;

foreach $treatedID (sort keys %distance) {

	print NET "n $ids{$treatedID} $maxMatch\n";
	foreach $controlID (sort keys %{$distance{$treatedID}}) {

		# keeps track of how much flow is circulating in the network	
		$numMatches++;

		$weight = int($distance{$treatedID}{$controlID}*100);

		# keep track of the largest weight seen so far.
		# we will use a number larger than the largest weight for the edges to the surplus node
		# that way we will have flow conservation in our network and flow will only go to 
                # that node if there is no match possible (if there were, then it would be made 
                # because the match would be cheaper than going to the surplus node)
		if ($weight > $maxWeight) {
			$maxWeight = $weight;
		}

		print NET "a $ids{$treatedID} $ids{$controlID} $lowerCapacity $upperCapacity $weight\n";
		$numEdges++;
	}
}

$maxWeight += 10;
$maxWeight = int($maxWeight*100);
$slopID = $curID++;
$slopFlow = -1*$maxMatch*$numTreated;
print NET "n $slopID $slopFlow\n";
$numNodes++;

print STDERR "Defining arcs...\n";
foreach $treatedID (keys %distance) {
	if ($matchGap != 0) {
		print NET "a $ids{$treatedID} $slopID 0 $matchGap $maxWeight\n";
		$numEdges++;
	}

        foreach $controlID (keys %{$distance{$treatedID}}) {
		$str = "a $ids{$controlID} $slopID $lowerCapacity $upperCapacity 0\n";
		unless ($printed{$str} == 1) {
			print NET "a $ids{$controlID} $slopID $lowerCapacity $upperCapacity 0\n";
			$numEdges++;
			$printed{$str} = 1;
		}
	}
}

close NET;

# we need to put the line: "p min $node_count $arc_count" at the 
# start of the file but we only know those after we've generated the 
# program so we need to copy the temp network file into the network file

open NET, ">>$network_file";
open NET2, "<$temp_network_file";
print NET "p min $node_count $arc_count\n";
while(<NET2>) {
        print NET $_;
}
close NET; 
close NET2;
unlink("$temp_network_file");

foreach $key (sort {$a <=> $b} keys %ids) {
	print MAP "$key,$ids{$key}\n";
}
close MAP;
