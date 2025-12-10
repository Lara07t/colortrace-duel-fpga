module cocotb_iverilog_dump();
initial begin
    $dumpfile("/home/lara/fa25-6205-team17/sim/sim_build/path_checker.fst");
    $dumpvars(0, path_checker);
end
endmodule
