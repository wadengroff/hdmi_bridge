//
//    Date Created : 07/29/2025
//    Author       : Wade Groff
//    
//    Description :
//        Module to control direction for HDMI CEC. CEC is bidirectional open-drain,
//        so we can't just connect both ends. 
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

module open_drain_passthrough (
    input logic clk_p,
    input logic data_side0_p,
    input logic data_side1_p,
    output logic ten_side0_p,
    output logic ten_side1_p
);

typedef enum logic [1:0] {
    IDLE = 2'b00,
    SIDE0_DRIVE = 2'b01,
    SIDE1_DRIVE = 2'b10
} drive_state_t;

drive_state_t drive_state_s = IDLE;


always_ff @(posedge clk_p) begin

    drive_state_s <= drive_state_s;
    ten_side0_p <= ten_side0_p;
    ten_side1_p <= ten_side1_p;

    case (drive_state_s)
        IDLE: begin
            ten_side0_p <= 1;
            ten_side1_p <= 1;

            if (!data_side1_p) begin
                drive_state_s <= SIDE0_DRIVE;
            end else if (!data_side0_p) begin
                drive_state_s <= SIDE1_DRIVE;
            end
        end

        // Gets to this state if RX is driving low
        // Leave RX tristated so we can see when it goes back high
        SIDE0_DRIVE: begin
            ten_side0_p <= 0;
            ten_side1_p <= 1;
            if (data_side1_p) begin
                drive_state_s <= IDLE;
            end
        end

        SIDE1_DRIVE: begin
            ten_side0_p <= 1;
            ten_side1_p <= 0;
            if (data_side0_p) begin
                drive_state_s <= IDLE;
            end
        end
    endcase

end



endmodule