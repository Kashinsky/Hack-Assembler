// This file is part of www.nand2tetris.org
// and the book "The Elements of Computing Systems"
// by Nisan and Schocken, MIT Press.
// File name: projects/04/Mult.asm

// Multiplies R0 and R1 and stores the result in R2.
// (R0, R1, R2 refer to RAM[0], RAM[1], and RAM[3], respectively.)

// Put your code here.
// Setup
@R0
D=M
@i
M=D-1
@total
M=0
// Main Loop
(loop) 
@i
D=M
// Checks if i < 0, Jumps to end if true
@almostend
D;JLT
// Adds value in R1 to total
@R1
D=M
@total
M=D+M
// Decrements i
@i
M=M-1
@loop
0;JMP
// Writes to R2
(almostend)
@total
D=M
@R2
M=D
@end
0;JMP
(end)
@end
0;JMP

