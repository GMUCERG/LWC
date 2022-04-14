import enum
import os
import random
from functools import reduce
from itertools import zip_longest

import cocotb
from cocolight import DUT, ValidReadyTb, cocotest, concat_bv
from cocotb.binary import BinaryValue

NUM_TV = int(os.environ.get("NUM_TV", 100))


class Incomplete(enum.Enum):
    Ignore = enum.auto()
    Fill = enum.auto()
    Strict = enum.auto()


def grouper(iterable, n, *, incomplete: Incomplete = Incomplete.Ignore, fillvalue=None):
    "Collect data into non-overlapping fixed-length chunks or blocks"
    args = [iter(iterable)] * n
    if incomplete == Incomplete.Fill:
        return zip_longest(*args, fillvalue=fillvalue)
    # if incomplete == 'strict':
    #     return zip(*args, strict=True)
    if incomplete == Incomplete.Ignore:
        return zip(*args)
    else:
        raise ValueError("Expected fill, strict, or ignore")


def random_bits(n: int) -> BinaryValue:
    # by default bigEndian=True
    return BinaryValue(value=random.getrandbits(n), n_bits=n)


@cocotest
async def test_sipo(dut: DUT, num_tests: int = NUM_TV, debug=False):
    tb = ValidReadyTb(dut, debug=debug)
    sin_driver = tb.driver("sin", data_suffix=["data", "last"])
    pout_monitor = tb.monitor("pout", data_suffix=["data", "last"])
    await tb.reset()
    # get bound parameters/generics from the simulator
    G_IN_W = tb.get_value("G_IN_W", int)
    G_N = tb.get_value("G_N", int)
    G_CHANNELS = tb.get_value("G_CHANNELS", int)
    G_ASYNC_RSTN = tb.get_value("G_ASYNC_RSTN", bool)
    G_PIPELINED = tb.get_value("G_PIPELINED", bool)
    G_BIGENDIAN = tb.get_value("G_BIGENDIAN", bool)
    G_SUBWORD = tb.get_value("G_SUBWORD", bool)
    G_CLEAR_INVALIDS = tb.get_value("G_CLEAR_INVALIDS", bool)

    def concat_words(g):
        return reduce(concat_bv, g if G_BIGENDIAN else reversed(g))

    tb.log.info(
        "[%s] G_IN_W:%d G_N:%d G_CHANNELS:%d G_ASYNC_RSTN:%s G_PIPELINED:%s G_BIGENDIAN:%s G_SUBWORD:%s G_CLEAR_INVALIDS:%s num_tests:%d",
        str(dut),
        G_IN_W,
        G_N,
        G_CHANNELS,
        G_ASYNC_RSTN,
        G_PIPELINED,
        G_BIGENDIAN,
        G_SUBWORD,
        G_CLEAR_INVALIDS,
        num_tests,
    )

    for test in range(num_tests):
        num_in_words = random.randint(1, 10 * G_N)
        if not G_SUBWORD or G_PIPELINED:
            # round up to multiple of G_N
            num_in_words = (num_in_words + G_N - 1) // G_N * G_N
        in_channels = [
            [random_bits(G_IN_W) for _ in range(num_in_words)]
            for _ in range(G_CHANNELS)
        ]
        in_data = [{"data": concat_words(g), "last": 0} for g in zip(*in_channels)]

        if G_SUBWORD:
            in_data[-1]["last"] = 1

        expected_outputs_of_channel = [
            [
                concat_words(g)
                for g in grouper(
                    ch,
                    G_N,
                    incomplete=Incomplete.Fill,
                    fillvalue=BinaryValue(0, n_bits=G_IN_W),
                )
            ]
            for ch in in_channels
        ]
        expected_outputs = [
            {"data": concat_words(per_channel), "last": 0}
            for per_channel in zip(*expected_outputs_of_channel)
        ]
        if G_SUBWORD and not G_PIPELINED:
            expected_outputs[-1]["last"] = 1

        stimulus = cocotb.start_soon(sin_driver.enqueue_seq(in_data))

        await pout_monitor.expect_seq(expected_outputs)

        await stimulus  # join stimulus thread
