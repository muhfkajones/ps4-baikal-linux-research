#!/usr/bin/env python3

import importlib.util
import socket
import threading
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).with_name("capture_exp014.py")
SPEC = importlib.util.spec_from_file_location("capture_exp014", MODULE_PATH)
CAPTURE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(CAPTURE)


def fixture(overrides=None):
    values = [0, 0x34313045, 1, 1, 0, 1, 0, 2, 0, 1, 0, 1, 0, 0, 1]
    if overrides:
        for index, value in overrides.items():
            values[index] = value
    lines = [
        f"[EXP014] {name}=0x{value:016x}"
        for name, value in zip(CAPTURE.FIELDS, values, strict=True)
    ]
    return ("\n".join(lines + [CAPTURE.PASS_LINE]) + "\n").encode("ascii")


class CaptureParserTests(unittest.TestCase):
    def test_accepts_complete_capture(self):
        self.assertEqual(len(CAPTURE.parse_capture(fixture())), 15)

    def test_rejects_truncation(self):
        with self.assertRaises(ValueError):
            CAPTURE.parse_capture(fixture()[:-1])

    def test_rejects_bad_magic(self):
        with self.assertRaises(ValueError):
            CAPTURE.parse_capture(fixture({1: 0}))

    def test_rejects_non_boolean_presence(self):
        with self.assertRaises(ValueError):
            CAPTURE.parse_capture(fixture({9: 2}))

    def test_rejects_extra_line(self):
        data = fixture().replace(CAPTURE.PASS_LINE.encode(), b"unexpected\n" + CAPTURE.PASS_LINE.encode())
        with self.assertRaises(ValueError):
            CAPTURE.parse_capture(data)

    def test_fixture_is_within_network_bound(self):
        self.assertLess(len(fixture()), CAPTURE.MAX_CAPTURE)


class ListenerTests(unittest.TestCase):
    def run_listener(self, payload):
        listener = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        listener.bind(("127.0.0.1", 0))
        listener.listen(1)
        port = listener.getsockname()[1]
        result = {}

        def target():
            try:
                result["data"] = CAPTURE.receive_connection(listener)
            except Exception as error:
                result["error"] = error
            finally:
                listener.close()

        thread = threading.Thread(target=target)
        thread.start()
        with socket.create_connection(("127.0.0.1", port), timeout=1) as connection:
            connection.sendall(payload)
        thread.join(timeout=2)
        self.assertFalse(thread.is_alive(), "listener did not terminate")
        return result

    def test_receives_one_complete_bounded_capture(self):
        data = fixture()
        result = self.run_listener(data)
        self.assertNotIn("error", result)
        self.assertEqual(result["data"], data)

    def test_rejects_capture_over_network_bound(self):
        result = self.run_listener(b"A" * (CAPTURE.MAX_CAPTURE + 1))
        self.assertIsInstance(result.get("error"), ValueError)


if __name__ == "__main__":
    unittest.main()
