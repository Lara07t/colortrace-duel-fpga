import cocotb
import os
import sys
from pathlib import Path
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles
from cocotb.runner import get_runner

test_file = os.path.basename(__file__).replace(".py", "")


@cocotb.test()
async def test_a(dut):
    """cocotb smoke test for path_checker"""
    dut._log.info("Starting path_checker smoke test...")

    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # Design defaults (match your module parameters)
    grid_w = 40
    grid_h = 40
    cell_w = 64
    cell_h = 72
    radius = 32

    dut._log.info(
        f"Using GRID_W={grid_w}, GRID_H={grid_h}, CELL_W={cell_w}, "
        f"CELL_H={cell_h}, RADIUS={radius}"
    )

    # Default inputs
    dut.rst.value       = 1
    dut.new_frame.value = 0

    dut.p1_x.value = 0
    dut.p1_y.value = 0
    dut.p2_x.value = 0
    dut.p2_y.value = 0

    dut.path_grid_p1.value = 0
    dut.path_grid_p2.value = 0

    await ClockCycles(dut.clk, 5)
    dut.rst.value = 0
    await ClockCycles(dut.clk, 5)

    # Place player 1 in a safe grid row so p1_y < 1024 (10-bit)
    cx = grid_w // 2
    # pick a small-ish row: e.g. cy = 5 ⇒ y = 5*72+36 = 396
    cy = 5

    p1_px = cx * cell_w + cell_w // 2
    p1_py = cy * cell_h + cell_h // 2
    dut._log.info(f"P1 target pixel center: ({p1_px}, {p1_py})")

    dut.p1_x.value = p1_px
    dut.p1_y.value = p1_py

    # Put player 2 somewhere else but still inside grid & 10-bit range
    dut.p2_x.value = 3 * cell_w + cell_w // 2
    dut.p2_y.value = 3 * cell_h + cell_h // 2

    async def run_frame_and_wait(label: str, wait_cycles: int = 300):
        """Pulse new_frame once, then wait for the whole sweep + pipeline to complete."""
        dut._log.info(f"--- {label}: new_frame pulse ---")
        dut.new_frame.value = 1
        await ClockCycles(dut.clk, 1)
        dut.new_frame.value = 0

        # allow the 5x5 windows and 2-stage pipeline to run & flush
        await ClockCycles(dut.clk, wait_cycles)

        p1_lost = int(dut.p1_life_lost.value)
        p2_lost = int(dut.p2_life_lost.value)
        dut._log.info(
            f"{label} result: p1_life_lost={p1_lost}, p2_life_lost={p2_lost}"
        )
        return p1_lost, p2_lost

    # Helper to build a path grid int with specific (x,y) bits = 1
    def make_path_int(on_cells):
        """
        on_cells: iterable of (x, y) pairs to set to 1,
        flattened row-major: idx = y * grid_w + x
        """
        val = 0
        for (x, y) in on_cells:
            if 0 <= x < grid_w and 0 <= y < grid_h:
                idx = y * grid_w + x
                val |= (1 << idx)
        return val

    # Coarse grid cell for P1 (should be cx, cy we picked)
    cx1 = p1_px // cell_w
    cy1 = p1_py // cell_h
    dut._log.info(f"P1 coarse cell: cx1={cx1}, cy1={cy1}")

    # Scenario 1: "Nice" path around P1 -> NO life lost ideally
    on_tiles = [
        (cx1,     cy1),
        (cx1 - 1, cy1),
        (cx1 + 1, cy1),
        (cx1,     cy1 - 1),
        (cx1,     cy1 + 1),
    ]
    path_ok = make_path_int(on_tiles)
    dut.path_grid_p1.value = path_ok
    dut.path_grid_p2.value = path_ok  # give P2 same pattern for now

    p1_lost, p2_lost = await run_frame_and_wait("Scenario 1: small +-shape path")
    if p1_lost or p2_lost:
        dut._log.warning(
            "Scenario 1: expected both players to be mostly on-path, "
            f"but got p1_life_lost={p1_lost}, p2_life_lost={p2_lost}"
        )

    # Scenario 2: everything OFF path -> life lost expected
    dut.path_grid_p1.value = 0
    dut.path_grid_p2.value = 0

    p1_lost, p2_lost = await run_frame_and_wait("Scenario 2: all tiles off-path")
    if not p1_lost:
        dut._log.warning(
            "Scenario 2: with all tiles off-path near P1, "
            "we expected p1_life_lost=1, but got 0."
        )



def path_checker_runner():
    """Path Checker Tester."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent

    sys.path.append(str(proj_path / "sim" / "model"))

    sources = [
        proj_path / "hdl" / "path_checker.sv",
    ]

    build_test_args = ["-g2012", "-Wall"]
    parameters = {}
    hdl_toplevel = "path_checker"

    sys.path.append(str(proj_path / "sim"))
    runner = get_runner(sim)
    runner.build(
        sources=sources,
        hdl_toplevel=hdl_toplevel,
        always=True,
        build_args=build_test_args,
        parameters=parameters,
        timescale=('1ns', '1ps'),
        waves=True,
    )
    run_test_args = []
    runner.test(
        hdl_toplevel=hdl_toplevel,
        test_module=test_file,
        test_args=run_test_args,
        waves=True,
    )


if __name__ == "__main__":
    path_checker_runner()
