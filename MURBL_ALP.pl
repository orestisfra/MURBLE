#!/usr/bin/perl -w

use strict;
use Math::Complex;

#----------------------------------------------
my $argvcount = @ARGV; #1-number of arguments
my $querycount = $argvcount - 1; #2-number of queries
my $database = $ARGV[0]; #3-name of database file
my @subject = (); #4-array of query files
my @bakfiles = (); #array containing the backup files of arguments
#----------------------------------------------
#checking if arguments are sufficient
if (($argvcount == 0) or ($argvcount == 1)) {
	die "not enough arguments. usage: $0 databasefile queryfile-1 queryfile-2 queryfile-3 ... queryfile-N.\n";
}
open(FIN1,"<$database") or die "unable to open $database. not in the same directory or doesn't exist";
close(FIN1);

#getting database and queries
for (my $z = 0; $z < $querycount; $z++){
	my $y=$z+1;
	$subject[$z]=$ARGV[$y];
	open(FIN2,"<$subject[$z]") or die "unable to open $subject[$z]. not in the same directory or doesn't exist";
	close(FIN2);
}
#creating backup of input files and change them to id/seq/id/seq/id/seq...
print "\ncreating backup files if they don't exist\n";
for (my $a = 0; $a < $argvcount; $a++) {
	$bakfiles[$a] = $ARGV[$a].".bak";
	unless (-f "$bakfiles[$a]") {
		system("cp $ARGV[$a] $bakfiles[$a]");
		if ($a == $argvcount - 1) {
			print "\nbackup files created\n";
		}
	}
}
for (my $a = 0; $a < $argvcount; $a++) {
	open(FOUT, "> $ARGV[$a]");
	open(FIN, "< $bakfiles[$a]") or die "Can't open '$bakfiles[$a]': $!";
	my $y = 1;
	while (my $line = <FIN>) {
		unless ($line =~ /^(>\S+)/ ) {
			chomp($line);
			print FOUT $line;
		}
		if (($line =~ /^(>\S+)/ ) && ($y != 1)) {
			print FOUT "\n".$1."_".$ARGV[$a]."\n";
		}
		if (($line =~ /^(>\S+)/ ) && ($y == 1)) {
			print FOUT $1."_".$ARGV[$a]."\n";
			$y++;
		}
	}
	close(FIN);
	close(FOUT);
}
#executing blast
for (my $z = 0; $z < $querycount; $z++){
	my $y=$z+1;
	print "\nrun number $y\n";
#blast1
	print "\n\n\n$y - first blast\n";
	my @database1 = ("makeblastdb", "-dbtype", "prot", "-in", $database, "-out", "database1");
	my @blast1 = ("blastp", "-max_target_seqs", 1, "-query", $subject[$z], "-db", "database1", "-num_threads", "30", "-out", "exit1[$y].txt", "-outfmt", "'6 qseqid sseqid evalue'");
	my $temp = "";
	foreach my $x (@blast1) {
		$temp = $temp." ".$x;
	}
	system(@database1);
	system($temp);

#blast2
	print "\n\n\n$y - second blast\n";
	my @database2 = ("makeblastdb", "-dbtype", "prot", "-in", $subject[$z], "-out", "database2");
	my @blast2 = ("blastp", "-max_target_seqs", 1, "-query", $database, "-db", "database2", "-num_threads", "30", "-out", "exit2[$y].txt", "-outfmt", "'6 qseqid sseqid evalue'");
	$temp = "";
	foreach my $y (@blast2) {
		$temp = $temp." ".$y;
	}
	system(@database2);
	system($temp);

#1 getting results
	open(EXIT1,"< exit1[$y].txt") or die "unable to open output file 1 (exit1[$y].txt). not in the same directory or doesn't exist\n";
	my %hash1;
	my ($query1, $data1, $evalue1, @second1) = "";
	my ($que, $d) = ("k","k");
	my $a = 1.1e+100;
	while (my $line1=<EXIT1>) {
		chomp($line1);
		if($line1 =~ /^(\S+)\t(\S+)\t(\S+)/) {
			$query1 = $1;
			$data1 = $2;
			$evalue1 = $3;
		}
		else {
			die "output file from 1st blast is in wrong format\n";
		}
		if (($d eq $data1) and ($que eq $query1)) {
			if ($a >= $evalue1) {
				@second1 = ($data1, $evalue1);
				$hash1{$query1} = [ @second1 ];
			}
			if ($a < $evalue1) {
				@second1 = ($data1, $a);
				$hash1{$query1} = [ @second1 ];
			}
		}
		else {
			@second1 = ($data1, $evalue1);
			$hash1{$query1} = [ @second1 ];
		}
		$que = $query1;
		$d = $data1;
		$a = $evalue1
	}
	close(EXIT1);

#2 getting results
	open(EXIT2,"< exit2[$y].txt") or die "unable to open output file 2 (exit2[$y].txt). not in the same directory or doesn't exist\n";
	my %hash2;
	my ($query2, $data2, $evalue2, @second2) = "";
	($que, $d) = ("k","k");
	$a = 1.1e+100;
	while (my $line2=<EXIT2>) {
		chomp($line2);
		if($line2 =~ /^(\S+)\t(\S+)\t(\S+)/) {
			$query2 = $1;
			$data2 = $2;
			$evalue2 = $3;
		}
		else {
			die "output file from 2nd blast is in wrong format\n";
		}
		if (($d eq $data2) and ($que eq $query2)) {
			if ($a >= $evalue2) {
				@second2 = ($data2, $evalue2);
				$hash2{$query2} = [ @second2 ];
			}
			if ($a < $evalue2) {
				@second2 = ($data2, $a);
				$hash2{$query2} = [ @second2 ];
			}
		}
		else {
			@second2 = ($data2, $evalue2);
			$hash2{$query2} = [ @second2 ];
		}
		$que = $query2;
		$d = $data2;
		$a = $evalue2
	}
	close(EXIT2);

#COMPARING RESULTS
	print "\n\n";
	my ($key1, $value1) = "";
	my $i = 1;
	my $out = "output[$y].txt";
	open(FILEOUT, "> $out");
	foreach $key1 (keys %hash1) {
		$value1 = $hash1{$key1}[0];
		if (exists $hash2{$value1}) {
			if ($hash2{$value1}[0] eq $key1) {
				print FILEOUT "$key1	@{ $hash1{$key1} } --> reciprocating hit\n";
			}
		}
	}
	close(FILEOUT);
	print "\nresults saved in: 'output[$y].txt'\n";
}

