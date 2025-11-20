`timescale 1ns / 1ps
`default_nettype none
 
module command_fifo #(parameter DEPTH=16, parameter WIDTH=16)(
        input wire clk,
        input wire rst,
        input wire write,
        input wire [WIDTH-1:0] command_in,
        output logic full,
 
        output logic [WIDTH-1:0] command_out,
        input wire read,
        output logic empty
    );
     
    localparam AW = $clog2(DEPTH);
    logic [AW-1:0]   write_pointer;
    logic [AW-1:0]   read_pointer;
    logic [WIDTH-1:0] fifo [0:DEPTH-1]; //when read asynchronously/combinationally, will result in distributed RAM usage
 
    //your design here.
    assign command_out = fifo[read_pointer];

    // status
    assign empty = (write_pointer == read_pointer);
    assign full  = ((write_pointer + 1'b1) == read_pointer);

    always_ff @(posedge clk) begin
        if (rst) begin
            write_pointer <= '0;
            read_pointer  <= '0;
        end else begin
            // store new command and advance pointer
            if (write && !full) begin
                fifo[write_pointer] <= command_in;
                write_pointer <= write_pointer + 1'b1;
            end
            // move to the next entry
            if (read && !empty) begin
                read_pointer <= read_pointer + 1'b1;
            end
        end
    end
 
endmodule
`default_nettype wire





// import cocotb
// import os
// import sys
// from math import log
// import logging
// from pathlib import Path
// from cocotb.clock import Clock
// from cocotb.triggers import Timer, ClockCycles, RisingEdge, FallingEdge, ReadOnly,with_timeout
// from cocotb.utils import get_sim_time as gst
// from cocotb.runner import get_runner
// test_file = os.path.basename(__file__).replace(".py","")


// @cocotb.test()
// async def test_a(dut):
//     """cocotb test for image_sprite"""
//     dut._log.info("Starting...")
//     cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
//     dut.rst.value = 1
//     dut.calculate.value = 0
//     await ClockCycles(dut.clk,3)
//     dut.rst.value = 0
//     dut.pixel_valid.value = 1
//     for i in range(700): 
//         dut.pixel_x.value = i
//         dut.pixel_y.value = i
//         await ClockCycles(dut.clk,1)
//     dut.calculate.value = 1
//     dut.pixel_valid.value = 0
//     dut.pixel_x.value=0
//     dut.pixel_y.value = 0 ##frst test done , 349, 349


//     await ClockCycles(dut.clk,1)
//     dut.calculate.value = 0
//     await ClockCycles(dut.clk,700)
//     dut.pixel_valid.value = 1
//     for i in range(700): 
//         dut.pixel_x.value = i
//         dut.pixel_y.value = 10
//         await ClockCycles(dut.clk,1)
//     dut.calculate.value = 1
//     dut.pixel_x.value=0
//     dut.pixel_y.value = 0
//     dut.pixel_valid.value = 0
//     await ClockCycles(dut.clk,1) #test two done , 348 , 10


//     dut.calculate.value = 0
//     await ClockCycles(dut.clk,700)
//     dut.pixel_valid.value = 1
//     dut.pixel_y.value = 10
//     dut.pixel_x.value = 10
//     await ClockCycles(dut.clk,1)
//     dut.calculate.value = 1
//     dut.pixel_valid.value = 0
//     dut.pixel_x.value=0
//     dut.pixel_y.value = 0
//     await ClockCycles(dut.clk,1)
//     dut.calculate.value = 0
//     await ClockCycles(dut.clk,600)

//     dut.calculate.value = 1
//     await ClockCycles(dut.clk, 1)
//     dut.calculate.value = 0
//     await ClockCycles(dut.clk, 200)
//     assert int(dut.com_valid.value) == 0 

// def center_of_mass():
//     """Image Sprite Tester."""
//     hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
//     sim = os.getenv("SIM", "icarus")
//     proj_path = Path(__file__).resolve().parent.parent
//     sys.path.append(str(proj_path / "sim" / "model"))
//     sources = [proj_path / "hdl" / "center_of_mass.sv"]
//     sources += [proj_path / "hdl" / "divider.sv"]
//     build_test_args = ["-Wall"]
//     parameters = {}
//     hdl_toplevel = "center_of_mass"
//     sys.path.append(str(proj_path / "sim"))
//     runner = get_runner(sim)
//     runner.build(
//         sources=sources,
//         hdl_toplevel=hdl_toplevel,
//         always=True,
//         build_args=build_test_args,
//         parameters=parameters,
//         timescale = ('1ns','1ps'),
//         waves=True
//     )
//     run_test_args = []
//     runner.test(
//         hdl_toplevel=hdl_toplevel,
//         test_module=test_file,
//         test_args=run_test_args,
//         waves=True
//     )

// if __name__ == "__main__":
//     center_of_mass()
