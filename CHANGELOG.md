# Release notes

## Unreleased

### Breaking

### Changed

### Added

### Fixed

## Version [v0.1.1] - 2024.12.12

### Breaking

* Redefine `pseudo_alloc!`, `pseudo_drop!` and `pseudo_reset!` to align with the syntax of `alloc!`, `drop!` and `reset!`, i.e., now one can simpy replace alloc/drop/reset with the pseudo functions (and delete other lines) to calculate the required Buffer length.
* `@print_buffer_usage` replaces all function calls with buffer as argument by their `pseudo_` version. For custom functions, the `pseudo_`functions have to be defined by the user (e.g., by using `@print_buffer_usage` on the function definition).

### Added

* Use JuliaFormatter

## Version [v0.1.0] - 2024.12.09

### Added

* First release: `Buffer`, `ThreadsBuffer`, `alloc!`, `drop!`, `reset!`, `release!`, `@print_buffer_usage`
