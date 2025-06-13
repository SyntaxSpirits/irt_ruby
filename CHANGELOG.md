# Changelog

All notable changes to this project are documented in this file.

## [0.3.0] - 2025-01-14

### Changed
- **Code Quality**
  - Updated RuboCop configuration to handle new cops and resolve style warnings
  - Fixed operator precedence ambiguity in Three-Parameter Model calculations
  - Added MFA requirement to gemspec metadata (RuboCop requirement)

### Notes
- This release maintains **full backward compatibility** with previous versions
- All 46 existing tests continue to pass
- Comprehensive performance benchmarking suite remains available via `bundle exec rake benchmark:all`

---

## [0.2.0] - 2025-03-01

### Added
- **Missing Data Strategies**
    - Introduced a `missing_strategy` parameter for **Rasch**, **TwoParameterModel**, and **ThreeParameterModel** to handle `nil` responses:
        - `:ignore` (default) – skip missing responses in log-likelihood and gradients.
        - `:treat_as_incorrect` – interpret `nil` as `0`.
        - `:treat_as_correct` – interpret `nil` as `1`.
    - Updated RSpec tests to cover each strategy and ensure graceful handling of missing responses.

- **Expanded Test Coverage**
    - Added tests for repeated fits, deterministic seeding, larger random datasets, and new edge cases (all-correct/all-incorrect).
    - Improved specs for parameter clamping (discriminations, guessing in 2PL/3PL).

- **Adaptive Learning Rate Enhancements**
    - Enhanced convergence checks combining log-likelihood changes and average parameter updates.
    - Clearer revert-and-decay logic if the likelihood decreases on a given step.

### Changed
- **Documentation / README**
    - Updated the README to reflect new missing data strategies, advanced usage (adaptive learning rate, parameter clamping), and test instructions.
    - Added examples showcasing how to set `missing_strategy` for each model.

### Notes
- This release remains **backward-compatible** with `0.1.x` in terms of existing usage; the default `:ignore` missing-data approach matches prior behavior.
- If upgrading, simply update your gem and enjoy the new features.
- For more details, see the updated [README](./README.md) and expanded test suites.

---

*(If you have older versions below `0.2.0`, you can keep them documented similarly, e.g., `## [0.1.x] ...`, under this new entry.)*
