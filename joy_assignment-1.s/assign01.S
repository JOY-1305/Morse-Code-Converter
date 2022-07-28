#include "hardware/regs/addressmap.h"
#include "hardware/regs/io_bank0.h"
#include "hardware/regs/timer.h"
#include "hardware/regs/m0plus.h"

.syntax unified
.cpu    cortex-m0plus
.thumb
.global main_asm
.align  4

.equ    DFLT_STATE_STRT, 1            @ set the value to start blinking
.equ    DFLT_STATE_STOP, 0            @ set the value to stop blinking
.equ    DFLT_ALARM_TIME, 1000000      @ set the default alarm timeout 

.equ    GPIO_BTN_DN_MSK, 0x00040000   @ the 18th-bit for falling-edge event on GP20 is passed
.equ    GPIO_BTN_EN_MSK, 0x00400000   @ the 22nd-bit for falling-edge event on GP21 is passed
.equ    GPIO_BTN_UP_MSK, 0x04000000   @ the 26th-bit for falling-edge event on GP22 is passed

.equ    GPIO_BTN_DN,  20              @ pin for the "btn_low" button is set
.equ    GPIO_BTN_EN,  21              @ pin for the "enter" button is set
.equ    GPIO_BTN_UP,  22              @ pin for the "btn_high" button is set
.equ    GPIO_LED_PIN, 25              @ pin for the built-in LED is set
.equ    GPIO_DIR_IN,   0              @ input direction for a GPIO pin 
.equ    GPIO_DIR_OUT,  1              @ output direction for a GPIO pinA


.equ    LED_VAL_ON,    1              @ 1 turns the LED "on"
.equ    LED_VAL_OFF,   0              @ 0 turns the LED "off"

.equ    GPIO_ISR_OFFSET, 0x74         @ GPIO is int #13 in vector table entry 29
.equ    ALRM_ISR_OFFSET, 0x40         @ ALARM0 is int #0 in vector table entry 16


@ main fuction that fires up assembly language
main_asm:
    bl    init_leds                              @ subroutine is called to initailize the LEDS
    bl    init_btns                              @ subroutine is called to initailize the GPIO input pins
    bl    install_alrm_isr                       @ subroutine is called to initailize the alarm isr
    bl    install_gpio_isr                       @ subroutine is called to initailize the GPIO isr
    ldr   r4, =DFLT_ALARM_TIME                   @ a alarm delay is set
    bl    set_alarm                              @ a new alarm is set
    ldr  r2, =(TIMER_BASE + TIMER_INTE_OFFSET)   @ enable alarm
    movs r1,#1                                   @ enable alarm
    str   r1, [r2]                               @ enable alarm
loop:
    wfi                                          @ Wait here for interrupt
    b     loop                



init_leds:
    push    {lr}                @ link register is stored in the stack
    movs    r0, #GPIO_LED_PIN   @ this value is the GPIO BUTTON pin on the PI PICO board
    bl      asm_gpio_init       @ subroutine is called to initialise the GPIO pin specified by r0
    movs    r0, #GPIO_LED_PIN   @ this is the GPIO LED pin on the PI PICO board
    movs    r1, #GPIO_DIR_OUT   @ GPIO pin is setup as an output pin
    bl      asm_gpio_set_dir    @ subroutine is called to set the GPIO pin specified by r0 to state specified by r1
    pop     {pc}                @ link register is popped from the stack