#preparing the end file
#----------------------------------------------
my %lehash; #5-key:database value:subject hash
my ($ledata, $org) = ""; #6-database proteome from output file #7-subject proteome from output file
#----------------------------------------------
for (my $g = 0; $g < $querycount; $g++){
	my $y=$g+1;
	my $out = "output[$y].txt";
	open(FILEINPUT1, "< $out");
	while (my $outline1 = <FILEINPUT1>) {
		chomp($outline1);
		if ($outline1 =~ /^(\S+)\t(\S+)\s/) {
			$ledata = $2;
			$org = $1;
			$lehash{$ledata}[$g] = $org;
		}
	}
	close(FILEINPUT1);
}

#writing the endfile
print "\ngetting results\n";
#----------------------------------------------
my $end = "endfile.txt"; #8-name of endfile
#----------------------------------------------
open(ENDFILE, "> $end");
foreach my $key2 (keys %lehash) {
	print ENDFILE "$key2";
	for (my $var = 0; $var < $querycount; $var++) {
		if ($lehash{$key2}[$var]) {
			print ENDFILE "\t$lehash{$key2}[$var]";
		} else {
			print ENDFILE "\t------------";
		}
	}
	print ENDFILE "\n";
}
close(ENDFILE);
print "\nresults saved in: 'endfile.txt'\n";

#orthologs file
#----------------------------------------------
my $orth = "orthologs.txt"; #9-name of file containing orthologs
#----------------------------------------------
if ($querycount > 1) {
	print "\npolishing results\n";
	open(ENDINPUT, "< $end");
	open(ORTHOLOG, "> $orth");
	while (my $line = <ENDINPUT>) {
		chomp($line);
		unless ($line =~ /------------/) {
			print ORTHOLOG "$line\n";
		}
	}
	close(ORTHOLOG);
	close(ENDINPUT);
	print "results saved in: 'orthologs.txt'\n";
}

#----------------------------------------------
my %fastafiles; #10-hash including all the initial fasta files used 
#----------------------------------------------
#get the original edited fasta files (before the blast) and make a hash: fasta key -> sequence
foreach my $x (@ARGV) {
	open(FIN, "< $x");
	my ($line1, $line2) = "";
	while ($line1 = <FIN>) {
		chomp($line1);
		$line2 = <FIN>;
		chomp($line2);
		$fastafiles{$line1} = $line2;
	}
	close(FIN);
}

#----------------------------------------------
my @orthologs = (); #11-multidimentional array including all fasta identifiers from orthologs.txt
my $a = 0; #12-counter
#----------------------------------------------
#get all the fasta ids from orthologs.txt
open(ORTHOLOG, "< $orth");
while (my $line = <ORTHOLOG>) {
	chomp($line);
	if ($line =~ /^(.+)/) {
		my @temp = split /\t/, $1;
		my $t = @temp;
		for (my $var = 0; $var < $t; $var++) {
			$orthologs[$a][$var] = ">".$temp[$var];
		}
	}
	$a++;
}
close(ORTHOLOG);

