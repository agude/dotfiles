#!/usr/bin/env python3

"""Calls rsync to synchronize the local and a remote machine.

Exit Codes:
    0: Exit successful.
"""

from distutils.spawn import find_executable
from subprocess import call
import argparse
import logging
import os.path
import sys


FLAGS = set([
    "--acls",
    "--archive",
    "--compress",
    "--fuzzy",
    "--hard-links",
    "--human-readable",
    "--itemize-changes",
    "--verbose",
    "--xattrs",
    "--rsh=ssh",
    # For testing, otherwise remove!!
    #"--dry-run",
])


def get_rsync_location():
    """Find the location of the rsync executable from the user path.

    This will return the location, or error.

    Returns:
        str: the location of the rsync executable.

    Raises:
        RuntimeError: If rsync is not found on the path

    """
    rsync_loc = find_executable("rsync")
    if rsync_loc is None:
        ERR_MSG = "Can not find rsync."
        logging.error(ERR_MSG)
        raise RuntimeError(ERR_MSG)
    logging.debug("Found rsync: %s", rsync_loc)
    return rsync_loc


class Rsync:
    def __init__(self, rsync_loc, flags, remote, location, is_pull):
        logging.info("Constructing rsync object.")
        self.rsync_loc = rsync_loc
        self.flags = sorted(flags)  # Sorting makes it easier to scan by eye
        self.remote = remote
        self.location = location

        # If pull, set local to target, otherwise set local to source
        self.is_pull = is_pull
        self.source, self.target = self.__set_source_and_target()

        self.command = self.__build_command()

    def __set_source_and_target(self):
        # The remote needs a host name, so add it
        remote_path = "{}:{}".format(self.remote, self.location)
        local = self.location

        # Output is (source, target)
        output = (remote_path, local)

        logging.debug("Is --pull: '%s'", self.is_pull)

        return output if self.is_pull else reversed(output)

    def __build_command(self):
        command = [self.rsync_loc] + self.flags + [self.source, self.target]

        logging.debug("Command: `%s`", ' '.join(command))

        return command

    def run(self):
        logging.info("Running rsync command.")
        call(self.command)


if __name__ == "__main__":
    # Parse the list of files
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--directory",
        help="the directory to sync",
        required=True,
    )
    parser.add_argument(
        "--remote",
        help="the host name of the remote system",
        required=True,
    )
    parser.add_argument(
        "--exclude",
        nargs="*",
        help="a list of files or directories to exclude, relative to the source path",
    )
    parser.add_argument(
        "--pull",
        help="set the local machine to the target",
        action="store_true",
        dest="pull",
    )
    parser.add_argument(
        "--push",
        help="set the local machine to the source",
        action="store_false",
        dest="pull",
    )
    parser.add_argument(
        "--log",
        help="set the logging level, defaults to WARNING",
        dest="log_level",
        default=logging.WARNING,
        choices=[
            "DEBUG",
            "INFO",
            "WARNING",
            "ERROR",
            "CRITICAL",
        ],
    )

    args, unknown_args = parser.parse_known_args()

    # Set the logging level based on the arguments
    logging.basicConfig(level=args.log_level)

    logging.debug("Arguments: %s", args)

    # Pass through flags unknown to argparse to rsync
    logging.info("Checking for pass through flags.")
    if unknown_args:
        logging.info("Pass through flags found.")
        for flag in unknown_args:
            logging.debug("Adding pass through flag: '%s'", flag)
            FLAGS.add(flag)

    # Add excludes to flags
    logging.info("Checking for excluded items.")
    if args.exclude:
        logging.info("Excluded items found.")
        for ex in args.exclude:
            exclude_statement = "--exclude={}".format(ex)
            logging.debug("Adding excluded item: '%s'", exclude_statement)
            FLAGS.add(exclude_statement)

    # Build the full directory path
    full_path = os.path.normpath(args.directory)
    full_path = os.path.join(full_path, "")  # Ensures a trailing slash

    # Construct the rsync command and run it
    rsync = Rsync(
        get_rsync_location(),
        FLAGS,
        args.remote,
        full_path,
        args.pull,
    )

    rsync.run()

    sys.exit(0)
