benchmark:
    odin build . -o:speed && hyperfine --warmup 10 \
    'cat /usr/share/dict/words | ./ouniq.bin' \
    'cat /usr/share/dict/words | zuniq -' \
    'cat /usr/share/dict/words | runiq -'
