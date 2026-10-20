"""Exercise admission, process coalescing, crash release, and unsafe files."""
import multiprocessing
import os
from pathlib import Path
import sys
import tempfile
import time
import unittest
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'lib'))
import request_scheduler as scheduler


def concurrent_fetch(index, active, maximum, calls, barrier):
    barrier.wait(timeout=5)
    def operation(timeout):
        with active.get_lock():
            active.value += 1
            maximum.value = max(maximum.value, active.value)
        with calls.get_lock():
            calls.value += 1
        time.sleep(0.1)
        with active.get_lock():
            active.value -= 1
        return b'{"events":[]}'
    scheduler.fetch('https://site.api.espn.com/apis/test/' + str(index), 100, 4, operation)


class SchedulerTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.base = Path(directory.name)
        environment = patch.dict(os.environ, {'XDG_RUNTIME_DIR': directory.name})
        environment.start()
        self.addCleanup(environment.stop)

    def run_workers(self, keys):
        ctx = multiprocessing.get_context('fork')
        active, maximum, calls = [ctx.Value('i', 0) for _ in range(3)]
        barrier = ctx.Barrier(len(keys))
        workers = [ctx.Process(target=concurrent_fetch, args=(key, active, maximum, calls, barrier)) for key in keys]
        for worker in workers:
            worker.start()
        for worker in workers:
            worker.join(8)
            if worker.is_alive():
                worker.kill()
                worker.join()
                self.fail('Scheduler worker hung')
            self.assertEqual(worker.exitcode, 0)
        return maximum.value, calls.value

    def test_global_network_limit_across_processes(self):
        maximum, calls = self.run_workers(range(8))
        self.assertLessEqual(maximum, 4)
        self.assertGreater(maximum, 1)
        self.assertEqual(calls, 8)

    def test_identical_requests_coalesce_across_processes(self):
        maximum, calls = self.run_workers([1] * 8)
        self.assertEqual(calls, 1)
        self.assertEqual(maximum, 1)

    def test_cache_respects_caller_limit_and_expires(self):
        calls = []
        def load(timeout):
            calls.append(1)
            return b'12345'
        self.assertEqual(scheduler.fetch('url', 10, 1, load), b'12345')
        scheduler.fetch('url', 10, 1, load)
        self.assertEqual(len(calls), 1)
        with patch.object(scheduler, 'CACHE_TTL', 0):
            scheduler.fetch('url', 10, 1, load)
        self.assertEqual(len(calls), 2)

    def test_queue_full_and_deadline_release(self):
        directory = scheduler.runtime_directory()
        self.addCleanup(os.close, directory)
        held = []
        try:
            for index in range(scheduler.ACTIVE_LIMIT + scheduler.QUEUE_LIMIT):
                descriptor = scheduler.open_slot(directory, 'ticket-' + str(index))
                self.assertTrue(scheduler.try_lock(descriptor))
                held.append(descriptor)
            with self.assertRaises(scheduler.BusyError):
                with scheduler.admission(directory, time.monotonic() + 0.1):
                    self.fail('Queue admission should fail')
        finally:
            for descriptor in held:
                os.close(descriptor)
        with scheduler.admission(directory, time.monotonic() + 0.1):
            pass
        held = []
        try:
            for index in range(scheduler.ACTIVE_LIMIT):
                descriptor = scheduler.open_slot(directory, 'worker-' + str(index))
                scheduler.try_lock(descriptor)
                held.append(descriptor)
            with self.assertRaises(scheduler.BusyError):
                with scheduler.admission(directory, time.monotonic() + 0.05):
                    self.fail('Worker admission should time out')
        finally:
            for descriptor in held:
                os.close(descriptor)

    def test_reject_symlink_directory_and_cache_file(self):
        target = self.base / 'target'
        target.mkdir()
        link = self.base / ('futbar-network-' + str(os.getuid()))
        link.symlink_to(target)
        with self.assertRaises(OSError):
            scheduler.runtime_directory()
        link.unlink()
        directory = scheduler.runtime_directory()
        self.addCleanup(os.close, directory)
        victim = self.base / 'victim'
        victim.write_bytes(b'keep')
        (link / 'response-0').symlink_to(victim)
        with self.assertRaises(OSError):
            scheduler.open_slot(directory, 'response-0')
        self.assertEqual(victim.read_bytes(), b'keep')
