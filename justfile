bench:
    werk build -Dprofile=release && poop \
    'target/ouniq /usr/share/dict/words' \
    'zuniq /usr/share/dict/words'

hyperfine:
    werk build -Dprofile=release && hyperfine --warmup 10 \
    'cat /usr/share/dict/words | target/ouniq -' \
    'cat /usr/share/dict/words | zuniq -' \
    'cat /usr/share/dict/words | runiq --filter digest -' \

check-output:
    werk build && \
    cat /usr/share/dict/words | wc -l && \
    cat /usr/share/dict/words | target/ouniq - | wc -l && \
    cat /usr/share/dict/words | zuniq - | wc -l
