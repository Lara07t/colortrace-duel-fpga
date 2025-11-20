module cocotb_iverilog_dump();
initial begin
    $dumpfile("/home/lara/lab06/sim/sim_build/command_fifo.fst");
    $dumpvars(0, command_fifo);
end
endmodule
