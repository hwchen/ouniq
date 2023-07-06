// I think that the hashmap is much slower than in zig.
// Part of the reason is that we can't pre-hash the key.
// Another is that the hash itself is slow (not wyhash)
// If I cared, it would probably make the most sense to write a specialist hashset.

package ouniq

import "core:bufio"
import "core:bytes"
import "core:hash"
import "core:os"
import "core:strings"

main :: proc() {
    filter := make(map[u64]struct {})

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
        line_str := string(bytes.trim_right(line, []byte{'\r'}))

        // Adding this extra hash doesn't affect overall speed.
        // So probably the hashmap itself is slow.
        line_hash := hash.fnv64(transmute([]u8)line_str)

        if line_hash in filter {
            continue
        } else {
            filter[line_hash] = {}
            bufio.writer_write_string(&w, line_str)
        }
    }
    bufio.writer_flush(&w)
}
