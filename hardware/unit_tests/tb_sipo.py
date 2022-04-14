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
    debug |= bool(os.environ.get("DEBUG", False))
    tb = ValidReadyTb(dut, debug=debug)
    sin_driver = tb.driver("sin", data_suffix=["data", "keep", "last"])
    pout_monitor = tb.monitor("pout", data_suffix=["data", "keep", "last"])
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

    def valid_bytes(w, total_bytes=None) -> str:
        num_bytes = w // 8
        r = total_bytes % num_bytes if total_bytes else 0
        num_ones = num_bytes if r == 0 else r
        vb = ("0" * (num_bytes - num_ones)) + ("1" * num_ones)
        if G_BIGENDIAN:
            return vb[::-1]
        return vb

    def div_ceil(n: int, m: int) -> int:
        """n/m rounded up to next multiple of m"""
        return (n + m - 1) // m

    OUT_WIDTH = G_IN_W * G_N
    M = 10  # max num parallel (output) words

    for _test in range(num_tests):
        if G_SUBWORD:
            num_data_bytes = random.randint(1, M * OUT_WIDTH // 8)
        else:
            num_data_bytes = random.randint(1, M) * OUT_WIDTH // 8
        num_in_words = div_ceil(num_data_bytes, G_IN_W // 8)
        num_out_words = div_ceil(num_data_bytes, OUT_WIDTH // 8)
        tb.log.debug("bytes:%d in_words:%d out_words:%d", num_data_bytes, num_in_words, num_out_words)
        data_byte_channels = [
            [random_bits(8) for _ in range(num_data_bytes)] for _ in range(G_CHANNELS)
        ]
        in_channels = [
            [
                concat_words(g)
                for g in grouper(
                    data_bytes,
                    G_IN_W // 8,
                    incomplete=Incomplete.Fill,
                    fillvalue=BinaryValue(0, n_bits=8),
                )
            ]
            for data_bytes in data_byte_channels
        ]
        in_data = [
            {  #
                "data": concat_words(g),
                "keep": valid_bytes(G_IN_W),
                "last": 0,
            }
            for g in zip(*in_channels)
        ]
        in_data[-1]["last"] = 1
        in_data[-1]["keep"] = valid_bytes(G_IN_W, num_data_bytes)

        expected_outputs_of_channel = [
            [
                concat_words(g)
                for g in grouper(
                    data_bytes,
                    OUT_WIDTH // 8,
                    incomplete=Incomplete.Fill,
                    fillvalue=BinaryValue(0, n_bits=8),
                )
            ]
            for data_bytes in data_byte_channels
        ]
        expected_outputs = [
            {
                "data": concat_words(per_channel),
                "keep": valid_bytes(OUT_WIDTH),
                "last": 0,
            }
            for per_channel in zip(*expected_outputs_of_channel)
        ]
        expected_outputs[-1]["last"] = 1
        expected_outputs[-1]["keep"] = valid_bytes(OUT_WIDTH, num_data_bytes)

        stimulus = cocotb.start_soon(sin_driver.enqueue_seq(in_data))

        await pout_monitor.expect_seq(expected_outputs)

        await stimulus  # join stimulus thread
