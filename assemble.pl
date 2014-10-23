#!usr/bin/perl
use strict;
use Getopt::Std;

# Hack assembler reserved labels
my %reservedLabels = ();
# Hack assembler computation codes
my %compCodes = ();
# Hack assembler destination codes
my %destCodes = ();
# Hack assembler jump codes
my %jumpCodes = ();

# Command Line Options
my %options = ();
getopts("dh",\%options) or printUsage();
if($options{h}) {
	printUsage();
}
my $file = $ARGV[0];
if(!($file =~ /\.asm$/)) {
	printUsage();
}

#printOptions();
getInstructions();
#processFile($file);

sub getInstructions {
	open(my $FH, "<","instructions") or die "Failed to open instructions file! Is it even there?!\nCroaking...";
	my $secC = -1;
	my $lno = 1;
	if($options{d}) {
		print "\n---Reading instructions---\n";
	}
	while(<$FH>) {
		my $line = $_;
		if(substr($line,0,1) eq "#" || $line eq "\n") {
			if($options{d}) {
				printf("[%d] SKIPPED: %s",$lno, $line);
			}
			$lno++;
			next;
		}
		if(substr($line,0,1) eq "\"") {
			$secC++;
			if($options{d}) {
				printf("\n\n---SECTION[%d]---\n[%s]: %s",$secC,$lno, $line);
			}
			$lno++;
			next;
		}
		my @instruction = split(/\s+/,$line);
		if($options{d}) {
			printf ("[%d] LINE: %s",$lno,$line);
			#printf ("Instruction size: %d\n", scalar @instruction);
			if($secC == 0) {
				printf ("Address of word (%s) = (%015b)\n",$instruction[0],$instruction[1]);
			} else {
				printf ("Address of word (%s) = (%s)\n",$instruction[0],$instruction[1]);
			}
		}
		if($secC == 0) {
			$reservedLabels{$instruction[0]} = sprintf("%015b", $instruction[1]);
		} elsif ($secC == 1) {
			$compCodes{$instruction[0]} = $instruction[1]; 
		} elsif ($secC == 2) {
			$destCodes{$instruction[0]} = $instruction[1];
		} elsif ($secC == 3) {
			$jumpCodes{$instruction[0]} = $instruction[1];
		}
		$lno++;

	}
	if($options{d}) {
		printAllCodes();
	}
}

sub processFile {
    my $file = shift;

}

sub printAllCodes {
	print "\n---Instruction Codes---\n";
	foreach(keys %reservedLabels) {
		printf("LABEL: %-10s VALUE: %s\n",$_, $reservedLabels{$_});
	}
	foreach(keys %compCodes) {
		printf("LABEL: %-10s VALUE: %s\n",$_, $compCodes{$_});
	}
	foreach(keys %destCodes) {
		printf("LABEL: %-10s VALUE: %s\n",$_, $destCodes{$_});
	}
	foreach(keys %jumpCodes) {
		printf("LABEL: %-10s VALUE: %s\n",$_, $jumpCodes{$_});
	}

}
sub printUsage {
	print "USAGE: perl assemble.pl [-d][-h] <file.asm>\n";
	exit 1;
}

sub printOptions {
	foreach(keys %options) {
		printf("Option (%s) => (%s)\n",$_,$options{$_});

	}
}