init_btns:
    push    {lr}                        @ link register is stored to the stack 
    movs    r0, #GPIO_BTN_EN            @ this value is the GPIO BUTTON pin on the PI PICO board
    bl      asm_gpio_init               @ subroutine specified by r0 is called to init GPIO pin
    movs    r0, #GPIO_BTN_EN            @ This is the GPIO LED pin on the PI PICO board
    movs    r1, #GPIO_DIR_IN            @ GPIO pin to be setup as an output pin
    bl      asm_gpio_set_dir            @ subroutine specified by r1 is called to init GPIO pin 
    movs    r0, GPIO_DIR_IN             @ This value is the GPIO BUTTON pin on the PI PICO board
    bl      asm_gpio_set_dir            @ subroutine specified by r1 is called to init GPIO pin 
     movs    r0, #GPIO_BTN_EN           @ This value is the GPIO BUTTON pin on the PI PICO board
    bl      asm_gpio_set_irq            @ the subroutine is called to set falling-edge interrupt

    movs    r0, #GPIO_BTN_UP            @ This is the GPIO BUTTON pin on the PI PICO board
    bl      asm_gpio_init               @ the subroutine is called to init the GPIO pin specified by r0
    movs    r0, #GPIO_BTN_UP            @ This is the GPIO LED pin on the PI PICO board
    movs    r1, #GPIO_DIR_IN            @ GPIO pin to be setup as an output pin
    bl      asm_gpio_set_dir            @ the subroutine is called to set the GPIO pin specified by r0 to state specified by r1
    movs    r0, GPIO_DIR_IN             @ This is the GPIO BUTTON pin on the PI PICO board
    bl      asm_gpio_set_dir            @ the subroutine is called to set the GPIO pin specified by r0 to state specified by r1
    movs    r0, #GPIO_BTN_UP            @ This is the GPIO BUTTON pin on the PI PICO board
    bl      asm_gpio_set_irq            @ the subroutine is called to set falling-edge interrupt

    movs    r0, #GPIO_BTN_DN            @ This is the GPIO BUTTON pin on the PI PICO board
    bl      asm_gpio_init               @ the subroutine is called to init the GPIO pin specified by r0
    movs    r0, #GPIO_BTN_DN            @ This is the GPIO LED pin on the PI PICO board
    movs    r1, #GPIO_DIR_IN            @ GPIO pin to be setup as an output pin
    bl      asm_gpio_set_dir            @ the subroutine is called to set the GPIO pin specified by r0 to state specified by r1
    movs    r0, GPIO_DIR_IN             @ This is the GPIO BUTTON pin on the PI PICO board
    bl      asm_gpio_set_dir            @ the subroutine is called to set the GPIO pin specified by r0 to state specified by r1
    movs    r0, #GPIO_BTN_DN            @ This is the GPIO BUTTON pin on the PI PICO board
    bl      asm_gpio_set_irq            @ the subroutine is called to set falling-edge interrupt
     
    pop     {pc}                        @ Pop the link register from stack counter  
    
set_alarm:
    
   
    
    ldr     r1, =(TIMER_BASE + TIMER_TIMELR_OFFSET)  @ fetches current timer value for relavant address
    ldr     r2,[r1]                                  @ fetches current timer value for relavant address
    movs     r1, r4                                  @ fetches desired delay  
    add     r1, r1, r2                               @ Add desired delay to current timer 
    ldr     r2, =(TIMER_BASE + TIMER_ALARM0_OFFSET)  @ push desired delay to revlvant alarm adress
    str     r1, [r2]                                 @ push desired delay to revlvant alarm adress
    bx      lr                                       @ exit subrouthine

install_alrm_isr:
    ldr     r2, =(PPB_BASE + M0PLUS_VTOR_OFFSET)        @ fetches the address of the RAM vector table using the (PPB_BASE + M0PLUS_VTOR_OFFSET) register
    ldr     r1, [r2]                                    @ Make r1 point to the location of entry point of the jump table
    movs    r2, #ALRM_ISR_OFFSET                        @ Store the address of the alrm_isr handler to the correct offset for ALARM0 in the vector table
    add     r2, r1                                      @ Find the location of this interrupt in this table and store in r2
    ldr     r0, =alrm_isr                               @ Load the entry point of this interrupt into r0
    str     r0, [r2]                                    @ Set the table location of R0 as the value caluated in r2
    ldr     r2, =(PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)   @ Disable the ALARM0 IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)
    movs    r1, #1                                      @ Disable the ALARM0 IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)
    str     r1 ,[r2]                                    @ Disable the ALARM0 IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ICPR_OFFSET)
    ldr     r2, =(PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)   @ Enable the ALARM0 IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)
    movs    r1, #1                                      @ Enable the ALARM0 IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)
    str     r1 ,[r2]                                    @ Enable the ALARM0 IRQ by writing the correct value to (PPB_BASE + M0PLUS_NVIC_ISER_OFFSET)
    bx      lr                                          @ Branch to the point at which the intterupt was called (stored in lr)

