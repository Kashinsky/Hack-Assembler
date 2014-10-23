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
processFile($file);


# Gets instructions from the instructions file and adds the values to the appropriate hash.
sub getInstructions {
	open(my $FH, "<","instructions") or die "Failed to open instructions file! Is it even there?!\nCroaking...";
	my $secC = -1;
	my $lno = 1;
	if($options{d}) {
		print "\n---Reading instructions---\n";
	}

    #Iterates through the lines in the instructions file
	while(<$FH>) {
		my $line = $_;
        # Skips 
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
    my $ofile = $file;
    $ofile =~s/\.asm/\.hack/;
    if($options{d}) {
        printf ("---PROCESSING %s---\n",$file);
        printf ("old File %s\n",$file);
        printf ("new File %s\n",$ofile);
    }
    my $lno = 0;
    open(my $ASM,'<', $file);
    open(my $HACK,'>',$ofile);
    while(<$ASM>) {
        my $line = $_;

        # Removes comments and remaining whitespace and skips the line
        $line =~ s/\/\/.*//g;
        $line =~ s/\s*//g;
        if(!$line) {
            next;
        }
        if($options{d}) {
            printf("[%03d]: %s\n",$lno ,$line);
        }

        my @code = "";
        my $dest = "";
        my $comp = "";
        my $jmp = "";

        my @d_cj = split("=",$line);
        my @c_j;
        if(!$d_cj[1]) {
            my @c_j = split(";",$d_cj[0]);
        
        }
        if($d_cj[0]) {
            $dest = $d_cj[0];
        }
        if($c_j[1]) {
            $jmp = $c_j[1];
        } else {
            $comp = $c_j[0];
        }
        printf("Code: dest(%s), comp(%s), jmp(%s)\n",$dest,$comp,$jmp);
        
        $lno++;
    }

}

sub printAllCodes {
	print "\n---Instruction Codes---\n";
	foreach(keys %reservedLabels) {
		printf("LABEL: %-8s\t VALUE: %s\n",$_, $reservedLabels{$_});
	}
	foreach(keys %compCodes) {
		printf("COMP: %-8s\t VALUE: %s\n",$_, $compCodes{$_});
	}
	foreach(keys %destCodes) {
		printf("DEST: %-8s\t VALUE: %s\n",$_, $destCodes{$_});
	}
	foreach(keys %jumpCodes) {
		printf("JUMPS: %-8s\t VALUE: %s\n",$_, $jumpCodes{$_});
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
