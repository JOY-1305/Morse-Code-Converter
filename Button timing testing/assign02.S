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
.equ    DFLT_ALARM_TIME, 1000000      @ Specify the default alarm timeout

.equ    GPIO_BTN_EN_MSK, 0x00400000   @ Bit-22 for RISING-edge event on GP21
.equ    GPIO_BTN_Fall_EN_MSK, 0x00200000   @ Bit-22 for falling-edge event on GP21

.equ    GPIO_BTN_EN,  21              @ Specify pin for the "enter" button
.equ    GPIO_DIR_IN,   0              @ Specify input direction for a GPIO pin
.equ    GPIO_DIR_OUT,  1              @ Specify output direction for a GPIO pin

.equ    GPIO_ISR_OFFSET, 0x74         @ GPIO is int #13 (vector table entry 29)
.equ    ALRM_ISR_OFFSET, 0x40         @ ALARM0 is int #0 (vector table entry 16)


@ Entry point to the ASM portion of the program
main_asm:
    @ As well as all the things initialized here we're gonna need to call functions to do the following: 
    @ Welcome the user (C)
    @ Handle the user button input to select difficulty (ARM for logic, C for output display)
    @ Figure out how long the user as held the button and write a 0 or 1 (dot or dash) to the appropriate register (ARM)
    @ As well as these function we have to figure out how to store/call various letters and numbers in ARM

    bl      init_btns                                   @ Use asm_gpio_set_irq C function to setup falling-edge interrutps
   @ bl      install_alrm_isr                            @ See below
   @ bl      set_alarm                                   @ Set a new alarm
    bl    install_gpio_isr  
    ldr     r2, =(TIMER_BASE + TIMER_INTE_OFFSET)       @ Enable alarm timer interrupts using the (TIMER_BASE + TIMER_INTE_OFFSET) register
    movs    r1, #1
    str     r1, [r2]
loop:
    wfi                                                 @ Wait for interrupt
    b       loop                                        @ Infiite loop for now



init_btns:
    push    {lr}

    movs    r0, #GPIO_BTN_EN            @ Move value of the button pin to r0  
    bl      asm_gpio_init               @ Initialize pin
    movs    r0, #GPIO_BTN_EN            @ Move value of the button pin to r0
    movs    r1, #GPIO_DIR_IN            @ Set direction as input
    bl      asm_gpio_set_dir            @ Set the direction of the input pin
    movs    r0, #GPIO_BTN_EN            @ Move value of the button pin to r0
    bl      asm_gpio_set_irq_fall       @ Set the falling edge inturrupt on the pin
    bl      asm_gpio_set_irq_rise       @ Set the rising edge inturrupt on the pin

    pop     {pc}


@ Enable alarm timer interrupts and set an alarm
set_alarm:
    @ Get the current timer count from (TIMER_BASE + TIMER_TIMELR_OFFSET) register
    ldr     r1, =(TIMER_BASE + TIMER_TIMELR_OFFSET)
    ldr     r2, [r1]
    @ Add the time delay you want to wait for to the current timer count
    ldr     r1, =timer
    ldr     r3, [r1]
    add     r3, r3, r2
    
    @ Push the updated value to (TIMER_BASE + TIMER_ALARM0_OFFSET)
    ldr     r2, =(TIMER_BASE + TIMER_ALARM0_OFFSET)
    str     r3, [r2]
    @ Exit subroutine
    bx      lr


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
@ Service the pending interrupt from the ALARM0 TIMER
alrm_isr:
    push    {lr}  
    @ Disable pending interrupt from TIMER by writing correct value to (TIMER_BASE + TIMER_INTR_OFFSET)                
    ldr     r1, =(TIMER_BASE + TIMER_INTR_OFFSET)
    movs    r0, #1
    str     r0, [r1]
    @ Check the state of button 21, if its been pressed do something
    ldr     r2, =state
    ldr     r3, [r2]
    cmp     r3, #DFLT_STATE_STRT
    beq     set_new_alrm 
    @ Put a function here to do something
    

@ Set a new alarm
 set_new_alrm:           
    bl      set_alarm
    @ Disable pending interrupt from TIMER by writing correct value to (TIMER_BASE + TIMER_INTR_OFFSET)  
    ldr     r1, =(TIMER_BASE + TIMER_TIMELR_OFFSET)
    movs    r0, #1
    str     r0, [r1]
 
    pop     {pc}   



install_gpio_isr:
    ldr     r2, =(PPB_BASE + M0PLUS_VTOR_OFFSET)         @ Get the address of the RAM vector table using the (PPB_BASE + M0PLUS_VTOR_OFFSET) register
    ldr     r1, [r2]                                    @ Make r1 point to the location of entry point of the jump table
    movs    r2, #GPIO_ISR_OFFSET                        @  Store the address of the alrm_isr handler to the correct offset for ALARM0 in the vector table
    add     r2, r1                                      @ Find the location of this interrupt in this table and store in r2
    ldr     r0, =gpio_isr                               @ Load the entry point of this interrupt into r0
    str     r0, [r2]                                    @ Set the table location of R0 as the value caluated in r2 
    ldr     r2, =(PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)   @ Disable the ALARM0 IRQ by writing the correct value (2^13) to (PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)
    ldr    r1, =8192                                    @ Disable the ALARM0 IRQ by writing the correct value (2^13) to (PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)
    str     r1 ,[r2]                                    @ Disable the ALARM0 IRQ by writing the correct value (2^13) to (PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)
    ldr     r2, =(PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)   @ Enable the ALARM0 IRQ by writing the correct value (2^13) to (PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)
    ldr    r1, =8192                                    @ Enable the ALARM0 IRQ by writing the correct value (2^13) to (PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)   
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
    ldr  r0 ,=8192                                             @ Acknowledge interrupt
    str  r0,[r2]                                               @ Acknowledge interrupt
    

 
    ldr  r2,=GPIO_BTN_EN_MSK                                   @ Compare to se which button was pressed
    CMP  r2, r1                                                @ Compare to se which button was pressed
    bne  falling                                                @ Branch to end if does not match any
    ldr  r2, =(TIMER_BASE + TIMER_TIMELR_OFFSET)               @ The time stamp at rising edge
    ldr  r4 ,[r2]                                              @ The time stamp at rising edge
    ldr  r2, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)          @ Gp21 pressed so reset this interrupt
    ldr  r1,=0x400000                                          @ Gp21 pressed so reset this interrupt
    str  r1,[r2]                                               @ Gp21 pressed so reset this interrupt
    bl  finish
    
   
   
falling:                                                       @ if in flashin state branch to skip
    ldr  r2, =(TIMER_BASE + TIMER_TIMELR_OFFSET)               @ The time stamp at rising edge
    ldr  r5 ,[r2]                                              @ The time stamp at rising edge
    ldr  r2, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)          @ Gp21 pressed so reset this interrupt
    ldr  r1,=GPIO_BTN_Fall_EN_MSK                               @ Gp21 pressed so reset this interrupt
    str  r1,[r2]                                               @ Gp21 pressed so reset this interrupt 
    subs r1, r4,r5
  
    bl finish
finish:
    pop {pc}                                                   @ Pop program counter to exit subroutine
 



@ Set data alignment
.align 4


.data
state: .word   DFLT_STATE_STRT
timer: .word   DFLT_ALARM_TIME

