build:
    odin build . -o:speed

benchmark:
    odin build . -o:speed && hyperfine --warmup 10 \
    'cat /usr/share/dict/words | ./ouniq' \
    'cat /usr/share/dict/words | ./ouniq --initial-capacity 4096_00' \
    'cat /usr/share/dict/words | zuniq -' \
    'cat /usr/share/dict/words | runiq --filter digest -' \
    'cat /usr/share/dict/words | runiq --filter naive -'

check-output:
    odin build . -o:speed && \
    cat /usr/share/dict/words | wc -l && \
    cat /usr/share/dict/words | ./ouniq | wc -l && \
    cat /usr/share/dict/words | zuniq - | wc -l