.thumb_func
alrm_isr:
 
   push    {lr}                                      @ Store the link register to the stack as we will call nested subroutines
   ldr     r1, =(TIMER_BASE+TIMER_INTR_OFFSET)       @ Acknowledge interrupt has been recieved
   movs     r0 ,#1                                   @ Acknowledge interrupt has been recieved
   str     r0,[r1]                                   @ Acknowledge interrupt has been recieved
   movs    r0, #GPIO_LED_PIN                         @ Set the LED GPIO pin number to r0 for use by asm_gpio_get
    bl      asm_gpio_get                             @ fetches current the value of the LED GPIO pin (returns to r0)
   cmp     r0, #LED_VAL_OFF                          @ Check if the LED GPIO pin value is "off"
   beq     led_set_on                                @ If it is "off" then then jump code to to turn it on
led_set_off:
  movs    r1, #LED_VAL_OFF                           @ The LED is currently "on" so we want to turn it "off"
  b       led_set_state                              @ Jump to portion of code where we set the state of the LED
led_set_on:
     movs    r1, #LED_VAL_ON                         @ The LED is currently "off" so we want to turn it "on"
led_set_state:
    movs    r0, #GPIO_LED_PIN                        @ Set the LED GPIO pin number to r0 for use by asm_gpio_put
    bl      asm_gpio_put                             @ Update the the value of the LED GPIO pin (based on value in r1)  
    bl    set_alarm                                  @ reset alarm
    ldr  r2, =(TIMER_BASE + TIMER_INTE_OFFSET)       @ Enable Alarm
    movs r1,#1                                       @ Enable Alarm
    str   r1, [r2]                                   @ Enable Alarm
    ldr     r0, =msg1                                @ LED toggled message is displayed on console
    bl      printf                                   @ LED toggled message is displayed on console
    pop     {pc}                                     @ Pop the link register from the stack to the program counter


install_gpio_isr:
   ldr     r2, =(PPB_BASE + M0PLUS_VTOR_OFFSET)         @ address of the RAM vector table is fetched using the (PPB_BASE + M0PLUS_VTOR_OFFSET) register
    ldr     r1, [r2]                                    @ r1 is pointed to the location of entry point of the jump table
    movs    r2, #GPIO_ISR_OFFSET                        @ the address of the alrm_isr handler is stored to the correct offset for ALARM0 in the vector table
    add     r2, r1                                      @ Finds the location of this interrupt in this table and store in r2
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
    // 
    push {lr}
    ldr  r2, =(IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET)    @ Read the interrupt status event from the (IO_BANK0_BASE + IO_BANK0_PROC0_INTS2_OFFSET) register
    Ldr  r1, [r2]                                              @ interruption is acknowledged
    ldr  r0 ,=8192                                             @ interruption is acknowledged
    str  r0,[r2]                                               @ interruption is acknowledged
    ldr  r2, =(TIMER_BASE + TIMER_INTE_OFFSET)                 @ fetches current blinking state of Led
    ldr  r0 ,[r2]                                              @ fetches current blinking state of Led
    ldr  r2,=GPIO_BTN_DN_MSK                                   @ button tapped are compared
    CMP  r2, r1                                                @ button tapped are compared
    beq  btn_low                                               @ Branch to btn_low if gp21 pressed
    ldr  r2,=GPIO_BTN_UP_MSK                                   @ button tapped are compared
    CMP  r2, r1                                                @ button tapped are compared
    beq  btn_high                                              @ Branch to btn_high if gp22 pressed
    ldr  r2,=GPIO_BTN_EN_MSK                                   @ button tapped are compared
    CMP  r2, r1                                                @ button tapped are compared
    bne  btn_final                                             @ Branch to end if does not match any
    ldr  r2, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)          @ Gp21 pressed to reset this interrupt
    ldr  r1,=0x400000                                          @ Gp21 pressed to reset this interrupt
    str  r1,[r2]                                               @ Gp21 pressed to reset this interrupt
    ldr  r2,=DFLT_STATE_STOP                                   @ Load in not blinking state reference
    cmp  r0, r2                                                @ Compare current LED state with off state
    bne  dsbl_nxt                                              @ if in flashin state branch to dsbl_nxt
    ldr  r2, =(TIMER_BASE + TIMER_INTE_OFFSET)                 @ the pause for Enable Alarm
    movs r1,#1                                                 @ the pause for Enable Alarm
    str  r1, [r2]                                              @ the pause for Enable Alarm
    ldr  r0, =msg2                                             @ Prints flash enable message
    bl   printf                                                @ Prints flash enable message
    bl   btn_final                                             @ Branch to btn_final
