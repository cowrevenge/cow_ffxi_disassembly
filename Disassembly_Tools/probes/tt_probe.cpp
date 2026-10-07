// TODO(trace): TT/schedule ground-truth probe — includes LSB blowfish.cpp verbatim so the private
// TT() and subkey[] are visible; dumps a TT battery + full key-schedule trace for diffing vs Python.
// Path is relative to this file (cow_tools/) — third_party now lives under Archived_cowengine/.
#include "../Archived_cowengine/third_party/lsb/src/common/blowfish.cpp"
#include "common/md52.h"

#include <cstdio>
#include <cstring>

int main(int argc, char** argv) {
    const char* path = (argc > 1) ? argv[1] : "first_s2c.bin";
    std::fprintf(stderr, "cp0\n");
    FILE* fp = std::fopen(path, "rb");
    if (!fp) return 2;
    uint8_t key20[20];
    if (std::fread(key20, 1, 20, fp) != 20) return 2;
    std::fclose(fp);
    std::fprintf(stderr, "cp1\n");

    // ---- TT battery on the INITIAL tables (pre-schedule) ----
    const uint32* Sinit = reinterpret_cast<const uint32*>(subkey + 72);
    static const uint32 xs[] = { 0x00000000u, 0x00000001u, 0x000000FFu, 0x00000100u, 0x00010000u,
                                 0x01000000u, 0xFFFFFFFFu, 0xA5A5A5A5u, 0x084241E0u };
    for (uint32 x : xs) {
        std::fprintf(stderr, "cp-tt %08X\n", x);
        std::printf("TT(%08X)=%08X\n", x, TT(x, const_cast<uint32*>(Sinit)));
    }
    std::fprintf(stderr, "cp-battery-done\n");

    // ---- full schedule trace (mirrors LSB blowfish_init step by step) ----
    std::fprintf(stderr, "cp2\n");
    unsigned char hash[16];
    md5(key20, hash, 20);
    std::fprintf(stderr, "cp3\n");
    for (int i = 0; i < 16; ++i) {
        if (hash[i] == 0) { std::memset(hash + i, 0, 16 - i); break; }
    }
    uint32 P[18];
    memcpy(P, subkey, 72);
    int j = 0;
    for (int i = 0; i < 18; ++i) {
        uint32 data = 0;
        for (int k = 0; k < 4; ++k) {
            data = (data << 8) | hash[j];
            if (++j >= 16) j = 0;
        }
        P[i] ^= data;
    }
    uint32 S[4][256];
    memcpy(S, subkey + 72, 4096);
    std::fprintf(stderr, "cp4\n");

    uint32 dl = 0, dr = 0;
    for (int i = 0; i < 18; i += 2) {
        std::fprintf(stderr, "cp-enc %d\n", i);
        blowfish_encipher(&dl, &dr, P, S[0]);
        std::fprintf(stderr, "enc[%d] = %08X %08X\n", i / 2, dl, dr);
        P[i]     = dl;
        P[i + 1] = dr;
    }
    for (int b = 0; b < 4; ++b) {
        for (int jj = 0; jj < 256; jj += 2) {
            blowfish_encipher(&dl, &dr, P, S[b]);
            S[b][jj]     = dl;
            S[b][jj + 1] = dr;
        }
    }
    std::fprintf(stderr, "cp-sdone\n");
    std::fprintf(stderr, "final P[0..5]:");
    for (int i = 0; i < 6; ++i) std::printf(" %08X", P[i]);
    std::printf("\nS[0][0..3]:");
    for (int i = 0; i < 4; ++i) std::printf(" %08X", S[0][i]);
    std::printf("\n");
    return 0;
}
