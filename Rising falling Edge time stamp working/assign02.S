#include "hardware/regs/addressmap.h"
#include "hardware/regs/io_bank0.h"
#include "hardware/regs/timer.h"
#include "hardware/regs/m0plus.h"

.syntax unified                                                 @ Specify unified assembly syntax
.cpu    cortex-m0plus                                           @ Specify CPU type is Cortex M0+
.thumb                                                          @ Specify thumb assembly for RP2040
.global main_asm                                                @ Provide program starting address to the linker
.align 4                                                        @ Specify code alignment

.equ    DFLT_STATE_STRT, 1            @ Specify the value to start flashing
.equ    DFLT_STATE_STOP, 0            @ Specify the value to stop flashing
.equ    DFLT_ALARM_TIME, 3000000      @ Specify the default alarm timeout

.equ    GPIO_BTN_EN_MSK, 0x00400000   @ Bit-22 for RISING-edge event on GP21
.equ    GPIO_BTN_Fall_EN_MSK, 0x00800000   @ Bit-23 for falling-edge event on GP21

.equ    GPIO_BTN_EN,  21              @ Specify pin for the "enter" button
.equ    GPIO_DIR_IN,   0              @ Specify input direction for a GPIO pin
.equ    GPIO_DIR_OUT,  1              @ Specify output direction for a GPIO pin

.equ    GPIO_ISR_OFFSET, 0x74         @ GPIO is int #13 (vector table entry 29)
.equ    ALRM_ISR_OFFSET, 0x40         @ ALARM0 is int #0 (vector table entry 16)



main_asm:
    @ As well as all the things initialized here we're gonna need to call functions to do the following: 
    @ Welcome the user (C)
    @ Handle the user button input to select difficulty (ARM for logic, C for output display)
    @ Figure out how long the user as held the button and write a 0 or 1 (dot or dash) to the appropriate register (ARM)
    @ As well as these function we have to figure out how to store/call various letters and numbers in ARM

   bl      init_btns                                   @ Use asm_gpio_set_irq C function to setup falling-edge interrutps
   bl      install_alrm_isr                            @ See below
   bl    install_gpio_isr  
loop:
    b loop 

/*     bl welcome               @level design NOT Intergrated
welcome:
    bl welcome_message        @print welcome screen
    bl RGB_display_welcome    @set led blue
    bl level1            
@select_level:
                                                    
 @   b       select_level                                       
level1:
    bl      level_1_display   @ chooses what letter/number to display wi
    bl      update_lives    @ checks if you still have lives writes it to r0
  @  cmp     r0, #0         @ Player has no more lives
   @ beq     death          @ Player has died
    @bl      level_sucess   @ player has entered 5 correct answers in a row
    @cmp     r0, #1         @ player has won and will move onto level 2
    beq     level_pass_1      @
    
 @   bl      matthewsfunction   @ matthews functionw waits for the interrupt to occurs calls on Joys function and should return a bool 1 or 0 to r0  if right or wrong
    wfi                  @place holder
    bl      update_lives   @ takes value in of right or wrong answer and gets lives
    b       level1
level_pass_1:
    @bl stats       @ print out stats from previouslevel 
    @bl stats_int   @ reset live and states for next level
    bl level2

level2:
    bl      still_alive    @ checks if you still have lives writes it to r0
    cmp     r0, #0         @ Player has no more lives
    beq     death          @ Player has died
    bl      level_sucess   @ player has entered 5 correct answers in a row
    cmp     r0, #1         @ player has won 
    beq     game_won       @ Player has completed the game
    bl      level_2_display   @ chooses what letter/number to display wi
  @  bl      matthewsfunction   @ matthews functionw waits for the interrupt to occurs calls on Joys function and should return a bool 1 or 0 to r0  if right or wrong
    wfi      @place holder
    bl      update_lives   @ takes value in of right or wrong answer and gets lives
    b       level2


game_won:
    bl winning_display @prints winsecond and stats 
    wfi                @ wait until button pressed or watchdog triggered
    bl welcome

death: 
    bl death_display  @print death and stats
    wfi                 
    bl welcome      @ retur

*/


init_btns:
    push    {lr}

    movs    r0, #GPIO_BTN_EN            @ Move value of the button pin to r0  
    bl      asm_gpio_init               @ Initialize pin
    movs    r0, #GPIO_BTN_EN            @ Move value of the button pin to r0
    movs    r1, #GPIO_DIR_IN            @ Set direction as input
    bl      asm_gpio_set_dir            @ Set the direction of the input pin
    movs    r0, #GPIO_BTN_EN            @ Move value of the button pin to r0
   bl      asm_gpio_set_irq_fall       @ Set the fall and rising edhge interrupt
  

    pop     {pc}


@ Enable alarm timer interrupts and set an alarm
set_alarm:
    ldr    r1, =(TIMER_BASE + TIMER_TIMELR_OFFSET)  @ Get current timer value for relavant address
    ldr     r2,[r1]                                  @ Get current timer value for relavant address
    ldr    r1, =DFLT_ALARM_TIME                                  @ Get desired delay  
    add     r1, r1, r2                               @ Add desired delay to current timer 
    ldr     r2, =(TIMER_BASE + TIMER_ALARM0_OFFSET)  @ push desired delay to revlvant alarm adress
    str     r1, [r2]                                 @ push desired delay to revlvant alarm adress
    ldr  r2, =(TIMER_BASE + TIMER_INTE_OFFSET)   @enable alarm
    movs r1,#1                                   @enable alarm
    str   r1, [r2]                               @enable alarm
    bx      lr                                       @ exit subrouthine

 
