import cocotb
import os
import sys
from math import log
import logging
from pathlib import Path
from cocotb.clock import Clock
from cocotb.triggers import Timer, ClockCycles, RisingEdge, FallingEdge, ReadOnly, with_timeout
from cocotb.utils import get_sim_time as gst
from cocotb.runner import get_runner

test_file = os.path.basename(__file__).replace(".py", "")


@cocotb.test()
async def test_a(dut):
    """cocotb test for autopath_gen"""
    dut._log.info("Starting autopath_gen test...")

    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # Default values
    dut.rst.value             = 1
    dut.new_frame.value       = 0
    dut.game_initiated.value  = 0
    dut.shift_left_req.value  = 0
    dut.shift_right_req.value = 0
    dut.cell_x.value          = 0
    dut.cell_y.value          = 0

    await ClockCycles(dut.clk, 5)
    dut.rst.value = 0
    await ClockCycles(dut.clk, 5)

    # Try to read parameters if available, otherwise fall back to defaults
    try:
        grid_w = int(dut.GRID_W)
        grid_h = int(dut.GRID_H)
    except AttributeError:
        grid_w = 40
        grid_h = 40

    track_half_width = 9
    min_center = track_half_width
    max_center = grid_w - 1 - track_half_width

    center = grid_w // 2
    if not (min_center <= center <= max_center):
        center = min_center

    left_idx = center - track_half_width
    right_idx = center + track_half_width
    if left_idx < 1:
        left_idx = 1
    if right_idx > grid_w - 2:
        right_idx = grid_w - 2

    dut._log.info(f"GRID_W={grid_w}, GRID_H={grid_h}")
    dut._log.info(f"Initial corridor approx from x={left_idx} to x={right_idx}")

    # Sample initial track row (row 0) using cell_on
    # Note: cell_on is registered, so we check previous (x, y)
    y = 0
    last_valid = False
    prev_x = 0

    for x in range(grid_w + 1):
        dut.cell_x.value = x if x < grid_w else 0
        dut.cell_y.value = y
        await ClockCycles(dut.clk, 1)

        if last_valid:
            on = int(dut.cell_on.value)
            expected = 1 if (left_idx <= prev_x <= right_idx) else 0
            if on != expected:
                dut._log.error(
                    f"Init row mismatch at (x={prev_x}, y={y}): "
                    f"cell_on={on}, expected={expected}"
                )
        prev_x = x
        last_valid = True

    # Log initial path_grid_out snapshot
    initial_grid = int(dut.path_grid_out.value)
    dut._log.info(f"Initial path_grid_out snapshot: 0x{initial_grid:0X}")

    # Start game and drive new_frame pulses to scroll path
    dut.game_initiated.value = 1
    dut.shift_left_req.value = 0
    dut.shift_right_req.value = 0

    num_frames = 64
    dut._log.info(f"Driving {num_frames} frames to exercise scrolling and randomness...")

    for frame in range(num_frames):
        dut.new_frame.value = 1
        await ClockCycles(dut.clk, 1)
        dut.new_frame.value = 0
        await ClockCycles(dut.clk, 1)

    final_grid = int(dut.path_grid_out.value)
    changed = (initial_grid != final_grid)
    dut._log.info(f"Final path_grid_out snapshot:   0x{final_grid:0X}")
    dut._log.info(f"Path grid changed after scrolling? {changed}")


def is_runner():
    """Auto Path Gen Tester."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent

    sys.path.append(str(proj_path / "sim" / "model"))

    sources = [proj_path / "hdl" / "auto_path_gen.sv"]

    build_test_args = ["-Wall"]
    parameters = {}
    hdl_toplevel = "autopath_gen"

    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel=hdl_toplevel,
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale=('1ns', '1ps'),
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
    is_runner()
