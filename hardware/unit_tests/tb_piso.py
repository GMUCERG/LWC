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
async def test_piso(dut: DUT, num_tests: int = NUM_TV, debug=False):
    tb = ValidReadyTb(dut, debug=debug)
    sin_driver = tb.driver("p_in", data_suffix=["data", "keep", "last"])
    pout_monitor = tb.monitor("s_out", data_suffix=["data", "keep", "last"])
    await tb.reset()
    # get bound parameters/generics from the simulator
    G_OUT_W = tb.get_value("G_OUT_W", int)
    G_N = tb.get_value("G_N", int)
    G_CHANNELS = tb.get_value("G_CHANNELS", int)
    G_ASYNC_RSTN = tb.get_value("G_ASYNC_RSTN", bool)
    G_BIGENDIAN = tb.get_value("G_BIGENDIAN", bool)
    G_SUBWORD = tb.get_value("G_SUBWORD", bool)

    def concat_words(g):
        return reduce(concat_bv, g if G_BIGENDIAN else reversed(g))

    tb.log.info(
        "[%s] G_OUT_W:%d G_N:%d G_CHANNELS:%d G_ASYNC_RSTN:%s G_BIGENDIAN:%s G_SUBWORD:%s num_tests:%d",
        str(dut),
        G_OUT_W,
        G_N,
        G_CHANNELS,
        G_ASYNC_RSTN,
        G_BIGENDIAN,
        G_SUBWORD,
        num_tests,
    )
    IN_WIDTH = G_OUT_W * G_N

    assert G_OUT_W % 8 == 0, "G_OUT_W should be multiple of bytes"

    M = 10  # max num parallel words

    def div_ceil(n: int, m: int) -> int:
        return (n + m - 1) // m

    for _test in range(num_tests):
        if G_SUBWORD:
            num_data_bytes = random.randint(1, M * IN_WIDTH // 8)
            num_out_words = div_ceil(num_data_bytes, G_OUT_W // 8)
            # round up to next multiple of G_N
            num_in_words = div_ceil(num_out_words, G_N)
        else:
            num_in_words = random.randint(1, M)
            num_out_words = num_in_words * G_N
            num_data_bytes = num_out_words * G_OUT_W // 8

        data_byte_channels = [
            [random_bits(8) for _ in range(num_data_bytes)] for _ in range(G_CHANNELS)
        ]
        expected_outputs_channels = [
            [
                concat_words(g)
                for g in grouper(
                    data_bytes,
                    G_OUT_W // 8,
                    incomplete=Incomplete.Fill,
                    fillvalue=BinaryValue(0, n_bits=8),
                )
            ]
            for data_bytes in data_byte_channels
        ]
        expected_outputs = [
            {
                "data": concat_words(per_channel),
                "keep": "1" * (G_OUT_W // 8),
                "last": 0,
            }  #
            for per_channel in zip(*expected_outputs_channels)
        ]

        in_data_channels = [
            [
                concat_words(g)
                for g in grouper(
                    data_byte,
                    IN_WIDTH // 8,
                    incomplete=Incomplete.Fill,
                    fillvalue=BinaryValue(
                        0,
                        n_bits=data_byte[0].n_bits if data_byte else None,
                    ),
                )
            ]
            for data_byte in data_byte_channels
        ]

        in_data = [
            {
                "data": concat_words(per_channel),
                "keep": "1" * (IN_WIDTH // 8),
                "last": 0,
            }
            for per_channel in zip(*in_data_channels)
        ]

        def last_valid_bytes(total_bytes, w) -> str:
            bs = w // 8
            r = total_bytes % bs
            x = bs if r == 0 else r
            vb = ("0" * (bs - x)) + ("1" * x)
            if G_BIGENDIAN:
                return vb[::-1]
            return vb

        in_data[-1]["last"] = 1
        in_data[-1]["keep"] = last_valid_bytes(num_data_bytes, IN_WIDTH)
        expected_outputs[-1]["last"] = 1
        expected_outputs[-1]["keep"] = last_valid_bytes(num_data_bytes, G_OUT_W)

        stimulus = cocotb.start_soon(sin_driver.enqueue_seq(in_data))

        await pout_monitor.expect_seq(expected_outputs)

        await stimulus  # join stimulus thread
