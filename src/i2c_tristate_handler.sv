//
//    Date Created : 07/28/2025
//    Author       : Wade Groff
//    
//    Description :
//        Module to keep track of I2C states and drive tristate enable signals SDA lines.
//        Necessary because of a feedback loop problem before.
//
//
//
//
//    Revisions :
//
//    Date       Who       Description
//    ------     ---      -----------------------------------------------------------
//    072825     wng      1. Created initial file.
//
//
//
//
//
//
//

module i2c_tristate_handler (
    input logic clk_p,
    input logic i2c_scl_p,
    input logic controller_sda_p,
    input logic subordinate_sda_p,
    output logic controller_sda_ten_p,
    output logic subordinate_sda_ten_p,
    output logic [2:0] i2c_state_p
);

typedef enum logic [2:0] {
    IDLE      = 3'b000,
    ADDR      = 3'b001,
    RW_EN     = 3'b010,
    START_ACK = 3'b011,
    ACK       = 3'b100,
    RDATA     = 3'b101,
    WDATA     = 3'b110
} i2c_state_t;

i2c_state_t i2c_state_reg_s = IDLE;
i2c_state_t i2c_state_s;

assign i2c_state_p = i2c_state_reg_s;

logic i2c_scl_reg_s, controller_sda_reg_s, subordinate_sda_reg_s;
logic risedge_scl_s, risedge_controller_s, risedge_subordinate_s;
logic falledge_scl_s, falledge_controller_s, falledge_subordinate_s;

logic [1:0] controller_cntr_s = 0;
logic [1:0] subordinate_cntr_s = 0;
logic controller_sda_debounce_s;
logic subordinate_sda_debounce_s;


logic [5:0] bit_ind_reg_s = 0;
logic [5:0] bit_ind_s;

logic [6:0] i2c_address_reg_s;
logic [6:0] i2c_address_s;

logic [7:0] rdata_reg_s;
logic [7:0] rdata_s;

logic [7:0] wdata_reg_s;
logic [7:0] wdata_s;

logic [2:0] scl_high_cntr_s = 0;
logic scl_held_high_s = 0;

logic rd_en_reg_s;
logic rd_en_s;

logic wr_en_reg_s;
logic wr_en_s;


// Keep track of scl being high for >8 clock cycles
// Used to avoid synchronization issues during state transitions
always_ff @(posedge clk_p) begin
    if (!i2c_scl_reg_s) begin
        scl_high_cntr_s <= 0;
        scl_held_high_s <= 0;
    end else begin
        if (scl_high_cntr_s == 7) begin
            scl_high_cntr_s <= 7;
            scl_held_high_s <= 1;
        end else begin
            scl_high_cntr_s <= scl_high_cntr_s + 1;
            scl_held_high_s <= 0;
        end
    end
end



// Make sure that transitions are done after, avoid problems with start/stop conditions
always_ff @(posedge clk_p) begin

    controller_sda_debounce_s <= controller_sda_debounce_s;
    subordinate_sda_debounce_s <= subordinate_sda_debounce_s;

    if (controller_sda_debounce_s != controller_sda_p) begin
        controller_cntr_s <= controller_cntr_s + 1;
        if (controller_cntr_s == 3) begin
            controller_sda_debounce_s <= controller_sda_p;
        end
    end else begin
        controller_cntr_s <= 0;
    end

    if (subordinate_sda_debounce_s != subordinate_sda_p) begin
        subordinate_cntr_s <= subordinate_cntr_s + 1;
        if (subordinate_cntr_s == 3) begin
            subordinate_sda_debounce_s <= subordinate_sda_p;
        end
    end else begin
        subordinate_cntr_s <= 0;
    end
end


