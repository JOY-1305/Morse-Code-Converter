#include <stdio.h>
#include "pico/stdlib.h"
#include "hardware/gpio.h"
#include "pico/multicore.h" // Required for using multiple cores on the RP2040.

int button_state;
int prev;
int press_time;

// Declare the main assembly code entry point.
void main_asm();

// Initialise a GPIO pin – see SDK for detail on gpio_init()
void asm_gpio_init(uint pin)
{
    gpio_init(pin);
}

// Set direction of a GPIO pin – see SDK for detail on gpio_set_dir()
void asm_gpio_set_dir(uint pin, bool out)
{
    gpio_set_dir(pin, out);
}

// Get the value of a GPIO pin – see SDK for detail on gpio_get()
bool asm_gpio_get(uint pin)
{
    return gpio_get(pin);
}

// Set the value of a GPIO pin – see SDK for detail on gpio_put()
void asm_gpio_put(uint pin, bool value)
{
    gpio_put(pin, value);
}

// Enable falling-edge interrupt – see SDK for detail on gpio_set_irq_enabled()
void asm_gpio_set_irq(uint pin)
{
    gpio_set_irq_enabled(pin, GPIO_IRQ_EDGE_FALL || GPIO_IRQ_EDGE_RISE, true);
}

// set up code to run on core 1
void core1_entry()
{
    while (1)
    {
        //
        int32_t (*func)() = (int32_t(*)())multicore_fifo_pop_blocking();
        int32_t p = multicore_fifo_pop_blocking();
        int32_t result = (*func)(p);
        multicore_fifo_push_blocking(result);
    }
}

int32_t core_1_process(int32_t fico)
{
    // always run
    while (true)
    {

        // for some reason even if the interrupt is set for falling and rising edge it still behaves as it would be set to high edge
        // so the interrupt runs in the loop while the button is pressed, continously updating the button_state

        // basically like this:

        //    button pressed down (button_state != prev && prev == 0)
        //             |
        //             V    ___ <- time untill the loop in core_1_process runs again
        //                 /
        //                /
        //               /
        //              /
        // ____________/        ______________   <- value in button_state (time)
        //                      ^
        //                      |
        //                button released (button_state == prev && button_state != 0)

        // runs when the button is pressed
        if (prev == 0 && button_state != prev)
        {
            printf("\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n"); // for clearing the cmd
            printf("\nPRESSED\nstart at:        %d", press_time);
            press_time = button_state; // set press_time value to initial time
        }

        // runs when the button is released
        if (button_state != 0 && button_state == prev)
        {
            press_time = button_state - press_time; // time pressed = current time - initial time

            printf("\nfinished at:     %d\n\nduration:        %d us\n", button_state, press_time);

            button_state = 0; // set to 0 to detect the next button press
        }

        prev = button_state;

        sleep_us(2604); // this value is for the second if not to run all the time (thats the average time the interrupt gets called again)
    }
}

// Main entry point of the application
int main()
{
    button_state = 0;
    prev = 0;

    stdio_init_all(); // Initialise all basic IO

    // initialise the c code to run on CORE 1
    multicore_launch_core1(core1_entry);
    multicore_fifo_push_blocking((uintptr_t)&core_1_process);
    multicore_fifo_push_blocking(10);

    // move the address of button_state to r1
    asm("movs r1, %0" ::"r"(&button_state));

    // run the assembly code on CORE 0
    main_asm();

    return 0; // Application return code
}
