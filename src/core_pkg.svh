


package core_pkg;



    localparam int CLK_SPEED_c = 1e7;
    

    typedef enum logic [2:0] {
        IDLE,           // State before an HDMI cable is plugged in
        CONTROL_PERIOD, // used to determine next period type and do synchronization
        VIDEO_PERIOD,   // transmits actual video data
        ISLAND_PERIOD   // transmits other data packets
    } period_state_t;

    localparam int SYNCH_CNTR_WIDTH_c = 32;


    // constant guardband values for a control period leading into a video period
    // used for character syncrhonization
    localparam logic [9:0] VIDEO_LEADING_GUARDBAND_c = {
        10'b1011001100, 10'b0100110011, 10'b1011001100
    };


    // constant guardband values for a control period leading into a data island period
    // used for character synchronization
    localparam logic [9:0] ISLAND_LEADING_GUARDBAND_c = {
        0,                // Encodes to a TERC4 value based on HSYNC and VSYNC
        10'b0100110011,   
        10'b0100110011
    };




endpackage