// combinational block for next state conditions
always_comb begin

    i2c_state_s = i2c_state_reg_s;
    bit_ind_s = bit_ind_reg_s;
    i2c_address_s = i2c_address_reg_s;
    rd_en_s = rd_en_reg_s;
    wr_en_s = wr_en_reg_s;

    // if the controller line is released while scl is high, that is the stop condition
    // use scl_held_high_s (active when scl has been high for 8 clock cycles) to avoid synchronization problems
    //    when going between states
    if (risedge_controller_s && scl_held_high_s) begin
        
        i2c_state_s = IDLE;

    end else if (falledge_controller_s && scl_held_high_s) begin
        
        bit_ind_s = 0;
        i2c_state_s = ADDR;

    end else begin

        case (i2c_state_reg_s)

            IDLE: begin
                if (scl_held_high_s && falledge_controller_s) begin
                    i2c_state_s = ADDR;
                    bit_ind_s = 0;
                end
            end

            ADDR: begin
                // sample data on the rising edge (pls work this should work with normal i2c standard)
                if (risedge_scl_s) begin

                    // put new data into address shift register
                    i2c_address_s = {i2c_address_reg_s[5:0], controller_sda_debounce_s};
                    bit_ind_s = bit_ind_reg_s + 1;

                end else if (falledge_scl_s) begin

                    // index 7 is the last part (this is after it is already taken into account)
                    if (bit_ind_reg_s == 7) begin
                        i2c_state_s = RW_EN;
                    end

                end
            end

            RW_EN: begin
                // sample on rising edge
                if (risedge_scl_s) begin
                    // store the operation type
                    rd_en_s = controller_sda_debounce_s;
                    wr_en_s = ~controller_sda_debounce_s;
                end else if (falledge_scl_s) begin
                    i2c_state_s = START_ACK;
                end
            end

            // START_ACK necessary to make the subordinate acknowledge, then can keep one state for read/write later
            START_ACK: begin
                if (falledge_scl_s) begin
                    bit_ind_s = 0;
                    if (wr_en_s) begin
                        i2c_state_s = WDATA;
                    end else if (rd_en_s) begin
                        i2c_state_s = RDATA;
                    end
                end
            end

            ACK: begin
                if (falledge_scl_s) begin
                    bit_ind_s = 0;
                    if (wr_en_s) begin
                        i2c_state_s = WDATA;
                    end else if (rd_en_s) begin
                        i2c_state_s = RDATA;
                    end
                end
            end

            // read 8 bits of data
            RDATA: begin
                if (risedge_scl_s) begin
                    bit_ind_s = bit_ind_reg_s + 1;
                    rdata_s = {rdata_reg_s[6:0], subordinate_sda_debounce_s};
                end else if (falledge_scl_s) begin
                    if (bit_ind_reg_s == 8) begin
                        i2c_state_s = ACK;
                    end
                end
            end

            // write 8 bits of data
            WDATA: begin
                if (risedge_scl_s) begin
                    bit_ind_s = bit_ind_reg_s + 1;
                    wdata_s = {wdata_reg_s[6:0], controller_sda_debounce_s};
                end else if (falledge_scl_s) begin
                    if (bit_ind_reg_s == 8) begin
                        i2c_state_s = ACK;
                    end
                end
            end

            default: begin
                i2c_state_s = IDLE;
            end

        endcase 
    end

end

// register state machine items
always_ff @(posedge clk_p) begin

    i2c_state_reg_s <= i2c_state_s;
    bit_ind_reg_s <= bit_ind_s;
    i2c_address_reg_s <= i2c_address_s;
    wr_en_reg_s <= wr_en_s;
    rd_en_reg_s <= rd_en_s;
    wdata_reg_s <= wdata_s;
    rdata_reg_s <= rdata_s;

end



// Detect Edges
always_ff @(posedge clk_p) begin

    // detect edges on scl
    i2c_scl_reg_s <= i2c_scl_p;
    risedge_scl_s <= (i2c_scl_reg_s == 0 && i2c_scl_p == 1) ? 1 : 0;
    falledge_scl_s <= (i2c_scl_reg_s == 1 && i2c_scl_p == 0) ? 1 : 0;

    // detect edges on controller-side sda
    controller_sda_reg_s <= controller_sda_debounce_s;
    risedge_controller_s <= (controller_sda_reg_s == 0 && controller_sda_debounce_s == 1) ? 1 : 0;
    falledge_controller_s <= (controller_sda_reg_s == 1 && controller_sda_debounce_s == 0) ? 1 : 0;

    // detect edges on subordinate-side sda
    subordinate_sda_reg_s <= subordinate_sda_debounce_s;
    risedge_subordinate_s <= (subordinate_sda_reg_s == 0 && subordinate_sda_debounce_s == 1) ? 1 : 0;
    falledge_subordinate_s <= (subordinate_sda_reg_s == 1 && subordinate_sda_debounce_s == 0) ? 1 : 0;

end


/////////////////////////////////////
// Assign the tristate enable outputs
always_comb begin
    case (i2c_state_reg_s)
        IDLE: begin
            controller_sda_ten_p = 1;   // simply tristate both outputs
            subordinate_sda_ten_p = 1;  // ^^^
        end
        ADDR: begin
            controller_sda_ten_p = 1;                      // Need data from controller, so tristate output
            subordinate_sda_ten_p = controller_sda_debounce_s;      // Output the data from controller
        end
        RW_EN: begin
            controller_sda_ten_p = 1;                      // Need data from controller, so tristate outptu
            subordinate_sda_ten_p = controller_sda_debounce_s;
        end
        START_ACK: begin
            controller_sda_ten_p = subordinate_sda_debounce_s;      // Output data from subordinate
            subordinate_sda_ten_p = 1;                     // Need data from Subordinate, so tristate output
        end
        ACK: begin
            if (wr_en_reg_s) begin
                // when writing, the subordinate will ACK. 
                controller_sda_ten_p = subordinate_sda_debounce_s;  // Output data from subordinate
                subordinate_sda_ten_p = 1;                 // Need data from subordinate, so tristate output
            end else begin
                // When reading, the controller will ACK
                controller_sda_ten_p = 1;                  // Need data from controller, so tristate output
                subordinate_sda_ten_p = controller_sda_debounce_s;  // Output data from controller
            end
        end
        RDATA: begin
            controller_sda_ten_p = subordinate_sda_debounce_s;      // Output data from subordinate
            subordinate_sda_ten_p = 1;                     // Need data from subordinate, so tristate output
        end
        WDATA: begin
            controller_sda_ten_p = 1;                      // Need data from controller, so tristate output
            subordinate_sda_ten_p = controller_sda_debounce_s;      // Output data from controller
        end
        default: begin
            controller_sda_ten_p = 1;   // Simply tristate both outputs
            subordinate_sda_ten_p = 1;  // ^^^
        end
    endcase
end


endmodule