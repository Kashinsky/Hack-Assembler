#!usr/bin/perl
use strict;

# Hack assembler reserved labels
my %reservedLabels = ();
# Hack assembler computation codes
my %compCodes = ();
# Hack assembler destination codes
my %destCodes = ();
# Hack assembler jump codes
my %jumpCodes = ();

if(scalar @ARGV != 1) {
    print "USAGE: perl assemble.pl <file.asm>\n";
    exit 1;
}

my $file = $ARGV[0];
getInstructions();
processFile($file);

sub getInstructions {
    open(my $FH, "<instructions") or die "Failed to open instructions file! Is it even there?!\nCroaking...";
    my $secC = -1;
    my $lno = 1;
    while(<$FH>) {
        my $line = $_;
        if(substr($line,0,1) eq "#" || $line eq "\n") {
            printf("[%d] SKIPPED: %s\n",$lno, $line);
            $lno++;
            next;
        }
        if(substr($line,0,1) eq "\"") {
            printf("[%d][%d] SECTION: %s\n",$lno,(++$secC), $line);
            $lno++;
            next;
        }
            my @instruction = split(/\s+/,$line);
            printf ("[%d] LINE: %s\n",$lno,$line);
            printf ("Instruction size: %d\n", scalar @instruction);
            printf ("Address of word (%s) = (%015b)\n",$instruction[0],$instruction[1]);
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
    foreach(keys %compCodes) {
        printf("LABEL:%s\t VALUE:%s\n",$_, $reservedLabels{$_});
    }
}

sub processFile {
    my $file = shift;

}
