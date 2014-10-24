#!usr/bin/perl
use strict;
use Getopt::Std;

my %reservedLabels = (); # Hack assembler reserved labels
my %compCodes = (); # Hack assembler computation codes
my %destCodes = (); # Hack assembler destination codes
my %jumpCodes = (); # Hack assembler jump codes
my %symTable = (); # Symbol Table
my %options = (); # Command Line Options

my $src;
my $hack;

{ # Main
    getArgs();
    getInstructions();
    pass_one();
    # printOptions();
}

# Gets command line arguments and assigns them the the src, hack, and options fields
sub getArgs {
    getopts("dh",\%options) or printUsage();
    if($options{h}) {
        printUsage();
    }
    $src = $ARGV[0];
    if(!($src =~ /\.asm$/)) {
        printUsage();
    }
    $hack = $src;
    $hack =~ s/\.asm$/\.hack/g;
}


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

# Traverses through the src file and adds labels to the symbol table
sub pass_one {
    my $lno = 0;
    my $pc = 0;
    my $varno = 16;
    open(my $SRC, '<', $src);
    if($options{d}) {
        printf("---First pass through %s---\n",$src);
    }
    while(<$SRC>) {
        my $line = $_;
        # Removing comments and useless whitespace
        $line =~ s/\/\/.*//g;
        $line =~ s/\s*//g;
        if(!$line) {
            $lno++;
            next;
        }
        if(substr($line, 0, 1) eq "(") {
            $line =~ s/\(//g;
            $line =~ s/\)//g;
            my $val = sprintf("0%015b",$pc);
            if(exists $symTable{$line}) {
                print "Pass one error\n";
                printf("[%03d]: Multiple occurences of label (%s)",$lno,$line);
            }
            printf("LABEL %s VALUE %s\n",$line,$val);
           i# printf("LABEL: %s VALUE: 0%015b\n",$line,$pc);
           # $symTable{
        }
        if($options{d}) {
            printf("[%03d]: PC[%d]: %s\n",$lno,$pc,$line);
        }
        $pc++;
        $lno++;
        
    }

}


#sub processFile {
#    my $file = shift;
#    my $ofile = $file;
#    $ofile =~s/\.asm/\.hack/;
#    if($options{d}) {
#        printf ("---PROCESSING %s---\n",$file);
#        printf ("old File %s\n",$file);
#        printf ("new File %s\n",$ofile);
#    }
#    my $lno = 0;
#    open(my $ASM,'<', $file);
#    open(my $HACK,'>',$ofile);
#    while(<$ASM>) {
#        my $line = $_;
#
#        # Removes comments and remaining whitespace and skips the line
#        $line =~ s/\/\/.*//g;
#        $line =~ s/\s*//g;
#        if(!$line) {
#            next;
#        }
#        if($options{d}) {
#            #        }
#
#        my @code = "";
#        my $dest = "";
#        my $comp = "";
#        my $jmp = "";
#
#        my @d_cj = split("=",$line);
#        my @c_j;
#        if(!$d_cj[1]) {
#            my @c_j = split(";",$d_cj[0]);
#        
#        }
#        if($d_cj[0]) {
#            $dest = $d_cj[0];
#        }
#        if($c_j[1]) {
#            $jmp = $c_j[1];
#        } else {
#            $comp = $c_j[0];
#        }
#        printf("Code: dest(%s), comp(%s), jmp(%s)\n",$dest,$comp,$jmp);
#        
#        $lno++;
#    }
#
#}

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