#----------------------------------------------
my $orthocount = @orthologs; #13-lines of orthologs.txt file
#----------------------------------------------
#separate the orthologs. each line = 1 file: id/seq/id/seq...
for (my $var1 = 0; $var1 < $orthocount; $var1++) {
	my $i=$var1+1;
	open(ORTHFILES, "> orthfile[$i].txt");
	for (my $var2 = 0; $var2 < $argvcount; $var2++) {
		if (exists $fastafiles{$orthologs[$var1][$var2]}) {
			print ORTHFILES "$orthologs[$var1][$var2]\n$fastafiles{$orthologs[$var1][$var2]}\n";
		}
	}
	close(ORTHFILES);
}

#running muscle - create aligned files and edit them to files with one line sequences
print "\nrunning alignment (muscle)\n";
system("mkdir orthfiles");
system("mkdir alignedfiles");
for (my $i = 1; $i <= $orthocount; $i++) {
	system("mv orthfile\[$i\].txt ./orthfiles/orthfile\[$i\].txt");
}
for (my $i = 1; $i <= $orthocount; $i++) {
	system("muscle -in ./orthfiles/orthfile\[$i\].txt -out ./alignedfiles/alignedfile\[$i\].txt");
}
system("mkdir alignedfiles_edited");

#----------------------------------------------
my @files = glob( './alignedfiles/*' ); #14-get the name of files from alignedfiles folder
my $filecount = @files; #15-how many files there are in alignedfiles folder
#----------------------------------------------
print "\nedit the aligned files\n";
for (my $i = 1; $i <= $filecount; $i++) {
	open(ALOUT, "> ./alignedfiles_edited/alignedfile[$i].txt");
	open(ALIN, "< ./alignedfiles/alignedfile[$i].txt");
	my $y = 1;
	while (my $line = <ALIN>) {
		unless ($line =~ /^(>\S+)/ ) {
			chomp($line);
			print ALOUT $line;
		}
		if (($line =~ /^(>\S+)/ ) && ($y != 1)) {
			print ALOUT "\n".$1."\n";
		}
		if (($line =~ /^(>\S+)/ ) && ($y == 1)) {
			print ALOUT $1."\n";
			$y++;
		}
	}

	close(ALIN);
	close(ALOUT);
}

#start the merged file - start from aligned_edited[1].txt in order database org1 org2 org3 ...
print "\nmerge everything together\n";
open(EDOUT, "> merged_aligned_first.txt");
for (my $var = 0; $var < $argvcount; $var++) {
	open(EDIN, "< ./alignedfiles_edited/alignedfile[1].txt");
	while (my $line = <EDIN>) {
		chomp($line);
		if (($line =~ /$ARGV[$var]/) && ($var == 0)) {
			print EDOUT ">"."$ARGV[$var]\n";
			$line = <EDIN>;
			chomp($line);
			print EDOUT "$line";
		}
		if (($line =~ /$ARGV[$var]/) && ($var > 0)) {
			print EDOUT "\n>"."$ARGV[$var]\n";
			$line = <EDIN>;
			chomp($line);
			print EDOUT "$line";
		}
	}
	close(EDIN);
}
close(EDOUT);

#continue the merged file - add the rest aligned_edited[N].txt files in the same order
for (my $i = 2; $i <= $filecount; $i++) {
	for (my $var = 0; $var < $argvcount; $var++) {
		open(EDIN, "< ./alignedfiles_edited/alignedfile[$i].txt");
		open(MIN, "< merged_aligned_first.txt");
		open(MOUT, "> merged_aligned.txt");
		while (my $line = <EDIN>) {
			chomp($line);
			my $mline = "";
			if ($line =~ /$ARGV[$var]/) {
				my $y = $var+1;
				my $z = $y*2;
				my $x = $z-1;
				for (my $u = 0; $u < $z; $u++) {
					$mline = <MIN>;
					chomp($mline);
					last if $u == $x;
					print MOUT $mline."\n";
				}
				my $temp = $mline;
				$line = <EDIN>;
				chomp($line);
				print MOUT "$mline"."$line\n";
				while ($mline = <MIN>) {
					chomp($mline);
					print MOUT $mline."\n";
				}
			}
		}
		close(MOUT);
		close(MIN);
		system("mv merged_aligned.txt merged_aligned_first.txt");
		close(EDIN);
	}
}
system("mv merged_aligned_first.txt merged_aligned.txt");
print "\nresults saved in: merged_aligned.txt\n";
system("Gblocks merged_aligned.txt -g");
