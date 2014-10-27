# Name: assemble.pl
# Date: 10/27/2014
# Author: Dillon Yeh <yehda194@potsdam.edu>
# Description: This programs will produce a .hack file that follows the standards
#              specified by the nand2tetris language specification from a .asm input

#!usr/bin/perl
use strict;
use Getopt::Std;

my %reservedLabels = (); # Hack assembler reserved labels
my %compCodes = (); # Hack assembler computation codes
my %destCodes = (); # Hack assembler destination codes
my %jumpCodes = (); # Hack assembler jump codes
my %symTable = (); # Symbol Table
my %options = (); # Command Line Options
my $src; # Source file
my $hack; # Output hack file
my $hackFH; # Hack file handle
my $var = 16; # Value assigned to user assigned variables
my $errStr = ""; # The error string to be printed
my $errNo = 0; # The number of errors found in src file

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
        # Skips over # deliminated comments
		if(substr($line,0,1) eq "#" || $line eq "\n") {
			debug(sprintf("[%d] SKIPPED: %s",$lno, $line));
			$lno++;
			next;
		}
        # Skips over section headers
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
# with the location of the next instruction as a value.
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
        # Checks the current line for the label pattern
        if($line =~ /\(.*\)/) {
            $line =~ s/\(//g;
            $line =~ s/\)//g;
            # Converts the current program counter to binary uses it as a hash value
            my $val = sprintf("0%015b",$pc);
            # Compares the label with pre-existing labels 
            if(exists $symTable{$line}) {
                err(sprintf("[%03d]: Multiple occurences of label (%s)\n",$lno,$line));
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

# Reads from the src file and calls functions to handle different instruction types
sub pass_two {
    my $outString = "";
    debug(sprintf ("\n\n---Second pass through %s---\n",$src));
    my $pc = 0;
    my $lno = 1;
    open(my $SRC,'<',$src);
    while(<$SRC>) {
        my $line = $_;
        # Comment removal and empty line skipping
        $line =~ s/\/\/.*//g;
        $line =~ s/\s*//g;
        if($line eq "") {
            $lno++;
            next;
        }
        # Skips lines starting with a label's paren
        if($line =~ /^\(/) {
            $lno++;
            next;
        }
        debug(sprintf ("LINE[%03d] PC[%03d] (%s)\n",$lno,$pc,$line));
        # Calls A instruction subroutine and appends result to the outString
        if($line =~ /^\@/) {
            $outString .= get_A($line, $lno);
            debug("\n");
            $lno++;
            $pc++;
            next;
        }
        # Appends the C Instruction to the out string
        $outString .= get_C($line, $lno);
        debug("\n");
        $pc++;
        $lno++;
        next;
    }
    printSymTable();
    return $outString;
}

# Returns:
#   the string containing the binary value associated with the c instruction
#   or the empty string if the c instruction is invalid
# Params: 
#   $line, the potential c instruction
#   $lno, the current line number in the src file (for debugging)
sub get_C {
    my $line = shift;
    my $lno = shift;
    debug(sprintf("Possible C-Instruction \"%s\" at line %d\n",$line,$lno));
    my $dest = "000";
    my $comp = "";
    my $jmp = "000";
    my @d_cj = split(/=/,$line); # The resulting array when line is split by '=' char
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

# Returns:
#   the string containing the binary value associated with the A instruction
#   or the empty string if the A instruction is invalid
# Params: 
#   $line, the potential A instruction
#   $lno, the current line number in the src file (for debugging)
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

# Returns:
#   The empty string to indicate that the a instruction contains illegal characters
#   or the string true to indicate the opposite
# Param: $val, the string containing to potential a instruction to be tested
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

# Prints message if debug flag is specified
# Param: $msg, the debug string
sub debug {
    my $msg = shift;
    if($options{d}) {
        print $msg;
    }
}

# Appends error string param to $errStr and increments $errNo
# Param: the error string to be appended to $errStr
sub err {
    $errStr .= shift;
    $errNo++;
}

# Prints the contents of the symbol table at the conclusion of the program if
# the l flag is specified
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

# Returns all the intruction codes read from the instruction file
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

# Prints the usage of the program then exits with the passed error number
sub printUsage {
    my $err = shift;
	print "USAGE: perl assemble.pl [-d][-h][-l] <file.asm>\n";
	exit $err;
}

# Print the contents of the options map
sub printOptions {
	foreach(keys %options) {
		printf("Option (%s) => (%s)\n",$_,$options{$_});

	}
}

