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
	opts, perr := parse_opts()
	if perr != nil {
		fmt.eprintln("Options parsing error:", perr)
		os.exit(1)
	}
	filter: Set
	set_init(&filter, opts.initial_capacity.? or_else 16)

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

		if set_contains(filter, hash) {
			continue
		} else {
			set_insert(&filter, hash)
			bufio.writer_write(&w, line)
		}
	}
	bufio.writer_flush(&w)
}


Opts :: struct {
	initial_capacity: Maybe(int),
}

ParseError :: enum {
	Ok,
	UnsupportedOption,
	InitialCapacityNotInteger,
	OptionMissingValue,
}

parse_opts :: proc() -> (opts: Opts, err: ParseError) {
	for i := 1; i < len(os.args); {
		switch os.args[i] {
		case "--initial-capacity", "-c":
			if i == len(os.args) - 1 {
				// end of args. TODO if there's more flags, will need to check
				// if next value is a flag
				err = .OptionMissingValue;return
			}
			init_cap, pok := strconv.parse_int(os.args[i + 1])
			if !pok {
				err = .InitialCapacityNotInteger;return
			}
			opts.initial_capacity = init_cap
			i += 2
		case:
		}
	}
	return
}


Set :: struct {
	count:   int,
	entries: []u64,
}

set_init :: proc(set: ^Set, capacity: int) {
	set.entries = make([]u64, capacity)
}

// returns true if call sets entry. returns false if entry already exists
set_insert :: proc(set: ^Set, hash: u64) -> bool {
	// max load 50%
	if (set.count + 1) * 2 >= len(set.entries) {
		set_realloc(set)
	}
	idx := hash % cast(u64)len(set.entries)

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
		idx = (idx + 1) % cast(u64)len(set.entries)
	}
}

set_contains :: proc(set: Set, hash: u64) -> bool {
	idx := hash % cast(u64)len(set.entries)

	for {
		entry := set.entries[idx]
		if entry == hash {
			return true
		}
		if entry == 0 {
			return false
		}
		idx = (idx + 1) % cast(u64)len(set.entries)
	}
}

set_realloc :: proc(set: ^Set) {
	old_entries := set.entries
	set.entries = make([]u64, len(old_entries) * 2)
	for entry in old_entries {
		set_insert(set, entry)
	}
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