@ Sets up the alrm_isr in the RAM vector table and enables the correct interrupt
install_alrm_isr:
    @ Get the address of the RAM vector table using the (PPB_BASE + M0PLUS_VTOR_OFFSET) register
    ldr     r2, =(PPB_BASE + M0PLUS_VTOR_OFFSET)        
    ldr     r1, [r2]                                    
    movs    r2, #ALRM_ISR_OFFSET                        
    add     r2, r1 
    @ Store the address of the alrm_isr handler to the correct offset for ALARM0 in the vector table                                     
    ldr     r0, =alrm_isr                               
    str     r0, [r2] 

    movs    r0, #1  
    @ Disable the ALARM0 IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)                   
    ldr     r1, =(PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)
    str     r0, [r1]
    @ Enable the ALARM0 IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)
    ldr     r1, =(PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)
    str     r0, [r1] 
    @ Exit subroutine   
    bx      lr 

.thumb_func
alrm_isr:

   push    {lr}                                      @ Store the link register to the stack as we will call nested subroutines
   ldr     r1, =(TIMER_BASE+TIMER_INTR_OFFSET)       @ Acknowledge interrupt has been recieved
   movs     r0 ,#1                                   @ Acknowledge interrupt has been recieved
   str     r0,[r1]                                   @ Acknowledge interrupt has been recieved

   movs    r0,r7
   bl update_lives
   ldr     r7,=0


   ldr  r2, =(TIMER_BASE + TIMER_INTE_OFFSET)       @ Enable Alarm
   movs r1,#1                                       @ Enable Alarm
   str   r1, [r2]                                   @ Enable Alarm
   
    pop     {pc}                                     @ Pop the link register from the stack to the program counter
   
    





install_gpio_isr:
    ldr     r2, =(PPB_BASE + M0PLUS_VTOR_OFFSET)         @ Get the address of the RAM vector table using the (PPB_BASE + M0PLUS_VTOR_OFFSET) register
    ldr     r1, [r2]                                    @ Make r1 point to the location of entry point of the jump table
    movs    r2, #GPIO_ISR_OFFSET                        @  Store the address of the alrm_isr handler to the correct offset for ALARM0 in the vector table
    add     r2, r1                                      @ Find the location of this interrupt in this table and store in r2
    ldr     r0, =gpio_isr                               @ Load the entry point of this interrupt into r0
    str     r0, [r2]                                    @ Set the table location of R0 as the value caluated in r2 
    ldr     r2, =(PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)   @ Disable the ALARM0 IRQ by writing the correct value (2^13) to (PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)
    ldr    r1,=8192
    str     r1 ,[r2]                                    @ Disable the ALARM0 IRQ by writing the correct value (2^13) to (PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)
    ldr     r2, =(PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)   @ Enable the ALARM0 IRQ by writing the correct value (2^13) to (PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)
    ldr    r1,=8192                                 @ Enable the ALARM0 IRQ by writing the correct value (2^13) to (PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)   
    str   r1 ,[r2]                                      @ Enable the ALARM0 IRQ by writing the correct value (2^13) to (PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)
    bx      lr                                          @ branch to the point at which the intterupt was called (stored in lr)

//
// Service the pending interrupt from the GPIO
//
.thumb_func
gpio_isr:

    push {lr}
    ldr  r2, =(IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET)    @ Read the interrupt status event from the (IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET) register
    Ldr  r1, [r2]   	                                       @ Acknowledge interrupt
    ldr  r0, =8192                                            @ Acknowledge interrupt
    str  r0,[r2]                                               @ Acknowledge interrupt
    

 
    ldr  r2,=GPIO_BTN_EN_MSK                                   @ Compare to se which button was pressed
    CMP  r2, r1                                                @ Compare to se which button was pressed
    bne  falling                                                @ Branch to end if does not match any
    ldr  r2, =(TIMER_BASE + TIMER_TIMELR_OFFSET)               @ The time stamp at rising edge
    ldr  r4 ,[r2]                                              @ The time stamp at rising edge
    ldr  r2, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)          @ Gp21 pressed so reset this interrupt
    ldr  r1,=0x400000                                          @ Gp21 pressed so reset this interrupt
    str  r1,[r2]   
    bl  finish
    
   
   
falling:                                                       @ if in flashin state branch to skip
    ldr  r2, =(TIMER_BASE + TIMER_TIMELR_OFFSET)               @ The time stamp at rising edge
    ldr  r5 ,[r2]                                              @ The time stamp at rising edge
    ldr  r2, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)          @ Gp21 pressed so reset this interrupt
    ldr  r1,=0x800000                               @Gp21 pressed so reset this interrupt
                                               @ Gp21 pressed so reset this interrupt
    str  r1,[r2]                                               @ Gp21 pressed so reset this interrupt 
    subs r3, r5, r4
    bl dot_dash
    bl finish
finish:
    pop {pc}                                                   @ Pop program counter to exit subroutine
  
dot_dash:
    push {lr}
    bl set_alarm
    ldr r0,=200000
    cmp r3,r0
    ble dot
    ldr r0,=500000
    cmp r3,r0
    bgt dash
    bl  other
dot:
    ldr r0,=1
    ldr r1,=3
    lsls r7,r1
    Eors r7,r7,r0
    bl end
dash:
    ldr r0,=7
    ldr r1,=3
    lsls r7,r1
    Eors r7,R7,r0
    bl end
other:
    ldr r0,=5
    ldr r1,=3
    lsls r7,r1
    Eors r7,R7,r0
    bl end
end:
    pop  {pc}


@ Set data alignment
.align 4


.data
state: .word   DFLT_STATE_STRT
timer: .word   DFLT_ALARM_TIME

