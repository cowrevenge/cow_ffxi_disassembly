// TODO(trace): offline spawn probe — walks an s2c_raw.bin capture with the EXACT MapClient::poll
// state machine (raw-md5 match or blowfish decrypt, bf increment after any frame containing s2c 0x0B),
// decodes sub-0A's GP_SERV_POS_HEAD (LSB src/map/packets/s2c/0x00a_login.h) and prints the spawn.
// Usage: spawn_probe.exe [key20.bin] [s2c_raw.bin]   (defaults: map_key.bin, s2c_raw.bin; run from repo root)
#include "net/fxi_pack.h"
#include "net/framing.h"

#include <cstdint>
#include <cstdio>
#include <cstring>
#include <vector>

static void hexline(const uint8_t* p, size_t n) {
    for (size_t i = 0; i < n; ++i) std::printf("%02X ", p[i]);
    std::printf("\n");
}

int main(int argc, char** argv) {
    std::setvbuf(stdout, nullptr, _IONBF, 0); // don't lose frame logs on a crash
    const char* keyPath = argc > 1 ? argv[1] : "map_key.bin";
    const char* rawPath = argc > 2 ? argv[2] : "s2c_raw.bin";

    std::vector<uint8_t> key;
    if (FILE* f = std::fopen(keyPath, "rb")) {
        std::fseek(f, 0, SEEK_END);
        const long sz = std::ftell(f);
        std::fseek(f, 0, SEEK_SET);
        key.resize(static_cast<size_t>(sz));
        if (std::fread(key.data(), 1, key.size(), f) != key.size()) return 2;
        std::fclose(f);
    }
    if (key.size() != 20) { std::fprintf(stderr, "bad key file %s (%zu bytes)\n", keyPath, key.size()); return 2; }

    std::vector<uint8_t> blob; // [u32len][bytes] entries, appended across runs
    if (FILE* f = std::fopen(rawPath, "rb")) {
        std::fseek(f, 0, SEEK_END);
        const long sz = std::ftell(f);
        std::fseek(f, 0, SEEK_SET);
        blob.resize(static_cast<size_t>(sz));
        if (std::fread(blob.data(), 1, blob.size(), f) != blob.size()) return 2;
        std::fclose(f);
    } else { std::fprintf(stderr, "no capture %s\n", rawPath); return 2; }

    if (!cow::pack::init("data/zlib_tables/compress.dat", "data/zlib_tables/decompress.dat"))
        return 4; // run from repo root

    cow::fx::BlowfishSession bf = {};
    std::memcpy(bf.key, key.data(), 20);
    bf.init();

    size_t off = 0;
    int    idx = 0;
    bool   found = false;
    while (off + 4 <= blob.size()) {
        const uint32_t len = *reinterpret_cast<const uint32_t*>(blob.data() + off);
        if (len == 0 || off + 4 + static_cast<size_t>(len) > blob.size()) break;
        const uint8_t* dg = blob.data() + off + 4;

        std::vector<uint8_t> region;
        cow::fx::Frame       f;
        const bool           ok = cow::fx::parseFrame(dg, static_cast<size_t>(len), bf, region, f);
        if (!ok) {
            std::printf("frame %3d: %4u bytes -> FAIL (other run / stale key)\n", idx++, len);
        } else {
            std::printf("frame %3d: %4u bytes -> OK outer=%u subs=%zu\n", idx++, len, f.outerCode, f.subs.size());
            bool inc = false;
            for (const auto& s : f.subs) {
                if (s.id == 0x0B) inc = true;
                std::printf("   sub %03X seq=%u len=%zu\n", s.id, s.seq, s.len);
                if (s.id == 0x0A && s.len >= 28 && !found) {
                    // GP_SERV_POS_HEAD: u32 UniqueNo @0, i8 dir @7, f32 x@8, f32 z(=up)@12, f32 y(world Z)@16
                    const uint8_t* p = s.data;
                    const uint32_t uniqueNo = *reinterpret_cast<const uint32_t*>(p);
                    const int8_t   dir      = static_cast<int8_t>(p[7]);
                    const float    x        = *reinterpret_cast<const float*>(p + 8);
                    const float    zUp      = *reinterpret_cast<const float*>(p + 12);
                    const float    yWZ      = *reinterpret_cast<const float*>(p + 16);
                    std::printf("   [spawn] uniqueNo=%u dir=%d raw=%02X x=%.4f up=%.4f z=%.4f\n", uniqueNo, dir, p[7], x,
                                zUp, yWZ);
                    hexline(p, s.len > 96 ? 96 : s.len);
                    found = true;
                }
            }
            if (inc) bf.increment(); // mirrors MapClient::poll: key bump after a frame containing s2c 0x0B
        }
        off += 4 + static_cast<size_t>(len);
    }
    std::printf(found ? "spawn decoded OK\n" : "no sub-0A parsed with this key (stale map_key.bin?)\n");
    return found ? 0 : 3;
}
