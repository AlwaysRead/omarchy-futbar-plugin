"""Per-user, cross-process HTTP admission and short-lived response coalescing.

Fixed lock/cache slots bound runtime files; flock releases on crashes. Request
keys are hashes; cached public ESPN bodies can contain provider links. Cached
bytes still pass each caller's validators.
"""
from contextlib import contextmanager
import fcntl
import hashlib
import os
import stat
import struct
import tempfile
import time

ACTIVE_LIMIT = 4
QUEUE_LIMIT = 16
CACHE_SLOTS = 32
CACHE_BYTES = 256 * 1024
CACHE_TTL = 3.0
HEADER = struct.Struct('!32sdI')


class BusyError(OSError):
    pass


def runtime_directory():
    # A private uid-specific directory; reject symlinks and unsafe permissions.
    base = os.environ.get('XDG_RUNTIME_DIR') or tempfile.gettempdir()
    path = os.path.join(base, 'futbar-network-' + str(os.getuid()))
    try:
        os.mkdir(path, 0o700)
    except FileExistsError:
        pass
    descriptor = os.open(path, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC)
    info = os.fstat(descriptor)
    if info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) != 0o700:
        os.close(descriptor)
        raise ValueError('Unsafe scheduler directory')
    return descriptor


def open_slot(directory, name):
    descriptor = os.open(name, os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW | os.O_CLOEXEC,
                         0o600, dir_fd=directory)
    info = os.fstat(descriptor)
    if (not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid()
            or stat.S_IMODE(info.st_mode) != 0o600 or info.st_nlink != 1):
        os.close(descriptor)
        raise ValueError('Unsafe scheduler file')
    return descriptor


def try_lock(descriptor):
    try:
        fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
        return True
    except BlockingIOError:
        return False


def wait_lock(descriptor, deadline):
    while not try_lock(descriptor):
        if time.monotonic() >= deadline:
            raise BusyError('FutBar busy: request queue deadline exceeded')
        time.sleep(0.025)


@contextmanager
def admission(directory, deadline):
    """At most four HTTP workers plus sixteen waiting callers, across helpers."""
    ticket = None
    worker = None
    try:
        for index in range(ACTIVE_LIMIT + QUEUE_LIMIT):
            candidate = open_slot(directory, 'ticket-' + str(index))
            if try_lock(candidate):
                ticket = candidate
                break
            os.close(candidate)
        if ticket is None:
            raise BusyError('FutBar busy: request queue is full')
        while worker is None:
            for index in range(ACTIVE_LIMIT):
                candidate = open_slot(directory, 'worker-' + str(index))
                if try_lock(candidate):
                    worker = candidate
                    break
                os.close(candidate)
            if worker is None:
                if time.monotonic() >= deadline:
                    raise BusyError('FutBar busy: request queue deadline exceeded')
                time.sleep(0.025)
        yield
    finally:
        if worker is not None:
            os.close(worker)
        if ticket is not None:
            os.close(ticket)


def read_cached(descriptor, digest, limit):
    os.lseek(descriptor, 0, os.SEEK_SET)
    header = os.read(descriptor, HEADER.size)
    if len(header) != HEADER.size:
        return None
    key, timestamp, length = HEADER.unpack(header)
    age = time.time() - timestamp
    if key != digest or not 0 <= age < CACHE_TTL or length > min(limit, CACHE_BYTES):
        return None
    body = os.read(descriptor, length + 1)
    return body if len(body) == length else None


def fetch(url, limit, timeout, operation):
    """Coalesce identical small responses; queue time consumes the timeout."""
    deadline = time.monotonic() + timeout
    directory = runtime_directory()
    cache = None
    try:
        digest = hashlib.sha256(url.encode('ascii')).digest()
        slot = int.from_bytes(digest[:2], 'big') % CACHE_SLOTS
        cache = open_slot(directory, 'response-' + str(slot))
        # Admission includes cache-lock waiters, so duplicate floods stay bounded.
        with admission(directory, deadline):
            wait_lock(cache, deadline)
            body = read_cached(cache, digest, limit)
            if body is not None:
                return body
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise BusyError('FutBar busy: request queue deadline exceeded')
            body = operation(remaining)
            # Clear the old slot even when the new response cannot be cached.
            os.ftruncate(cache, 0)
            if len(body) <= CACHE_BYTES:
                os.lseek(cache, 0, os.SEEK_SET)
                payload = HEADER.pack(digest, time.time(), len(body)) + body
                while payload:
                    written = os.write(cache, payload)
                    if written <= 0:
                        raise OSError('Could not write scheduler cache')
                    payload = payload[written:]
            return body
    finally:
        if cache is not None:
            os.close(cache)
        os.close(directory)
