#!/usr/bin/perl -w

use strict;

system("rm ./proteomes/MURBL_ALP.pl");
system("ls -1 proteomes/ > temp.txt");
open(FIN, "< temp.txt");
my @array;
while (my $line = <FIN>) {
	chomp($line);
	push(@array, $line);
}
close(FIN);
my ($comb, $y) = ""; 
foreach my $x (@array) {
	unless ($y) {
		$comb = $x;
	} else {
		$comb = $y." ".$x;
	}
	$y = $comb;
}
system("cp MURBL_ALP.pl ./proteomes/MURBL_ALP.pl");
system("rm temp.txt");
exec("cd ./proteomes/; ./MURBL_ALP.pl $comb");
