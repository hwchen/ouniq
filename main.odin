/// Hacky uniq implementation
/// - hard-codes the hashset capacity (will impl realloc in future if necessary)
/// - insert-only hashset
/// - pre-hashes line into digest and stores digest instead of bytestring. This makes collisions undetectable.
///
/// With this hackiness, it's pretty close to zig using StringHashMap and wyhash for digesting.

package ouniq

import "core:bufio"
import "core:bytes"
import "core:hash/xxhash"
import "core:os"
import "core:testing"

main :: proc() {
    filter: Set
    set_init(&filter, 4096 * 100)

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


Set :: struct {
    count:   int,
    entries: []u64,
}

set_init :: proc(set: ^Set, expected_count: int) {
    set.entries = make([]u64, expected_count * 2) // 50% load, no realloc
}

// returns true if call sets entry. returns false if entry already exists
set_insert :: proc(set: ^Set, hash: u64) -> bool {
    if set.count + 1 >= len(set.entries) do panic("Number of entries exceeded fixed-size buffer of set")
    idx := hash % cast(u64)len(set.entries)

    for {
        entry := &set.entries[idx]
        if entry^ == hash {
            return false
        }
        if entry^ == 0 {     // TODO should actually bias, in case there's a zero-value hash
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

@(test)
test_seqset :: proc(t: ^testing.T) {
    set: Set
    set_init(&set, 4)
    set_insert(&set, 0)
    set_insert(&set, 1)
    set_insert(&set, 11)
    set_insert(&set, 11)

    testing.expect(t, set_contains(set, 0))
    testing.expect(t, set_contains(set, 1))
    testing.expect(t, set_contains(set, 11))
}
