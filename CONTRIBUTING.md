# Contributing

Keep instructional text and comments in English. Explain the purpose, target machine, prerequisites, expected output, and rollback for every state-changing exercise.

Run `python3 tests/validate.py` and `python3 -m unittest discover -s tests -v`. On a disposable lab VM also run the host checks and the Kali exercises. Record runtime results separately from static tests.

Do not broaden a whitelist to silence an unexplained failure. Preserve unrelated host configuration and fail clearly on unsupported topologies. Changes to thresholds need both malicious and benign test cases. Keep source links and version assumptions current.