dsbl_nxt:
    ldr  r2, =(TIMER_BASE + TIMER_INTE_OFFSET)                 @ Disable Alarm interupt
    movs r1,#0                                                 @ Disable Alarm interupt
    str  r1, [r2]                                              @ Disable Alarm interupt
    ldr  r0, =msg3                                             @ Print flash Disabled message
    bl   printf                                                @ Print flash Disabled message
    bl   btn_final                                                @ Branch to btn_final
btn_low:
    ldr  r2, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)          @ Gp20 reset this interrupt when presed
    ldr  r1,=0x40000                                           @ Gp20 reset this interrupt when presed
    str  r1,[r2]                                               @ Gp20 reset this interrupt when presed
    ldr  r2,=DFLT_STATE_STOP                                   @ Load in reference led flash disable state
    cmp  r0, r2                                                @ current state and off state is compared
    bne  dsbl_nxt2                                             @ branch to dsbl_nxt 2 if not equal
    ldr  r4, =DFLT_ALARM_TIME                                  @ If equal reset toggle interval to default
    ldr  r0, =msg4                                             @ Print interval reset message
    bl   printf                                                @ Print interval reset message
    bl   btn_final                                             @ Print interval reset message
dsbl_nxt2:   
    lsrs r4, r4,#1                                             @ Divide interval by two by shifting to the right
    ldr  r0, =msg5                                             @ Print interval divided message
    bl   printf                                                @ Print interval divided message
    bl   btn_final                                             @ Branch to end
btn_high:
    ldr  r2, =(IO_BANK0_BASE + IO_BANK0_INTR2_OFFSET)          @ Gp21 reset this interrupt when presed
    ldr  r1,=0x4000000                                         @ Gp21 reset this interrupt when presed
    str  r1,[r2]                                               @ Gp21 reset this interrupt when presed
    ldr  r2,=DFLT_STATE_STOP                                   @ Load in reference led flash disable state
    cmp  r0, r2                                                @ current state and off state is compared
    bne  dsbl_nxt3                                             @ branch to dsbl_nxt 2 if not equal
    ldr  r4, =DFLT_ALARM_TIME                                  @ If equal reset toggle interval to default
    ldr  r0, =msg4                                             @ Print interval reset message
    bl   printf                                                @ Print interval reset message
    bl   btn_final                                                @ Branch to btn_final
dsbl_nxt3:
    lsls r4, r4,#1                                             @ Increase by a factor of 2 by shifting interval to the right by 1
    ldr  r0, =msg6                                             @ Print Interval Increase message
    bl   printf                                                @ Print Interval Increase message
    bl   btn_final                                                @ Branch to btn_final  
btn_final:  
    bl set_alarm                                               @ Reset Alarm time
    pop {pc}                                                   @ Pop program counter to exit subroutine
 

.align 4
msg1:    .asciz "LED Toggled.\n"
msg2:    .asciz "LED is in flashing state.\n"
msg3:    .asciz "LED is in not flashing state.\n"
msg4:    .asciz "Time interval reset to default.\n"
msg5:    .asciz "Time interval decressed by a factor of two.\n"
msg6:    .asciz "Time interval incressed by a factor of two.\n"

.data
lstate: .word   DFLT_STATE_STRT
ltimer: .word   DFLT_ALARM_TIME
