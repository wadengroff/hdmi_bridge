//
//    Date Created : 09/19/2025
//    Author       : Wade Groff
//    
//    Description :
//        Takes in a pushbutton signal from the IO port, debounces it, and outputs its state,
//        rising edge, and falling edge.
//
//
//
//
//
//    Revisions :
//
//    Date       Who       Description
//    ------     ---      -----------------------------------------------------------
//    091925     wng      1. Created initial file.
//
//


module button_debouncer #(parameter DEBOUNCE_CYCLES = 100) (
    input logic clk_p,
    input logic button_in_p,
    output logic button_state_p,
    output logic button_rising_edge_p,
    output logic button_falling_edge_p
);

// double register for metastability
(*ASYNC_REG = "TRUE"*) logic button_in_reg0;
(*ASYNC_REG = "TRUE"*) logic button_in_reg1;

always_ff @(posedge clk_p) begin
    button_in_reg0 <= button_in_p;
    button_in_reg1 <= button_in_reg0;
end


logic [9:0] debounce_cntr;
logic button_state_reg = 0;


always_ff @(posedge clk_p) begin

    button_rising_edge_p <= 0;
    button_falling_edge_p <= 0;
    button_state_reg <= button_state_reg;

    if (button_in_reg1 != button_state_reg) begin
        debounce_cntr <= debounce_cntr + 1;

        if (debounce_cntr == DEBOUNCE_CYCLES) begin
            button_state_reg <= button_in_reg1;
            button_rising_edge_p <= button_in_reg1;
            button_falling_edge_p <= ~button_in_reg1;
        end

    end else begin
        debounce_cntr <= 0;
    end

end

endmodule
