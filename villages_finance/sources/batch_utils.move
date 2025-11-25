module villages_finance::batch_utils {

use std::error;
use std::vector;

/// Error codes
const E_BATCH_TOO_LARGE: u64 = 1;
const E_EMPTY_BATCH: u64 = 2;

/// Maximum batch size for most operations
const MAX_BATCH_SIZE: u64 = 100;

/// Maximum batch size for gas-intensive operations
const MAX_BATCH_SIZE_GAS_LIMITED: u64 = 20;

/// Validate batch size
public fun validate_batch_size(items: vector<u8>, max_size: u64): bool {
    let size = vector::length(&items);
    size > 0 && size <= max_size
}

/// Validate batch size and abort if invalid
public fun assert_batch_size(items: vector<u8>, max_size: u64) {
    let size = vector::length(&items);
    assert!(size > 0, error::invalid_argument(E_EMPTY_BATCH));
    assert!(size <= max_size, error::invalid_argument(E_BATCH_TOO_LARGE));
}

/// Get batch size
public fun get_batch_size<T>(items: &vector<T>): u64 {
    vector::length(items)
}

}
