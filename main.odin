/// Hacky uniq implementation
/// - will reallocate, but reallocation strategy is naive and not performant.
/// - insert-only hashset
/// - pre-hashes line into digest and stores digest instead of bytestring. This makes collisions undetectable.
///
/// With this hackiness, it's pretty close to zig using HashMap and wyhash for digesting.
/// For this benchmark, about 1.5x slower if starting with small capacity; equal if using large buffer.

package ouniq

import "core:bufio"
import "core:bytes"
import "core:fmt"
import "core:hash/xxhash"
import "core:os"
import "core:strconv"
import "core:testing"

main :: proc() {
	filter: Set
	set_init(&filter, 16)

	r: bufio.Reader
	read_stream_buf: [4096]byte
	bufio.reader_init_with_buf(&r, os.stream_from_handle(os.stdin), read_stream_buf[:])
	defer bufio.reader_destroy(&r)

	w: bufio.Writer
	write_stream_buf: [4096]byte
	bufio.writer_init_with_buf(&w, os.stream_from_handle(os.stdout), write_stream_buf[:])
	defer bufio.writer_destroy(&w)

	for {
		line, err := bufio.reader_read_slice(&r, '\n')
		if err != nil {
			break
		}

		// Use hash directly. This means there's a chance of undetected collisions.
		hash := xxhash.XXH64(line)

		if set_insert(&filter, hash) {
			bufio.writer_write(&w, line)
		}
	}
	bufio.writer_flush(&w)
}

Set :: struct {
	count:   int,
	entries: []u64,
}

set_init :: proc(set: ^Set, capacity: int) {
	assert((capacity & (capacity - 1)) == 0, "capacity must be a power of 2")

	set.entries = make([]u64, capacity)
}

// returns true if call sets entry. returns false if entry already exists
set_insert :: proc(set: ^Set, hash: u64) -> bool {
	// max load 80%
	if cast(f32)set.count * 1.25 >= cast(f32)len(set.entries) {
		set_realloc(set)
	}
	mask := u64(len(set.entries) - 1)
	idx := hash & mask

	for {
		entry := &set.entries[idx]
		if entry^ == hash {
			return false
		}
		if entry^ == 0 { 	// TODO should actually bias, in case there's a zero-value hash
			set.count += 1
			entry^ = hash
			return true
		}
		idx = (idx + 1) & mask
	}
}

set_insert_assume_capacity :: proc(set: ^Set, hash: u64) -> bool {
	mask := u64(len(set.entries) - 1)
	idx := hash & mask

	for {
		entry := &set.entries[idx]
		if entry^ == hash {
			return false
		}
		if entry^ == 0 { 	// TODO should actually bias, in case there's a zero-value hash
			set.count += 1
			entry^ = hash
			return true
		}
		idx = (idx + 1) & mask
	}
}

set_contains :: proc(set: Set, hash: u64) -> bool {
	mask := u64(len(set.entries) - 1)
	idx := hash & mask

	for {
		entry := set.entries[idx]
		if entry == hash {
			return true
		}
		if entry == 0 {
			return false
		}
		idx = (idx + 1) & mask
	}
}

set_realloc :: proc(set: ^Set) {
	old_entries := set.entries
	set.entries = make([]u64, len(old_entries) * 2)

	old_count := set.count
	set.count = 0
	for entry in old_entries {
		if entry != 0 {
			set_insert_assume_capacity(set, entry)
		}
		if set.count == old_count do break
	}
	// TODO Set stores allocator
	delete(old_entries)

}

@(test)
test_set :: proc(t: ^testing.T) {
	// Not tested: 0 value, as that's the default. Will fix when impl biasing
	set: Set
	set_init(&set, 2)
	set_insert(&set, 1)
	set_insert(&set, 11)
	set_insert(&set, 11)

	testing.expect(t, set_contains(set, 1))
	testing.expect(t, set_contains(set, 11))
	testing.expect(t, !set_contains(set, 111))
}
