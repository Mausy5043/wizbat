#!/usr/bin/env python3

import os
import sys

import pytz
from sh import CommandNotFound, git  # type: ignore[import-untyped]

_MYHOME: str = os.environ["HOME"]
_DATABASE_FILENAME: str = "wizbat.sqlite3"
_DATABASE: str = f"/srv/rmt/_databases/wizbat/{_DATABASE_FILENAME}"
_HERE_list: list[str] = os.path.realpath(__file__).split("/")
# ['', 'home', 'pi', 'kimnaty', 'bin', 'constants.py']
_HERE: str = "/".join(_HERE_list[0:-2])
_WEBSITE: str = "/run/wizbat/site/img"

if not os.path.isfile(_DATABASE):
    _DATABASE = f"/srv/databases/{_DATABASE_FILENAME}"
if not os.path.isfile(_DATABASE):
    _DATABASE = f"/srv/data/{_DATABASE_FILENAME}"
if not os.path.isfile(_DATABASE):
    _DATABASE = f"/mnt/data/{_DATABASE_FILENAME}"
if not os.path.isfile(_DATABASE):
    _DATABASE = f".local/{_DATABASE_FILENAME}"
    print(f"Searching for {_DATABASE}")
if not os.path.isfile(_DATABASE):
    # mkdir ~/.sqlite3/wizbat
    # ln -s ~/Dropbox/raspi/_databases/wizbat/wizbat.swlite3 ~/.sqlite3/wizbat/wizbat.sqlite3
    _DATABASE = f"{_MYHOME}/.sqlite3/wizbat/{_DATABASE_FILENAME}"
    print(f"Searching for {_DATABASE}")
if not os.path.isfile(_DATABASE):
    _DATABASE = f"{_DATABASE_FILENAME}"
    print(f"Searching for {_DATABASE}")
if not os.path.isfile(_DATABASE):
    print("Database is missing.")
    sys.exit(1)

if not os.path.isdir(_WEBSITE):
    print("Graphics will be diverted to /tmp")
    _WEBSITE = "/tmp"  # nosec B108

D_FORMAT = "%Y-%m-%d"
DT_FORMAT = "%Y-%m-%d %H:%M:%S"
TIMEZONE = pytz.timezone("Europe/Amsterdam")
FLOAT_FMT = "+.0f"

# fmt: off
TREND: dict = {
    "database": _DATABASE,
    "website": _WEBSITE,
    "hour_graph": f"{_WEBSITE}/bat_pasthours",
    "day_graph": f"{_WEBSITE}/bat_pastdays",
    "month_graph": f"{_WEBSITE}/bat_pastmonths",
    "year_graph": f"{_WEBSITE}/bat_pastyears",
}

WIZ_BAT: dict = {
    "database": _DATABASE,
    "sql_table": "mains",
    "sql_command": "INSERT INTO mains ("
                   "sample_time, sample_epoch, "
                   "water"
                   ");"
                   "VALUES (?, ?, ?)",
    "report_interval": 900,
    "samplespercycle": 15,
    "delay": 0,
    "template": {
        "sample_time": "yyyy-mm-dd hh:mm:ss",
        "sample_epoch": 0,
        "water": 0,  # L
        },
    "offset": 0,
    "calibration": {
        # datetime(str): offset(float)
        "2024-12-25 11:00:00": 0.000,
        },
    }
# fmt: on


def get_app_version() -> str:
    """Retrieve information of current version of wizbat.

    Returns:
        versionstring
    """
    # git log -n1 --format="%h"
    # git --no-pager log -1 --format="%ai"
    git_args = ["-C", f"{_HERE}", "--no-pager", "log", "-1", "--format='%h'"]
    try:
        _exit_h = git(git_args).strip("\n").strip("'")
    except CommandNotFound as e:
        print(f"Error executing git command: {e}")
        _exit_h = None
    git_args[5] = "--format='%ai'"
    _exit_ai = git(git_args).strip("\n").strip("'")
    return f"{_exit_h}  -  {_exit_ai}"


if __name__ == "__main__":
    print(f"home              = {_MYHOME}")
    print(f"database location = {_DATABASE}")
    print("")
    print(f"wizbat (me)      = {get_app_version()}")
