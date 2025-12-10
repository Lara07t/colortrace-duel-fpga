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
    """cocotb test for game_fsm"""
    dut._log.info("Starting game_fsm test...")

    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # Default inputs
    dut.rst.value          = 1
    dut.new_frame.value    = 0
    dut.p1_life_lost.value = 0
    dut.p2_life_lost.value = 0
    dut.p1_com_valid.value = 0
    dut.p2_com_valid.value = 0
    dut.start_game.value   = 0

    await ClockCycles(dut.clk, 5)
    dut.rst.value = 0
    await ClockCycles(dut.clk, 5)

    # Try to read parameters, fallback if needed
    try:
        lives_init = int(dut.LIVES)
    except AttributeError:
        lives_init = 3
    try:
        pause_frames = int(dut.PAUSE_FRAMES)
    except AttributeError:
        pause_frames = 120

    INIT      = 0
    READY     = 1
    PLAY      = 2
    LIFE_LOSS = 3
    GAME_OVER = 4

    # After reset
    await ClockCycles(dut.clk, 1)
    state    = int(dut.state.value)
    p1_lives = int(dut.p1_lives.value)
    p2_lives = int(dut.p2_lives.value)
    dut._log.info(f"After reset: state={state}, p1_lives={p1_lives}, p2_lives={p2_lives}")

    # INIT -> READY
    dut.start_game.value = 1
    await ClockCycles(dut.clk, 1)
    dut.start_game.value = 0
    await ClockCycles(dut.clk, 1)
    state = int(dut.state.value)
    dut._log.info(f"After start_game: state={state}")

    # READY: show P1 then P2 ready (COM valid & not off-path)
    for _ in range(3):
        dut.p1_com_valid.value = 1
        dut.p1_life_lost.value = 0
        await ClockCycles(dut.clk, 1)
    dut.p1_com_valid.value = 0

    for _ in range(3):
        dut.p2_com_valid.value = 1
        dut.p2_life_lost.value = 0
        await ClockCycles(dut.clk, 1)
    dut.p2_com_valid.value = 0

    # Give FSM time to go to PLAY
    await ClockCycles(dut.clk, 5)
    state = int(dut.state.value)
    dut._log.info(f"After READY handshake: state={state}")

    # Helper: trigger a P1 life loss and wait through LIFE_LOSS
    async def do_p1_life_loss(label):
        dut._log.info(f"--- {label}: triggering P1 life loss ---")
        dut.p1_life_lost.value = 1
        await ClockCycles(dut.clk, 1)
        dut.p1_life_lost.value = 0
        await ClockCycles(dut.clk, 1)

        # Should enter LIFE_LOSS
        s = int(dut.state.value)
        dut._log.info(f"State after hit: {s}, p1_lives={int(dut.p1_lives.value)}")

        # Drive new_frame pulses to let pause_ctr / blink_ctr run
        for i in range(pause_frames + 5):
            dut.new_frame.value = 1
            await ClockCycles(dut.clk, 1)
            dut.new_frame.value = 0
            await ClockCycles(dut.clk, 1)

        s2 = int(dut.state.value)
        dut._log.info(f"State after LIFE_LOSS phase: {s2}, p1_lives={int(dut.p1_lives.value)}")
        return s2

    # Only do full GAME_OVER scenario if LIVES >= 3
    if lives_init >= 3:
        # 1st hit
        await do_p1_life_loss("Hit 1")
        # 2nd hit
        await do_p1_life_loss("Hit 2")
        # 3rd hit – should end game
        final_state = await do_p1_life_loss("Hit 3 (should reach GAME_OVER)")
        await ClockCycles(dut.clk, 2)
        final_state = int(dut.state.value)
        winner      = int(dut.winner.value)
        p1_lives    = int(dut.p1_lives.value)
        p2_lives    = int(dut.p2_lives.value)
        dut._log.info(
            f"Final state={final_state}, winner={winner}, "
            f"p1_lives={p1_lives}, p2_lives={p2_lives}"
        )
    else:
        dut._log.info("LIVES < 3, skipping full GAME_OVER scenario for this test.")


def is_runner():
    """Game FSM Tester."""
    hdl_toplevel_lang = os.getenv("HDL_TOPLEVEL_LANG", "verilog")
    sim = os.getenv("SIM", "icarus")
    proj_path = Path(__file__).resolve().parent.parent

    sys.path.append(str(proj_path / "sim" / "model"))

    sources = [proj_path / "hdl" / "game_fsm.sv"]

    build_test_args = ["-Wall"]
    parameters = {}
    hdl_toplevel = "game_fsm"

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
    is_runner()
