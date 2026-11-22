"""Shared Hypothesis profiles; select one with HYPOTHESIS_PROFILE.

- ci:    the default; fast, derandomized, no example database, so routine
         runs and mutation runs are reproducible and cannot leak failing
         examples between mutants.
- long:  many more examples for on-demand runs (still no database).
- stats: ci plus per-test statistics, for checking generator variety.
- mutation: half of ci, for the per-mutant runs of tests/mutation/runner.py.
"""

from __future__ import annotations

import os

from hypothesis import HealthCheck, settings

_COMMON = dict(
    database=None,
    deadline=None,
    suppress_health_check=[HealthCheck.too_slow, HealthCheck.data_too_large],
)

settings.register_profile("ci", max_examples=200, derandomize=True, **_COMMON)
settings.register_profile("long", max_examples=5000, **_COMMON)
settings.register_profile("stats", max_examples=200, derandomize=True, **_COMMON)
settings.register_profile("mutation", max_examples=100, derandomize=True, **_COMMON)
settings.load_profile(os.environ.get("HYPOTHESIS_PROFILE", "ci"))

LONG = os.environ.get("HYPOTHESIS_PROFILE") == "long"
