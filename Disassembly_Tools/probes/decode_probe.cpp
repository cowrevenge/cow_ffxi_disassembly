// TODO(trace): offline decode probe — runs the *exact* LSB verbatim crypto (blowfish/md5/pack)
// on a [key20][frame] capture and prints intermediates for diffing against the Python port.
// Usage: decode_probe.exe <capture.bin>   (run from repo root; reads data/zlib_tables).
#include "common/blowfish.h"
#include "common/md52.h"
#include "net/fxi_pack.h"

#include <cstdio>
#include <cstring>
#include <vector>

// defined in the verbatim LSB blowfish.cpp (not exposed via header; TT stays private,
// we compare through blowfish_encipher instead)
extern uint8 subkey[4168];

int main(int argc, char** argv) {
    const char* path = (argc > 1) ? argv[1] : "first_s2c.bin";
    FILE* fp = std::fopen(path, "rb");
    if (!fp) { std::fprintf(stderr, "no file %s\n", path); return 2; }
    std::fseek(fp, 0, SEEK_END);
    const long fsize = std::ftell(fp);
    std::fseek(fp, 0, SEEK_SET);
    std::vector<uint8_t> blob(static_cast<size_t>(fsize));
    if (std::fread(blob.data(), 1, blob.size(), fp) != blob.size()) return 2;
    std::fclose(fp);

    const uint32_t* key = reinterpret_cast<const uint32_t*>(blob.data());
    size_t n            = blob.size() - 20;
    uint8_t* buf        = blob.data() + 20;

    // ---- MapSession::initBlowfish, verbatim ----
    uint32_t P[18];
    uint32   S[4][256];
    unsigned char hash[16];
    md5(reinterpret_cast<unsigned char*>(blob.data()), hash, 20);
    for (int i = 0; i < 16; ++i) {
        if (hash[i] == 0) { std::memset(hash + i, 0, 16 - i); break; }
    }
    std::printf("derived key16:");
    for (int i = 0; i < 16; ++i) std::printf(" %02x", hash[i]);
    std::printf("\n");
    // ---- manual schedule trace (mirrors LSB blowfish_init step by step) ----
    uint32_t Pt[18];
    uint32   St[4][256];
    std::memcpy(Pt, subkey, 72);
    std::memcpy(St, subkey + 72, 4096);
    int jj = 0;
    for (int i = 0; i < 18; ++i) {
        uint32_t data = 0;
        for (int k = 0; k < 4; ++k) {
            data = (data << 8) | hash[jj];
            if (++jj >= 16) jj = 0;
        }
        Pt[i] ^= data;
    }
    std::printf("after keyxor P[0..3]:");
    for (int i = 0; i < 4; ++i) std::printf(" %08x", Pt[i]);
    std::printf("\n");
    uint32 tl = 0, tr = 0;
    blowfish_encipher(&tl, &tr, Pt, St[0]);
    std::printf("enc(0,0) after keyxor: %08x %08x\n", tl, tr);

    blowfish_init(reinterpret_cast<const int8*>(hash), 16, P, S[0]);
    std::printf("P[0..5]:");
    for (int i = 0; i < 6; ++i) std::printf(" %08x", P[i]);
    std::printf("\nS[0][0..7]:");
    for (int i = 0; i < 8; ++i) std::printf(" %08x", S[0][i]);
    std::printf("\n");

    // ---- decrypt exactly like framing.cpp parseFrame does ----
    const size_t O   = 0x1C;
    uint16_t tmp     = static_cast<uint16_t>((n - O) / 4);
    tmp             -= tmp % 2;
    blowfish_decipher_blocks(reinterpret_cast<uint32_t*>(buf) + 7, tmp / 2, P, S[0]);

    unsigned char h2[16];
    md5(buf + O, h2, static_cast<int>(n - (O + 16)));
    const bool ok = std::memcmp(h2, buf + n - 16, 16) == 0;
    std::printf("dec md5: %s\n", ok ? "OK" : "FAIL");
    if (!ok) return 3;

    // ---- decompress (current C++ semantics incl. bounds check) + sub-walk ----
    const uint32_t bitSize = *reinterpret_cast<const uint32_t*>(buf + n - 20);
    const size_t   packedLen = n - O - sizeof(uint32_t) - 16;
    std::printf("bitSize=%u packed_len=%zu expected_bits=%zu\n", bitSize, packedLen, packedLen * 8);
    if (!cow::pack::init("data/zlib_tables/compress.dat", "data/zlib_tables/decompress.dat")) {
        std::fprintf(stderr, "pack tables missing (run from repo root)\n");
        return 4;
    }
    std::vector<uint8_t> region(buf + O, buf + n - 20);
    std::vector<uint8_t> unpacked;
    if (!cow::pack::decompress(region.data(), region.size(), bitSize, unpacked, 4096)) {
        std::printf("decompress: FAIL (bounds/depth)\n");
        return 5;
    }
    std::printf("unpacked[%zu] first16:", unpacked.size());
    for (size_t i = 0; i < 16 && i < unpacked.size(); ++i) std::printf(" %02X", unpacked[i]);
    std::printf("\n");
    size_t off = 0;
    std::printf("subs(%zu):", unpacked.size());
    while (off + 2 <= unpacked.size()) {
        if ((unpacked[off + 1] & 0xFE) == 0) break;
        const uint16_t hdr   = *reinterpret_cast<const uint16_t*>(unpacked.data() + off);
        const size_t fullLen = (unpacked[off + 1] & 0xFE) * 2;
        std::printf(" %X", hdr & 0x1FF);
        if (fullLen < 4 || off + fullLen > unpacked.size()) break;
        off += fullLen;
    }
    std::printf("\n");
    return 0;
}
