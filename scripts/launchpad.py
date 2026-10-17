#!/usr/bin/env python3

import argparse
from datetime import datetime, timezone
from launchpadlib.launchpad import Launchpad

TEAM = 'bullwinkle-team'
PPA = 'rocm-7.14'

class BuildInfo:

    def __init__(self, build):
        self._source_package_name = build.source_package_name
        self._series = str(build.distro_series.name)
        self._arch_tag = build.arch_tag
        self._state = build.buildstate
        self._date_queued = build.datecreated
        self._date_started = build.date_started
        self._date_finished = build.datebuilt
        self.__setup()

    def __setup(self):
        self.enqueued_time = self.__enqueued_time()
        self.build_time = self.__build_time()
        self.current_build_time = self.__current_build_time()
        self.total_time = self.__total_time()

    def __enqueued_time(self):
        if self._date_queued is None or self._date_started is None:
            return None

        return self._date_started - self._date_queued

    def __build_time(self):
        if self._date_finished is None or self._date_started is None:
            return None

        return self._date_finished - self._date_started

    def __current_build_time(self):
        if self._date_started is None:
            return None

        return datetime.now(timezone.utc) - self._date_started

    def __total_time(self) -> None | datetime:
        if self.build_time is None or self.enqueued_time is None:
            return None

        return self.build_time + self.enqueued_time

    def __is_excluded(self, state: str, patterns: list[str]) -> bool:
        for pattern in patterns:
            if pattern in state:
                return True

        return False

    def summarize(self, excludes: list[str] | None = None) -> None:

        if excludes:
            if self.__is_excluded(self._state, excludes):
                return

        print(f"{self._source_package_name} [{self._arch_tag}] [{self._series}] - {self._state}")
        if self._date_queued:
            print(f"  Queued:   {self._date_queued}")

        if self._date_started:
            print(f"  Started:  {self._date_started}")

        if self._date_finished:
            print(f"  Finished: {self._date_finished}")

        if self.enqueued_time:
            print(f"    Took {self.enqueued_time} to start building")

        if self.build_time:
            print(f"    Took {self.build_time} to finish building")
        else:
            if self.current_build_time:
                print(f"    Build is taking {self.current_build_time}")

        print("")

def parse_args(argv : list[str] | None = None) -> argparse.Namespace:

    parser = argparse.ArgumentParser(description="PPA verification tool")

    parser.add_argument(
        "--team",
        help="The name of the team owning the PPA",
        default=TEAM
    )

    parser.add_argument(
        "--ppa",
        help="The name of the PPA",
        default=PPA
    )

    parser.add_argument(
        "--package",
        help="The name of the package in the PPA",
    )

    parser.add_argument(
        "--exclude_state",
        metavar="PATTERN",
        nargs="+",
        default=[],
        help="Strings to be used in state filtering. E.g: --exclude_state 'Cancelled'"
    )

    return parser.parse_args(argv)

def main(argv: list[str] | None = None):

    args = parse_args(argv)

    lp = Launchpad.login_anonymously('check-ppa-builds', 'production', version='devel')
    team = lp.people[args.team]
    ppa = team.getPPAByName(name=args.ppa)

    print(f"{ppa.displayname} [{ppa.web_link}]\n")

    builds = ppa.getBuildRecords(source_name=args.package)
    excludes = args.exclude_state if args.exclude_state else None

    for lp_build in builds:
        BuildInfo(lp_build).summarize(excludes)

if __name__ == "__main__":
    main()
