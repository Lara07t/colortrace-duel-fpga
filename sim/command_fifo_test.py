 import cocotb
import os
import sys
from math import log
import logging
from pathlib import Path
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, ReadOnly
from cocotb.runner import get_runner
test_file = os.path.basename(__file__).replace(".py","")


@cocotb.test()
async def test_command_fifo(dut):
    """cocotb test for command_fifo"""
    dut._log.info("Starting command_fifo test...")
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    dut.rst.value = 1
    dut.write.value = 0
    dut.read.value  = 0
    dut.command_in.value = 0
    await ClockCycles(dut.clk, 3)
    dut.rst.value = 0
    await ClockCycles(dut.clk, 1)

# test 1 — show-ahead FIFO
    vals = [0xA1, 0xA2, 0xA3]

    # write phase
    for v in vals:
        assert int(dut.full.value) == 0
        dut.command_in.value = v
        dut.write.value = 1
        await ClockCycles(dut.clk, 1)
        dut.write.value = 0
    #read
    for exp in vals:
        await ReadOnly()
        got = int(dut.command_out.value)
        dut._log.info(f"Expected(head)=0x{exp:02X}, Got=0x{got:02X}")
        await ClockCycles(dut.clk, 1)
        dut.read.value = 0





    #test 2 - wrapping around of both the read and write pointers.
    tries = 0
    while int(dut.full.value) == 0 and tries < 20:
        dut.command_in.value = 0x10 + tries
        dut.write.value = 1
        await ClockCycles(dut.clk, 1)
        dut.write.value = 0
        tries += 1
    assert int(dut.full.value) == 1
    dut.read.value = 1
    await ClockCycles(dut.clk, 1)
    dut.read.value = 0

    #test 3 - filling up the FIFO and full flag behavior
    for w in [0xE1, 0xE2, 0xE3, 0xE4]:
        if int(dut.empty.value) == 0:
            dut.read.value = 1
            await ClockCycles(dut.clk, 1)
            dut.read.value = 0
        if int(dut.full.value) == 0:
            dut.command_in.value = w
            dut.write.value = 1
            await ClockCycles(dut.clk, 1)
            dut.write.value = 0
    if int(dut.empty.value) == 0:
        _ = int(dut.command_out.value)

    #test4- empty flag going from 0 to 1
    for _ in range(20):
        if int(dut.empty.value) == 1:
            break
        dut.read.value = 1
        await ClockCycles(dut.clk, 1)
        dut.read.value = 0
    assert int(dut.empty.value) == 1
    await ClockCycles(dut.clk, 1)




def command_fifo():
    """Command FIFO Tester."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent
    sys.path.append(str(proj_path / "sim" / "model"))
    sources = [proj_path / "hdl" / "command_fifo.sv"]
    build_test_args = ["-Wall"]
    parameters = {"DEPTH": 8, "WIDTH": 8}
    hdl_toplevel = "command_fifo"
    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel=hdl_toplevel,
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale=('1ns','1ps'),
        waves=True
    )
    run_test_args = []
    runner.test(
        hdl_toplevel=hdl_toplevel,
        test_module=test_file,
        test_args=run_test_args,
        waves=True
    )

if __name__ == "__main__":
    command_fifo()

