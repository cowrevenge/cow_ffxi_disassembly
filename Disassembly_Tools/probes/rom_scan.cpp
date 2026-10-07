// TODO(assets): FFXI ROM .DAT structure scanner — census of 4-byte chunk tags per table directory.
// Empirical layout (see docs/ROM-LAYOUT.md): each .DAT starts with a file-type tag at offset 0 and a
// ~32-byte header, followed by chunks [4c ascii tag][u32 size LE][payload]. This tool aggregates the
// tags so we can map which ROM table directories hold maps / models / textures.
// Usage: rom_scan.exe <gameRoot|romDir> [maxBytesPerFile]
#include <algorithm>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <filesystem>
#include <map>
#include <string>
#include <vector>

namespace fs = std::filesystem;

static bool isTag(const uint8_t* p) {
    for (int i = 0; i < 4; ++i)
        if (p[i] < 32 || p[i] > 126) return false; // printable ASCII only
    return true;
}

static std::string tagStr(const uint8_t* p) { return std::string(reinterpret_cast<const char*>(p), 4); }

int main(int argc, char** argv) {
    if (argc < 2) { std::fprintf(stderr, "usage: rom_scan.exe <gameRoot|romDir> [maxBytesPerFile]\n"); return 2; }
    const fs::path root = argv[1];
    const size_t cap = argc > 2 ? static_cast<size_t>(std::atol(argv[2])) : 262144;

    std::map<std::string, std::map<std::string, long>> hist; // "rom/table" -> tag histogram
    std::map<std::string, long> fileCount;
    long totalFiles = 0;

    struct TableDir { fs::path path; std::string key; };
    std::vector<TableDir> tableDirs;
    if (fs::is_directory(root / "0")) {
        tableDirs.push_back({root, root.filename().string()}); // called directly with a ROM dir
    } else {
        for (const auto& rom : fs::directory_iterator(root))
            if (rom.is_directory())
                for (const auto& sub : fs::directory_iterator(rom.path()))
                    if (sub.is_directory()) tableDirs.push_back({sub.path(), rom.path().filename().string() + "/" + sub.path().filename().string()});
    }

    for (const auto& td : tableDirs) {
        const std::string tname = td.key;
        for (const auto& f : fs::directory_iterator(td.path)) {
            if (!f.is_regular_file() || !f.path().extension().generic_string().ends_with(".DAT")) continue;
            ++fileCount[tname];
            ++totalFiles;

            std::FILE* fp = std::fopen(f.path().string().c_str(), "rb");
            if (!fp) continue;
            long fsize = 0;
            std::fseek(fp, 0, SEEK_END);
            fsize = std::ftell(fp);
            std::fseek(fp, 0, SEEK_SET);
            const size_t n = static_cast<size_t>(std::min<long>(fsize, (long)cap));
            std::vector<uint8_t> buf(n);
            if (n && std::fread(buf.data(), 1, n, fp) != n) { std::fclose(fp); continue; }
            std::fclose(fp);

            // file-type tag @0
            if (n >= 4 && isTag(buf.data())) ++hist[tname][tagStr(buf.data())];

            // walk chunks from the end of the header: [4c tag][u32 size][payload]
            size_t off = 32;
            int seen = 0;
            while (off + 8 <= n && ++seen < 64) {
                if (!isTag(buf.data() + off)) break;
                const uint32_t sz = *reinterpret_cast<const uint32_t*>(buf.data() + off + 4);
                ++hist[tname][tagStr(buf.data() + off)];
                if (sz == 0 || static_cast<size_t>(sz) > n - off - 8) break; // sanity: size must fit
                off += 8 + sz;
            }
        }
    }

    std::printf("scanned %ld files\n", totalFiles);
    for (const auto& [tname, counts] : fileCount) {
        const auto& h = hist[tname]; // empty if no tags parsed
        std::string summary;
        size_t shown = 0;
        for (const auto& [tag, c] : h) {
            if (++shown > 24) break;
            if (!summary.empty()) summary += " ";
            char part[96];
            std::snprintf(part, sizeof(part), "%s:%ld", tag.c_str(), c);
            summary += part;
        }
        std::printf("table %-16s files=%-7ld %s\n", tname.c_str(), counts, summary.c_str());
    }
    return 0;
}
