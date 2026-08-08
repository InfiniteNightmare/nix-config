import argparse
import asyncio
import os
import subprocess
from urllib.parse import unquote_to_bytes, urlsplit

from dbus_fast.aio import MessageBus
from dbus_fast.constants import BusType, NameFlag, RequestNameReply
from dbus_fast.service import ServiceInterface, method


BUS_NAME = "org.freedesktop.FileManager1"
OBJECT_PATH = "/org/freedesktop/FileManager1"
MAX_ENTRIES = 9


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--footclient", required=True)
    parser.add_argument("--yazi", required=True)
    return parser.parse_args()


def local_file_paths(uris):
    paths = []

    for uri in uris:
        try:
            parsed = urlsplit(uri)
        except ValueError:
            continue

        if parsed.scheme == "":
            if not os.path.isabs(uri):
                continue
            path = uri
        elif parsed.scheme == "file" and parsed.netloc in ("", "localhost"):
            if parsed.query or parsed.fragment:
                continue
            path = os.fsdecode(unquote_to_bytes(parsed.path))
        else:
            continue

        if path and "\0" not in path:
            paths.append(path)

    return paths


def open_in_yazi(footclient, yazi, uris):
    paths = local_file_paths(uris)

    for start in range(0, len(paths), MAX_ENTRIES):
        batch = paths[start:start + MAX_ENTRIES]
        subprocess.Popen(
            [
                footclient,
                "--no-wait",
                "--app-id=yazi",
                "--title=yazi",
                yazi,
                "--",
                *batch,
            ],
            close_fds=True,
            start_new_session=True,
        )


class FileManager(ServiceInterface):
    def __init__(self, footclient, yazi):
        super().__init__(BUS_NAME)
        self.footclient = footclient
        self.yazi = yazi

    def open(self, uris):
        open_in_yazi(self.footclient, self.yazi, uris)

    @method()
    def ShowFolders(self, uris: "as", startup_id: "s"):  # noqa: F722, F821
        self.open(uris)

    @method()
    def ShowItems(self, uris: "as", startup_id: "s"):  # noqa: F722, F821
        self.open(uris)

    @method()
    def ShowItemProperties(self, uris: "as", startup_id: "s"):  # noqa: F722, F821
        # Yazi has no separate properties window; focus the requested items.
        self.open(uris)


async def run(footclient, yazi):
    bus = await MessageBus(bus_type=BusType.SESSION).connect()
    bus.export(OBJECT_PATH, FileManager(footclient, yazi))

    reply = await bus.request_name(BUS_NAME, NameFlag.DO_NOT_QUEUE)
    if reply not in (
        RequestNameReply.PRIMARY_OWNER,
        RequestNameReply.ALREADY_OWNER,
    ):
        raise RuntimeError(f"could not acquire {BUS_NAME}: {reply.name}")

    try:
        await bus.wait_for_disconnect()
    except EOFError:
        pass


def main():
    args = parse_args()
    asyncio.run(run(args.footclient, args.yazi))


if __name__ == "__main__":
    main()
