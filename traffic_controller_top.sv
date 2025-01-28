`include "config_timer.sv"
module traffic_controller_top #(
    parameter CLOCK_TIME = 30
)
(
input logic clk, rst_n, 

input logic pedestrian_request,     //Initiates pedestrian crossing.
                                    //The pedestrian crossing is only allowed during the traffic red phase to ensure no vehicle movement. 
input logic emergency,              //when emergency mode is ON, all signals are red

//traffic signal outputs
output logic traffic_red,           //Red signal will be ON for 30s
output logic traffic_yellow,        //Yellow signal will be ON for 5s
output logic traffic_green,         //Green signal will be ON for 30s

//pedestrian signal outputs 
output logic pedestrian_walk,       //when ON, pedestrians can cross and traffic stops
output logic pedestrian_dont_walk   //Traffic is ongoing, pedestrians should not walk
);
logic red_done, grn_done, ylw_done, ped_done;
logic ped_req_reg;
logic red_trigger, yellow_trigger, green_trigger, ped_trigger;

always_ff@(posedge clk) begin
    if(~rst_n)
        ped_req_reg <= 1'b0;
    else if (pedestrian_dont_walk | emergency) 
        ped_req_reg <= pedestrian_request;
    else
        ped_req_reg <= pedestrian_walk ? 1'b0 : ped_req_reg; //if ped request in granted deassert the reg else it holds value
end

always_comb begin
    red_trigger     =   cs==T_RED;
    yellow_trigger  =   cs==T_YELLOW;
    green_trigger   =   cs==T_GREEN;
    ped_trigger     =   cs==P_WALK;
end

config_timer #(
    .CLOCK_TIME(30)
)
config_timer_red (
    .clk            (clk),
    .rst_n          (rst_n),
    .input_trigger  (red_trigger),
    .emergency      (emergency),
    .signal_change  (red_done)
);

config_timer #(
    .CLOCK_TIME(30)
)
config_timer_grn (
    .clk            (clk),
    .rst_n          (rst_n),
    .input_trigger  (green_trigger),
    .emergency      (emergency),
    .signal_change  (grn_done)
);

config_timer #(
    .CLOCK_TIME(5)
)
config_timer_ylw (
    .clk            (clk),
    .rst_n          (rst_n),
    .input_trigger  (yellow_trigger),
    .emergency      (emergency),
    .signal_change  (ylw_done)
);

config_timer #(
    .CLOCK_TIME(5)
)
config_timer_ped (
    .clk            (clk),
    .rst_n          (rst_n),
    .input_trigger  (ped_trigger),
    .emergency      (emergency),
    .signal_change  (ped_done)
);

typedef enum logic { 
    IDLE, T_RED, T_YELLOW, T_GREEN, P_WALK, P_RED, EMERGENCY;
 } state_t;

 state_t cs, ns;

always_ff @(posedge clk) begin
    if(~rst_n)
        cs <= IDLE;
    else
        cs <= ns;
end

always_comb begin
    case (cs):
        IDLE:       ns = T_RED;
                    //signal assignments
                    traffic_red = 1'b0;
                    traffic_yellow = 1'b0;
                    traffic_green = 1'b0;
                    pedestrian_walk = 1'b0;
                    pedestrian_dont_walk = ~pedestrian_walk;

        T_RED:      //next state logic
                    if(emergency) begin
                        ns = EMERGENCY;
                    end
                    else  begin  if (pedestrian_request | ped_req_reg)
                                ns = P_WALK;
                            else ns = red_done ? T_GREEN : T_RED;
                    end

                    //signal assignments
                    traffic_red = 1'b1;
                    traffic_yellow = 1'b0;
                    traffic_green = 1'b0;
                    pedestrian_walk = 1'b0;
                    pedestrian_dont_walk = ~pedestrian_walk;

        P_WALK:     if(emergency)
                        ns = EMERGENCY;
                    else
                        ns = ped_done ? P_RED : P_WALK;

                    //signal assignments
                    traffic_red = 1'b0;
                    traffic_yellow = 1'b0;
                    traffic_green = 1'b0;
                    pedestrian_walk = 1'b1;
                    pedestrian_dont_walk = ~pedestrian_walk;
                    
        P_RED:      if(emergency)
                        ns = EMERGENCY;
                    else
                        ns = T_GREEN;

                    //signal assignments
                    traffic_red = 1'b0;
                    traffic_yellow = 1'b0;
                    traffic_green = 1'b0;
                    pedestrian_walk = 1'b0;
                    pedestrian_dont_walk = ~pedestrian_walk;

        T_GREEN:    if(emergency)
                        ns = EMERGENCY;
                    else
                        ns = grn_done ? T_YELLOW : T_GREEN;

                    //signal assignments
                    traffic_red = 1'b0;
                    traffic_yellow = 1'b0;
                    traffic_green = 1'b1;
                    pedestrian_walk = 1'b0;
                    pedestrian_dont_walk = ~pedestrian_walk;

        T_YELLOW:   if(emergency)
                        ns = EMERGENCY
                    else    
                        ns = ylw_done ? T_RED : T_YELLOW;
                    //signal assignments
                    traffic_red = 1'b0;
                    traffic_yellow = 1'b1;
                    traffic_green = 1'b0;
                    pedestrian_walk = 1'b0;
                    pedestrian_dont_walk = ~pedestrian_walk;

        EMERGENCY:  if(emergency)
                        ns = EMERGENCY
                    else    if(ped_req_reg)
                                ns = P_WALK
                            else
                                ns = T_RED

                    //signal assignments
                    traffic_red = 1'b0;
                    traffic_yellow = 1'b0;
                    traffic_green = 1'b0;
                    pedestrian_walk = 1'b0;
                    pedestrian_dont_walk = ~pedestrian_walk;

    endcase
end


endmodule

