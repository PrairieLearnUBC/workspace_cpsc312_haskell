#!/usr/bin/env bash

# Clean up after the ghcup install of HLS and ghc to reduce image size.
# Some of this may be dangerous!

clean_hls_variants() {
    # First, find which version of GHC we're using.
    VERSION=$(cd /home/coder/.ghcup && ls | head -n 1)

    # Now, delete everything but the needed version.
    cd /home/coder/.ghcup/hls/2.9.0.1/lib/haskell-language-server-2.9.0.1/lib
    for i in $(ls)
    do
        if [[ "${i}" != "${VERSION}" ]]
        then
            rm -r "${i}"
        fi
    done
}

clean_ghc_profiling_versions() {
    cd /home/coder/.ghcup/ghc
    find . -name '*_p.a' -exec rm {} \;
}

clean_hls_variants && clean_ghc_profiling_versions
