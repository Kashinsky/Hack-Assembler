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
my $hackFH;
my $var = 16;
my $errStr = "";
my $errNo = 0;
{ # Main
    getArgs();
    getInstructions();
    pass_one();
    my $outString = pass_two();
    if($errNo > 0) {
        print $errStr;
        exit 1;
    }
    print $hackFH $outString;
    # printOptions();
}

# Gets command line arguments and assigns them the the src, hack, and options fields
sub getArgs {
    getopts("dhl",\%options) or printUsage(1);
    if($options{h}) {
        printUsage(0);
    }
    $src = $ARGV[0];
    if(!($src =~ /\.asm$/)) {
        printUsage();
    }
    $hack = $src;
    $hack =~ s/\.asm$/\.hack/g;
    open($hackFH,">",$hack);
}


# Gets instructions from the instructions file and adds the values to the appropriate hash.
sub getInstructions {
	open(my $FH, "<","instructions") or die "Failed to open instructions file! Is it even there?!\nCroaking...";
	my $secC = -1;
	my $lno = 1;
	debug("\n---Reading instructions---\n");
    
    #Iterates through the lines in the instructions file
	while(<$FH>) {
		my $line = $_;
        # Skips 
		if(substr($line,0,1) eq "#" || $line eq "\n") {
			debug(sprintf("[%d] SKIPPED: %s",$lno, $line));
			$lno++;
			next;
		}
		if(substr($line,0,1) eq "\"") {
			$secC++;
			debug(sprintf("\n\n---SECTION[%d]---\n[%s]: %s",$secC,$lno, $line));
			$lno++;
			next;
		}
		my @instruction = split(/\s+/,$line);
        debug(sprintf ("[%d] LINE: %s",$lno,$line));
        if($secC == 0) {
            debug(sprintf ("Address of word (%s) = (%015b)\n",$instruction[0],$instruction[1]));
        } else {
            debug(sprintf ("Address of word (%s) = (%s)\n",$instruction[0],$instruction[1]));
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
    debug(printAllCodes());
}

# Traverses through the src file and adds labels to the symbol table
sub pass_one {
    my $lno = 0;
    my $pc = 0;
    open(my $SRC, '<', $src);
    debug(sprintf("\n\n---First pass through %s---\n",$src));
    while(<$SRC>) {
        my $line = $_;
        # Removing comments and useless whitespace
        $line =~ s/\/\/.*//g;
        $line =~ s/\s*//g;
        if($line eq "") {
            $lno++;
            next;
        }
        if($line =~ /\(.*\)/) {
            $line =~ s/\(//g;
            $line =~ s/\)//g;
            my $val = sprintf("0%015b",$pc);
            if(exists $symTable{$line}) {
                print "Pass one error\n";
                printf("[%03d]: Multiple occurences of label (%s)\n",$lno,$line);
            }
            $symTable{$line} = $val;
            debug(sprintf("Adding %s to symbol table\n",$line));
            $pc--;
        }
        debug(sprintf("[%03d]: PC[%d]: %s\n",$lno,$pc,$line));
        $lno++;
        $pc++;
    }
    close $SRC;
}

sub pass_two {
    my $outString = "";
    debug(sprintf ("\n\n---Second pass through %s---\n",$src));
    my $pc = 0;
    my $lno = 1;
    open(my $SRC,'<',$src);
    while(<$SRC>) {
        my $line = $_;
        $line =~ s/\/\/.*//g;
        $line =~ s/\s*//g;
        if($line eq "") {
            $lno++;
            next;
        }
        if($line =~ /^\(/) {
            $lno++;
            next;
        }
        debug(sprintf ("LINE[%03d] PC[%03d] (%s)\n",$lno,$pc,$line));
        if($line =~ /^\@/) {
            $outString .= get_A($line, $lno);
            debug("\n");
            $lno++;
            $pc++;
            next;
        }
        $outString .= get_C($line, $lno);
        debug("\n");
        $pc++;
        $lno++;
        next;
    }
    printSymTable();
    return $outString;
}

sub get_C {
    my $line = shift;
    my $lno = shift;
    debug(sprintf("Possible C-Instruction \"%s\" at line %d\n",$line,$lno));
    my $dest = "000";
    my $comp = "";
    my $jmp = "000";
    my @d_cj = split(/=/,$line);
    my @c_j;
    if($d_cj[1] ne "") {
        debug(sprintf("Dest \"%s\" Remain \"%s\"\n",$d_cj[0], $d_cj[1]));
        if($d_cj[0]) {
            $dest = $destCodes{$d_cj[0]};
        }
        @c_j = split(/;/,$d_cj[1]);
    } else {
        if($line =~ /=/) {
           err(sprintf("Invalid C-Instruction \"%s\" at line %03d\n",$line,$lno));
           return "";
        }
        @c_j = split(/;/,$d_cj[0]);
    }

    if($c_j[1] ne "") {
        $jmp = $jumpCodes{$c_j[1]};
    }
    $comp = $compCodes{$c_j[0]};
    if($dest && $comp && $jmp) {
        my $code = "111$comp$dest$jmp\n";
        debug(sprintf("Passed C-Instruction \"%s\" at line %d\n",$line,$lno));
        debug("Code = ".$code);
        return "$code"; 
    }
    err(sprintf("Invalid C-Instruction \"%s\" at line %03d\n",$line,$lno));
    return "";
}

sub get_A {
    my $line = shift;
    my $lno = shift;
    my $val = $line;
    $val =~ s/^\@//g;
    if(exists $reservedLabels{$val}) {
        my $bin = $reservedLabels{$val};
        debug(sprintf("Reserved Word \"%s\" Value \"%s\" \n",$val,$bin));
        return "0$bin\n";
    }
    if($val =~ /^\-?\d+$/) {
        if(int $val < 0) {
            err(sprintf("Constant \"%d\" must be a non-negative value\n",$val));
        }
        my $bin = sprintf("0%015b",$val);
        #$outString .= "$bin\n";
        debug(sprintf("Constant \"%d\" Value \"%s\" \n",$val,$bin));
        return "$bin\n";
    }
    if(exists $symTable{$val}) {
        my $bin = $symTable{$val};
        debug(sprintf("OLDID \"%s\" Value \"%s\" \n",$val,$bin));
        return "$bin\n";
    }
    if(match_var($val)) {
        my $bin = sprintf("0%015b",$var);
        $symTable{$val} = $bin;
        $var++;
        debug(sprintf("NEWID \"%s\" Value \"%s\" \n",$val,$bin));
        return "$bin\n";
    }
    err(sprintf("Invalid A-instruction \"%s\"\n", $val));
}

sub match_var {
    my $val = shift;
    if($val =~ /^\d+/) {
        return "";
    }
    $val =~ s/\_//g;
    $val =~ s/\://g;
    $val =~ s/\.//g;
    $val =~ s/\$//g;
    $val =~ s/\d//g;
    $val =~ s/\w//g;
    if($val) {
        return "";
    }
    return "true";
}

sub debug {
    my $msg = shift;
    if($options{d}) {
        print $msg;
    }
}

sub err {
    $errStr .= shift;
    $errNo++;
}

sub printSymTable {
    if(!$options{l}) {
        return;
    }
    my $sts = "\n\n---SYMBOL TABLE---\n";
    foreach(keys %symTable) {
        $sts .= sprintf("(%s,%s)\n", $_, $symTable{$_});
    }
    $sts .= "------------------\n\n";
    print $sts;
}

sub printAllCodes {
	my $codes = "\n---Instruction Codes---\n";
	foreach(keys %reservedLabels) {
		$codes .= sprintf("LABEL: %-8s\t VALUE: %s\n",$_, $reservedLabels{$_});
	}
	foreach(keys %compCodes) {
		$codes .= sprintf("COMP: %-8s\t VALUE: %s\n",$_, $compCodes{$_});
	}
	foreach(keys %destCodes) {
		$codes .= sprintf("DEST: %-8s\t VALUE: %s\n",$_, $destCodes{$_});
	}
	foreach(keys %jumpCodes) {
		$codes .= sprintf("JUMPS: %-8s\t VALUE: %s\n",$_, $jumpCodes{$_});
	}
    return $codes;
}

sub printUsage {
    my $err = shift;
	print "USAGE: perl assemble.pl [-d][-h][-l] <file.asm>\n";
	exit $err;
}

sub printOptions {
	foreach(keys %options) {
		printf("Option (%s) => (%s)\n",$_,$options{$_});

	}
}

