#include "hardware/regs/addressmap.h"
#include "hardware/regs/io_bank0.h"
#include "hardware/regs/timer.h"
#include "hardware/regs/m0plus.h"

.syntax unified                                                 @ Specify unified assembly syntax
.cpu    cortex-m0plus                                           @ Specify CPU type is Cortex M0+
.thumb                                                          @ Specify thumb assembly for RP2040
.global main_asm                                                @ Provide program starting address to the linker
.align 4                                                        @ Specify code alignment

.equ    GPIO_BTN_EN_MSK, 0x00400000   @ Bit-22 for falling-edge event on GP21

.equ    GPIO_BTN,  21                 @ Specify pin for the "enter" button
.equ    GPIO_DIR_IN,   0              @ Specify input direction for a GPIO pin
.equ    GPIO_DIR_OUT,  1              @ Specify output direction for a GPIO pin

.equ    GPIO_ISR_OFFSET, 0x74         @ GPIO is int #13 (vector table entry 29)

main_asm:
    ldr     r0, =button_addr                            @ set r0 to the address of button_addr variable
    str     r1, [r0]                                    @ store the button_state address in r1 as the value of button_addr 
    bl      init_btns                                   @ Use asm_gpio_set_irq C function to setup falling-edge interrutps
    bl      install_gpio_isr                            @ See below


loop:  
    wfi                                                 @ Wait for interrupt
    b       loop                                        @ Loop forever

init_btns:
    push    {lr}
    movs    r0, #GPIO_BTN               @ Move value of the button pin to r0  
    bl      asm_gpio_init               @ Initialize pin
    movs    r0, #GPIO_BTN               @ Move value of the button pin to r0
    movs    r1, #GPIO_DIR_IN            @ Set direction as input
    bl      asm_gpio_set_dir            @ Set the direction of the input pin
    movs    r0, #GPIO_BTN               @ Move value of the button pin to r0
    bl      asm_gpio_set_irq            @ Set the falling edge inturrupt on the pin
    pop     {pc}


install_gpio_isr:
    ldr     r2, =(PPB_BASE + M0PLUS_VTOR_OFFSET)            @ set r2 to address of the vector table
    ldr     r1, [r2]                                        @ load it to r1
    movs    r2, #GPIO_ISR_OFFSET                            @ move the gpio offset to r2
    add     r2, r1                                          @ add it to vector table offset
    ldr     r0, =gpio_isr                                   @ load address of gpio_isr to r0
    str     r0, [r2]                                        @ store the address to r2

    ldr     r0, =8192                                       @ value to disable GPIO IRQ    
    ldr     r1, =(PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)       @ set r1 to GPIO IRQ Interrupt Clear-Pending Register
    str     r0, [r1]                                        @ store the value to clear 
    ldr     r1, =(PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)       @ set r1 to GPIO IRQ set enable register
    str     r0, [r1]                                        @ store the value to enable
    bx      lr
     
.thumb_func


@ interrupt gets called the whole duration of the button press
@ it updates the button_state with the current time recorded by the system

gpio_isr:

    ldr     r2, =(IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET)        @ set r2 to offset of Interrupt status after masking & forcing for proc0
    ldr     r3, [r2]                                                  @ load its value to r3
 
    ldr     r0, =button_addr                                          @ set r0 to the address of button_addr variable
    ldr     r2, [r0]                                                  @ set r2 to the value of button_addr (address of button_state)
    ldr     r1, =(TIMER_BASE + TIMER_TIMELR_OFFSET)                   @ set r1 to the address of TIMELR (system timestamp)
    ldr     r1, [r1]                                                  @ set r1 to the value of TIMELR
    str     r1, [r2]                                                  @ store the TIMELR value to button_state variable 
             
    ldr     r3, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)              @ load the address of raw interrupt offset INTR2
    str     r2, [r3]                                                  @ store the pin number of gpio to disable the interrupt
    bx      lr

@ Set data alignment
.data
button_addr: .word   1
    .align 4
