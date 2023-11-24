;*-------------------------------------------------------------------
;*This program starts at a flashing light stage that flashes all 8 LEDS at a frequency of 5Hz. 
;*Then, when the button is pressed, it will saignal the interrupt to cease the code and go into the interrupt handler.
;*It will print out a randomly generated number and decrement it by 10 until the value is less or equal to 0 and reset to flashing stage.
;*-------------------------------------------------------------------
				THUMB 								; Declare THUMB instruction set 
				AREA 	My_code, CODE, READONLY 	; 
				EXPORT 		__MAIN 					; Label __MAIN is used externally 
                EXPORT          EINT3_IRQHandler
				ENTRY 

__MAIN

; The following lines are similar to previous labs.
; They just turn off all LEDs 
				LDR			R10, =LED_BASE_ADR		; R10 is a  pointer to the base address for the LEDs
				MOV 		R3, #0xB0000000		; Turn off three LEDs on port 1  
				STR 		R3, [R10, #0x20]
				MOV 		R3, #0x0000007C
				STR 		R3, [R10, #0x40] 	; Turn off five LEDs on port 2 
				
				LDR			R1, =ISER0
				MOV			R2, #0x00200000
				STR 		R2, [R1]

				LDR			R1, =IO2IntEnf
				MOV			R2, #0x400
				STR 		R2, [R1]

; This line is very important in your main program
; Initializes R11 to a 16-bit non-zero value and NOTHING else can write to R11 !!
				MOV			R11, #0xABCD		; Init the random number generator with a non-zero number
LOOP 			
				
FLASHING						
				; Flash the 8 LEDs on and off
				MOV			R3, #0xFFFF       ; LED ON
				BL			DISPLAY_NUM
				
				MOV			R0, #3
				BL 			DELAY
				
				MOV			R3, #0			  ; LED OFF
				BL			DISPLAY_NUM
				
				MOV			R0, #3			
				BL 			DELAY
				
				B			FLASHING				
				B 			LOOP
				
		;
		; Your main program can appear here 
		;
				
				
;*------------------------------------------------------------------- 
; Subroutine CHECK_NUM ... Checks if the number is between 5 and 25, otherwise create a new number
;*------------------------------------------------------------------- 				
CHECK_NUM		; If the pseudorandom number is less than 2, get a new number				
				CMP			R6, #50
				BLT			LOOP
				
				; If the pseudorandom number is greater than 10, get a new number
				CMP			R6, #250
				BGT			LOOP
				
				BX 			LR


;*------------------------------------------------------------------- 
; Subroutine DISPLAY_NUM ... displays the number onto the LEDs
;*------------------------------------------------------------------- 		
DISPLAY_NUM		STMFD		R13!,{R1, R2, R4, R5, R6, R7, R14}

; Usefull commaands:  RBIT (reverse bits), BFC (bit field clear), LSR & LSL to shift bits left and right, ORR & AND and EOR for bitwise operations	
				; Initial addresses for FIOSET and FIOCLR
				LDR			R4, =FIO1SET
				LDR			R5, =FIO2SET
				LDR			R6, =FIO1CLR
				LDR			R7, =FIO2CLR
				
				; 1. Reverse the bits and turn the leds off
				RBIT		R3, R3
				EOR			R3, #-1
				STR			R3, [R10]
				
				; 2. Seperate port 1 and 2 
				; Port 1: shifts all the bits to the left, leaving us with bits 29, 30, 31
				; Then we shift it back to the right getting 28, 29, 30, 31
				; Finally we clear 30 so that we are left with bits 28, 29, 31 
				MOV			R1, R3
				LSL			R1, #5
				ASR			R1, #1
				AND 		R1, #0xB0000000
				
				; Port 2: shifts all the bits to the right by 25, leaving us with bits 0, 1, 2, 3, 4, 5, 6
				; Then we only take bits 2-6, as we don't need bits 0 and 1
				MOV 		R2, R3
				LSR			R2, #25
				AND			R2, #0x0000007C
				
				; Use FIOCLR to clear all the LEDS				
				STR			R1, [R6]
				STR			R2, [R7]
				
				; NOT the port 1 and port 2 led outputs
				EOR		 	R1, #-1
				EOR			R2, #-1
				
				; Use FIOSET to set the leds according to the port 1 and port 2 led outputs				
				STR			R1, [R4]
				STR			R2, [R5]
				
				; Reverse the R3 register again, then NOT it so we can continue incrementing it
				RBIT		R3, R3
				EOR			R3, #-1

				LDMFD		R13!,{R1, R2, R4, R5, R6, R7, R15}
				
;*------------------------------------------------------------------- 
; Subroutine RNG ... Generates a pseudo-Random Number in R11 
;*------------------------------------------------------------------- 
; R11 holds a random number as per the Linear feedback shift register (Fibonacci) on WikiPedia
; R11 MUST be initialized to a non-zero 16-bit value at the start of the program
; R11 can be read anywhere in the code but must only be written to by this subroutine
RNG 			STMFD		R13!,{R1-R3, R14} 	; Random Number Generator 
				AND			R1, R11, #0x8000
				AND			R2, R11, #0x2000
				LSL			R2, #2
				EOR			R3, R1, R2
				AND			R1, R11, #0x1000
				LSL			R1, #3
				EOR			R3, R3, R1
				AND			R1, R11, #0x0400
				LSL			R1, #5
				EOR			R3, R3, R1			; The new bit to go into the LSB is present
				LSR			R3, #15
				LSL			R11, #1
				ORR			R11, R11, R3
				LDMFD		R13!,{R1-R3, R15}

;*------------------------------------------------------------------- 
; Subroutine DELAY ... Causes a delay of 1ms * R0 times
;*------------------------------------------------------------------- 
; 		aim for better than 10% accuracy
DELAY			STMFD		R13!,{R2, R14}
		;
		; Code to generate a delay of 1mS * R0 times
		;
		
MultipleDelay		TEQ		R0, #0		; test R0 to see if it's 0 - set Zero flag so you can use BEQ, BNE
					MOV32 	R2, #0x208D5
					;MOV		R2, #1
counter				SUBS    R2, #1
					BNE		counter
					SUBS 	R0, #1
					BEQ		exitDelay
					BNE		MultipleDelay
					
exitDelay		LDMFD		R13!,{R2, R15}

; The Interrupt Service Routine MUST be in the startup file for simulation 
;   to work correctly.  Add it where there is the label "EINT3_IRQHandler
;
;*------------------------------------------------------------------- 
; Interrupt Service Routine (ISR) for EINT3_IRQHandler 
;*------------------------------------------------------------------- 
; This ISR handles the interrupt triggered when the INT0 push-button is pressed 
; with the assumption that the interrupt activation is done in the main program
EINT3_IRQHandler 	
				STMFD 		R13!, {R1, R2, R6, R7, R14}			; Use this command if you need it  
		;
		; Code that handles the interrupt 
		;
					BL 			RNG  

					MOV			R6, R11				; Store pseudorandom number into R6
					LSL			R6, #24				; Shift left then right to get the first 
					LSR			R6, #24	
					BL			CHECK_NUM			; Check if the number is between 50 and 250
					MOV			R7, R6				; Store the original random number so that we can check if there is overflow after decrementing R6
					
DECREMENT			MOV			R3, R6				; Move value of R6 into R3 so we can display it to the LEDs
					BL 			DISPLAY_NUM
					SUBS		R6, #10				; Decrement by 10
					MOV			R0, #10				; Delay by 1s
					BL			DELAY					
					
					CMP			R7, R6
					BHI			DECREMENT
					
					LDR			R1, =IO2IntClr
					MOV			R2, #0x400				; Clear on bit 10
					STR			R2, [R1]
					
					MOV			R6, #0
	
				LDMFD 		R13!, {R1, R2, R6, R7, R15} 				; Use this command if you used STMFD (otherwise use BX LR) 


;*-------------------------------------------------------------------
; Below is a list of useful registers with their respective memory addresses.
;*------------------------------------------------------------------- 
LED_BASE_ADR	EQU 	0x2009c000 		; Base address of the memory that controls the LEDs 
PINSEL3			EQU 	0x4002C00C 		; Pin Select Register 3 for P1[31:16]
PINSEL4			EQU 	0x4002C010 		; Pin Select Register 4 for P2[15:0]
FIO1DIR			EQU		0x2009C020 		; Fast Input Output Direction Register for Port 1 
FIO2DIR			EQU		0x2009C040 		; Fast Input Output Direction Register for Port 2 
FIO1SET			EQU		0x2009C038 		; Fast Input Output Set Register for Port 1 
FIO2SET			EQU		0x2009C058 		; Fast Input Output Set Register for Port 2 
FIO1CLR			EQU		0x2009C03C 		; Fast Input Output Clear Register for Port 1 
FIO2CLR			EQU		0x2009C05C 		; Fast Input Output Clear Register for Port 2 
IO2IntEnf		EQU		0x400280B4		; GPIO Interrupt Enable for port 2 Falling Edge 
IO2IntClr		EQU		0x400280AC		; GPIO Interrupt Clear for port 2 
ISER0			EQU		0xE000E100		; Interrupt Set-Enable Register 0 

				ALIGN 

				END 
